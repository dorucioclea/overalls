defmodule Lilly.VM.Disk do
  @moduledoc "Persistent native-ZFS sparse disks, independent of the disposable jail."
  require Lilly.Events

  @create_turn_ms 30_000
  alias Lilly.Host.{
    Command,
    Image,
    ImageTemplate,
    Lock,
    Pool,
    PrivateFiles,
    Storage,
    ZFSDataset
  }

  alias Lilly.VM.{Spec, WorkloadBundle}

  # A multi-GiB image flush is bulk I/O, like the bounded image copy. The generic
  # three-second metadata deadline can expire while ZFS commits a valid copy.
  # Do not publish or launch until the flush succeeds; timeout still fails closed.

  # @cc [owner:ghuntley,label:capacity;durability] disk-image-io-deadline
  # Every root-disk image copy and flush MUST be bounded by the pool's
  # `image_io_timeout_ms` (default 300 s, `services.lilly.imageIoTimeoutSeconds`)
  # and still fail closed when it expires; no copy or flush is unbounded.

  @spec path(Pool.t(), Spec.t()) :: Path.t()
  def path(pool, spec), do: Path.join([pool.path, "vms", spec.id, "rootfs.ext4"])

  # @cc [owner:ghuntley,label:security;recovery] imported-disk-requires-portable-boot-bundle
  # adopt/2 MUST validate the received placement's closed boot bundle and admitted
  # architecture/shape without consulting a local image catalog. Callers must hold current relocation authority
  # and prove streams and VMMs quiescent. Adoption MUST NOT use ordinary image-copy
  # initialization, and success MUST NOT authorize launch or source reclamation.
  # Pool acquisition may retry contention for two seconds before adoption; the
  # protected adoption MUST NOT be replayed by that acquisition retry.
  @spec adopt(Pool.t(), OverallsProtocol.Relocation.descriptor()) ::
          :ok | {:error, atom()}
  def adopt(pool, %{workload: workload, destination: destination} = descriptor) do
    with true <- workload.architecture == :x86_64,
         {:ok, spec} <-
           workload
           |> Map.drop([:architecture])
           |> Map.merge(%{id: destination.placement_id, pool_id: destination.pool_id})
           |> Spec.new(),
         true <- spec.pool_id == pool.id and destination.host_id == pool.host_id,
         true <- spec.image_id == workload.image_id do
      Storage.locked(pool, fn -> ZFSDataset.adopt(pool, spec, descriptor) end, 2000)
    else
      _ -> {:error, :disk_import_unconfirmed}
    end
  end

  def adopt(_, _), do: {:error, :disk_import_unconfirmed}

  @doc "Caller must fence execution and prove streams, VMMs and jail access quiescent before cancellation cleanup."
  @spec discard_import(Pool.t(), OverallsProtocol.Relocation.descriptor()) ::
          :ok | {:error, atom()}
  def discard_import(pool, descriptor),
    do: Storage.locked(pool, fn -> Lilly.Transfer.ImportCleanup.cleanup(pool, descriptor) end)

  # @cc [owner:ghuntley,label:security;recovery] discarded-import-retains-external-fences
  # discard_import_intent/2 requires permanent transfer and execution fences plus
  # proven stream/VMM/jail quiescence. It MUST serialize local-history lookup and
  # reclamation under the pool lock, without requiring a remotely received GUID.
  # Success MUST NOT release remote commitments or remove the caller's fences.
  @spec discard_import_intent(Pool.t(), OverallsProtocol.Relocation.intent()) ::
          :ok | {:error, atom()}
  def discard_import_intent(pool, intent),
    do: Storage.locked(pool, fn -> Lilly.Transfer.ImportCleanup.cleanup_intent(pool, intent) end)

  # @cc [owner:ghuntley,label:recovery] persistent-disk-not-reinitialized
  # prepare/3 MUST reuse an existing correctly bound disk without copying the
  # boot image over its contents. If disk-ready metadata exists but the disk is missing, it must
  # fail rather than silently recreate user storage. ZFS uses an
  # owned sparse child dataset and logical size is never physical allocation credit.
  # Disk claims and readiness markers MUST remain outside the portable dataset.
  # Native usage-only observation races MUST propagate storage_busy before VMM launch, without
  # relaxing ownership, missing-disk or property checks or replacing an initialized disk.
  @spec prepare(Pool.t(), Image.t(), Spec.t()) :: :ok | {:error, atom()}
  def prepare(pool, image, spec) do
    placement_owner = Lock.current()

    image_access(pool, image, spec, fn verified ->
      Lock.with_owner(placement_owner, fn ->
        directory = ZFSDataset.metadata_directory(pool, spec)

        with true <- spec.pool_id == pool.id and spec.image_id == image.id,
             true <- verified.id == image.id and verified.manifest.architecture == :x86_64,
             {:ok, source_evidence} <- source_evidence(verified),
             true <-
               spec.disk_bytes >= verified.manifest.minimum_disk_bytes and
                 spec.memory_bytes >= verified.manifest.minimum_memory_bytes,
             :ok <- prepare_dataset(pool, spec),
             :ok <-
               prepare_step(
                 materialize(pool, verified, spec, source_evidence),
                 spec,
                 :materialize
               ),
             :ok <- prepare_step(materialize_additional(pool, spec), spec, :additional_drives),
             :ok <- prepare_step(finalize_drives(pool, spec), spec, :drive_flush),
             :ok <-
               prepare_step(
                 WorkloadBundle.materialize(ZFSDataset.directory(pool, spec), verified, spec),
                 spec,
                 :workload_bundle
               ),
             :ok <-
               prepare_step(
                 PrivateFiles.write(
                   directory,
                   "disk-ready.json",
                   JSON.encode!(Spec.encode(spec))
                 ),
                 spec,
                 :ready_marker
               ),
             # Concurrent creates' readiness checks share one set of pool
             # reads (ZFSDataset.ready_batch/2, ADR-0176).
             :ok <-
               Storage.combine(
                 pool,
                 :ready,
                 spec,
                 fn specs ->
                   for {spec, result} <- ZFSDataset.ready_batch(pool, specs),
                       do: prepare_step(result, spec, :ready)
                 end,
                 @create_turn_ms
               ) do
          :ok
        else
          {:error, :storage_busy} = error -> error
          _ -> {:error, :disk_prepare_failed}
        end
      end)
    end)
  end

  # The dedicated Inception image is excluded from asynchronous template
  # prewarming because it is large and profile-specific. Keep its launch path
  # on the same freshly hashed, uncached authority instead of creating a cache
  # entry on demand after prewarming deliberately skipped it.

  # @cc [owner:ghuntley,label:capacity;recovery] inception-image-uncached
  # Inception disk preparation MUST validate the configured image bytes directly
  # and MUST NOT reserve or publish a template incarnation.
  defp image_access(_pool, image, %{network: %{profile: :inception}}, fun),
    do: ImageTemplate.with_uncached_image(image, fun)

  defp image_access(pool, image, _spec, fun), do: ImageTemplate.with_image(pool, image, fun)

  # @cc [owner:ghuntley,label:concurrency;recovery] disk-copy-outside-pool-lock
  # Caller MUST hold the placement lock through preparation. Claim/create and
  # final readiness serialize with pool accounting; bulk artifact I/O runs under
  # the placement/template lease so unrelated placements can make progress.
  # Bound/creating datasets earn no physical reservation credit during copying.
  # Both pool sections of a create wait in the pool's FIFO turn queue for up to
  # 30 s, so a burst of creates drains in arrival order instead of returning
  # storage_busy to be retried on a later tick (ADR-0176).
  # Concurrent creates on one pool are prepared together: the turn holder runs
  # the whole queued batch with one snapshot, audit and re-read (ADR-0176).
  defp prepare_dataset(pool, spec),
    do: Storage.combine(pool, :prepare, spec, &prepare_datasets(pool, &1), @create_turn_ms)

  defp prepare_datasets(pool, specs) do
    # ZFSDataset.prepare_batch/3 binds the pool's exact native identity
    # (including its filesystem id) under this lock and creates the private vms/
    # directory before any other check or effect (ADR-0152).
    for {spec, result} <- ZFSDataset.prepare_batch(pool, specs) do
      with :ok <- prepare_step(result, spec, :dataset),
           do: prepare_step(claim(pool, spec), spec, :claim)
    end
  end

  @doc "Verify an already provisioned placement without consulting an image catalog."
  # @cc [owner:ghuntley,label:recovery;security] restart-readiness-preserves-contention
  # ready/2 MUST return storage_busy unchanged from either pool acquisition or
  # native validation or independently owned import staging, without retrying
  # the protected work. Every other failure
  # remains terminal. Success requires both owned disks and the portable bundle;
  # contention MUST NOT authorize launch or reconstruct missing data.
  @spec ready(Pool.t(), Spec.t()) :: :ok | {:error, atom()}
  def ready(pool, spec) do
    Storage.locked(
      pool,
      fn ->
        with :ok <- ZFSDataset.ready(pool, spec),
             {:bundle, {:ok, _}} <-
               {:bundle, WorkloadBundle.load(ZFSDataset.directory(pool, spec), spec)} do
          :ok
        else
          {:error, :storage_busy} = error ->
            error

          {:bundle, _} ->
            Lilly.Events.emit("vm.disk_readiness_failed",
              placement_id: spec.id,
              stage: :boot_bundle,
              reason: :invalid
            )

            {:error, :disk_not_ready}

          _ ->
            {:error, :disk_not_ready}
        end
      end,
      1000,
      :ready
    )
  end

  # @cc [owner:ghuntley,label:security;observability] disk-preparation-stage-diagnostics
  # Stage diagnostics MUST preserve results and quiet storage_busy retries. Failures
  # MUST expose only a fixed stage and VM ID, never native output,
  # paths, ownership records or disk contents.
  defp prepare_step(:ok, _spec, _stage), do: :ok
  defp prepare_step({:ok, _} = result, _spec, _stage), do: result
  defp prepare_step({:error, :storage_busy} = result, _spec, _stage), do: result

  defp prepare_step(result, spec, stage) do
    Lilly.Events.emit("vm.disk_preparation_failed", vm_id: spec.id, stage: stage)

    result
  end

  @doc "Caller owns the placement lock and has fenced and confirmed stopped execution."
  @spec resize(Pool.t(), Spec.t(), Spec.t(), String.t()) :: :ok | {:error, atom()}
  def resize(pool, source, target, request_id) do
    Storage.locked(
      pool,
      fn ->
        ZFSDataset.resize(pool, source, target, request_id, fn ->
          with :ok <- extend(pool, path(pool, source), target),
               {:ok, _} <-
                 Command.run(:sync, ["--", path(pool, target)], pool.image_io_timeout_ms),
               do: :ok
        end)
      end,
      1000,
      :resize
    )
  end

  @doc "Caller must confirm all VMM processes and jail mounts have been removed first."
  # @cc [owner:ghuntley,label:assumption;recovery] disk-delete-precondition
  # Callers of Disk.delete/2 and delete/3 MUST first confirm no VMM process or jail mount can access the disk;
  # deletion must serialize with pool snapshots and reject a mismatched disk identity.
  # An optional bounded acquisition retry MUST NOT replay deletion effects.
  # Ordinary deletion waits up to 30 s in the pool's FIFO queue, like a
  # create's sections, instead of giving up after one second and losing its
  # place behind newer work (ADR-0176 decision 1).
  @spec delete(Pool.t(), Spec.t()) :: :ok | {:error, atom()}
  @spec delete(Pool.t(), Spec.t(), 0..30_000) :: :ok | {:error, atom()}
  def delete(%{backend: :zfs} = pool, spec, retry_ms \\ 30_000) do
    Storage.locked(pool, fn -> ZFSDataset.delete(pool, spec) end, retry_ms, :delete)
  end

  defp claim(pool, spec) do
    directory = ZFSDataset.metadata_directory(pool, spec)

    case Lilly.Host.Privilege.lstat(Path.join(directory, "disk.json")) do
      {:error, :enoent} ->
        case Lilly.Host.Privilege.lstat(path(pool, spec)) do
          {:error, :enoent} ->
            PrivateFiles.write(directory, "disk.json", JSON.encode!(Spec.encode(spec)))

          _ ->
            :error
        end

      {:ok, _} ->
        existing_claim(directory, spec)

      _ ->
        :error
    end
  end

  defp existing_claim(directory, spec) do
    with {:ok, bytes} <- PrivateFiles.read_secret(Path.join(directory, "disk.json")),
         {:ok, value} <- JSON.decode(bytes),
         true <- value == Spec.encode(spec),
         do: :ok
  end

  # @cc [owner:ghuntley,label:verification;security] native-materialization-source-evidence
  # First materialization of an independent root disk MUST emit its actual
  # reflink/offload/copy method and source kind only after the copy and sync succeed.
  # Reuse of an existing correctly bound disk does not copy or emit. Template UUID metadata
  # MUST come from the validated ready record held under the native reader lease;
  # the verified uncached path MUST emit neither template identifier.
  defp materialize(pool, image, spec, {source, template_record_id, template_incarnation}) do
    destination = path(pool, spec)

    case Lilly.Host.Privilege.lstat(destination) do
      {:ok, _} ->
        if disk_shape?(destination, spec),
          do: allocation_shape(pool, destination, spec),
          else: :error

      {:error, :enoent} ->
        temporary = Path.join(Path.dirname(destination), ".rootfs.pending")

        with {:error, :enoent} <-
               Lilly.Host.Privilege.lstat(
                 Path.join(ZFSDataset.metadata_directory(pool, spec), "disk-ready.json")
               ),
             :ok <- remove_temporary(temporary),
             {_, stat} = image.files[Image.root_artifact(image)],
             {:ok, method, kind, record_id, incarnation} <-
               root_copy(
                 pool,
                 image,
                 spec,
                 temporary,
                 {source, template_record_id, template_incarnation}
               ),
             :ok <- Lilly.Host.Privilege.chmod(temporary, 0o600),
             :ok <- extend(pool, temporary, spec),
             :ok <- allocation_shape(pool, temporary, spec),
             {:ok, _} <-
               materialize_command(spec, :sync, ["--", temporary], pool.image_io_timeout_ms),
             {:ok, _} <-
               materialize_command(spec, :mv, [
                 "--no-target-directory",
                 "--",
                 temporary,
                 destination
               ]),
             {:ok, _} <- materialize_command(spec, :sync, ["--", Path.dirname(destination)]) do
          Lilly.Events.emit("vm.image_materialized",
            placement_id: spec.id,
            method: method,
            bytes: stat.size,
            source: kind,
            template_record_id: record_id,
            template_incarnation: incarnation
          )

          :ok
        end

      _ ->
        :error
    end
  end

  # Every root disk is copied on demand from the verified image or sealed
  # template, by block clone where the store allows it (ADR-0177).
  defp root_copy(pool, image, spec, temporary, {source, record_id, incarnation}) do
    with {:ok, method} when method in ["copy\n", "offload\n", "reflink\n"] <-
           materialize_command(
             spec,
             :image_copy,
             Image.copy_arguments(image, Image.root_artifact(image), temporary),
             pool.image_io_timeout_ms
           ),
         do: {:ok, copy_method(method), source, record_id, incarnation}
  end

  defp copy_method("reflink\n"), do: :reflink
  defp copy_method("offload\n"), do: :offload
  defp copy_method("copy\n"), do: :copy

  @spec source_evidence(Image.t()) ::
          {:ok, {:template | :verified, String.t() | nil, String.t() | nil}} | :error
  defp source_evidence(%Image{
         source_lease: nil,
         template_record_id: nil,
         template_incarnation: nil
       }),
       do: {:ok, {:verified, nil, nil}}

  defp source_evidence(%Image{
         source_lease: lease,
         template_record_id: record,
         template_incarnation: incarnation
       })
       when is_binary(lease) and is_binary(record) and is_binary(incarnation) do
    if OverallsProtocol.uuid?(record) and OverallsProtocol.uuid?(incarnation),
      do: {:ok, {:template, record, incarnation}},
      else: :error
  end

  defp source_evidence(_), do: :error

  # @cc [owner:ghuntley,label:recovery] additional-drive-not-reinitialized
  # Additional drives MUST use the validated profile layout and durable root claim.
  # A published ready marker forbids recreating any missing drive. Preparation MUST
  # preserve existing exact-size regular single-link files, reject substitutions,
  # and flush every drive before publishing the shared ready marker.
  defp materialize_additional(pool, spec) do
    spec
    |> Spec.drives()
    |> Enum.reject(& &1.root)
    |> Enum.reduce_while(:ok, fn drive, :ok ->
      case materialize_empty(pool, spec, drive) do
        :ok -> {:cont, :ok}
        _ -> {:halt, :error}
      end
    end)
  end

  defp materialize_empty(pool, spec, drive) do
    destination = Path.join(Path.dirname(path(pool, spec)), drive.name)
    temporary = destination <> ".pending"

    case Lilly.Host.Privilege.lstat(destination) do
      {:ok, %File.Stat{type: :regular, links: 1, size: size, uid: uid}}
      when size == drive.bytes and uid in [0, spec.network.uid] ->
        :ok

      {:error, :enoent} ->
        with {:error, :enoent} <-
               Lilly.Host.Privilege.lstat(
                 Path.join(ZFSDataset.metadata_directory(pool, spec), "disk-ready.json")
               ),
             :ok <- remove_temporary(temporary),
             :ok <- File.write(temporary, "", [:exclusive]),
             :ok <- File.chmod(temporary, 0o600),
             {:ok, _} <-
               materialize_command(spec, :truncate, [
                 "--size",
                 Integer.to_string(drive.bytes),
                 "--",
                 temporary
               ]),
             {:ok, _} <-
               materialize_command(spec, :sync, ["--", temporary], pool.image_io_timeout_ms),
             {:ok, _} <-
               materialize_command(spec, :mv, [
                 "--no-target-directory",
                 "--",
                 temporary,
                 destination
               ]),
             {:ok, _} <- materialize_command(spec, :sync, ["--", Path.dirname(destination)]),
             do: :ok

      _ ->
        :error
    end
  end

  defp finalize_drives(pool, spec) do
    Enum.reduce_while(Spec.drives(spec), :ok, fn drive, :ok ->
      file = Path.join(Path.dirname(path(pool, spec)), drive.name)

      with {:ok, _} <-
             materialize_command(spec, :chown, [
               "#{spec.network.uid}:#{spec.network.uid}",
               "--",
               file
             ]),
           :ok <- Lilly.Host.Privilege.chmod(file, 0o600),
           {:ok, _} <- materialize_command(spec, :sync, ["--", file], pool.image_io_timeout_ms) do
        {:cont, :ok}
      else
        _ -> {:halt, :error}
      end
    end)
  end

  defp extend(%{backend: :zfs}, path, spec) do
    with {:ok, _} <-
           materialize_command(spec, :truncate, [
             "--size",
             Integer.to_string(spec.disk_bytes),
             "--",
             path
           ]),
         do: :ok
  end

  # @cc [owner:ghuntley,label:security] disk-materialization-diagnostics
  # Failed materialization commands MUST report only the fixed utility name,
  # elapsed milliseconds and VM ID. Paths, command output and disk contents MUST NOT
  # enter diagnostics; the original result and deadline MUST be preserved.
  # Successful steps report only the fixed utility atom and elapsed milliseconds
  # so creation latency can be attributed per step (ADR-0143).
  defp materialize_command(spec, name, arguments, timeout \\ 3000) do
    started = System.monotonic_time(:millisecond)
    result = Command.run(name, arguments, timeout)

    case result do
      {:error, _reason} ->
        Lilly.Events.emit("vm.disk_materialization_failed",
          vm_id: spec.id,
          utility: name,
          duration_ms: System.monotonic_time(:millisecond) - started
        )

      {:ok, _} ->
        Lilly.Events.emit("vm.disk_materialization_step",
          vm_id: spec.id,
          utility: name,
          duration_ms: System.monotonic_time(:millisecond) - started
        )
    end

    result
  end

  defp allocation_shape(%{backend: :zfs}, path, spec),
    do: if(disk_shape?(path, spec), do: :ok, else: :error)

  defp disk_shape?(path, spec) do
    case Lilly.Host.Privilege.lstat(path) do
      {:ok, %File.Stat{type: :regular, links: 1, size: size, uid: uid}} ->
        size == spec.disk_bytes and uid in [0, spec.network.uid]

      _ ->
        false
    end
  end

  defp remove_temporary(path) do
    case Lilly.Host.Privilege.lstat(path) do
      {:error, :enoent} -> :ok
      {:ok, %File.Stat{type: :regular, links: 1, uid: 0}} -> remove(path)
      _ -> :error
    end
  end

  defp remove(path) do
    case Command.run(:rm, ["--force", "--", path]) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end
end
