package dev.overalls.mila.nativeui

/** Pure Android projection of the Rust AppLock state machine.
 *
 * Platform authentication is supplied by [authenticate]. No secret or credential crosses this
 * boundary; only the success bit is applied with the current attempt number.
 */
enum class MilaLockDelay(val millis: Long) { Immediate(0), OneMinute(60_000), FiveMinutes(300_000) }
enum class MilaLockAvailability { Unknown, Available, Unavailable }
enum class MilaLockPhase { Unlocked, Locked, Authenticating }

data class MilaAppLockState(
    val enabled: Boolean,
    val delay: MilaLockDelay,
    val availability: MilaLockAvailability = MilaLockAvailability.Unknown,
    val phase: MilaLockPhase = if (enabled) MilaLockPhase.Locked else MilaLockPhase.Unlocked,
    val attempt: UInt = 0u,
    val backgroundedAt: Long? = null,
    val lastFailed: Boolean = false,
) {
    val obscured: Boolean get() = phase != MilaLockPhase.Unlocked
    val effective: Boolean get() = enabled && availability != MilaLockAvailability.Unavailable

    fun availability(value: MilaLockAvailability): MilaAppLockState =
        if (value == MilaLockAvailability.Unavailable) copy(availability = value, phase = MilaLockPhase.Unlocked, lastFailed = false)
        else copy(availability = value)

    fun enable(): MilaAppLockState = if (phase == MilaLockPhase.Unlocked && availability == MilaLockAvailability.Available) copy(enabled = true) else this
    fun disable(): MilaAppLockState = if (phase == MilaLockPhase.Unlocked) copy(enabled = false) else this
    fun delay(value: MilaLockDelay): MilaAppLockState = if (phase == MilaLockPhase.Unlocked) copy(delay = value) else this

    fun backgrounded(at: Long): MilaAppLockState = if (phase == MilaLockPhase.Authenticating) this else copy(
        backgroundedAt = at,
        phase = if (effective && delay == MilaLockDelay.Immediate) MilaLockPhase.Locked else phase,
    )

    fun foregrounded(at: Long): MilaAppLockState {
        if (phase == MilaLockPhase.Authenticating) return this
        val shouldLock = effective && backgroundedAt?.let { at < it || at - it >= delay.millis } == true
        return copy(backgroundedAt = null, phase = if (shouldLock) MilaLockPhase.Locked else phase)
    }

    fun requestUnlock(): MilaAppLockState = if (phase == MilaLockPhase.Locked && availability == MilaLockAvailability.Available)
        copy(phase = MilaLockPhase.Authenticating, attempt = attempt + 1u) else this

    fun finishUnlock(token: UInt, success: Boolean): MilaAppLockState = if (phase == MilaLockPhase.Authenticating && token == attempt)
        if (success) copy(phase = MilaLockPhase.Unlocked, backgroundedAt = null, lastFailed = false)
        else copy(phase = MilaLockPhase.Locked, lastFailed = true)
    else this
}

/** Small persistence boundary; implementations should use encrypted, device-only preferences. */
interface MilaAppLockStore {
    fun read(): MilaAppLockState?
    fun write(state: MilaAppLockState)
}

class MilaAppLockPreferencesStore(private val preferences: android.content.SharedPreferences) : MilaAppLockStore {
    override fun read(): MilaAppLockState? {
        if (!preferences.contains("enabled")) return null
        val delay = MilaLockDelay.entries.firstOrNull { it.name == preferences.getString("delay", null) } ?: MilaLockDelay.Immediate
        return MilaAppLockState(preferences.getBoolean("enabled", false), delay)
    }
    override fun write(state: MilaAppLockState) {
        preferences.edit().putBoolean("enabled", state.enabled).putString("delay", state.delay.name).apply()
    }
}

class MilaAppLockController(private val store: MilaAppLockStore, initial: MilaAppLockState = store.read() ?: MilaAppLockState(false, MilaLockDelay.Immediate)) {
    var state: MilaAppLockState = initial
        private set

    private fun update(next: MilaAppLockState) { state = next; store.write(next) }
    fun setAvailability(value: MilaLockAvailability) = update(state.availability(value))
    fun setEnabled(value: Boolean) = update(if (value) state.enable() else state.disable())
    fun setDelay(value: MilaLockDelay) = update(state.delay(value))
    fun onBackground(at: Long) = update(state.backgrounded(at))
    fun onForeground(at: Long) = update(state.foregrounded(at))
    fun requestUnlock(): UInt? { val next = state.requestUnlock(); update(next); return next.attempt.takeIf { next.phase == MilaLockPhase.Authenticating } }
    fun pendingAttempt(): UInt? = state.attempt.takeIf { state.phase == MilaLockPhase.Authenticating }
    fun finishUnlock(token: UInt, success: Boolean) = update(state.finishUnlock(token, success))
}
