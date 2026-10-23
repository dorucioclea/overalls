package dev.overalls.mila.nativeui

import android.content.Intent

/** Builds a text share intent only for a canonical navigation route. */
internal object MilaShareIntentFactory {
    fun create(route: MilaRoute): Intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, route.toCanonicalUri())
    }

    private fun MilaRoute.toCanonicalUri(): String = when (this) {
        MilaRoute.Machines -> "overalls://mila/machines"
        MilaRoute.Threads -> "overalls://mila/threads"
        MilaRoute.Settings -> "overalls://mila/settings"
        is MilaRoute.Machine -> "overalls://mila/machines/${id}
        is MilaRoute.Thread -> "overalls://mila/threads/${id}"
    }
}
