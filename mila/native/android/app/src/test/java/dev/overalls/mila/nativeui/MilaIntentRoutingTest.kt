package dev.overalls.mila.nativeui

import android.content.Intent
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test

class MilaIntentRoutingTest {
    @Test fun viewAndShareRoutesAreAccepted() {
        val id = UUID.randomUUID()
        val controller = MilaDeepLinkController()
        val generation = controller.beginSession()
        assertTrue(acceptExternalIntent(controller, Intent(Intent.ACTION_VIEW).setData(android.net.Uri.parse("overalls://mila/machines/$id")), generation))
        assertEquals(MilaRoute.Machine(id), controller.target)
        val share = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "overalls://mila/threads")
        assertTrue(acceptExternalIntent(controller, share, generation))
        assertEquals(MilaRoute.Threads, controller.target)
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

    @Test fun nonNavigationShareTextIsRejected() {
        val controller = MilaDeepLinkController()
        val generation = controller.beginSession()
        val share = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "https://example.invalid/command?rm")
        assertFalse(acceptExternalIntent(controller, share, generation))
        assertEquals(MilaRoute.Machines, controller.target)
    }
}
