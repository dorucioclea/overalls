package dev.overalls.mila.nativeui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private const val FINGERPRINT = "SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU"

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class MilaApprovalTest {
    @Test fun decodesPendingApprovalWithoutPersistingSecrets() {
        val reply = """{"version":1,"status":"approval_required","fingerprint":"$FINGERPRINT","approval_url":"https://overalls.example/ssh/approve/abc"}"""
        val decoded = MilaApprovalInfo.decode(reply.toByteArray())
        val pending = decoded as MilaWhoami.Pending
        assertEquals("https://overalls.example/ssh/approve/abc", pending.approval.url)
        assertEquals(FINGERPRINT, pending.approval.fingerprint)
    }

    @Test fun refusesForeignOrUnsafeApprovalLinks() {
        val unsafe = listOf(
            "http://overalls.example/ssh/approve/abc",
            "https://user@overalls.example/ssh/approve/abc",
            "https://overalls.example/ssh/approve/abc#fragment",
        )
        unsafe.forEach { url ->
            assertTrue(MilaApprovalInfo.decode(
                """{"version":1,"status":"approval_required","fingerprint":"$FINGERPRINT","approval_url":"$url"}""".toByteArray(),
            ) is MilaWhoami.Invalid)
        }
        val foreign = MilaApprovalInfo.decode(
            """{"version":1,"status":"approval_required","fingerprint":"$FINGERPRINT","approval_url":"https://other.example/ssh/approve/abc"}""".toByteArray(),
            expectedHost = "overalls.example",
        )
        assertTrue(foreign is MilaWhoami.Invalid)
    }

    @Test fun approvedAndMalformedRepliesAreTyped() {
        assertEquals(MilaWhoami.Approved, MilaApprovalInfo.decode("{\"version\":1,\"status\":\"succeeded\"}".toByteArray()))
        assertEquals(MilaWhoami.Invalid, MilaApprovalInfo.decode("{\"version\":2}".toByteArray()))
    }
}
