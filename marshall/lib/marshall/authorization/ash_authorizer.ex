defmodule Marshall.Authorization.AshAuthorizer do
  @moduledoc """
  Ash entry-point authorization through the compiled Cedar engine.

  Internal mutations have no user policy. Explicit public generic actions admit
  signed-in users; their coordinators apply fresh record-specific Cedar checks.
  Adding an Ash action does not grant it access.
  """
  use Ash.Authorizer
  alias Marshall.Authorization.Cedar

  @internal %{
    Marshall.SSH.HostCertificate => [
      :read,
      :record,
      :issue,
      :fail,
      :retry,
      :supersede,
      :request,
      :prune,
      :purge
    ],
    Marshall.Ingress.FleetCertificate => [
      :read,
      :enqueue,
      :save_request,
      :mark_order_attempt,
      :bind_order,
      :record_proof,
      :refresh_proof,
      :finish_issued,
      :activate,
      :retire,
      :fail,
      :fail_unknown_order,
      :progress,
      :ensure_due,
      :deliver,
      :acknowledge,
      :audit
    ],
    Marshall.Ingress.FleetCertificateInstallation => [:read, :record, :rebind_service],
    Marshall.Ingress.FleetCertificateInstallation.Version => [:read, :create],
    Marshall.Ingress.FleetCertificate.Version => [:read, :create],
    Marshall.Ingress.FleetCertificateAccount => [:read, :register],
    Marshall.Ingress.FleetCertificateAccount.Version => [:read, :create],
    Marshall.Enrico.Repository => [
      :read,
      :register,
      :begin_refresh,
      :publish,
      :fail,
      :request_remove,
      :remove
    ],
    Marshall.Enrico.AuditEvent => [:read, :record],
    Marshall.Agents.Root => [:read, :register],
    Marshall.Agents.Root.Version => [:read, :create],
    Marshall.Agents.Thread => [:read, :open, :advance, :set_mode, :set_context, :delete],
    Marshall.Agents.Thread.Version => [:read, :create],
    Marshall.Agents.Turn => [:read, :enqueue, :transition],
    Marshall.Agents.Event => [:read, :append],
    Marshall.Agents.Executor => [:read, :register, :heartbeat, :invalidate],
    Marshall.Agents.Command => [:read, :queue, :transition],
    Marshall.Agents.ModelCall => [:read, :queue, :transition],
    Marshall.Agents.CLISession => [:read, :approve, :expire],
    Marshall.Agents.AuditEvent => [:read, :record],
    Marshall.Agents.SearchCache => [:read],
    Marshall.Agents.SearchUsage => [:read, :record],
    Marshall.Agents.ContextSnapshot => [:read, :capture],
    Marshall.Agents.ContextCheckpoint => [:read, :install],
    Marshall.Agents.PlanningQuestion => [:read, :request, :resolve, :cancel],
    Marshall.Agents.PlanProposal => [:read, :record, :implement],
    Marshall.Agents.SkillInstallation => [:read, :register, :publish, :configure, :fail],
    Marshall.Agents.SkillRevision => [:read, :record],
    Marshall.MessageBoards.Board => [:read, :open],
    Marshall.MessageBoards.Post => [:read, :post, :destroy],
    Marshall.Agents.ThreadSubscription => [:read, :subscribe, :activate, :deactivate, :revoke],
    Marshall.Agents.ThreadReceiver => [
      :read,
      :register,
      :activate,
      :deactivate,
      :acknowledge,
      :defer
    ],
    Marshall.Agents.ThreadNotification => [:read, :append],
    Marshall.Agents.AttachmentAudit => [:read, :record],
    Marshall.Agents.AttachmentChunk => [:read, :store, :destroy],
    Marshall.Agents.SkillOperation => [:read, :record, :dispatch, :finish],
    Marshall.Agents.Attachment => [
      :read,
      :create_pending,
      :begin_upload,
      :touch_upload,
      :publish,
      :quarantine,
      :fail,
      :begin_delete,
      :finish_delete
    ],
    Marshall.Threads.Thread => [
      :read,
      :history,
      :open,
      :record_admitted_machine,
      :begin_provisioning,
      :bind_agent,
      :mark_ready,
      :mark_failed,
      :requeue,
      :replace_generation,
      :mark_archived,
      :mark_deleting,
      :reopen,
      :set_title,
      :set_collaboration_mode_state,
      :touch_activity,
      :archive
    ],
    Marshall.Threads.Grant => [:read, :history, :grant, :mark_revoked, :revoke],
    Marshall.Threads.Grant.Version => [:read, :create],
    Marshall.Threads.AccessChange => [:read, :record],
    Marshall.Threads.Generation => [:read, :open, :bind, :state],
    Marshall.Threads.ReadMarker => [:read, :record, :advance],
    Marshall.Artifacts.Artifact => [
      :read,
      :create,
      :advance,
      :request_delete,
      :admin_delete,
      :finish_delete
    ],
    Marshall.Artifacts.Artifact.Version => [:read, :create],
    Marshall.Artifacts.Version => [:read, :record],
    Marshall.Artifacts.VersionFile => [:read, :record],
    Marshall.Artifacts.Blob => [:read],
    Marshall.Artifacts.Grant => [:read, :history, :grant, :revoke],
    Marshall.Artifacts.Grant.Version => [:read, :create],
    Marshall.Artifacts.AccessChange => [:read, :record],
    Marshall.Artifacts.StorageEntry => [:read, :put, :replace, :destroy],
    Marshall.Artifacts.StorageUsage => [:read, :open, :adjust],
    Marshall.Artifacts.ViewTicket => [:read, :issue, :expire, :revoke, :destroy],
    Marshall.Artifacts.PublishRequest => [
      :read,
      :open,
      :attach_stage,
      :commit,
      :refuse,
      :expire
    ],
    Marshall.Artifacts.AuditEvent => [:read, :record],
    Marshall.Compute.WakeRequest => [:read, :request, :advance],
    Marshall.Compute.WakeRequestKey => [:read, :record],
    Marshall.Compute.LifecycleEvent => [:read, :record, :expire],
    Marshall.Galileo.Credential => [:read, :issue, :revoke],
    Marshall.Galileo.Credential.Version => [:read, :create],
    Marshall.Peach.Credential => [:read, :issue, :revoke],
    Marshall.Peach.Credential.Version => [:read, :create],
    Marshall.Galileo.Integration => [:read, :register, :edit, :archive, :history],
    Marshall.Galileo.Integration.Version => [:read, :create],
    Marshall.Galileo.IntegrationHeader => [:read, :record, :remove],
    Marshall.Galileo.Attachment => [:read, :attach, :detach, :history],
    Marshall.Galileo.Attachment.Version => [:read, :create],
    Marshall.GitHub.Connection => [
      :read,
      :register,
      :authorize,
      :connect,
      :drain,
      :start_refresh,
      :refresh,
      :require_reconnect,
      :disconnect,
      :revoked,
      :invalidate_restored
    ],
    Marshall.GitHub.AuthorizationAttempt => [
      :read,
      :record,
      :exchange,
      :consume,
      :fail,
      :cancel,
      :purge,
      :stage_result,
      :clear_result
    ],
    Marshall.GitHub.RefreshAttempt => [
      :read,
      :record,
      :submit,
      :stage,
      :finish,
      :fail,
      :purge,
      :retain_result,
      :clear_result
    ],
    Marshall.GitHub.Exclusion => [:read, :exclude, :remove],
    Marshall.GitHub.RequestLease => [:read, :record, :renew, :close, :purge],
    Marshall.GitHub.RestoreEpoch => [:read, :record, :apply_epoch],
    Marshall.GitHub.AuditEvent => [:read, :record],
    Marshall.Agents.ToolBootstrap => [
      :read,
      :queue,
      :reset,
      :claim,
      :start,
      :complete,
      :fail,
      :uncertain
    ],
    Marshall.Agents.ToolMaintenance => [
      :read,
      :queue,
      :reset,
      :claim,
      :start,
      :complete,
      :fail,
      :uncertain
    ],
    Marshall.Teams.Team => [:read, :register, :archive, :history, :mark_retiring],
    Marshall.Teams.Team.Version => [:read, :create],
    Marshall.Teams.TeamMember => [:read, :record, :replace_role, :remove, :history],
    Marshall.Teams.TeamMember.Version => [:read, :create],
    Marshall.Teams.Transfer => [:read, :offer, :accept, :decline, :cancel, :archive, :history],
    Marshall.Teams.Transfer.Version => [:read, :create],
    Marshall.Inference.Daily => [:read, :record, :add, :purge],
    Marshall.Inference.Credential => [:read, :issue, :ensure, :revoke],
    Marshall.Inference.Credential.Version => [:read, :create],
    Marshall.Inference.Request.Version => [:read, :create],
    Marshall.Inference.Request => [:read, :record, :renew, :complete, :purge, :prune],
    Marshall.Ingress.EnvironmentStream => [
      :read,
      :record,
      :renew,
      :close,
      :purge,
      :prune,
      :open_nested,
      :renew_nested,
      :close_nested
    ],
    Marshall.Ingress.EnvironmentStream.Version => [:read, :create],
    Marshall.Ingress.EnvironmentPublication => [:read, :record, :advance],
    Marshall.Ingress.Environment => [:read, :record, :change_policy, :current_ssh],
    Marshall.Ingress.Environment.Version => [:read, :create],
    Marshall.Ingress.WebLogin => [
      :read,
      :record,
      :approve,
      :consume,
      :purge,
      :begin_login,
      :exchange_login
    ],
    Marshall.Ingress.WebLogin.Version => [:read, :create],
    Marshall.Ingress.WebStream => [
      :prune,
      :read,
      :record,
      :renew,
      :close,
      :purge,
      :open_web,
      :open_peer_web,
      :renew_web,
      :close_web
    ],
    Marshall.Ingress.WebStream.Version => [:read, :create],
    Marshall.Ingress.WebCredential => [:read, :record, :revoke, :purge],
    Marshall.Ingress.WebCredential.Version => [:read, :create],
    Marshall.Editor.Login => [
      :read,
      :record,
      :approve,
      :consume,
      :purge,
      :begin_login,
      :exchange_login
    ],
    Marshall.Editor.Login.Version => [:read, :create],
    Marshall.Editor.Credential => [:read, :record, :revoke, :purge],
    Marshall.Editor.Credential.Version => [:read, :create],
    Marshall.Editor.Lease => [
      :read,
      :record,
      :renew,
      :close,
      :purge,
      :prune,
      :open_editor,
      :renew_editor,
      :close_editor
    ],
    Marshall.Editor.Lease.Version => [:read, :create],
    Marshall.Ingress.EditorAssetsReceipt => [:read, :record, :report, :refresh, :purge],
    Marshall.Ingress.EditorAssetsReceipt.Version => [:read, :create],
    Marshall.Compute.Evacuation => [
      :read,
      :record,
      :pause,
      :continue,
      :confirm_ready,
      :resume,
      :retire,
      :advance
    ],
    Marshall.Compute.Evacuation.Version => [:read, :create],
    Marshall.Compute.EvacuationItem => [
      :read,
      :record,
      :approve,
      :block,
      :schedule,
      :replan,
      :resolve
    ],
    Marshall.Compute.EvacuationItem.Version => [:read, :create],
    Marshall.Administration.JobSnapshot => [:read, :expire],
    Marshall.Administration.JobEvent => [:read],
    Marshall.Administration.AuditEvent => [:read, :record],
    Marshall.Accounts.AdminBootstrap => [:read, :complete],
    Marshall.Accounts.AdminEvent => [:read, :record, :list_for_admin],
    Marshall.Ingress.Publication => [:read, :initialize, :advance, :snapshot],
    Marshall.Ingress.Route => [:read, :record, :replace, :refresh, :report_ready, :current],
    Marshall.Ingress.Route.Version => [:read, :create],
    Marshall.Ingress.Session => [
      :read,
      :record,
      :renew,
      :close,
      :purge,
      :prune,
      :ssh_key_status,
      :open_ssh,
      :renew_ssh,
      :close_ssh
    ],
    Marshall.Ingress.Session.Version => [:read, :create],
    Marshall.Ingress.Service => [
      :open_connection,
      :catalog,
      :read,
      :record,
      :rotate,
      :configure,
      :ensure,
      :disable,
      :identity,
      :record_host_key,
      :publish_host_key
    ],
    Marshall.Ingress.Service.Version => [:read, :create],
    Marshall.Ingress.Relay => [
      :read,
      :record,
      :consume,
      :renew,
      :purge,
      :consume_connection,
      :renew_connection
    ],
    Marshall.Ingress.Endpoint => [:read, :record, :change_policy],
    Marshall.Ingress.Endpoint.Version => [:read, :create],
    Marshall.SSH.Request => [:read, :record, :finish, :execute],
    Marshall.SSH.Gateway => [:read, :record, :rotate, :configure, :ensure, :disable, :ready],
    Marshall.SSH.Session => [
      :read,
      :record,
      :approve,
      :close,
      :purge,
      :prune,
      :open_session,
      :session_status,
      :close_session,
      :watch_subscribe
    ],
    Marshall.SSH.Approval => [:read, :record, :consume, :purge],
    Marshall.SSH.Key => [:read, :history, :register, :relabel, :revoke],
    Marshall.SSH.Key.Version => [:read, :create],
    Marshall.Notifications.Device => [
      :read,
      :history,
      :register,
      :activate,
      :refresh,
      :set_preference,
      :invalidate,
      :revoke
    ],
    Marshall.Notifications.Device.Version => [:read, :create],
    Marshall.Notifications.Delivery => [
      :read,
      :history,
      :enqueue,
      :record_coalesced,
      :begin_send,
      :deliver,
      :retry_later,
      :fail_permanent,
      :drop,
      :prune,
      :reconcile
    ],
    Marshall.Notifications.Delivery.Version => [:read, :create],
    Marshall.Notifications.InstallIdentity => [:read, :generate],
    Marshall.Accounts.AuthEmail => [:read, :enqueue, :deliver, :purge],
    Marshall.Terminal.Event => [:read, :record, :recent],
    Marshall.Terminal.Grant => [:read, :history, :grant, :revoke, :archive],
    Marshall.Terminal.Grant.Version => [:read, :create],
    Marshall.Terminal.Session => [
      :read,
      :history,
      :open,
      :close,
      :archive,
      :request_kill,
      :confirm_kill,
      :retire_kill
    ],
    Marshall.Terminal.Session.Version => [:read, :create],
    Marshall.Terminal.Ticket => [:read, :create, :destroy, :purge, :prune],
    Marshall.Terminal.Opening => [
      :read,
      :reserve,
      :complete,
      :begin_cancel,
      :fail,
      :destroy,
      :reconcile
    ],
    Marshall.Terminal.Location => [:read, :publish, :renew, :destroy],
    Marshall.Access.Grant => [:read, :history, :grant, :mark_revoked, :revoke],
    Marshall.Access.Grant.Version => [:read, :create],
    Marshall.Access.Change => [:read, :record],
    Marshall.Access.Pin => [:read, :history, :pin, :unpin, :repin, :remove],
    Marshall.Access.Pin.Version => [:read, :create],
    Marshall.Compute.Host => [
      :read,
      :enroll,
      :connect,
      :report,
      :disconnect,
      :configure,
      :maintenance
    ],
    Marshall.Compute.EnrollmentOperation => [:read, :record],
    Marshall.Compute.HostCredential => [:read, :history, :issue, :revoke],
    Marshall.Compute.HostDrain => [:read, :request, :advance, :confirm, :resume, :retire],
    Marshall.Compute.HostDrain.Version => [:read, :create],
    Marshall.Compute.HostCredential.Version => [:read, :create],
    Marshall.Compute.HostSession => [:read, :open],
    Marshall.Compute.StoragePool => [
      :read,
      :enroll,
      :report,
      :extend_freshness,
      :configure_overhead
    ],
    Marshall.Compute.WorkloadPlacement => [:read, :allocate],
    Marshall.Compute.Relocation => [
      :read,
      :record,
      :dispatch_key,
      :record_key,
      :schedule,
      :advance,
      :record_stop,
      :record_commit,
      :request_cancellation,
      :request_deletion,
      :offer_source_revocation,
      :record_source_revocation,
      :record_cancellation_stop,
      :record_cancellation_start,
      :record_source_restored,
      :offer_source_snapshot_cleanup,
      :offer_destination_cleanup,
      :record_destination_cleanup,
      :offer_destination_revocation,
      :record_destination_revocation,
      :record_source_snapshot_cleanup,
      :complete,
      :finish_cancellation,
      :finish_deletion,
      :begin_copy,
      :begin_import,
      :confirm_import,
      :confirm_readiness,
      :fail_readiness,
      :fail_activation,
      :observe_activation
    ],
    Marshall.Compute.CleanupRequest => [
      :read,
      :record,
      :offer,
      :complete,
      :record_operation,
      :request_key_retirement,
      :offer_key_retirement,
      :retire_key
    ],
    Marshall.Compute.ReadinessRequest => [:read, :record, :offer, :ready, :fail],
    Marshall.Compute.ProbeRequest => [:read, :enqueue, :dispatch, :record_result],
    Marshall.Compute.SourcePermitRequest => [
      :read,
      :enqueue,
      :dispatch,
      :record_result,
      :record_receive,
      :prepare_import,
      :record_import,
      :dispatch_destination,
      :supersede
    ],
    Marshall.Compute.TransferSlot => [:read, :occupy, :release],
    Marshall.Compute.Image => [:read, :register, :configure],
    Marshall.Compute.Image.Version => [:read, :create],
    Marshall.Compute.NetworkAddress => [:read, :history, :reserve, :release],
    Marshall.Compute.WorkspaceSource => [:read, :record],
    Marshall.Compute.VirtualMachine => [
      :read,
      :history,
      :allocate,
      :request_start,
      :request_pause,
      :idle_policy,
      :checkpoint,
      :request_stop,
      :request_delete,
      :apply_resize,
      :handoff,
      :restore_source,
      :observe,
      :archive
    ],
    Marshall.Compute.VirtualMachine.Version => [:read, :create],
    Marshall.Compute.Reservation => [
      :settle_usage,
      :resize_hold,
      :read,
      :reserve,
      :hold_compute,
      :hold_temporary_disk,
      :hold_checkpoint,
      :release_checkpoint,
      :release_temporary_disk,
      :release_compute,
      :release_all
    ],
    Marshall.Compute.ResizeRequest => [
      :read,
      :record,
      :record_progress,
      :stop,
      :resize,
      :restart,
      :fence,
      :complete,
      :cancel,
      :cancelled
    ],
    Marshall.Compute.RelocationRetry => [:read],
    Marshall.Compute.CloneEffect => [:read, :record, :offer, :complete, :record_unconfirmed],
    Marshall.Compute.CloneRequest => [
      :request_cancel,
      :read,
      :enqueue,
      :schedule,
      :reconcile,
      :record_progress,
      :prepare,
      :stop_source,
      :capture,
      :confirm_capture,
      :confirm_copy,
      :publish,
      :complete,
      :complete_cleanup,
      :defer,
      :cancel,
      :fail,
      :retry
    ],
    Marshall.Compute.CloneRequest.Version => [:read, :create],
    Marshall.Compute.Operation => [:read, :enqueue, :dispatch, :acknowledge, :complete, :cancel],
    Marshall.Compute.ServiceLevelAttempt => [:read, :admit, :finish, :check_pending],
    Marshall.Compute.WorkflowServiceLevelAttempt => [:read, :admit, :finish, :check_pending],
    Marshall.Compute.ServiceLevelTotal => [:read, :initialize, :add],
    Marshall.Compute.PhysicalOutcome => [:read, :record]
  }

  # SCIM provisioning writes, admitted only for the hidden service owner that
  # Marshall.Scim.Auth presents for an authenticated bearer while SCIM is
  # enabled. Paper-trail versions follow their audited action's actor.
  @scim %{
    Marshall.Teams.Team => [:read, :scim_read, :scim_create, :scim_update, :scim_destroy],
    Marshall.Teams.Team.Version => [:create],
    Marshall.Teams.TeamMember => [:read, :scim_record, :scim_remove],
    Marshall.Teams.TeamMember.Version => [:create]
  }

  @impl true
  def initial_state(actor, resource, action, _domain) do
    %{actor: actor, resource: resource, action: action.name}
  end

  @impl true
  def strict_check_context(_), do: []

  # @cc [owner:ghuntley,label:security] ash-generic-action-recheck
  # Entry authorization for public generic actions MUST establish only signed-in
  # admission; their coordinators remain responsible for current record-level
  # Cedar checks. Unlisted resource/action pairs MUST fail closed, including for
  # a trusted actor, rather than inherit access from another action's policy.
  @impl true
  def strict_check(state, _context) do
    allowed =
      if state.resource == Marshall.Compute.Evacuation and
           state.action in [
             :request_for_admin,
             :control_for_admin,
             :approve_for_admin,
             :replan_for_admin,
             :nodes_for_admin,
             :capacity_for_admin,
             :inspect_for_admin
           ] do
        action =
          if state.action in [:nodes_for_admin, :inspect_for_admin, :capacity_for_admin],
            do: "admin_read",
            else: "admin_operate"

        Cedar.allowed?(state.actor, action, Cedar.entity("ControlPlane", "marshall"))
      else
        if (state.resource == Marshall.Compute.LifecycleEvent and state.action == :list_for_admin) or
             (state.resource == Marshall.Inference.Request and state.action == :list_for_admin) or
             (state.resource == Marshall.Administration.JobSnapshot and
                state.action in [:list_for_admin, :get_for_admin, :retry_for_admin]) or
             (state.resource == Marshall.Accounts.AdminEvent and
                state.action == :list_for_admin) or
             (state.resource == Marshall.Compute.Host and
                state.action == :configure_for_admin) or
             (state.resource == Marshall.Galileo.Integration and
                state.action == :list_for_admin) or
             (state.resource == Marshall.Editor.Lease and state.action == :audit) or
             (state.resource == Marshall.Ingress.FleetCertificate and
                state.action in [:audit, :rotate_for_admin]) do
          action =
            cond do
              state.resource == Marshall.Administration.JobSnapshot ->
                if(state.action == :retry_for_admin, do: "admin_jobs", else: "admin_read")

              state.resource == Marshall.Compute.Host ->
                "admin_configure"

              state.resource == Marshall.Ingress.FleetCertificate and
                  state.action == :rotate_for_admin ->
                "admin_operate"

              true ->
                "admin_read"
            end

          Cedar.allowed?(state.actor, action, Cedar.entity("ControlPlane", "marshall"))
        else
          if (state.resource == Marshall.SSH.Key and
                state.action in [:list_for_admin, :revoke_for_admin]) or
               (state.resource == Marshall.SSH.Session and
                  state.action in [:list_for_admin, :revoke_for_admin]) or
               (state.resource == Marshall.Access.Grant and
                  state.action in [:list_for_admin, :revoke_for_admin]) or
               (state.resource == Marshall.Compute.VirtualMachine and
                  state.action == :list_for_admin) do
            Cedar.allowed?(
              state.actor,
              if(
                state.resource == Marshall.Compute.VirtualMachine or
                  state.action == :list_for_admin,
                do: "admin_read",
                else: "admin_accounts"
              ),
              Cedar.entity("ControlPlane", "marshall")
            )
          else
            if (state.resource == Marshall.Inference.Request and state.action == :list_for_user) or
                 (state.resource == Marshall.Ingress.WebLogin and state.action == :authorize_login) or
                 (state.resource == Marshall.Editor.Login and
                    state.action in [:launch, :authorize_login]) or
                 (state.resource == Marshall.Ingress.Endpoint and
                    state.action in [:get_for_user, :get_for_ssh, :configure]) or
                 (state.resource == Marshall.SSH.Approval and
                    state.action in [:inspect_approval, :approve_key]) or
                 (state.resource == Marshall.SSH.Key and
                    state.action in [
                      :list_for_user,
                      :add_for_user,
                      :rename_for_user,
                      :remove_for_user
                    ]) or
                 (state.resource == Marshall.Notifications.Device and
                    state.action in [
                      :register_for_user,
                      :list_for_user,
                      :remove_for_user,
                      :set_preference_for_user
                    ]) or
                 (state.resource == Marshall.Compute.VirtualMachine and
                    state.action in [
                      :clone,
                      :get_clone,
                      :list_clones,
                      :retry_clone,
                      :cancel_clone,
                      :provision,
                      :lifecycle,
                      :cancel_relocation,
                      :retry_relocation,
                      :relocate,
                      :resize,
                      :retry_resize,
                      :cancel_resize,
                      :get_for_user,
                      :resolve_for_user,
                      :list_for_user,
                      :pinned_for_user,
                      :catalog,
                      :repository_launch_request
                    ]) or
                 (state.resource == Marshall.Access.Grant and
                    state.action in [:set_access, :list_grants]) or
                 (state.resource == Marshall.Access.Pin and
                    state.action in [:pin_machine, :unpin_machine]) or
                 (state.resource == Marshall.Threads.Grant and
                    state.action in [:set_access, :list_grants]) or
                 (state.resource == Marshall.Threads.ReadMarker and state.action == :mark_read) or
                 (state.resource == Marshall.Galileo.Integration and
                    state.action in [
                      :configure,
                      :remove,
                      :attach,
                      :detach,
                      :show,
                      :list_for_user
                    ]) or
                 (state.resource == Marshall.Teams.Team and
                    state.action in [
                      :create_team,
                      :list_for_user,
                      :list_all_for_user,
                      :set_member,
                      :list_members,
                      :list_transfers
                    ]) or
                 (state.resource == Marshall.Agents.Thread and
                    state.action == :submit_prompt) or
                 (state.resource == Marshall.Threads.Thread and
                    state.action in [
                      :create_thread,
                      :list_for_user,
                      :list_page_for_user,
                      :get_for_user,
                      :submit_prompt,
                      :retry_provisioning,
                      :archive_thread,
                      :delete_thread,
                      :reopen_thread,
                      :thread_controls,
                      :set_collaboration_mode,
                      :answer_questions,
                      :implement_plan,
                      :compact_context,
                      :reload_context,
                      :context_info,
                      :list_skills,
                      :install_skill,
                      :update_skill,
                      :set_skill_enabled,
                      :remove_skill
                    ]) or
                 (state.resource == Marshall.Terminal.Session and
                    state.action in [
                      :open_session,
                      :refresh_session,
                      :close_session,
                      :claim_writer,
                      :release_writer,
                      :read_output,
                      :send_input
                    ]) do
              Cedar.allowed?(state.actor, "provision", Cedar.entity("ControlPlane", "marshall"))
            else
              if Map.has_key?(@scim, state.resource) and
                   Marshall.Teams.ServiceOwner.actor?(state.actor) do
                scim_provisioning?(state)
              else
                state.action in Map.get(@internal, state.resource, []) and
                  Cedar.allowed?(
                    state.actor,
                    "coordinate",
                    Cedar.entity("Internal", "#{inspect(state.resource)}:#{state.action}")
                  )
              end
            end
          end
        end
      end

    if allowed, do: {:authorized, state}, else: {:error, Ash.Error.Forbidden.exception([])}
  end

  # @cc [owner:ghuntley,label:security] ash-scim-service-owner-entry
  # SCIM Group writes MUST be admitted only for the listed resource/action pairs,
  # only for the persisted hidden service owner and only while SCIM is enabled.
  # The service owner never receives internal coordinator authority; any other
  # actor, action or a disabled SCIM configuration MUST fail closed.
  defp scim_provisioning?(state) do
    state.action in Map.get(@scim, state.resource, []) and Marshall.Scim.enabled?()
  end

  @impl true
  def check_context(_), do: []
  @impl true
  def check(state, _), do: {:error, :forbidden, state}
end
