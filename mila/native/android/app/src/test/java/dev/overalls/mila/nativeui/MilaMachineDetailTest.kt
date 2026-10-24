package dev.overalls.mila.nativeui

import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

private open class DetailAdapter(private val accepted: Boolean = true) : MilaFfiAdapter {
    override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
    override suspend fun machineAction(machineId: UUID, command: MilaMachineCommand): Result<Unit> =
        if (accepted) Result.success(Unit) else Result.failure(IllegalStateException("rejected"))
}

class MilaMachineDetailTest {
    private val id = UUID.fromString("00000000-0000-0000-0000-000000000001")
    private val listing = MilaSessionListing(listOf(MilaMachineRow(id, "build", "running")), false)

    @Test fun mutationRequiresSignedInListing() = runBlocking {
        val controller = MilaMachineDetailController(DetailAdapter())
        controller.setSession(false, listing)
        assertFalse(controller.select(id))
        assertFalse(controller.submit(MilaMachineCommand.Start))
        assertEquals(MilaMachineMutationState.SignedOut, controller.state)
    }

    @Test fun zeroMachineIdCannotSelectDetail() = runBlocking {
        val controller = MilaMachineDetailController(DetailAdapter())
        controller.setSession(true, listing)
        assertFalse(controller.select(UUID(0L, 0L)))
        assertEquals(MilaMachineMutationState.Idle, controller.state)
    }

    @Test fun successfulMutationUsesSelectedMachine() = runBlocking {
        val controller = MilaMachineDetailController(DetailAdapter())
        controller.setSession(true, listing)
        assertTrue(controller.select(id))
        assertTrue(controller.submit(MilaMachineCommand.Stop))
        assertEquals(MilaMachineMutationState.Applied(listing.machines.single(), MilaMachineCommand.Stop), controller.state)
    }

    @Test fun sharingCommandsAreRejectedByLifecycleController() = runBlocking {
        val controller = MilaMachineDetailController(DetailAdapter())
        controller.setSession(true, listing)
        assertTrue(controller.select(id))
        assertFalse(controller.submit(MilaMachineCommand.ShareAdd))
        assertEquals(MilaMachineMutationState.Ready(listing.machines.single()), controller.state)
    }

    @Test fun failedMutationIsVisibleAndTyped() = runBlocking {
        val controller = MilaMachineDetailController(DetailAdapter(accepted = false))
        controller.setSession(true, listing)
        controller.select(id)
        assertFalse(controller.submit(MilaMachineCommand.Delete))
        assertTrue(controller.state is MilaMachineMutationState.Failed)
    }

    @Test fun staleMutationResultCannotRestoreSignedOutProjection() = runBlocking {
        val gate = CompletableDeferred<Result<Unit>>()
        val adapter = object : DetailAdapter() {
            override suspend fun machineAction(machineId: UUID, command: MilaMachineCommand): Result<Unit> = gate.await()
        }
        val controller = MilaMachineDetailController(adapter)
        controller.setSession(true, listing)
        controller.select(id)
        val pending = async { controller.submit(MilaMachineCommand.Start) }
        controller.setSession(false, null)
        gate.complete(Result.success(Unit))
        assertFalse(pending.await())
        assertEquals(MilaMachineMutationState.SignedOut, controller.state)
    }
}

