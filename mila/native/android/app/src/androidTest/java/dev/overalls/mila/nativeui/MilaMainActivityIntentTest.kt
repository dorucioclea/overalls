package dev.overalls.mila.nativeui

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/** Packaged smoke coverage for the native activity's external route lifecycle. */
@RunWith(AndroidJUnit4::class)
class MilaMainActivityIntentTest {
    @Test
    fun canonicalViewIntentLaunchesNativeActivity() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = android.net.Uri.parse("overalls://mila/machines")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val activity = instrumentation.startActivitySync(intent)
        assertNotNull(activity)
        activity.finish()
    }
}
