using System;
using System.Threading;
using System.Threading.Tasks;

namespace Mila.Windows.Interop;

public enum MilaWindowsHelloAvailability
{
    Unknown,
    Available,
    Unavailable
}

public enum MilaWindowsHelloVerification
{
    Verified,
    Unavailable,
    Rejected
}

public interface IMilaWindowsHelloVerifier
{
    Task<MilaWindowsHelloAvailability> CheckAvailabilityAsync(CancellationToken cancellationToken = default);
    Task<MilaWindowsHelloVerification> VerifyAsync(string message, CancellationToken cancellationToken = default);
}

public enum MilaAppLockState { Unlocked, Locked, Unavailable }

/// Owns the app-lock boundary. UI code only observes state and asks this controller
/// to unlock; credentials and verification details never cross this interface.
public sealed class MilaAppLockController
{
    private readonly IMilaWindowsHelloVerifier _verifier;
    public MilaAppLockState State { get; private set; } = MilaAppLockState.Unlocked;
    public bool IsLocked => State == MilaAppLockState.Locked;

    public MilaAppLockController(IMilaWindowsHelloVerifier verifier)
    {
        _verifier = verifier ?? throw new ArgumentNullException(nameof(verifier));
    }

    public async Task<MilaAppLockState> RefreshAvailabilityAsync(CancellationToken cancellationToken = default)
    {
        MilaWindowsHelloAvailability availability;
        try { availability = await _verifier.CheckAvailabilityAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { throw; }
        catch (Exception) { availability = MilaWindowsHelloAvailability.Unavailable; }
        if (availability != MilaWindowsHelloAvailability.Available && !IsLocked) State = MilaAppLockState.Unavailable;
        else if (availability == MilaWindowsHelloAvailability.Available && State == MilaAppLockState.Unavailable) State = MilaAppLockState.Unlocked;
        return State;
    }

    /// Locks the app when the native window loses activation.
    public void OnDeactivated() => Lock();

    public void Lock()
    {
        if (State != MilaAppLockState.Unavailable) State = MilaAppLockState.Locked;
    }

    public async Task<bool> UnlockAsync(CancellationToken cancellationToken = default)
    {
        if (!IsLocked) return State == MilaAppLockState.Unlocked;
        MilaWindowsHelloVerification result;
        try { result = await _verifier.VerifyAsync("Unlock Mila", cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { throw; }
        catch (Exception) { result = MilaWindowsHelloVerification.Rejected; }
        if (result == MilaWindowsHelloVerification.Verified) { State = MilaAppLockState.Unlocked; return true; }
        return false;
    }
}
