package dev.overalls.mila.nativeui

/** Generation-safe target routing for external Android intents. */
class MilaDeepLinkController {
    var target: MilaRoute = MilaRoute.Machines
        private set
    private var generation: Long = 0
    private var pending: String? = null

    /** Queues a validated external target until the authenticated shell consumes it. */
    fun queue(uri: String, expectedGeneration: Long = generation): Boolean {
        if (expectedGeneration != generation || parseMilaRoute(uri) == null) return false
        pending = uri
        return true
    }

    /** Applies the queued target after authentication, refusing stale generations. */
    fun acceptPending(expectedGeneration: Long = generation): Boolean {
        val uri = pending ?: return false
        pending = null
        return accept(uri, expectedGeneration)
    }

    fun accept(uri: String, expectedGeneration: Long = generation): Boolean {
        if (expectedGeneration != generation) return false
        val route = parseMilaRoute(uri) ?: return false
        target = route
        return true
    }

    fun beginSession(): Long {
        generation += 1
        target = MilaRoute.Machines
        pending = null
        return generation
    }
}
