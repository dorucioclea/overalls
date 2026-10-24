using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Web.WebView2.Core;
using System.Security.Cryptography;
using Windows.System;
using Mila.Windows.Interop;
namespace Mila.Windows;
public sealed partial class MainWindow : Window
{
    private string? _activeHost;
    private string? _deviceFingerprint;
    private ushort _deploymentPort = MilaDeployment.DefaultPort;
    private bool _notificationsEnabled;
    private readonly MilaWindowsNotificationController _notificationController = new();
    private readonly MilaWindowsNotificationDevicesController _notificationDevices;
    private readonly MilaSshKeysController _sshKeys;
    private readonly MilaThreadController _threadController = new();
    private readonly MilaMachineMutationController _machineMutation = new();
    private MilaMachineRow? _selectedMachine;
    private readonly MilaAppLockController _appLock = new(new MilaWindowsHelloBroker());
    private readonly MilaSessionConnection _session = new();
    private readonly MilaTerminalSession _terminal = new();
    private long _terminalGeneration;
    private ulong _webRevision;
    private Uri? _webUrl;
    private bool _webNavigationBound;
    private long _webGeneration;
    private long _machineGeneration;
    private readonly MilaSignInFlow _signIn = new();
    private bool _closed;
    public MainWindow(string? activation = null)
    {
        InitializeComponent();
        _sshKeys = new MilaSshKeysController(LoadSshKeysAsync, RevokeSshKeyAsync);
        _notificationDevices = new MilaWindowsNotificationDevicesController(LoadNotificationDevicesAsync, RemoveNotificationDeviceAsync, SetNotificationPreferenceAsync);
        Closed += (_, _) => { _closed = true; _signIn.SignOut(); _session.Dispose(); };
        Activated += (_, args) =>
        {
            if (args.WindowActivationState == WindowActivationState.Deactivated)
            {
                _appLock.OnDeactivated();
                LockButton.Content = S("unlock", "Unlock");
                LockStatus.Text = S("lockedTitle", "Mila is locked");
            }
        };
        ApplyStrings();
        LoadSettings();
        LoadDeployments();
        Navigation.SelectedItem = Navigation.MenuItems[0];
        if (!string.IsNullOrWhiteSpace(activation)) HandleExternalActivation(activation);
    }
    private void LoadDeployments()
    {
        DeploymentRows.ItemsSource = MilaDeploymentStore.LoadAll();
        if (MilaDeploymentStore.Load() is not { } deployment) return;
        DeploymentHost.Text = deployment.Host;
        _deploymentPort = deployment.Port;
    }
    private void OnDeploymentSelected(object sender, SelectionChangedEventArgs args)
    {
        if (DeploymentRows.SelectedItem is not MilaDeployment deployment) return;
        DeploymentHost.Text = deployment.Host;
        _deploymentPort = deployment.Port;
    }
    private void ForgetDeploymentClicked(object sender, RoutedEventArgs args)
    {
        if (DeploymentRows.SelectedItem is not MilaDeployment deployment) return;
        if (MilaDeploymentStore.Forget(deployment))
        {
            LoadDeployments();
            StatusText.Text = S("deploymentForgotten", "Deployment forgotten");
        }
    }
    internal void HandleExternalActivation(string activation)
    {
        MilaExternalActivation? external = MilaExternalActivationParser.ParseArguments(activation);
        MilaRoute? route = external?.Route;
        if (route is null)
        {
            StatusText.Text = S("invalidRoute", "This link is not a valid Mila route.");
            return;
        }
        // Share activations must be authorized against the already-authenticated
        // deployment before changing navigation or host state. Never let the
        // incoming route establish its own trust context.
        if (external is { IsShareTarget: true } share)
        {
            bool authenticated = _session.Handle is { } handle && handle != 0;
            if (!MilaShareTarget.TryAuthorize(share, authenticated, _activeHost, out _))
            {
                StatusText.Text = S("signInFirst", "Sign in first");
                return;
            }
        }
        _activeHost = route.Value.Host;
        DeploymentHost.Text = route.Value.Host;
        Navigation.SelectedItem = route.Value.Kind switch
        {
            MilaRouteKind.Thread or MilaRouteKind.Threads => Navigation.MenuItems[1],
            MilaRouteKind.Settings => Navigation.MenuItems[2],
            _ => Navigation.MenuItems[0]
        };
        StatusText.Text = route.Value.Kind switch
        {
            MilaRouteKind.Machine => $"{S("routeMachine", "Machine")}: {route.Value.Id?.ToString("D")}",
            MilaRouteKind.Thread => $"{S("routeThread", "Thread")}: {route.Value.Id?.ToString("D")}",
            _ => $"{S("routeOpened", "Opened")}: {route.Value.Path}"
        };
        if (external is { IsShareTarget: true })
            StatusText.Text += $" ({S("routeShared", "shared")})";
    }
    private static string S(string id, string fallback) => MilaStrings.Text(id, fallback);
    private void ApplyStrings()
    {
        ((NavigationViewItem)Navigation.MenuItems[0]).Content = S("machinesTitle", "Machines");
        ((NavigationViewItem)Navigation.MenuItems[1]).Content = S("tabThreads", "Threads");
        ((NavigationViewItem)Navigation.MenuItems[2]).Content = S("settingsTitle", "Settings");
        PageTitle.Text = S("machinesTitle", "Machines");
        PageBody.Text = S("machinesEmpty", "Select a machine to view its status.");
        StatusText.Text = S("ready", "Ready");
        DeploymentHostLabel.Text = S("deploymentHostLabel", "Deployment host");
        DeploymentHost.PlaceholderText = S("deploymentHostHint", "overalls.example");
        ConnectDeployment.Content = S("signInStart", "Sign in in browser");
        ForgetDeployment.Content = S("forgetDeployment", "Forget deployment");
        ApprovalFingerprint.Header = S("signInFingerprint", "Key fingerprint");
        OpenApproval.Content = S("signInOpenBrowser", "Open approval page");
        MachineCommandsTitle.Text = S("machineMore", "Machine commands");
        MachineCommandsHelp.Text = S("machineAccess", "Commands are classified by the Rust core before execution.");
        MachineList.Content = S("tabInfo", "List"); MachineShow.Content = S("machineLoading", "Show");
        MachineNew.Content = S("actionNew", "New"); MachineResize.Content = S("actionResize", "Resize");
        ResizeCpu.Header = S("machineCpu", "CPU"); ResizeMemory.Header = S("machineMemory", "Memory MiB"); ResizeDisk.Header = S("machineDisk", "Disk GiB");
        ResizeCpu.Text = "2"; ResizeMemory.Text = "2048"; ResizeDisk.Text = "20";
        MachineStart.Content = S("actionStart", "Start"); MachineStop.Content = S("actionStop", "Stop");
        MachinePause.Content = S("actionPause", "Pause"); MachineResume.Content = S("actionResume", "Resume");
        MachineDelete.Content = S("actionDelete", "Delete"); MachineShareAdd.Content = S("sharingAdd", "Share add");
        MachineShareRemove.Content = S("sharingRemove", "Share remove"); MachineWebShow.Content = S("webOpen", "Web show");
        MachineWebSet.Content = S("webSave", "Web set");
        CreateMachineButton.Content = S("actionCreate", "Create machine");
        ShareAdd.Content = S("sharingAdd", "Share add");
        ShareRemove.Content = S("sharingRemove", "Share remove");
        SshKeysTitle.Text = S("sshKeysTitle", "SSH keys");
        SshKeysStatus.Text = S("sshKeysSignInFirst", "Sign in to manage SSH keys.");
        RefreshSshKeys.Content = S("refresh", "Refresh");
        RevokeSshKey.Content = S("sshKeyRevoke", "Revoke");
        ThreadCommandsTitle.Text = S("tabThreads", "Thread commands");
        ThreadCommandsHelp.Text = S("threadWorking", "Commands are validated by the Rust core before execution.");
        ThreadList.Content = S("tabInfo", "List"); ThreadShow.Content = S("machineLoading", "Show");
        ThreadTurns.Content = S("threadEventTurnStarted", "Turns"); ThreadRead.Content = S("threadEventOther", "Read");
        ThreadPrompt.Content = S("threadPrompt", "Prompt"); ThreadAnswer.Content = S("threadAnswer", "Answer");
        ThreadApprove.Content = S("threadPlanApprove", "Approve plan"); ThreadRevise.Content = S("threadPlanRevise", "Revise plan");
        Refresh.Content = S("refresh", "Refresh");
        LockButton.Content = S("lockTitle", "Lock app");
        LockStatus.Text = S("lockUnavailable", "App lock is unavailable until Windows Hello is configured.");
        SettingsHelp.Text = S("settingsOffline", "Runtime settings are managed by the core library.");
        LocalePicker.ItemsSource = new[] { "en", "en-GB", "fr", "de", "es", "ja", "ar", "he" };
        SaveSettings.Content = S("settingsSave", "Save settings");
        SettingsStatus.Text = S("ready", "Ready");
        _ = RefreshLockAvailabilityAsync();
        TerminalTitle.Text = S("tabTerminals", "Terminal");
        TerminalAttach.Content = S("terminalAttach", "Attach");
        TerminalResize.Content = S("terminalModeControl", "Resize");
        TerminalInput.Content = S("terminalPaste", "Send input");
        TerminalKill.Content = S("terminalKill", "Kill");
        NotificationsButton.Content = S("notificationsTurnOn", "Turn notifications on");
        NotificationsStatus.Text = S("pushStateOff", "Notifications off");
        RefreshNotifications.Content = S("refresh", "Refresh");
        RemoveNotification.Content = S("notificationRemove", "Remove");
        WebOpen.Content = S("webOpen", "Open web");
        WebCopy.Content = S("webCopy", "Copy address");
        WebSet.Content = S("webSave", "Save web settings");
        WebStatus.Text = S("webNoAddress", "No web address");
    }
    private async void RefreshSshKeysClicked(object sender, RoutedEventArgs args) => await RefreshSshKeyListAsync();

    private async Task RefreshSshKeyListAsync(CancellationToken cancellationToken = default)
    {
        await _sshKeys.LoadAsync(_activeHost is not null);
        SshKeyRows.ItemsSource = _sshKeys.Keys;
        SshKeysStatus.Text = _activeHost is null
            ? S("sshKeysSignInFirst", "Sign in to manage SSH keys.")
            : _sshKeys.Status == MilaSshKeysStatus.Failed
                ? S("sshKeysFailed", "Unable to load SSH keys.")
                : string.Format(S("sshKeysLoaded", "{0} approved keys."), _sshKeys.Keys.Count);
    }

    private async Task<IReadOnlyList<MilaSshKey>> LoadSshKeysAsync(CancellationToken cancellationToken)
    {
        if (_session.Handle is not { } handle) throw new InvalidOperationException("SSH session is unavailable");
        MilaNativeSessionBytesResult result = await Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            return RustNative.TrySessionSshKeys(handle);
        }, cancellationToken);
        if (!result.Succeeded || result.Data is not { } bytes)
            throw new IOException($"SSH key listing failed: {result.Status}");
        string? currentFingerprint = _deviceFingerprint;
        return MilaSshKeysController.DecodeListing(bytes)
            .Select(key => key with { IsCurrentDevice = key.Fingerprint == currentFingerprint })
            .ToArray();
    }

    private async Task RevokeSshKeyAsync(Guid keyId, CancellationToken cancellationToken)
    {
        if (_session.Handle is not { } handle) throw new InvalidOperationException("SSH session is unavailable");
        string requestId = "porsche-" + Guid.NewGuid().ToString("N");
        MilaNativeSessionActionResult result = await Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            return RustNative.TrySessionSshKeyRevoke(handle, keyId, requestId);
        }, cancellationToken);
        if (!result.Succeeded) throw new IOException($"SSH key revocation failed: {result.Status}");
    }

    private void OnSshKeySelected(object sender, SelectionChangedEventArgs args)
    {
        RevokeSshKey.IsEnabled = SshKeyRows.SelectedItem is MilaSshKey key && !key.IsCurrentDevice &&
            _sshKeys.Status == MilaSshKeysStatus.Loaded;
    }

    private async void RevokeSelectedSshKey(object sender, RoutedEventArgs args)
    {
        if (SshKeyRows.SelectedItem is not MilaSshKey key || key.IsCurrentDevice) return;
        RevokeSshKey.IsEnabled = false;
        await _sshKeys.RevokeAsync(key);
        SshKeyRows.ItemsSource = _sshKeys.Keys;
        SshKeysStatus.Text = _sshKeys.Status == MilaSshKeysStatus.Failed
            ? S("sshKeysFailed", "Unable to load SSH keys.")
            : string.Format(S("sshKeysLoaded", "{0} approved keys."), _sshKeys.Keys.Count);
        RevokeSshKey.IsEnabled = false;
    }
    private void ShareMachine(object sender, RoutedEventArgs args) => ClassifyMachine($"share add {SampleMachine} user viewer");
    private void UnshareMachine(object sender, RoutedEventArgs args) => ClassifyMachine($"share remove {SampleMachine} user");
    private void CreateMachine(object sender, RoutedEventArgs args)
    {
        if (_session.Handle is not { } handle || handle == 0)
        {
            MachineCommandStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        MilaMachineCommandKind? kind = RustNative.TryClassifyMachineCommand("new");
        if (kind != MilaMachineCommandKind.New) { MachineCommandStatus.Text = S("requestRefused", "Create request refused"); return; }
        MilaNativeSessionActionResult result = RustNative.TrySessionMachineCreate(
            handle, "mila-machine", 1, 256, 1, "porsche-" + Guid.NewGuid().ToString("N"));
        MachineCommandStatus.Text = result.Succeeded
            ? S("requestWaiting", "Create request submitted")
            : S("requestRefused", "Create request refused");
    }
    private async void OpenWebControl(object sender, RoutedEventArgs args)
    {
        long generation = _webGeneration;
        if (_selectedMachine is not { } machine || _session.Handle is not { } handle)
        {
            WebStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        MilaNativeSessionBytesResult result = await Task.Run(() => RustNative.TrySessionWebShow(handle, machine.Id));
        if (generation != _webGeneration || _session.Handle != handle) return;
        if (!result.Succeeded || result.Data is null) { WebStatus.Text = S("webFailed", "Web control unavailable"); return; }
        try
        {
            MilaWebEndpoint endpoint = MilaWebEndpointDecoder.Decode(result.Data, machine.Id);
            _webRevision = endpoint.Revision;
            WebRevision.Text = endpoint.Revision.ToString(System.Globalization.CultureInfo.InvariantCulture);
            WebPort.Text = endpoint.Port.ToString(System.Globalization.CultureInfo.InvariantCulture);
            WebPublic.IsChecked = endpoint.IsPublic;
            _webUrl = endpoint.Url;
            WebStatus.Text = endpoint.Url is { } url ? url.ToString() : S("webVisibility", "Web control validated");
            if (endpoint.Url is { } address)
            {
                await WebBrowser.EnsureCoreWebView2Async();
                BindWebNavigationFence();
                WebBrowser.Source = address;
                WebBrowser.Visibility = Visibility.Visible;
            }
        }
        catch (InvalidDataException) { WebStatus.Text = S("webFailed", "Web control unavailable"); }
    }
    private void BindWebNavigationFence()
    {
        if (_webNavigationBound || WebBrowser.CoreWebView2 is not { } core) return;
        core.NavigationStarting += (_, eventArgs) =>
        {
            if (_webUrl is not { } origin || !Uri.TryCreate(eventArgs.Uri, UriKind.Absolute, out Uri? target) ||
                !MilaWebOrigin.IsAllowed(origin, target))
            {
                eventArgs.Cancel = true;
                WebStatus.Text = S("webFailed", "Web navigation refused");
            }
        };
        _webNavigationBound = true;
    }
    private async void CopyWebAddress(object sender, RoutedEventArgs args)
    {
        if (_webUrl is not { } address)
        {
            await OpenWebControlAsync();
            if (_webUrl is not { } loaded) return;
            address = loaded;
        }
        var package = new global::Windows.ApplicationModel.DataTransfer.DataPackage();
        package.SetText(address.ToString());
        global::Windows.ApplicationModel.DataTransfer.Clipboard.SetContent(package);
        WebStatus.Text = S("webCopied", "Web address copied");
    }

    private async Task OpenWebControlAsync()
    {
        long generation = _webGeneration;
        if (_selectedMachine is not { } machine || _session.Handle is not { } handle)
        {
            WebStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        MilaNativeSessionBytesResult result = await Task.Run(() => RustNative.TrySessionWebShow(handle, machine.Id));
        if (!result.Succeeded || result.Data is null) { WebStatus.Text = S("webFailed", "Web control unavailable"); return; }
        try
        {
            MilaWebEndpoint endpoint = MilaWebEndpointDecoder.Decode(result.Data, machine.Id);
            _webRevision = endpoint.Revision;
            WebRevision.Text = endpoint.Revision.ToString(System.Globalization.CultureInfo.InvariantCulture);
            WebPort.Text = endpoint.Port.ToString(System.Globalization.CultureInfo.InvariantCulture);
            WebPublic.IsChecked = endpoint.IsPublic;
            _webUrl = endpoint.Url;
            WebStatus.Text = endpoint.Url is { } url ? url.ToString() : S("webVisibility", "Web control validated");
            if (endpoint.Url is { } address)
            {
                await WebBrowser.EnsureCoreWebView2Async();
                WebBrowser.Source = address;
                WebBrowser.Visibility = Visibility.Visible;
            }
        }
        catch (InvalidDataException) { WebStatus.Text = S("webFailed", "Web control unavailable"); }
    }
    private async void SetWebControl(object sender, RoutedEventArgs args)
    {
        if (_selectedMachine is not { } machine || _session.Handle is not { } handle)
        {
            WebStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        if (!ushort.TryParse(WebPort.Text.Trim(), out ushort port) || port is 0 or > 65_535)
        {
            WebStatus.Text = S("webInvalidPort", "Enter a valid web port.");
            return;
        }
        if (!ulong.TryParse(WebRevision.Text.Trim(), out ulong revision) || revision == 0)
        {
            WebStatus.Text = S("webInvalidRevision", "Enter the current web policy revision.");
            return;
        }
        WebSet.IsEnabled = false;
        try
        {
            MilaNativeSessionActionResult result = await Task.Run(() => RustNative.TrySessionWebSet(
                handle, machine.Id, port, WebPublic.IsChecked == true, revision,
                "porsche-" + Guid.NewGuid().ToString("N")));
            if (result.Succeeded)
            {
                _webRevision = revision == ulong.MaxValue ? revision : revision + 1;
                WebRevision.Text = _webRevision.ToString(System.Globalization.CultureInfo.InvariantCulture);
                WebStatus.Text = S("webSaved", "Web settings saved");
            }
            else WebStatus.Text = S("webFailed", "Web control unavailable");
        }
        finally { WebSet.IsEnabled = true; }
    }
    private void ToggleNotifications(object sender, RoutedEventArgs args)
    {
        if (_session.Handle is not { } handle || handle == 0)
        {
            _notificationController.SetSession(false);
            _notificationsEnabled = false;
            NotificationsStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        _notificationsEnabled = !_notificationsEnabled;
        MilaNativePokeResult result = RustNative.TryValidatePushPoke(ReadOnlySpan<byte>.Empty, (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        NotificationsStatus.Text = result.IsValid
            ? (_notificationsEnabled ? S("pushStateOn", "Notifications on") : S("pushStateOff", "Notifications off"))
            : S("pushUnsupported", "Notifications unavailable");
        NotificationsButton.Content = _notificationsEnabled ? S("notificationsTurnOff", "Turn notifications off") : S("notificationsTurnOn", "Turn notifications on");
    }
    private async void RefreshNotificationsClicked(object sender, RoutedEventArgs args)
    {
        await RefreshNotificationDevicesAsync();
    }
    private async void RemoveNotificationClicked(object sender, RoutedEventArgs args)
    {
        if (NotificationRows.SelectedItem is not MilaWindowsNotificationDevice device) return;
        RemoveNotification.IsEnabled = false;
        await _notificationDevices.RemoveAsync(device);
        NotificationRows.ItemsSource = _notificationDevices.Devices;
    }
    private async Task RefreshNotificationDevicesAsync()
    {
        await _notificationDevices.LoadAsync(_session.Handle is { } handle && handle != 0);
        NotificationRows.ItemsSource = _notificationDevices.Devices;
        RemoveNotification.IsEnabled = false;
    }
    private void OnNotificationSelected(object sender, SelectionChangedEventArgs args)
        => RemoveNotification.IsEnabled = NotificationRows.SelectedItem is MilaWindowsNotificationDevice &&
            _notificationDevices.Status == MilaWindowsNotificationDevicesStatus.Loaded;
    private Task<IReadOnlyList<MilaWindowsNotificationDevice>> LoadNotificationDevicesAsync(CancellationToken cancellationToken)
    {
        if (_session.Handle is not { } handle || handle == 0) return Task.FromResult<IReadOnlyList<MilaWindowsNotificationDevice>>(Array.Empty<MilaWindowsNotificationDevice>());
        MilaNativeSessionBytesResult result = RustNative.TrySessionDevices(handle);
        if (!result.Succeeded) throw new InvalidDataException("Notification listing unavailable");
        return Task.FromResult(MilaWindowsNotificationDevicesController.DecodeListing(result.Bytes));
    }
    private Task RemoveNotificationDeviceAsync(string deviceId, CancellationToken cancellationToken)
    {
        if (_session.Handle is not { } handle || handle == 0) throw new InvalidOperationException("Sign in required");
        MilaNativeSessionActionResult result = RustNative.TrySessionDeviceRemove(handle, deviceId);
        if (!result.Succeeded) throw new InvalidOperationException("Notification removal failed");
        return Task.CompletedTask;
    }
    private Task SetNotificationPreferenceAsync(string deviceId, bool enabled, CancellationToken cancellationToken)
    {
        if (_session.Handle is not { } handle || handle == 0) throw new InvalidOperationException("Sign in required");
        MilaNativeSessionActionResult result = RustNative.TrySessionDevicePreferences(handle, deviceId, enabled);
        if (!result.Succeeded) throw new InvalidOperationException("Notification preference failed");
        return Task.CompletedTask;
    }

    private async void OpenApprovalPage(object sender, RoutedEventArgs args)
    {
        MilaSignInState state = _signIn.State;
        MilaApprovalInfo? approval = state.Approval;
        if (approval is null && _signIn.SetApproval(state.Generation, ApprovalUrl.Text.Trim(), ApprovalFingerprint.Text.Trim(),
                (ulong)DateTimeOffset.UtcNow.ToUnixTimeSeconds()))
            approval = _signIn.State.Approval;
        if (approval is null || !await Launcher.LaunchUriAsync(new Uri(approval.Url)))
            StatusText.Text = S("signInExpired", "The approval link is no longer valid. Start again to get a new one.");
    }
    private void ValidateTerminalAttach(object sender, RoutedEventArgs args)
    {
        if (_session.Handle is not { } sessionHandle || sessionHandle == 0)
        {
            TerminalStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        MilaNativeTerminalResult result = RustNative.TryValidateTerminalAttach(0, 80, 24, true);
        _terminalGeneration = DateTime.UtcNow.Ticks;
        TerminalStatus.Text = result.IsValid && _terminal.BeginAuthenticatedAttach(sessionHandle, _terminalGeneration, true) > 0
            ? S("terminalAttaching", "Attaching…") : S("terminalRefused", "Terminal refused");
        // This is the bounded renderer acknowledgement. Actual PTY frames
        // arrive through the authenticated transport and must be projected by
        // Rust before being appended with AppendReceived.
        if (result.IsValid && _terminal.AppendReceived(_terminalGeneration, "Mila terminal ready\r\n"))
            TerminalOutput.Text = _terminal.Output;
    }
    private void ValidateTerminalResize(object sender, RoutedEventArgs args)
    {
        if (_session.Handle is not { } sessionHandle || sessionHandle == 0 ||
            !_terminal.Reconnect(_terminalGeneration))
        {
            TerminalStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        MilaNativeTerminalResult result = RustNative.TryValidateTerminalResize(80, 24, true);
        TerminalStatus.Text = result.IsValid && _terminal.Resize(_terminalGeneration, 80, 24)
            ? S("terminalLive", "Terminal live") : S("terminalInvalid", "Invalid terminal dimensions");
    }
    private void ValidateTerminalInput(object sender, RoutedEventArgs args)
    {
        if (_session.Handle is not { } sessionHandle || sessionHandle == 0 ||
            !_terminal.Reconnect(_terminalGeneration))
        {
            TerminalStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        byte[] input = System.Text.Encoding.UTF8.GetBytes(TerminalInputText.Text);
        MilaNativeTerminalResult result = RustNative.TryValidateTerminalInput((nuint)input.Length, true);
        bool sent = result.IsValid && _terminal.SendInput(_terminalGeneration, input);
        TerminalStatus.Text = sent ? S("terminalLive", "Terminal live") : S("terminalReadOnly", "Terminal is read only");
        if (sent) TerminalInputText.Text = string.Empty;
    }
    private void KillTerminal(object sender, RoutedEventArgs args)
    {
        if (_session.Handle is not { } sessionHandle || sessionHandle == 0)
        {
            TerminalStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        // Kill is valid while an authenticated attach is still negotiating;
        // requiring Reconnect here left an attaching PTY impossible to cancel.
        _terminal.Kill(_terminalGeneration);
        TerminalStatus.Text = S("terminalEnded", "Terminal ended");
    }
    private void ConnectToDeployment(object sender, RoutedEventArgs args)
    {
        string host = DeploymentHost.Text.Trim();
        if (host.Length == 0)
        {
            StatusText.Text = S("invalidHost", "Enter a valid deployment host.");
            return;
        }
        StatusText.Text = S("signInConnecting", "Connecting to deployment…").Replace("{host}", host, StringComparison.Ordinal);
        ConnectDeployment.IsEnabled = false;
        // A browser connection is not an authenticated Rust session yet. Keep
        // mutation controls explicitly signed out until the session broker
        // supplies its non-zero handle.
        _activeHost = null;
        _deviceFingerprint = null;
        _selectedMachine = null;
        MachineRows.ItemsSource = Array.Empty<MilaMachineRow>();
        UpdateMachineMutationAvailability();
        _threadController.SetSession(false, null);
        _machineMutation.SetSession(false);
        long generation = _signIn.Start();
        _session.SignOut();
        _notificationController.SetSession(false);
        _notificationsEnabled = false;
        // Clear authenticated web and terminal state before beginning a new
        // approval generation. This prevents stale endpoint navigation or a
        // previous PTY stream from surviving a deployment switch.
        _webGeneration++;
        _machineGeneration++;
        _webUrl = null;
        _webRevision = 0;
        WebBrowser.Source = null;
        WebBrowser.Visibility = Visibility.Collapsed;
        WebStatus.Text = S("webNoAddress", "No web address");
        _terminal.Kill(_terminalGeneration);
        TerminalOutput.Text = string.Empty;
        TerminalStatus.Text = S("terminalEnded", "Terminal ended");
        _ = RefreshSshKeyListAsync();
        _ = ConnectDeploymentAsync(host, generation);
    }
    private async Task ConnectDeploymentAsync(string host, long generation)
    {
        try
        {
            byte[]? trust = await new MilaTrustEnrollment(
                MilaTrustStore.HttpsFetch(host), RustNative.TryReconcileTrust)
                .ResolveAsync(host);
            if (trust is null)
            {
                _activeHost = null;
                _session.SignOut();
                if (!_signIn.AwaitApproval(generation)) return;
                ApprovalUrl.Visibility = Visibility.Visible;
                ApprovalFingerprint.Visibility = Visibility.Visible;
                OpenApproval.Visibility = Visibility.Visible;
                StatusText.Text = S("signInApprove", "Approve this device in your browser, then return here.");
                return;
            }

            using DeviceKey deviceKey = DeviceKey.OpenOrCreate(host);
            byte[] publicKey = deviceKey.PublicPoint();
            _deviceFingerprint = MilaSshKeysController.Fingerprint(System.Text.Encoding.UTF8.GetString(publicKey));
            byte[] trustBytes = trust;
            byte[] publicKeyBytes = publicKey;
            bool connected = await Task.Run(() => _session.Connect(
                trustBytes, host, publicKeyBytes, _deploymentPort, 30_000, bytes => deviceKey.Sign(bytes)));
            if (_closed) return;
            if (!connected || _session.Handle is not { } handle)
            {
                _activeHost = null;
                _signIn.Fail(MilaSignInFailure.Unreachable, generation);
                _machineMutation.SetSession(false);
                UpdateMachineMutationAvailability();
                StatusText.Text = S("signInFailedUnreachable", "Unable to connect to deployment.");
                return;
            }

            _activeHost = host;
            _signIn.Authenticated(generation, host);
            _notificationController.SetSession(true);
            ApprovalUrl.Visibility = Visibility.Collapsed;
            ApprovalFingerprint.Visibility = Visibility.Collapsed;
            OpenApproval.Visibility = Visibility.Collapsed;
            MilaDeploymentStore.Save(new MilaDeployment(host, _deploymentPort));
            _machineMutation.SetSession(true, handle);
            UpdateMachineMutationAvailability();
            StatusText.Text = S("connected", MilaStrings.Connected);
            await RefreshSshKeyListAsync();
            await RefreshNotificationDevicesAsync();
            RefreshMachines();
        }
        catch (ArgumentException)
        {
            _activeHost = null;
            _session.SignOut();
            _signIn.Fail(MilaSignInFailure.HostUntrusted, generation);
            if (!_closed && _signIn.State.Generation == generation)
                StatusText.Text = S("invalidHost", "Enter a valid deployment host.");
        }
        catch (Exception error) when (error is CryptographicException or IOException or UnauthorizedAccessException)
        {
            _activeHost = null;
            _session.SignOut();
            _signIn.Fail(MilaSignInFailure.Unreachable, generation);
            _machineMutation.SetSession(false);
            UpdateMachineMutationAvailability();
            if (!_closed && _signIn.State.Generation == generation)
                StatusText.Text = S("signInFailedUnreachable", "Unable to connect to deployment.");
        }
        finally
        {
            if (!_closed) ConnectDeployment.IsEnabled = true;
        }
    }
    private async Task RefreshLockAvailabilityAsync()
    {
        await _appLock.RefreshAvailabilityAsync();
        if (_appLock.State == MilaAppLockState.Unavailable)
            LockStatus.Text = S("lockUnavailable", "App lock is unavailable until Windows Hello is configured.");
    }
    private void LockApp(object sender, RoutedEventArgs args)
    {
        _appLock.Lock();
        if (!_appLock.IsLocked) return;
        Navigation.IsHitTestVisible = false;
        LockButton.Content = S("unlock", "Unlock");
        LockStatus.Text = S("lockedTitle", "Mila is locked") + " — " + S("lockReason", "Unlock Mila");
        LockButton.Click -= LockApp;
        LockButton.Click += UnlockApp;
    }
    private async void UnlockApp(object sender, RoutedEventArgs args)
    {
        LockButton.IsEnabled = false;
        bool unlocked = await _appLock.UnlockAsync();
        LockButton.IsEnabled = true;
        if (!unlocked)
        {
            LockStatus.Text = S("lockReason", "Unlock Mila");
            return;
        }
        Navigation.IsHitTestVisible = true;
        LockButton.Content = S("lockTitle", "Lock app");
        LockStatus.Text = S("ready", "Ready");
        LockButton.Click -= UnlockApp;
        LockButton.Click += LockApp;
    }
    private void LoadSettings()
    {
        MilaSettings settings = MilaSettingsStore.Load();
        MilaStrings.SetLocale(settings.Locale);
        LocalePicker.SelectedItem = settings.Locale;
        if (LocalePicker.SelectedItem is null) LocalePicker.SelectedItem = "en";
        DarkModeToggle.IsOn = settings.DarkMode;
        ApplyTheme(settings.DarkMode);
        Navigation.FlowDirection = settings.Direction() == LocaleDirection.Rtl
            ? FlowDirection.RightToLeft
            : FlowDirection.LeftToRight;
    }

    private void SaveSettingsClicked(object sender, RoutedEventArgs args)
    {
        string locale = LocalePicker.SelectedItem?.ToString() ?? "en";
        try
        {
            MilaSettings settings = new MilaSettings(locale, DarkModeToggle.IsOn).Normalize();
            MilaSettingsStore.Save(settings);
            MilaStrings.SetLocale(settings.Locale);
            ApplyStrings();
            LocalePicker.SelectedItem = settings.Locale;
            ApplyTheme(settings.DarkMode);
            Navigation.FlowDirection = settings.Direction() == LocaleDirection.Rtl
                ? FlowDirection.RightToLeft
                : FlowDirection.LeftToRight;
            SettingsStatus.Text = S("settingsSaved", "Settings saved");
        }
        catch (ArgumentException) { SettingsStatus.Text = S("settingsInvalid", "Locale rejected by core policy."); }
    }

    /// <summary>Apply the persisted appearance at the native WinUI root.</summary>
    private void ApplyTheme(bool darkMode)
    {
        Navigation.RequestedTheme = darkMode ? ElementTheme.Dark : ElementTheme.Light;
    }

    private void OnNavigationChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item) {
            string tag = item.Tag?.ToString() ?? "machines";
            PageTitle.Text = item.Content?.ToString() ?? "Mila";
            PageBody.Text = tag switch { "threads" => S("threadsRecentTitle", "Recent conversations appear here."), "settings" => S("settingsOffline", "Runtime settings are managed by the core library."), _ => S("machinesEmpty", "Select a machine to view its status.") };
            ThreadPanel.Visibility = tag == "threads" ? Visibility.Visible : Visibility.Collapsed;
            SettingsPanel.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;
            if (tag == "threads") RefreshThreads();
            MachineRows.Visibility = tag == "machines" ? Visibility.Visible : Visibility.Collapsed;
            MachinePanel.Visibility = tag == "machines" ? Visibility.Visible : Visibility.Collapsed;
        }
    }
    private void CheckNativeBridge(object sender, RoutedEventArgs args)
    {
        MilaNativeVersionResult result = RustNative.TryGetVersion();
        StatusText.Text = result.Status == MilaNativeStatus.Ok
            ? MilaStrings.Text("connected", MilaStrings.Connected)
            : MilaStrings.Text("runtimeUnavailable", MilaStrings.RuntimeUnavailable);
        RefreshMachines();
    }

    private async void RefreshMachines()
    {
        long generation = ++_machineGeneration;
        _selectedMachine = null;
        _machineMutation.SetSession(_session.Handle is { } handle, _session.Handle ?? 0);
        UpdateMachineMutationAvailability();
        MachineRows.ItemsSource = Array.Empty<MilaMachineRow>();
        if (_activeHost is not { } host || _session.Handle is not { } sessionHandle)
            return;
        MilaNativeSessionBytesResult result = await Task.Run(() => RustNative.TrySessionListing(sessionHandle));
        if (generation != _machineGeneration || _session.Handle != sessionHandle || _activeHost is null)
            return;
        if (result.Succeeded && result.Data is { } bytes)
        {
            try
            {
                MilaSessionListing listing = RustNative.DecodeSessionListing(bytes);
                MachineRows.ItemsSource = listing.Machines;
                StatusText.Text = $"{S("machinesSavedAt", "Machines for")} {host}: {listing.Machines.Count}";
                return;
            }
            catch (InvalidDataException) { }
        }
        StatusText.Text = S("requestFailed", "Unable to load machines.");
    }
    private void OnMachineSelected(object sender, SelectionChangedEventArgs args)
    {
        if (MachineRows.SelectedItem is not MilaMachineRow machine) return;
        _selectedMachine = machine;
        UpdateMachineMutationAvailability();
        string access = machine.CanManage ? S("machineAccessOwner", "Manage") : machine.CanWrite ? S("machineAccessShared", "Write") : S("terminalReadOnly", "Read only");
        MachineCommandStatus.Text = $"{machine.Name} ({machine.DesiredState}) — {access}";
    }

    private void UpdateMachineMutationAvailability()
    {
        bool enabled = _session.Handle is not null && _selectedMachine is not null;
        MachineResize.IsEnabled = enabled;
        MachineStart.IsEnabled = enabled;
        MachineStop.IsEnabled = enabled;
        MachinePause.IsEnabled = enabled;
        MachineResume.IsEnabled = enabled;
        MachineDelete.IsEnabled = enabled;
        MachineShareAdd.IsEnabled = enabled;
        MachineShareRemove.IsEnabled = enabled;
        MachineWebShow.IsEnabled = enabled;
        MachineWebSet.IsEnabled = enabled;
    }

    private async void RefreshThreads()
    {
        if (_activeHost is null)
        {
            _threadController.SetSession(false, null);
            ThreadRows.ItemsSource = Array.Empty<MilaThreadRow>();
            ThreadDetail.Text = S("signInFirst", "Sign in first");
            return;
        }
        if (_session.Handle is not { } handle)
        {
            _threadController.SetSession(false, null);
            ThreadRows.ItemsSource = Array.Empty<MilaThreadRow>();
            ThreadDetail.Text = S("signInFirst", "Sign in first");
            return;
        }
        MilaNativeSessionBytesResult result = await Task.Run(() => RustNative.TrySessionThreadAction(handle, null, "ls", null, null, null));
        if (!result.Succeeded || result.Data is not { } bytes)
        {
            _threadController.SetSession(false, null);
            ThreadRows.ItemsSource = Array.Empty<MilaThreadRow>();
            ThreadDetail.Text = S("requestFailed", "Unable to load threads.");
            return;
        }
        try
        {
            MilaThreadListing listing = MilaThreadListing.Decode(bytes);
            _threadController.SetSession(true, listing);
            ThreadRows.ItemsSource = listing.Threads;
            ThreadDetail.Text = listing.Threads.Count == 0 ? S("threadsEmpty", "No threads") : string.Format(S("threadsLoaded", "{0} threads."), listing.Threads.Count);
        }
        catch (InvalidDataException)
        {
            _threadController.SetSession(false, null);
            ThreadRows.ItemsSource = Array.Empty<MilaThreadRow>();
            ThreadDetail.Text = S("requestFailed", "Unable to load threads.");
        }
    }

    private void OnThreadSelected(object sender, SelectionChangedEventArgs args)
    {
        if (ThreadRows.SelectedItem is not MilaThreadRow thread || !_threadController.Select(thread.Id)) return;
        ThreadDetail.Text = $"{thread.Title} ({thread.State})";
        ThreadCommandStatus.Text = S("threadReady", "Thread selected");
    }
    private void SubmitThreadPrompt(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.Prompt);
    private void SubmitThreadAnswer(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.Answer);
    private void SubmitThreadApprove(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.PlanApprove);
    private void SubmitThreadRevise(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.PlanRevise);
    private async void SubmitThread(MilaThreadAction action)
    {
        if (_session.Handle is not { } handle)
        {
            ThreadCommandStatus.Text = S("signInFirst", "Sign in first");
            return;
        }
        ThreadPrompt.IsEnabled = ThreadAnswer.IsEnabled = ThreadApprove.IsEnabled = ThreadRevise.IsEnabled = false;
        try
        {
            string? input = string.IsNullOrWhiteSpace(ThreadInput.Text) ? null : ThreadInput.Text.Trim();
            string? secondary = action is MilaThreadAction.PlanApprove or MilaThreadAction.PlanRevise ? input : null;
            string? payload = action is MilaThreadAction.Prompt or MilaThreadAction.Answer ? input : null;
            bool applied = await Task.Run(() => _threadController.SubmitLive(handle, action, secondary, payload));
            ThreadCommandStatus.Text = applied ? S("requestSucceeded", "Request submitted") : S("requestFailed", "Request refused");
            if (applied) ThreadInput.Text = string.Empty;
        }
        finally
        {
            ThreadPrompt.IsEnabled = ThreadAnswer.IsEnabled = ThreadApprove.IsEnabled = ThreadRevise.IsEnabled = true;
        }
    }

    private void ClassifyThreadList(object sender, RoutedEventArgs args) => RefreshThreads();
    private void ClassifyThreadShow(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.Show);
    private void ClassifyThreadTurns(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.Turns);
    private void ClassifyThreadRead(object sender, RoutedEventArgs args) => SubmitThread(MilaThreadAction.Read);

    private void ClassifyMachineList(object sender, RoutedEventArgs args) => ClassifyMachine("ls");
    private const string SampleMachine = "00000000-0000-0000-0000-000000000000";
    private void ClassifyMachineShow(object sender, RoutedEventArgs args) => ClassifyMachine("show demo");
    private void ClassifyMachineNew(object sender, RoutedEventArgs args) => ClassifyMachine("new");
    private void ClassifyMachineResize(object sender, RoutedEventArgs args)
    {
        if (_selectedMachine is not { } machine)
        {
            MachineCommandStatus.Text = S("machineNotSelected", "Select a machine first.");
            return;
        }
        if (!uint.TryParse(ResizeCpu.Text, out uint cpu) || !ulong.TryParse(ResizeMemory.Text, out ulong memory) ||
            !ulong.TryParse(ResizeDisk.Text, out ulong disk) || cpu is < 1 or > 256 || memory is < 256 or > 4_194_304 ||
            disk is < 1 or > 16_777_216)
        {
            MachineCommandStatus.Text = S("resizeInvalid", "Enter valid CPU, memory and disk sizes.");
            return;
        }
        bool applied = _machineMutation.Resize(machine.Id, cpu, memory, disk,
            "porsche-" + Guid.NewGuid().ToString("N"));
        MachineCommandStatus.Text = applied
            ? S("requestSucceeded", "Request submitted")
            : S("requestFailed", "Request refused");
    }
    private void ClassifyMachineStart(object sender, RoutedEventArgs args) => SubmitMachineMutation("start");
    private void ClassifyMachineStop(object sender, RoutedEventArgs args) => SubmitMachineMutation("stop");
    private void ClassifyMachinePause(object sender, RoutedEventArgs args) => SubmitMachineMutation("pause");
    private void ClassifyMachineResume(object sender, RoutedEventArgs args) => SubmitMachineMutation("resume");
    private void ClassifyMachineDelete(object sender, RoutedEventArgs args) => SubmitMachineMutation("rm");
    private void ClassifyMachineShareAdd(object sender, RoutedEventArgs args) => SubmitShare(true);
    private void ClassifyMachineShareRemove(object sender, RoutedEventArgs args) => SubmitShare(false);
    private void SubmitShare(bool add)
    {
        if (_session.Handle is not { } handle || _selectedMachine is not { } machine)
        { MachineCommandStatus.Text = S("signInFirst", "Sign in first"); return; }
        string email = ShareEmail.Text.Trim();
        if (email.Length is < 3 or > 320 || !email.Contains('@', StringComparison.Ordinal))
        { MachineCommandStatus.Text = S("sharingEmailInvalid", "Enter a valid sharing email."); return; }
        MilaNativeSessionActionResult result = RustNative.TrySessionShareMutation(handle, machine.Id, email, add ? "viewer" : null, add, "porsche-" + Guid.NewGuid().ToString("N"));
        MachineCommandStatus.Text = result.Succeeded ? S("requestSucceeded", "Request submitted") : S("requestFailed", "Request refused");
    }
    private void ClassifyMachineWebShow(object sender, RoutedEventArgs args) => ClassifyMachine($"web show {SampleMachine}");
    private void ClassifyMachineWebSet(object sender, RoutedEventArgs args) => ClassifyMachine($"web set {SampleMachine} --port=8080");

    private void ClassifyMachine(string command)
    {
        MilaMachineCommandKind? kind = RustNative.TryClassifyMachineCommand(command);
        if (kind is not { } value)
        {
            MachineCommandStatus.Text = $"{command}: unavailable or requires arguments";
            return;
        }
        if (_activeHost is null)
        {
            MachineCommandStatus.Text = $"{command}: {value} — {S("signInFirst", "Sign in first")}";
            return;
        }
        MilaNativeCommandResult formatted = RustNative.TryFormatMachineCommand(command.Split(' ')[0], Guid.Parse(SampleMachine), null);
        MachineCommandStatus.Text = formatted.Status == MilaNativeStatus.Ok
            ? $"{command}: {value} — {S("requestWaiting", "Request formatted by Rust")}" 
            : $"{command}: {S("requestRefused", "Request refused")}";
    }

    private void SubmitMachineMutation(string action)
    {
        if (_selectedMachine is null)
        {
            MachineCommandStatus.Text = S("machineNotSelected", "Select a machine first.");
            return;
        }
        // The Rust/core mutation contract calls destructive removal "delete";
        // keep the WinUI label/event name "rm" only at the presentation edge.
        string coreAction = action == "rm" ? "delete" : action;
        bool applied = _machineMutation.Submit(
            _selectedMachine.Id,
            coreAction,
            "porsche-" + Guid.NewGuid().ToString("N"));
        MachineCommandStatus.Text = applied
            ? S("requestSucceeded", "Request submitted")
            : _machineMutation.State.Kind == MilaMachineMutationStateKind.SignedOut
                ? S("signInFirst", "Sign in first")
                : S("requestFailed", "Request refused");
    }
}
