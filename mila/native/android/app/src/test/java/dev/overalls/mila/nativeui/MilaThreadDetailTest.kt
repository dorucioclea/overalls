package dev.overalls.mila.nativeui

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.UUID

private class ThreadAdapter(private val accepted: Boolean = true) : MilaFfiAdapter {
    override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
    override suspend fun threadAction(threadId: UUID, command: MilaThreadCommand): Result<Unit> =
        if (accepted) Result.success(Unit) else Result.failure(IllegalStateException("rejected"))
    override suspend fun threadAction(threadId: UUID, command: MilaThreadCommand, input: String?): Result<Unit> =
        if (accepted) Result.success(Unit) else Result.failure(IllegalStateException("rejected"))
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class MilaThreadDetailTest {
    @Test fun decodesBoundedThreadListing() {
        val id = "00000000-0000-0000-0000-000000000001"
        val listing = MilaThreadListing.decode("""{"result":{"threads":[{"id":"$id","title":"Build","status":"open"}],"has_more":false}}""".toByteArray())
        assertEquals(1, listing.threads.size)
        assertEquals("Build", listing.threads.single().title)
    }
    private val id = UUID.fromString("00000000-0000-0000-0000-000000000002")
    private val listing = MilaThreadListing(listOf(MilaThreadRow(id, "deploy", "active")), false)


    @Test fun rejectsZeroThreadIdentifier() {
        assertThrows(IllegalArgumentException::class.java) {
            MilaThreadListing.decode("""{"result":{"threads":[{"id":"00000000-0000-0000-0000-000000000000","title":"Build","status":"open"}]}}""".toByteArray())
        }
    }

    @Test fun rejectsOversizedThreadProjectionFields() {
        val id = "00000000-0000-0000-0000-000000000003"
        val title = "x".repeat(257)
        assertThrows(IllegalArgumentException::class.java) {
            MilaThreadListing.decode("""{"result":{"threads":[{"id":"$id","title":"$title","status":"open"}]}}""".toByteArray())
        }
    }

    @Test fun threadActionsRequireAuthenticationAndSelection() = runBlocking {
        val controller = MilaThreadDetailController(ThreadAdapter())
        assertFalse(controller.select(id))
        assertFalse(controller.submit(MilaThreadCommand.Show))
        assertFalse(controller.canSubmit())
        controller.setSession(true, listing)
        assertTrue(controller.select(id))
        assertTrue(controller.canSubmit())
        assertTrue(controller.submit(MilaThreadCommand.Turns))
        assertEquals(MilaThreadActionState.Applied(listing.threads.single(), MilaThreadCommand.Turns), controller.state)
    }

    @Test fun promptAndAnswerRequireBoundedInput() = runBlocking {
        val controller = MilaThreadDetailController(ThreadAdapter())
        controller.setSession(true, listing)
        controller.select(id)
        assertFalse(controller.submit(MilaThreadCommand.Prompt, ""))
        assertTrue(controller.state is MilaThreadActionState.Failed)
        assertTrue(controller.submit(MilaThreadCommand.Prompt, "approve\nplan"))
        assertFalse(controller.submit(MilaThreadCommand.Show, "unexpected"))
    }

    @Test fun promptInputUsesUtf8ByteBound() = runBlocking {
        val controller = MilaThreadDetailController(ThreadAdapter())
        controller.setSession(true, listing)
        controller.select(id)
        assertFalse(controller.submit(MilaThreadCommand.Prompt, "é".repeat(2049)))
        assertTrue(controller.submit(MilaThreadCommand.Prompt, "é".repeat(2048)))
    }

    @Test fun planApprovalUsesClosedCommandInputContract() = runBlocking {
        val controller = MilaThreadDetailController(ThreadAdapter())
        controller.setSession(true, listing)
        controller.select(id)
        assertTrue(controller.submit(MilaThreadCommand.PlanApprove))
        assertFalse(controller.submit(MilaThreadCommand.PlanApprove, "unexpected"))
        assertTrue(controller.submit(MilaThreadCommand.PlanRevise, "tighten rollout"))
    }

    @Test fun rejectedThreadCommandIsTyped() = runBlocking {
        val controller = MilaThreadDetailController(ThreadAdapter(false))
        controller.setSession(true, listing)
        controller.select(id)
        assertFalse(controller.submit(MilaThreadCommand.Answer))
        assertTrue(controller.state is MilaThreadActionState.Failed)
    }
}
