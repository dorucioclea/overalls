package dev.overalls.mila.nativeui

import java.util.UUID

/** A validated machine principal used by the sharing surface. */
data class MilaSharePrincipal private constructor(val value: String) {
    companion object {
        fun parse(raw: String): Result<MilaSharePrincipal> {
            val value = raw.trim()
            if (value.length !in 3..256 || value.toByteArray(Charsets.UTF_8).size > 256 || value.any { it.isISOControl() || it.isWhitespace() }) {
                return Result.failure(IllegalArgumentException("invalid share principal"))
            }
            return Result.success(MilaSharePrincipal(value))
        }
    }
}

sealed interface MilaMachineSharingState {
    data object SignedOut : MilaMachineSharingState
    data object Idle : MilaMachineSharingState
    data class Ready(val machine: MilaMachineRow) : MilaMachineSharingState
    data class Submitting(val machine: MilaMachineRow, val principal: MilaSharePrincipal, val remove: Boolean) : MilaMachineSharingState
    data class Applied(val machine: MilaMachineRow, val principal: MilaSharePrincipal, val remove: Boolean) : MilaMachineSharingState
    data class Failed(val machine: MilaMachineRow, val principal: MilaSharePrincipal?, val remove: Boolean, val reason: String) : MilaMachineSharingState
}

/**
 * Coordinates authenticated machine sharing. Principal syntax is checked before the Rust
 * machine command is submitted; the closed command catalog remains authoritative for add/remove.
 */
class MilaMachineSharingController(private val adapter: MilaFfiAdapter) {
    var state: MilaMachineSharingState = MilaMachineSharingState.SignedOut
        private set
    private var machine: MilaMachineRow? = null
    private var listing: MilaSessionListing? = null
    private var authenticated = false

    fun setSession(signedIn: Boolean, listing: MilaSessionListing?) {
        this.listing = listing
        authenticated = signedIn && listing != null
        machine = if (authenticated) machine?.let { current -> listing!!.machines.firstOrNull { it.id == current.id } } else null
        state = if (!authenticated) MilaMachineSharingState.SignedOut else machine?.let { MilaMachineSharingState.Ready(it) } ?: MilaMachineSharingState.Idle
    }

    fun select(machineId: UUID): Boolean {
        if (!authenticated) return false
        return true.also {
            // Selection is supplied by the current authenticated listing through setMachine.
        }
    }

    fun setMachine(selected: MilaMachineRow): Boolean {
        if (!authenticated || listing?.machines?.none { it.id == selected.id } == true) return false
        machine = selected
        state = MilaMachineSharingState.Ready(selected)
        return true
    }

    suspend fun submit(rawPrincipal: String, remove: Boolean = false): Boolean {
        val current = machine ?: return false
        val principal = MilaSharePrincipal.parse(rawPrincipal).getOrElse {
            state = MilaMachineSharingState.Failed(current, null, remove, "invalid share principal")
            return false
        }
        if (!authenticated) { state = MilaMachineSharingState.SignedOut; return false }
        state = MilaMachineSharingState.Submitting(current, principal, remove)
        val command = if (remove) MilaMachineCommand.ShareRemove else MilaMachineCommand.ShareAdd
        return adapter.machineAction(current.id, command).fold(
            onSuccess = { state = MilaMachineSharingState.Applied(current, principal, remove); true },
            onFailure = { error -> state = MilaMachineSharingState.Failed(current, principal, remove, error.message ?: "sharing rejected"); false },
        )
    }
}
