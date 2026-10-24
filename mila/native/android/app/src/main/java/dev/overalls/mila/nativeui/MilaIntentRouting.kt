package dev.overalls.mila.nativeui

import android.content.Intent

/** Extracts navigation-only targets from Android external intents. */
internal fun externalMilaUri(intent: Intent): String? = when (intent.action) {
    Intent.ACTION_VIEW -> intent.dataString
    Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
    else -> null
}

/** A share target is accepted only when its text is itself a canonical Mila route. */
internal fun acceptExternalIntent(controller: MilaDeepLinkController, intent: Intent, generation: Long): Boolean =
    externalMilaUri(intent)?.let { controller.accept(it, generation) } ?: false

/** Accepts an external route only while the native session is authenticated. */
internal fun acceptAuthenticatedExternalIntent(
    controller: MilaDeepLinkController,
    intent: Intent,
    generation: Long,
    signedIn: Boolean,
): Boolean = signedIn && acceptExternalIntent(controller, intent, generation)
