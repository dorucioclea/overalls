using System.Text.Json;
using System.IO;
namespace Mila.Windows.Interop;

internal sealed record MilaWindowsNotificationDevice(string Id, string Platform, bool Enabled);
internal enum MilaWindowsNotificationDevicesStatus { SignedOut, Loading, Loaded, Failed }

internal sealed class MilaWindowsNotificationDevicesController
{
    private readonly Func<CancellationToken, Task<IReadOnlyList<MilaWindowsNotificationDevice>>> load;
    private readonly Func<string, CancellationToken, Task> remove;
    private readonly Func<string, bool, CancellationToken, Task> preferences;
    private long generation;
    internal MilaWindowsNotificationDevicesStatus Status { get; private set; } = MilaWindowsNotificationDevicesStatus.SignedOut;
    internal IReadOnlyList<MilaWindowsNotificationDevice> Devices { get; private set; } = Array.Empty<MilaWindowsNotificationDevice>();
    internal MilaWindowsNotificationDevicesController(
        Func<CancellationToken, Task<IReadOnlyList<MilaWindowsNotificationDevice>>> load,
        Func<string, CancellationToken, Task> remove,
        Func<string, bool, CancellationToken, Task> preferences) { this.load = load; this.remove = remove; this.preferences = preferences; }

    internal async Task LoadAsync(bool signedIn, CancellationToken cancellationToken = default)
    {
        long current = Interlocked.Increment(ref generation);
        if (!signedIn) { Devices = Array.Empty<MilaWindowsNotificationDevice>(); Status = MilaWindowsNotificationDevicesStatus.SignedOut; return; }
        Status = MilaWindowsNotificationDevicesStatus.Loading;
        try { IReadOnlyList<MilaWindowsNotificationDevice> result = await load(cancellationToken); if (current == Volatile.Read(ref generation)) { Devices = result; Status = MilaWindowsNotificationDevicesStatus.Loaded; } }
        catch { if (current == Volatile.Read(ref generation)) Status = MilaWindowsNotificationDevicesStatus.Failed; }
    }
    internal async Task RemoveAsync(MilaWindowsNotificationDevice device, CancellationToken cancellationToken = default)
    { if (Status != MilaWindowsNotificationDevicesStatus.Loaded || device.Id.Length == 0) return; await remove(device.Id, cancellationToken); await LoadAsync(true, cancellationToken); }
    internal async Task SetEnabledAsync(MilaWindowsNotificationDevice device, bool enabled, CancellationToken cancellationToken = default)
    { if (Status != MilaWindowsNotificationDevicesStatus.Loaded || device.Id.Length == 0) return; await preferences(device.Id, enabled, cancellationToken); await LoadAsync(true, cancellationToken); }

    internal static IReadOnlyList<MilaWindowsNotificationDevice> DecodeListing(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length > 256 * 1024) throw new InvalidDataException("Notification listing too large");
        using JsonDocument document = JsonDocument.Parse(bytes.ToArray());
        JsonElement devices = document.RootElement.GetProperty("devices");
        if (devices.ValueKind != JsonValueKind.Array || devices.GetArrayLength() > 256) throw new InvalidDataException("Invalid notification listing");
        List<MilaWindowsNotificationDevice> result = new(devices.GetArrayLength());
        foreach (JsonElement item in devices.EnumerateArray())
        {
            string id = item.GetProperty("id").GetString() ?? throw new InvalidDataException("Missing device id");
            string platform = item.GetProperty("platform").GetString() ?? throw new InvalidDataException("Missing device platform");
            if (id.Length is 0 or > 128 || platform.Length is 0 or > 32) throw new InvalidDataException("Invalid device metadata");
            result.Add(new(id, platform, item.GetProperty("enabled").GetBoolean()));
        }
        return result;
    }
}

internal enum MilaWindowsNotificationState { Disabled, Registered, Unavailable, Invalid }

/// <summary>
/// Owns the Windows notification capability without retaining the WNS bearer URI.
/// The native runner obtains the channel; this controller only validates its metadata.
/// </summary>
internal sealed class MilaWindowsNotificationController
{
    private readonly Func<string, string, string, MilaNativeStatus> _validate;
    internal MilaWindowsNotificationState State { get; private set; } = MilaWindowsNotificationState.Disabled;
    private long generation;
    private bool signedIn;

    internal MilaWindowsNotificationController(
        Func<string, string, string, MilaNativeStatus>? validate = null)
    {
        _validate = validate ?? RustNative.TryValidateWindowsPushRegistration;
    }

    internal void SetSession(bool authenticated)
    {
        signedIn = authenticated;
        generation++;
        if (!authenticated) State = MilaWindowsNotificationState.Disabled;
    }

    /// <summary>
    /// @cc [owner:ghuntley,label:security] mila-windows-push-registration
    /// WNS channel URIs MUST be validated by Rust and MUST NOT be retained by the
    /// managed shell; failed validation MUST leave notifications disabled.
    /// </summary>
    internal MilaWindowsNotificationState Register(
        string channelUri, string appId, string deployment)
    {
        if (!signedIn)
        {
            State = MilaWindowsNotificationState.Invalid;
            return State;
        }
        long current = generation;
        MilaNativeStatus status = _validate(channelUri, appId, deployment);
        if (current != generation || !signedIn)
        {
            State = MilaWindowsNotificationState.Disabled;
            return State;
        }
        State = status switch
        {
            MilaNativeStatus.Ok => MilaWindowsNotificationState.Registered,
            MilaNativeStatus.Unavailable => MilaWindowsNotificationState.Unavailable,
            _ => MilaWindowsNotificationState.Invalid,
        };
        return State;
    }

    internal void Disable() => State = MilaWindowsNotificationState.Disabled;
}

internal sealed class MilaWindowsNotificationDeviceStore
{
    private readonly string path;
    internal MilaWindowsNotificationDeviceStore(string? path = null)
    {
        this.path = path ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Mila", "notification-devices.json");
    }

    internal IReadOnlyList<MilaWindowsNotificationDevice> Load()
    {
        try
        {
            if (!File.Exists(path)) return Array.Empty<MilaWindowsNotificationDevice>();
            return MilaWindowsNotificationDevicesController.DecodeListing(File.ReadAllBytes(path));
        }
        catch (IOException) { return Array.Empty<MilaWindowsNotificationDevice>(); }
        catch (JsonException) { return Array.Empty<MilaWindowsNotificationDevice>(); }
        catch (InvalidDataException) { return Array.Empty<MilaWindowsNotificationDevice>(); }
    }

    internal void Save(IReadOnlyList<MilaWindowsNotificationDevice> devices)
    {
        if (devices.Count > 256) throw new ArgumentOutOfRangeException(nameof(devices));
        string? directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
        string json = JsonSerializer.Serialize(new { devices });
        File.WriteAllText(path, json);
    }
}
