defmodule MarshallComputeContractTest do
  use Covenant.Case, component: "marshall.compute"

  @tag obligation: "marshall.compute.I1"
  test "declared modules compile and remain loadable" do
    modules = [
      Marshall.Compute,
      Marshall.Compute.AddressAllocation,
      Marshall.Compute.AdminHostConfiguration,
      Marshall.Compute.AdminViews,
      Marshall.Compute.Admission,
      Marshall.Compute.AdvanceDrain,
      Marshall.Compute.AdvanceEvacuation,
      Marshall.Compute.Budget,
      Marshall.Compute.CapacityPolicy,
      Marshall.Compute.Changes.ValidateImage,
      Marshall.Compute.CleanupRequest,
      Marshall.Compute.CloneCoordinator,
      Marshall.Compute.CloneDispatch,
      Marshall.Compute.CloneEffect,
      Marshall.Compute.CloneEffects,
      Marshall.Compute.CloneFailure,
      Marshall.Compute.CloneGuard,
      Marshall.Compute.ClonePlacement,
      Marshall.Compute.CloneRequest,
      Marshall.Compute.Cloning,
      Marshall.Compute.CommandSnapshot,
      Marshall.Compute.CredentialLifetime,
      Marshall.Compute.Credentials,
      Marshall.Compute.DestinationReceiveDispatch,
      Marshall.Compute.Dispatch,
      Marshall.Compute.Drains,
      Marshall.Compute.Enrollment,
      Marshall.Compute.EnrollmentOperation,
      Marshall.Compute.EnrollmentPreparation,
      Marshall.Compute.EnrollmentRequest,
      Marshall.Compute.Error,
      Marshall.Compute.Evacuation,
      Marshall.Compute.EvacuationActions,
      Marshall.Compute.EvacuationItem,
      Marshall.Compute.EvacuationViews,
      Marshall.Compute.Evacuations,
      Marshall.Compute.ExpireLifecycleEvents,
      Marshall.Compute.Host,
      Marshall.Compute.HostCredential,
      Marshall.Compute.HostDrain,
      Marshall.Compute.HostLiveness,
      Marshall.Compute.HostReports,
      Marshall.Compute.HostSession,
      Marshall.Compute.Image,
      Marshall.Compute.Images,
      Marshall.Compute.Ledger,
      Marshall.Compute.Lifecycle,
      Marshall.Compute.LifecycleAudit,
      Marshall.Compute.LifecycleEvent,
      Marshall.Compute.LifecycleHistory,
      Marshall.Compute.LifecycleLog,
      Marshall.Compute.NativeGuid,
      Marshall.Compute.NetworkAddress,
      Marshall.Compute.Operation,
      Marshall.Compute.Outcomes,
      Marshall.Compute.PhysicalOutcome,
      Marshall.Compute.ProbeDispatch,
      Marshall.Compute.ProbeRequest,
      Marshall.Compute.ProbeRequestPayload,
      Marshall.Compute.Profiles,
      Marshall.Compute.ProvisionerControl,
      Marshall.Compute.ProvisionerRequests,
      Marshall.Compute.ReadinessRequest,
      Marshall.Compute.Relocation,
      Marshall.Compute.RelocationAdmission,
      Marshall.Compute.RelocationAdvance,
      Marshall.Compute.RelocationCancellation,
      Marshall.Compute.RelocationCapacity,
      Marshall.Compute.RelocationCleanup,
      Marshall.Compute.RelocationCoordinator,
      Marshall.Compute.RelocationDeletion,
      Marshall.Compute.RelocationDestinationCleanups,
      Marshall.Compute.RelocationDestinationRevocations,
      Marshall.Compute.RelocationGuard,
      Marshall.Compute.RelocationImports,
      Marshall.Compute.RelocationKeyDispatch,
      Marshall.Compute.RelocationKeyRetirement,
      Marshall.Compute.RelocationKeys,
      Marshall.Compute.RelocationProbes,
      Marshall.Compute.RelocationReadiness,
      Marshall.Compute.RelocationReadinessState,
      Marshall.Compute.RelocationReceives,
      Marshall.Compute.RelocationRestoration,
      Marshall.Compute.RelocationRetry,
      Marshall.Compute.RelocationRetryAdmission,
      Marshall.Compute.RelocationRevocations,
      Marshall.Compute.RelocationSnapshotCleanups,
      Marshall.Compute.RelocationSources,
      Marshall.Compute.RelocationStatus,
      Marshall.Compute.Reservation,
      Marshall.Compute.Resize,
      Marshall.Compute.ResizeRequest,
      Marshall.Compute.RestartCapacity,
      Marshall.Compute.ServiceLevelAdmission,
      Marshall.Compute.ServiceLevelAttempt,
      Marshall.Compute.ServiceLevelPublisher,
      Marshall.Compute.ServiceLevelTotal,
      Marshall.Compute.ServiceLevelTotals,
      Marshall.Compute.ServiceLevels,
      Marshall.Compute.SourcePermitDispatch,
      Marshall.Compute.SourcePermitRequest,
      Marshall.Compute.SourceRequestPayload,
      Marshall.Compute.StartupHolds,
      Marshall.Compute.StoragePool,
      Marshall.Compute.TransferDescriptor,
      Marshall.Compute.TransferEndpoint,
      Marshall.Compute.TransferPublicKey,
      Marshall.Compute.TransferSlot,
      Marshall.Compute.TransferSlots,
      Marshall.Compute.Views,
      Marshall.Compute.VirtualMachine,
      Marshall.Compute.WorkflowServiceLevelAttempt,
      Marshall.Compute.WorkflowServiceLevels,
      Marshall.Compute.WorkloadPlacement,
      Marshall.Compute.WorkspaceSource,
      Marshall.Control.FaultGate,
      Marshall.Control.Hints,
      Marshall.Control.Hints.Change,
      Marshall.Control.Hints.Hosts,
      Marshall.Control.Hints.Relay,
      Marshall.Control.Service,
      Marshall.Control.Services.Audi,
      Marshall.Control.Services.Galileo,
      Marshall.Control.Services.Lilly,
      Marshall.Control.Services.Porsche,
      Marshall.Control.Services.Peach,
      Marshall.Control.Services.Ziggy,
      Marshall.Control.Socket
    ]

    assert Enum.all?(modules, &Code.ensure_loaded?/1)
  end

  @tag obligation: "marshall.compute.I3"
  test "inception default shape preserves minimum resources" do
    shape =
      Marshall.Compute.Profiles.default_shape(:inception, %{
        minimum_memory_bytes: 34_359_738_368,
        minimum_disk_bytes: 68_719_476_736
      })

    # The profile's declared defaults are an API contract, not just lower
    # bounds. Keeping these exact values catches accidental drift (for example
    # changing the form's default while leaving admission's minimum intact).
    assert shape == %{
             vcpu: 16,
             memory_bytes: 34_359_738_368,
             disk_bytes: 68_719_476_736
           }

    ordinary =
      Marshall.Compute.Profiles.default_shape(:standard, %{
        minimum_memory_bytes: 3,
        minimum_disk_bytes: 4
      })

    assert ordinary.vcpu == 1
    assert ordinary.memory_bytes >= 1_048_576
    assert ordinary.disk_bytes >= 2_147_483_648
  end

  @tag obligation: "marshall.compute.I2"
  test "inception admission enforces its configured image and resource minima" do
    previous = Application.get_env(:marshall, :inception_image_id)
    Application.put_env(:marshall, :inception_image_id, "sha256:" <> String.duplicate("a", 64))

    on_exit(fn ->
      if previous,
        do: Application.put_env(:marshall, :inception_image_id, previous),
        else: Application.delete_env(:marshall, :inception_image_id)
    end)

    request = %{
      profile: :inception,
      image_id: "sha256:" <> String.duplicate("a", 64),
      vcpu: 16,
      memory_bytes: 34_359_738_368,
      disk_bytes: 68_719_476_736
    }

    assert :ok = Marshall.Compute.Profiles.validate(request)

    assert {:error, :profile_image_mismatch} =
             Marshall.Compute.Profiles.validate(%{
               request
               | image_id: "sha256:" <> String.duplicate("b", 64)
             })

    assert {:error, :image_requirements_not_met} =
             Marshall.Compute.Profiles.validate(%{request | vcpu: 1})

    assert Marshall.Compute.Profiles.host_ready?(request, %{
             "inception_image_id" => request.image_id
           })

    refute Marshall.Compute.Profiles.host_ready?(request, %{
             "inception_image_id" => "sha256:" <> String.duplicate("b", 64)
           })
  end

  @tag obligation: "marshall.compute.I4"
  test "the owner-pin refusal is a closed compute reason across the SSH control API" do
    error = Marshall.Compute.Error.exception(reason: :machine_pinned)
    assert Exception.message(error) == "Compute request rejected: machine_pinned"

    assert {:error, 409, "machine_pinned"} =
             Marshall.SSH.ControlRequests.classify({:error, :machine_pinned})

    assert {:error, 409, "pin_limit"} =
             Marshall.SSH.ControlRequests.classify({:error, :pin_limit})
  end
end
