package dev.overalls.mila.nativeui

import org.junit.Assert.assertEquals
import org.junit.Test

private class MemorySettingsStore : MilaSettingsStore {
    val values = mutableMapOf<String, String>()
    override fun read(key: String): String? = values[key]
    override fun write(key: String, value: String) { values[key] = value }
}

class MilaSettingsTest {
    @Test fun localeIsCanonicalizedToBcp47() {
        assertEquals("fr", canonicalMilaLocale(" fr_fr "))
        assertEquals("fr", canonicalMilaLocale("fr-FR"))
        assertEquals(null, canonicalMilaLocale("not a locale"))
        assertEquals(null, canonicalMilaLocale("en-" + "x".repeat(64)))
    }
    @Test fun roundTripPreservesTypedPreferences() {
        val store = MemorySettingsStore(); val controller = MilaSettingsController(store)
        val expected = MilaSettings(MilaAppearance.Dark, "fr"); controller.save(expected)
        assertEquals(expected, controller.load())
    }
    @Test fun malformedValuesUseSafeDefaults() {
        val store = MemorySettingsStore().also { it.values["mila.appearance"] = "invalid"; it.values["mila.locale"] = "not a locale" }
        assertEquals(MilaSettings(), MilaSettingsController(store).load())
    }
    @Test fun unsupportedCanonicalLocaleFallsBackToBundledDefault() {
        val store = MemorySettingsStore().also { it.values["mila.locale"] = "zh-CN" }
        assertEquals("zh-Hans", MilaSettingsController(store).load().locale)
    }
    @Test fun saveWritesCanonicalLocale() {
        val store = MemorySettingsStore(); MilaSettingsController(store).save(MilaSettings(MilaAppearance.System, " fr_fr "))
        assertEquals("fr", store.values["mila.locale"])
    }
    @Test fun localeDirectionIsTypedAndFailsClosed() {
        assertEquals(MilaLocaleDirection.Rtl, milaLocaleDirection("ar-EG"))
        assertEquals(MilaLocaleDirection.Rtl, milaLocaleDirection("fa"))
        assertEquals(MilaLocaleDirection.Ltr, milaLocaleDirection("en"))
        assertEquals(MilaLocaleDirection.Ltr, milaLocaleDirection("bad locale"))
    }
}
