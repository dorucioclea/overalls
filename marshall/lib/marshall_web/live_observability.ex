defmodule MarshallWeb.LiveObservability do
  @moduledoc """
  Reviewed traces and metrics for every Marshall LiveView callback.

  Phoenix spans mount, `handle_params` and `handle_event`, including their
  `on_mount` and attached hooks. `use MarshallWeb, :live_view` adds the same
  Telemetry span around `handle_info`. Each becomes one
  `marshall.live.callback` span and one `[:marshall, :live, :callback]`
  measurement, labelled only by the view's registered label and the callback
  phase, with the callback's duration and its own process's database queries.

  The same callbacks are the `marshall_live` service-level source: each is
  admitted to the independent request recorder through `Marshall.LiveRecorder`
  before it runs and settled once, as a success when it returns and a failure
  when it raises, throws or exits. The recorder settles a callback whose
  process dies as a failure.
  """
  alias Overalls.Diagnostics.{Metrics, Tracing}
  alias Overalls.RequestAccounting.Producer

  # Literal labels keep every view in the reviewed trace vocabulary; the
  # registry test fails when a LiveView is added without one.
  @views %{
    MarshallWeb.AccountLive => :account_live,
    MarshallWeb.AgentCLIApprovalLive => :agent_cli_approval_live,
    MarshallWeb.AgentThreadsLive => :agent_threads_live,
    MarshallWeb.ArtifactsLive => :artifacts_live,
    MarshallWeb.AutomaticMagicSignInLive => :automatic_magic_sign_in_live,
    MarshallWeb.GitLive => :git_live,
    MarshallWeb.HLDDLive => :hldd_live,
    MarshallWeb.InferenceLive => :inference_live,
    MarshallWeb.IntegrationsLive => :integrations_live,
    MarshallWeb.LaunchLive => :launch_live,
    MarshallWeb.MachineProvisioningLive => :machine_provisioning_live,
    MarshallWeb.MachinesLive => :machines_live,
    MarshallWeb.MessageBoardLive => :message_board_live,
    MarshallWeb.OverviewLive => :overview_live,
    MarshallWeb.ResizeLive => :resize_live,
    MarshallWeb.ScimSignInLive => :scim_sign_in_live,
    MarshallWeb.SSHApprovalLive => :ssh_approval_live,
    MarshallWeb.TeamsLive => :teams_live,
    MarshallWeb.TerminalLive => :terminal_live,
    MarshallWeb.ThreadsLive => :threads_live,
    MarshallWeb.Admin.AccessLive => :admin_access_live,
    MarshallWeb.Admin.ArtifactsLive => :admin_artifacts_live,
    MarshallWeb.Admin.AuditLive => :admin_audit_live,
    MarshallWeb.Admin.GitLive => :admin_git_live,
    MarshallWeb.Admin.JobsLive => :admin_jobs_live,
    MarshallWeb.Admin.LillyNodesLive => :admin_lilly_nodes_live,
    MarshallWeb.Admin.OperationsLive => :admin_operations_live,
    MarshallWeb.Admin.RedactionLive => :admin_redaction_live,
    MarshallWeb.Admin.ScimLive => :admin_scim_live,
    MarshallWeb.Admin.UsersLive => :admin_users_live,
    MarshallWeb.Admin.WorkloadsLive => :admin_workloads_live
  }
  @unregistered :unregistered_live_view
  @phases [:mount, :handle_params, :handle_event, :handle_info]
  @handler __MODULE__

  @type label :: atom()
  @type phase :: :mount | :handle_params | :handle_event | :handle_info

  @doc "The registered label of every Marshall LiveView module."
  @spec views() :: %{module() => label()}
  def views, do: @views

  @doc "A view's registered label, or the closed unregistered label."
  @spec label(module()) :: label()
  def label(view), do: Map.get(@views, view, @unregistered)

  @doc "Attach the callback handlers once; reattaching replaces the previous ones."
  @spec attach() :: :ok
  def attach do
    _ = :telemetry.detach(@handler)

    events =
      for phase <- @phases, suffix <- [:start, :stop, :exception] do
        if phase == :handle_info,
          do: [:marshall, :live_view, phase, suffix],
          else: [:phoenix, :live_view, phase, suffix]
      end

    :ok = :telemetry.attach_many(@handler, events, &__MODULE__.handle/4, nil)
  end

  @doc false
  defmacro __before_compile__(env) do
    if Module.defines?(env.module, {:handle_info, 2}) do
      quote do
        defoverridable handle_info: 2

        @impl true
        def handle_info(message, socket) do
          MarshallWeb.LiveObservability.handle_info(socket, fn -> super(message, socket) end)
        end
      end
    end
  end

  # @cc [owner:ghuntley,label:observability;security] live-callback-span-closed
  # A wrapped handle_info MUST run the view's callback exactly once and return
  # its exact result or exception. Telemetry metadata MUST carry only the socket,
  # never the message.
  @doc false
  @spec handle_info(Phoenix.LiveView.Socket.t(), (-> result)) :: result when result: term()
  def handle_info(socket, callback) when is_function(callback, 0) do
    :telemetry.span([:marshall, :live_view, :handle_info], %{socket: socket}, fn ->
      {callback.(), %{socket: socket}}
    end)
  end

  # @cc [owner:ghuntley,label:observability;security] live-callback-measurement
  # Every LiveView mount, handle_params, handle_event and handle_info MUST
  # produce one span and one measurement carrying only the view's closed label,
  # the phase, the duration and the callback process's query count. Event names,
  # params, session, URI, messages and assigns MUST NOT be recorded. A handler
  # failure MUST NOT raise into the LiveView or detach the handler.

  # @cc [owner:ghuntley,label:reliability;security] live-callback-service-level
  # Each callback MUST be admitted to Marshall.LiveRecorder before it runs and
  # settled exactly once: success on return, failure on raise, throw or exit.
  # An unavailable recorder MUST leave the callback unrecorded, never succeed
  # it, and MUST NOT change the callback's execution or result.
  @doc false
  @spec handle([atom()], map(), map(), term()) :: :ok
  def handle([_, :live_view, phase, :start], _measurements, metadata, _config)
      when phase in @phases do
    with %{socket: %{view: view}, telemetry_span_context: context} <- metadata do
      ticket = Producer.admit(Marshall.LiveRecorder)

      span =
        Tracing.start("marshall.live.callback", live_view: label(view), phase: phase)

      Process.put(
        {__MODULE__, context},
        {span, Marshall.Observability.begin_queries(), ticket}
      )
    end

    :ok
  catch
    _, _ -> :ok
  end

  def handle([_, :live_view, phase, outcome], measurements, metadata, _config)
      when phase in @phases and outcome in [:stop, :exception] do
    with %{socket: %{view: view}, telemetry_span_context: context} <- metadata,
         {span, outer, ticket} <- Process.delete({__MODULE__, context}) do
      queries = Marshall.Observability.end_queries(outer)
      duration = max(Map.get(measurements, :duration, 0), 0)
      status = if outcome == :stop, do: :ok, else: :error

      failure =
        if outcome == :exception,
          do: [reason: exception_reason(metadata[:kind], metadata[:reason])],
          else: []

      :ok =
        Producer.complete(
          Marshall.LiveRecorder,
          ticket,
          if(outcome == :stop, do: :success, else: :failure),
          System.convert_time_unit(duration, :native, :microsecond)
        )

      :ok = Tracing.finish(span, status, [query_count: queries] ++ failure)

      _ =
        Metrics.record(
          [:marshall, :live, :callback],
          %{duration: duration, queries: queries},
          %{live_view: label(view), phase: phase}
        )
    end

    :ok
  catch
    _, _ -> :ok
  end

  def handle(_event, _measurements, _metadata, _config), do: :ok

  @type exception_reason ::
          :db_unavailable
          | :deadlock
          | :lock_timeout
          | :statement_timeout
          | :database_error
          | :ash_error
          | :exit
          | :throw
          | :other

  # @cc [owner:ghuntley,label:observability;security] live-callback-exception-reason
  # A failed callback span MUST carry exactly one closed exception reason derived
  # from the exception's kind and struct module, unwrapping Ash error classes and
  # the leading module and PostgreSQL condition name Ash keeps when it
  # stringifies a foreign exception. The message, query, parameters and
  # stacktrace MUST NOT be recorded.
  @doc "The closed failure reason a failed callback span records."
  @spec exception_reason(term(), term()) :: exception_reason()
  def exception_reason(:exit, _reason), do: :exit
  def exception_reason(:throw, _reason), do: :throw
  def exception_reason(:error, reason), do: classify(reason, 4)
  def exception_reason(_kind, _reason), do: :other

  @spec classify(term(), non_neg_integer()) :: exception_reason()
  defp classify(%DBConnection.ConnectionError{}, _depth), do: :db_unavailable
  defp classify(%DBConnection.OwnershipError{}, _depth), do: :db_unavailable
  defp classify(%Postgrex.Error{postgres: %{code: :deadlock_detected}}, _depth), do: :deadlock

  defp classify(%Postgrex.Error{postgres: %{code: :lock_not_available}}, _depth),
    do: :lock_timeout

  defp classify(%Postgrex.Error{postgres: %{code: :query_canceled}}, _depth),
    do: :statement_timeout

  defp classify(%Postgrex.Error{}, _depth), do: :database_error

  defp classify("** (" <> rest, _depth) do
    case String.split(rest, ")", parts: 2) do
      ["DBConnection.ConnectionError" | _] -> :db_unavailable
      ["DBConnection.OwnershipError" | _] -> :db_unavailable
      ["Postgrex.Error", detail] -> postgres_condition(detail)
      _ -> :other
    end
  end

  defp classify(%{__exception__: true} = error, depth) when depth > 0 do
    nested =
      error
      |> Map.get(:errors, [])
      |> List.wrap()
      |> Kernel.++(List.wrap(Map.get(error, :error)))
      |> Enum.map(&classify(&1, depth - 1))
      |> Enum.reject(&(&1 in [:ash_error, :other]))

    case nested do
      [reason | _] -> reason
      [] -> if ash_error?(error), do: :ash_error, else: :other
    end
  end

  defp classify(%{__exception__: true} = error, _depth),
    do: if(ash_error?(error), do: :ash_error, else: :other)

  defp classify(_reason, _depth), do: :other

  @spec postgres_condition(String.t()) :: exception_reason()
  defp postgres_condition(detail) do
    cond do
      String.contains?(detail, "(deadlock_detected)") -> :deadlock
      String.contains?(detail, "(lock_not_available)") -> :lock_timeout
      String.contains?(detail, "(query_canceled)") -> :statement_timeout
      true -> :database_error
    end
  end

  @spec ash_error?(Exception.t()) :: boolean()
  defp ash_error?(%module{}), do: match?(["Ash", "Error" | _], Module.split(module))
end
