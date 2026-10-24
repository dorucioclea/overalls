package dev.overalls.mila.nativeui

import java.util.UUID
import org.json.JSONObject

data class MilaThreadRow(val id: UUID, val title: String, val status: String)
data class MilaThreadListing(val threads: List<MilaThreadRow>, val hasMore: Boolean) {
 companion object {
  fun decode(bytes: ByteArray): MilaThreadListing {
    require(bytes.size <= 256 * 1024)
    val result = JSONObject(bytes.toString(Charsets.UTF_8)).optJSONObject("result") ?: JSONObject()
    val rows = result.optJSONArray("threads") ?: result.optJSONArray("items") ?: error("threads missing")
    require(rows.length() <= 500)
    val threads = buildList {
        for (index in 0 until rows.length()) {
            val row = rows.getJSONObject(index)
            val title = row.optString("title")
            val status = row.optString("status")
            require(title.toByteArray(Charsets.UTF_8).size <= 256)
            require(status.toByteArray(Charsets.UTF_8).size <= 64)
            val id = UUID.fromString(row.getString("id"))
            require(id != UUID(0L, 0L))
            add(MilaThreadRow(id, title, status))
        }
    }
    return MilaThreadListing(threads, result.optBoolean("has_more", false))
  }
 }
}

sealed interface MilaThreadActionState {
    data object SignedOut : MilaThreadActionState
    data object Idle : MilaThreadActionState
    data class Ready(val thread: MilaThreadRow) : MilaThreadActionState
    data class Submitting(val thread: MilaThreadRow, val command: MilaThreadCommand) : MilaThreadActionState
    data class Applied(val thread: MilaThreadRow, val command: MilaThreadCommand) : MilaThreadActionState
    data class Failed(val thread: MilaThreadRow, val command: MilaThreadCommand, val reason: String) : MilaThreadActionState
}

class MilaThreadDetailController(private val adapter: MilaFfiAdapter) {
    var state: MilaThreadActionState = MilaThreadActionState.SignedOut
        private set
    private var listing: MilaThreadListing? = null
    private var authenticated = false

    fun setSession(signedIn: Boolean, current: MilaThreadListing?) {
        val active = signedIn && current != null
        if (active == authenticated && current == listing) return
        authenticated = active
        listing = if (active) current else null
        state = if (active) MilaThreadActionState.Idle else MilaThreadActionState.SignedOut
    }

    fun select(id: UUID): Boolean {
        val thread = listing?.threads?.firstOrNull { it.id == id } ?: return false
        state = MilaThreadActionState.Ready(thread)
        return true
    }

    /** Whether the selected thread can accept a command in the current authenticated lifecycle. */
    fun canSubmit(): Boolean = authenticated && state is MilaThreadActionState.Ready

    suspend fun submit(command: MilaThreadCommand): Boolean = submit(command, null)

    suspend fun submit(command: MilaThreadCommand, input: String?): Boolean {
        val thread = (state as? MilaThreadActionState.Ready)?.thread ?: return false
        if (!authenticated) { state = MilaThreadActionState.SignedOut; return false }
        val needsInput = command == MilaThreadCommand.Prompt || command == MilaThreadCommand.Answer || command == MilaThreadCommand.PlanRevise
        val inputBytes = input?.toByteArray(Charsets.UTF_8)
        if (needsInput && (inputBytes == null || inputBytes.isEmpty() || inputBytes.size > 4096 || input.any { it.code < 0x20 && it !in "\n\r\t" })) {
            state = MilaThreadActionState.Failed(thread, command, "invalid thread input")
            return false
        }
        if (!needsInput && input != null) {
            state = MilaThreadActionState.Failed(thread, command, "input is not accepted for this command")
            return false
        }
        state = MilaThreadActionState.Submitting(thread, command)
        return adapter.threadAction(thread.id, command, input).fold(
            { state = MilaThreadActionState.Applied(thread, command); true },
            { error -> state = MilaThreadActionState.Failed(thread, command, error.message ?: "command rejected"); false },
        )
    }
}
