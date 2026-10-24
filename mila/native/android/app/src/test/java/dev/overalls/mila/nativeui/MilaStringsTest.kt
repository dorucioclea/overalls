package dev.overalls.mila.nativeui

import org.junit.Assert.assertEquals
import org.junit.Test

class MilaStringsTest {
    @Test fun supportedLocaleCatalogIncludesRtlHebrew() {
        assert(MilaStrings.supportedLocales.contains("he"))
        assertEquals(MilaLocaleDirection.Rtl, milaLocaleDirection("he"))
    }

    @Test fun stableMessageIdentityHasDeterministicFallback() {
        assertEquals("Mila", MilaStrings.text(MilaMessage.AppName))
        assertEquals("Machines", MilaStrings.text(MilaMessage.Machines))
        assertEquals("Reconnect", MilaStrings.text(MilaMessage.Reconnect))
    }
}
