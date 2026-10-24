namespace Mila.Windows.Interop;

internal enum MilaMachineMutationStateKind { SignedOut, Ready, Applied, Failed }
internal sealed record MilaMachineMutationState(MilaMachineMutationStateKind Kind, Guid? MachineId, string? Action, string? Error);

/// <summary>Owns authenticated machine mutation dispatch and keeps UI state typed.</summary>
internal sealed class MilaMachineMutationController
{
    internal MilaMachineMutationState State { get; private set; } = new(MilaMachineMutationStateKind.SignedOut, null, null, null);
    private bool _authenticated;
    private ulong _handle;
    private readonly HashSet<string> _requests = new(StringComparer.Ordinal);

    internal void SetSession(bool authenticated, ulong handle = 0) {
        _authenticated = authenticated && handle != 0;
        _handle = _authenticated ? handle : 0;
        if (!_authenticated) _requests.Clear();
        State = _authenticated
            ? new(MilaMachineMutationStateKind.Ready, null, null, null)
            : new(MilaMachineMutationStateKind.SignedOut, null, null, null);
    }

    internal bool Submit(Guid machineId, string action, string requestId)
    {
        if (!_authenticated) { State = new(MilaMachineMutationStateKind.SignedOut, null, action, null); return false; }
        if (machineId == Guid.Empty || action is not ("start" or "stop" or "pause" or "resume" or "delete") || !ValidRequest(requestId) || !_requests.Add(requestId))
        { State = new(MilaMachineMutationStateKind.Failed, machineId, action, "InvalidRequest"); return false; }
        MilaNativeSessionActionResult result = RustNative.TrySessionMachineAction(_handle, machineId, action, requestId);
        State = result.Succeeded
            ? new(MilaMachineMutationStateKind.Applied, machineId, action, null)
            : new(MilaMachineMutationStateKind.Failed, machineId, action, result.Status.ToString());
        return result.Succeeded;
    }

    internal bool Resize(Guid machineId, uint cpu, ulong memory, ulong disk, string requestId)
    {
        if (!_authenticated)
        {
            State = new(MilaMachineMutationStateKind.SignedOut, machineId, "resize", null);
            return false;
        }
        if (machineId == Guid.Empty || cpu == 0 || memory == 0 || disk == 0 || !ValidRequest(requestId) || !_requests.Add(requestId))
        { State = new(MilaMachineMutationStateKind.Failed, machineId, "resize", "InvalidRequest"); return false; }
        MilaNativeSessionActionResult result = RustNative.TrySessionMachineResize(
            _handle, machineId, cpu, memory, disk, requestId);
        State = result.Succeeded
            ? new(MilaMachineMutationStateKind.Applied, machineId, "resize", null)
            : new(MilaMachineMutationStateKind.Failed, machineId, "resize", result.Status.ToString());
        return result.Succeeded;
    }

    private static bool ValidRequest(string requestId) => requestId.Length is > 0 and <= 128 && requestId.All(c => !char.IsControl(c));
}
