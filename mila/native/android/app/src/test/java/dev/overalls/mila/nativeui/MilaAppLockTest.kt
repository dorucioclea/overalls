package dev.overalls.mila.nativeui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MilaAppLockTest {
    @Test fun immediateLockObscuresWhenBackgrounded() {
        var state = MilaAppLockState(false, MilaLockDelay.Immediate).availability(MilaLockAvailability.Available)
        state = state.enable().backgrounded(100)
        assertEquals(MilaLockPhase.Locked, state.phase)
        assertTrue(state.obscured)
    }

    @Test fun delayedLockStaysUnlockedBeforeDeadline() {
        var state = MilaAppLockState(false, MilaLockDelay.OneMinute).availability(MilaLockAvailability.Available)
        state = state.enable().backgrounded(100).foregrounded(101)
        assertEquals(MilaLockPhase.Unlocked, state.phase)
        state = state.backgrounded(200).foregrounded(260)
        assertEquals(MilaLockPhase.Unlocked, state.phase)
        state = state.backgrounded(300).foregrounded(361)
        assertEquals(MilaLockPhase.Locked, state.phase)
    }

    @Test fun staleUnlockResultCannotUnlockNewAttempt() {
        var state = MilaAppLockState(true, MilaLockDelay.Immediate, MilaLockAvailability.Available, MilaLockPhase.Locked)
        val token = state.requestUnlock().attempt
        state = state.finishUnlock(token + 1u, true)
        assertEquals(MilaLockPhase.Authenticating, state.phase)
        state = state.finishUnlock(token, true)
        assertEquals(MilaLockPhase.Unlocked, state.phase)
    }

    @Test fun backgroundingAuthenticationInvalidatesPromptResult() {
        var state = MilaAppLockState(true, MilaLockDelay.Immediate, MilaLockAvailability.Available, MilaLockPhase.Locked)
        val token = state.requestUnlock().attempt
        state = state.backgrounded(100)
        assertEquals(MilaLockPhase.Locked, state.phase)
        state = state.finishUnlock(token, true)
        assertEquals(MilaLockPhase.Locked, state.phase)
    }
    @Test fun unavailableAuthenticatorCannotEnableOrUnlock() {
        val store = object : MilaAppLockStore {
            var value: MilaAppLockState? = null
            override fun read(): MilaAppLockState? = value
            override fun write(state: MilaAppLockState) { value = state }
        }
        val controller = MilaAppLockController(store, MilaAppLockState(false, MilaLockDelay.Immediate))
        controller.setAvailability(MilaLockAvailability.Unavailable)
        controller.setEnabled(true)
        assertEquals(false, controller.state.enabled)
        assertEquals(null, controller.requestUnlock())
    }
}
