using Mila.Windows.Interop;

internal static class WindowsNotificationsSmoke
{
    internal static void Run()
    {
        MilaWindowsNotificationController controller = new((channel, app, host) =>
            channel == "https://push.notify.windows.com/channel/abc" &&
            app == "dev.overalls.mila" && host == "mgmt.example.test"
                ? MilaNativeStatus.Ok
                : MilaNativeStatus.InvalidRequest);
        Program.Require(controller.Register("https://push.notify.windows.com/channel/abc", "dev.overalls.mila", "mgmt.example.test") == MilaWindowsNotificationState.Invalid, "signed-out registration refusal");
        controller.SetSession(true);
        Program.Require(
            controller.Register("https://push.notify.windows.com/channel/abc", "dev.overalls.mila", "mgmt.example.test") ==
            MilaWindowsNotificationState.Registered, "WNS metadata registration");
        Program.Require(controller.Register("https://evil.example/channel", "dev.overalls.mila", "mgmt.example.test") ==
            MilaWindowsNotificationState.Invalid, "foreign WNS channel refusal");
        controller.Disable();
        Program.Require(controller.State == MilaWindowsNotificationState.Disabled, "notification disable");
        controller.SetSession(false);
        Program.Require(controller.State == MilaWindowsNotificationState.Disabled, "sign-out clears notification state");

        Guid id = Guid.NewGuid();
        byte[] listing = System.Text.Encoding.UTF8.GetBytes($"{{\"devices\":[{{\"id\":\"{id:D}\",\"platform\":\"wns\",\"enabled\":true}}]}}");
        IReadOnlyList<MilaWindowsNotificationDevice> devices = MilaWindowsNotificationDevicesController.DecodeListing(listing);
        Program.Require(devices.Count == 1 && devices[0].Id == id.ToString("D") && devices[0].Enabled, "device listing projection");
        bool removed = false;
        var devicesController = new MilaWindowsNotificationDevicesController(
            _ => Task.FromResult<IReadOnlyList<MilaWindowsNotificationDevice>>(devices),
            (device, _) => { removed = device == id.ToString("D"); return Task.CompletedTask; },
            (_, _, _) => Task.CompletedTask);
        devicesController.LoadAsync(true).GetAwaiter().GetResult();
        devicesController.RemoveAsync(devices[0]).GetAwaiter().GetResult();
        Program.Require(removed && devicesController.Status == MilaWindowsNotificationDevicesStatus.Loaded, "authenticated device removal workflow");
        string storePath = Path.Combine(Path.GetTempPath(), $"mila-notifications-{Guid.NewGuid():N}.json");
        try
        {
            MilaWindowsNotificationDeviceStore store = new(storePath);
            store.Save(devices);
            Program.Require(store.Load().Count == 1 && store.Load()[0].Id == devices[0].Id, "notification device persistence");
        }
        finally { if (File.Exists(storePath)) File.Delete(storePath); }
    }
}
