package dev.overalls.mila.nativeui

import android.content.Intent
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class MilaIntentRoutingTest {
    @Test fun viewAndShareRoutesAreAccepted() {
        val id = UUID.randomUUID()
        val controller = MilaDeepLinkController()
        val generation = controller.beginSession()
        assertTrue(acceptExternalIntent(controller, Intent(Intent.ACTION_VIEW).setData(android.net.Uri.parse("overalls://mila/machines/$id")), generation))
        assertEquals(MilaRoute.Machines, controller.target)
        assertTrue(acceptAuthenticatedExternalIntent(controller, Intent(Intent.ACTION_VIEW).setData(android.net.Uri.parse("overalls://mila/machines/$id")), generation, signedIn = true))
        assertEquals(MilaRoute.Machine(id), controller.target)
        val share = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "overalls://mila/threads")
        assertTrue(acceptExternalIntent(controller, share, generation))
        assertEquals(MilaRoute.Machines, controller.target)
    }

    @Test fun authenticatedShareTargetRefusesSignedOutSession() {
        val controller = MilaDeepLinkController()
        val generation = controller.beginSession()
        val share = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "overalls://mila/threads")
        assertFalse(acceptAuthenticatedExternalIntent(controller, share, generation, signedIn = false))
        assertEquals(MilaRoute.Machines, controller.target)
        assertTrue(acceptAuthenticatedExternalIntent(controller, share, generation, signedIn = true))
        assertEquals(MilaRoute.Threads, controller.target)
    }

    @Test fun nonTextSharePayloadIsRejected() {
        val controller = MilaDeepLinkController()
        val generation = controller.beginSession()
        val share = Intent(Intent.ACTION_SEND).setType("image/png")
            .putExtra(Intent.EXTRA_TEXT, "overalls://mila/threads")
        assertFalse(acceptExternalIntent(controller, share, generation))
        assertEquals(MilaRoute.Machines, controller.target)
    }

    @Test fun nonNavigationShareTextIsRejected() {
        val controller = MilaDeepLinkController()
        val generation = controller.beginSession()
        val share = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "https://example.invalid/command?rm")
        assertFalse(acceptExternalIntent(controller, share, generation))
        assertEquals(MilaRoute.Machines, controller.target)
    }
}

