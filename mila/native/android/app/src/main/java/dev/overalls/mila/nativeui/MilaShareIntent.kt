package dev.overalls.mila.nativeui

import android.content.Intent

/** Builds a text share intent only for a canonical navigation route. */
internal object MilaShareIntentFactory {
    fun create(route: MilaRoute): Intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, route.toCanonicalUri())
    }

    /** Wraps the route payload in the platform chooser without exposing arbitrary text. */
    fun chooser(route: MilaRoute): Intent = Intent.createChooser(create(route), null)

    /** Returns a chooser only for an authenticated session; signed-out callers cannot share routes. */
    fun authenticatedChooser(route: MilaRoute, signedIn: Boolean): Intent? =
        if (signedIn) chooser(route) else null

    private fun MilaRoute.toCanonicalUri(): String = when (this) {
        MilaRoute.Machines -> "overalls://mila/machines"
        MilaRoute.Threads -> "overalls://mila/threads"
        MilaRoute.Settings -> "overalls://mila/settings"
        is MilaRoute.Machine -> "overalls://mila/machines/${id}"
        is MilaRoute.Thread -> "overalls://mila/threads/${id}"
    }
}
