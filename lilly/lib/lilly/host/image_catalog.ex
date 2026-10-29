defmodule Lilly.Host.ImageCatalog do
  @moduledoc """
  Background full-digest verification of configured images.

  Startup stages images structurally (`Lilly.Host.Image.stage/1`) so the
  control runtime, ingress, private services and Brady attribution never wait
  for multi-gigabyte artifact hashing. This process hashes each staged image
  once and publishes only digest-verified images for availability reporting.
  """
  use GenServer
  require Lilly.Events
  alias Lilly.Host.Image

  @type state :: %{
          table: atom(),
          pending: [Image.t()],
          cache: Path.t() | nil,
          verified: non_neg_integer(),
          rejected: non_neg_integer()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    name = Keyword.get(options, :name, __MODULE__)
    GenServer.start_link(__MODULE__, Keyword.put(options, :name, name), name: name)
  end

  # @cc [owner:ghuntley,label:security;recovery] image-catalog-verified-projection
  # verified/2 MUST return only load/1 results (verified: true) whose path and
  # manifest ID equal a configured staged image. An absent, restarting or
  # unfinished catalog MUST yield no advertised image, never a staged one.
  # Verification MUST NOT delay or fail startup of any other Lilly component.
  @spec verified(atom(), [Image.t()]) :: [Image.t()]
  def verified(table \\ __MODULE__, staged) when is_atom(table) and is_list(staged) do
    Enum.flat_map(staged, fn %Image{id: id, path: path} ->
      case :ets.lookup(table, path) do
        [{^path, %Image{id: ^id, path: ^path, verified: true} = image}] -> [image]
        _ -> []
      end
    end)
  rescue
    ArgumentError -> []
  end

  @impl true
  @spec init(keyword()) :: {:ok, state(), {:continue, :verify}}
  def init(options) do
    table = Keyword.fetch!(options, :name)
    # Smaller images are digest-verified first, so a large image (a 32 GiB
    # firmware disk) delays advertising the others as little as possible.
    staged = Enum.sort_by(Keyword.fetch!(options, :images), &artifact_bytes/1)
    :ets.new(table, [:named_table, :protected, :set, read_concurrency: true])
    cache = Keyword.get(options, :digest_cache)

    {:ok, %{table: table, pending: staged, cache: cache, verified: 0, rejected: 0},
     {:continue, :verify}}
  end

  @impl true
  def handle_continue(:verify, %{pending: []} = state) do
    Lilly.Events.emit("lilly.images_verified",
      verified_images: state.verified,
      rejected_images: state.rejected
    )

    {:noreply, state}
  end

  def handle_continue(:verify, %{pending: [%Image{id: id, path: path} | rest]} = state) do
    # An unchanged image skips rehashing through the private digest cache
    # (image-digest-cache-exact-identity, ADR-0176).
    # Nix-store images are immutable deployment outputs. Structural validation
    # plus the store's read-only, content-addressed authority avoids rereading
    # a multi-GiB root artifact during startup; mutable paths retain the
    # digest-cache path and its full byte verification.
    loaded =
      case Image.load_immutable(path) do
        {:ok, _} = result ->
          result

        {:error, :invalid_local_image} ->
          if state.cache, do: Image.load_cached(path, state.cache), else: Image.load(path)
      end

    state =
      case loaded do
        {:ok, %Image{id: ^id, path: ^path, verified: true} = image} ->
          :ets.insert(state.table, {path, image})
          %{state | verified: state.verified + 1}

        _ ->
          %{state | rejected: state.rejected + 1}
      end

    {:noreply, %{state | pending: rest}, {:continue, :verify}}
  end

  defp artifact_bytes(%Image{files: files}),
    do: Enum.sum(Enum.map(files, fn {_, {_, stat}} -> stat.size end))

  @impl true
  def format_status(status), do: Lilly.DiagnosticStatus.redact(status)
end
