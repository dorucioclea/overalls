package dev.overalls.mila.nativeui

import java.util.UUID

/** A machine mutation can only be submitted from a live signed-in listing. */
sealed interface MilaMachineMutationState {
    data object SignedOut : MilaMachineMutationState
    data object Idle : MilaMachineMutationState
    data class Ready(val machine: MilaMachineRow) : MilaMachineMutationState
    data class Submitting(val machine: MilaMachineRow, val command: MilaMachineCommand) : MilaMachineMutationState
    data class Applied(val machine: MilaMachineRow, val command: MilaMachineCommand) : MilaMachineMutationState
    data class Failed(val machine: MilaMachineRow, val command: MilaMachineCommand, val reason: String) : MilaMachineMutationState
}

/**
 * Coordinates the authenticated machine detail surface. The UI supplies command tags only
 * after Rust classification; this controller never accepts an arbitrary operation string.
 */
class MilaMachineDetailController(private val adapter: MilaFfiAdapter) {
    var state: MilaMachineMutationState = MilaMachineMutationState.SignedOut
        private set

    private var listing: MilaSessionListing? = null
    private var authenticated: Boolean = false
    private var generation: Long = 0

    fun setSession(signedIn: Boolean, current: MilaSessionListing?) {
        if (authenticated == (signedIn && current != null) && listing == current) return
        authenticated = signedIn && current != null
        listing = if (authenticated) current else null
        generation += 1
        state = if (!authenticated) MilaMachineMutationState.SignedOut else MilaMachineMutationState.Idle
    }

    fun select(machineId: UUID): Boolean {
        // The zero UUID is a sentinel and can never identify a server machine.
        // Reject it before projecting a detail row or allowing a mutation.
        if (machineId == UUID(0L, 0L)) return false
        val machine = listing?.machines?.firstOrNull { it.id == machineId } ?: return false
        state = MilaMachineMutationState.Ready(machine)
        return true
    }

    suspend fun submit(command: MilaMachineCommand): Boolean {
        val machine = (state as? MilaMachineMutationState.Ready)?.machine
            ?: return false
        if (!authenticated) {
            state = MilaMachineMutationState.SignedOut
            return false
        }
        // Only lifecycle mutations are valid on this surface. Sharing, resize,
        // and thread commands have dedicated controllers and must never cross
        // this FFI boundary.
        if (command !in setOf(
                MilaMachineCommand.Start,
                MilaMachineCommand.Stop,
                MilaMachineCommand.Pause,
                MilaMachineCommand.Resume,
                MilaMachineCommand.Delete,
            )) return false
        val submittedGeneration = generation
        state = MilaMachineMutationState.Submitting(machine, command)
        return adapter.machineAction(machine.id, command).fold(
            onSuccess = {
                if (submittedGeneration != generation || !authenticated) return@fold false
                state = MilaMachineMutationState.Applied(machine, command)
                true
            },
            onFailure = { error ->
                if (submittedGeneration != generation || !authenticated) return@fold false
                state = MilaMachineMutationState.Failed(machine, command, error.message ?: "action rejected")
                false
            },
        )
    }
}
