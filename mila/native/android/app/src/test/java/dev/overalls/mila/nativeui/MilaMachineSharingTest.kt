package dev.overalls.mila.nativeui

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

private class SharingAdapter(private val accepted: Boolean = true) : MilaFfiAdapter {
    override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
    override suspend fun machineAction(machineId: UUID, command: MilaMachineCommand): Result<Unit> =
        if (accepted) Result.success(Unit) else Result.failure(IllegalStateException("rejected"))
}

class MilaMachineSharingTest {
    private val id = UUID.fromString("00000000-0000-0000-0000-000000000001")
    private val row = MilaMachineRow(id, "build", "running")
    private val listing = MilaSessionListing(listOf(row), false)

    @Test fun sharingRequiresAuthenticatedMachine() = runBlocking {
        val c = MilaMachineSharingController(SharingAdapter())
        c.setSession(false, listing)
        assertFalse(c.setMachine(row))
        assertFalse(c.submit("person@example.test"))
        assertEquals(MilaMachineSharingState.SignedOut, c.state)
    }

    @Test fun addAndRemoveUseClosedCommands() = runBlocking {
        val c = MilaMachineSharingController(SharingAdapter())
        c.setSession(true, listing)
        assertTrue(c.setMachine(row))
        assertTrue(c.submit("person@example.test"))
        assertTrue((c.state as MilaMachineSharingState.Applied).principal.value.contains("@"))
        assertTrue(c.submit("person@example.test", remove = true))
        assertTrue((c.state as MilaMachineSharingState.Applied).remove)
    }

    @Test fun cannotShareMachineOutsideAuthenticatedListing() = runBlocking {
        val c = MilaMachineSharingController(SharingAdapter())
        c.setSession(true, listing)
        val other = MilaMachineRow(UUID.fromString("00000000-0000-0000-0000-000000000002"), "other", "running")
        assertFalse(c.setMachine(other))
        assertFalse(c.submit("person@example.test"))
    }

    @Test fun principalRejectsWhitespaceAndUtf8Overflow() = runBlocking {
        val c = MilaMachineSharingController(SharingAdapter())
        c.setSession(true, listing)
        c.setMachine(row)
        assertFalse(c.submit("person @example.test"))
        assertFalse(c.submit("é".repeat(130)))
        assertTrue(c.state is MilaMachineSharingState.Failed)
    }

    @Test fun malformedPrincipalIsRejectedBeforeRustCall() = runBlocking {
        val c = MilaMachineSharingController(SharingAdapter())
        c.setSession(true, listing)
        c.setMachine(row)
        assertFalse(c.submit("\u0000"))
        assertTrue(c.state is MilaMachineSharingState.Failed)
    }
}
