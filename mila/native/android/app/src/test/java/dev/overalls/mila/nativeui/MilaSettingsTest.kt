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
        assertEquals("fr-FR", canonicalMilaLocale(" fr_fr "))
        assertEquals("fr-FR", canonicalMilaLocale("fr-FR"))
        assertEquals(null, canonicalMilaLocale("not a locale"))
    }
    @Test fun roundTripPreservesTypedPreferences() {
        val store = MemorySettingsStore(); val controller = MilaSettingsController(store)
        val expected = MilaSettings(MilaAppearance.Dark, "fr-FR"); controller.save(expected)
        assertEquals(expected, controller.load())
    }
    @Test fun malformedValuesUseSafeDefaults() {
        val store = MemorySettingsStore().also { it.values["mila.appearance"] = "invalid"; it.values["mila.locale"] = "not a locale" }
        assertEquals(MilaSettings(), MilaSettingsController(store).load())
    }
    @Test fun unsupportedCanonicalLocaleFallsBackToBundledDefault() {
        val store = MemorySettingsStore().also { it.values["mila.locale"] = "zh-CN" }
        assertEquals("en", MilaSettingsController(store).load().locale)
    }
    @Test fun localeDirectionIsTypedAndFailsClosed() {
        assertEquals(MilaLocaleDirection.Rtl, milaLocaleDirection("ar-EG"))
        assertEquals(MilaLocaleDirection.Rtl, milaLocaleDirection("fa"))
        assertEquals(MilaLocaleDirection.Ltr, milaLocaleDirection("en"))
        assertEquals(MilaLocaleDirection.Ltr, milaLocaleDirection("bad locale"))
    }
}
