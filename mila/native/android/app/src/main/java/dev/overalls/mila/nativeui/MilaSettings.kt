package dev.overalls.mila.nativeui

import android.content.SharedPreferences
import java.util.Locale

/** Persisted user preferences shared by the Android shell and its tests. */
enum class MilaAppearance { System, Light, Dark }

data class MilaSettings(
    val appearance: MilaAppearance = MilaAppearance.System,
    val locale: String = "en",
) {
    init { require(canonicalMilaLocale(locale) != null) { "invalid locale" } }
}

/** Canonical BCP-47 locale accepted by the shared catalog loader. */
fun canonicalMilaLocale(value: String): String? {
    val normalized = value.trim().replace('_', '-')
    if (!normalized.matches(Regex("^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$"))) return null
    val tag = Locale.forLanguageTag(normalized).toLanguageTag()
    return tag.takeIf { it != "und" && it.substringBefore('-').length in 2..3 }
}

interface MilaSettingsStore {
    fun read(key: String): String?
    fun write(key: String, value: String)
}

class MilaSharedPreferencesStore(private val preferences: SharedPreferences) : MilaSettingsStore {
    override fun read(key: String): String? = preferences.getString(key, null)
    override fun write(key: String, value: String) { preferences.edit().putString(key, value).apply() }
}

/** Typed boundary around platform key/value storage; malformed values fall back safely. */
class MilaSettingsController(private val store: MilaSettingsStore) {
    fun load(): MilaSettings {
        val appearance = when (store.read(KEY_APPEARANCE)?.lowercase()) {
            "light" -> MilaAppearance.Light
            "dark" -> MilaAppearance.Dark
            else -> MilaAppearance.System
        }
        val locale = store.read(KEY_LOCALE)?.let(::canonicalMilaLocale)?.takeIf { it in MilaStrings.supportedLocales } ?: "en"
        return MilaSettings(appearance, locale)
    }

    fun save(settings: MilaSettings) {
        store.write(KEY_APPEARANCE, settings.appearance.name.lowercase())
        store.write(KEY_LOCALE, settings.locale)
    }

    private companion object {
        const val KEY_APPEARANCE = "mila.appearance"
        const val KEY_LOCALE = "mila.locale"
    }
}
