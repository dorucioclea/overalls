namespace Mila.Windows.Interop;

/// <summary>Bounded, generation-fenced terminal lifecycle state.</summary>
internal sealed class MilaTerminalSession
{
    internal const int MaxOutputCharacters = 1_048_576;
    internal const int MaxInputBytes = 65_536;
    internal MilaTerminalState State { get; private set; } = MilaTerminalState.SignedOut;
    private long _generation;
    private ulong _sessionHandle;
    private bool _readWrite;
    private readonly System.Text.StringBuilder _output = new();

    internal string Output => _output.ToString();
    internal long BeginAttach(long generation, bool readWrite)
    {
        _generation = generation;
        _readWrite = readWrite;
        _output.Clear();
        State = readWrite ? MilaTerminalState.Attaching : MilaTerminalState.ReadOnly;
        return generation;
    }

    /// Starts a stream only for a live authenticated Rust session. A zero
    /// handle is never accepted, and the generation fences late PTY frames.
    internal long BeginAuthenticatedAttach(ulong sessionHandle, long generation, bool readWrite)
    {
        if (sessionHandle == 0) return 0;
        _sessionHandle = sessionHandle;
        return BeginAttach(generation, readWrite);
    }
    internal bool Append(long generation, ReadOnlySpan<char> text)
    {
        if (generation != _generation || State is MilaTerminalState.SignedOut or MilaTerminalState.Killed) return false;
        if (_output.Length + text.Length > MaxOutputCharacters) return false;
        _output.Append(text);
        State = MilaTerminalState.Live;
        return true;
    }

    /// Appends a renderer-safe projection received from the authenticated
    /// transport. The native boundary deliberately never passes terminal
    /// bytes into this class; callers must decode and sanitize in Rust first.
    internal bool AppendReceived(long generation, ReadOnlySpan<char> text) =>
        Append(generation, text);
    internal bool Resize(long generation, ushort columns, ushort rows)
    {
        if (generation != _generation || !_readWrite || columns is 0 or > 4096 || rows is 0 or > 512) return false;
        State = MilaTerminalState.Live;
        return true;
    }
    internal bool SendInput(long generation, ReadOnlySpan<byte> input)
    {
        if (generation != _generation || !_readWrite || input.Length > MaxInputBytes || State is MilaTerminalState.SignedOut or MilaTerminalState.Killed) return false;
        return true;
    }
    internal bool Reconnect(long generation) => generation == _generation &&
        State is (MilaTerminalState.Live or MilaTerminalState.ReadOnly);
    /// Marks the authenticated PTY closed by the transport. A clean EOF must
    /// invalidate reconnect and input until a fresh attach generation starts.
    internal bool ReceiveEof(long generation)
    {
        if (generation != _generation || State is MilaTerminalState.SignedOut or MilaTerminalState.Killed) return false;
        State = MilaTerminalState.Failed;
        return true;
    }
    internal void Kill(long generation) { if (generation == _generation) State = MilaTerminalState.Killed; }
    internal void SignOut() { _generation++; _readWrite = false; State = MilaTerminalState.SignedOut; _output.Clear(); }
}

internal enum MilaTerminalState { SignedOut, Attaching, ReadOnly, Live, Failed, Killed }
