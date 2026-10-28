package dev.overalls.mila.nativeui

import org.junit.Assert.assertEquals
import org.junit.Test

class MilaStringsTest {
    @Test fun supportedLocaleCatalogIncludesRtlUrdu() {
        assert(MilaStrings.supportedLocales.contains("ur"))
        assertEquals(MilaLocaleDirection.Rtl, milaLocaleDirection("ur"))
    }

    @Test fun stableMessageIdentityHasDeterministicFallback() {
        assertEquals("Mila", MilaStrings.text(MilaMessage.AppName))
        assertEquals("Machines", MilaStrings.text(MilaMessage.Machines))
        assertEquals("Reconnect", MilaStrings.text(MilaMessage.Reconnect))
    }
}
