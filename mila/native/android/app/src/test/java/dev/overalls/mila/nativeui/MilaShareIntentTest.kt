package dev.overalls.mila.nativeui

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.UUID

class MilaShareIntentTest {
    @Test fun refusesShareChooserWhenSignedOut() {
        assertEquals(null, MilaShareIntentFactory.authenticatedChooser(MilaRoute.Machines, false))
    }

    @Test fun createsCanonicalTextShareIntent() {
        val intent = MilaShareIntentFactory.create(MilaRoute.Machine(UUID.fromString("11111111-1111-1111-1111-111111111111")))
        assertEquals(Intent.ACTION_SEND, intent.action)
        assertEquals("text/plain", intent.type)
        assertEquals("overalls://mila/machines/11111111-1111-1111-1111-111111111111", intent.getStringExtra(Intent.EXTRA_TEXT))
    }
}
