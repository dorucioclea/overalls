import Foundation

/// Stable message identities shared with the Rust localization catalog.
public enum MilaMessage: String, Sendable { case appName, sharePrincipal, shareAdd, shareRemove, shareAdded, shareRemoved, machines, threads, settings, ready, refresh, connecting, connected, runtimeUnavailable, noAction, snapshotLoaded, noSnapshotLoaded, machinesEmpty, machinesHint, openTerminal, actionSubmitted, actionNotSubmitted, rejectedByRust, machineUnavailable, commandsRust, noThreads, threadsHint, unavailable, terminal, input, send, reconnect, appearance, appearanceSystem, appearanceLight, appearanceDark, lockTitle, lockExplain, lockUnavailable, lockUnlock, lockFailed, notificationsTitle, notificationsExplain, notificationsTurnOn, notificationsTurnOff, pushUnsupported, sshKeysTitle, sshKeysExplain, sshKeysEmpty, sshKeyRevoke, sshKeyAlgorithm, sshKeyThisDevice, webOpen, webInvalid, webPlaceholder }

public enum MilaStrings {
    /// Canonicalize a user-selected BCP-47 locale to one of the bundled catalogs.
    public static func canonicalLocale(_ raw: String) -> String {
        let normalized = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64)).replacingOccurrences(of: "_", with: "-")
        let parts = normalized.split(separator: "-").map(String.init)
        guard let language = parts.first?.lowercased(), !language.isEmpty else { return "en" }
        let script = parts.dropFirst().first(where: { $0.count == 4 })?.capitalized
        let region = parts.dropFirst().first(where: { $0.count == 2 || $0.count == 3 && $0.allSatisfy(\.isNumber) })?.uppercased()
        let candidate = [language, script, region].compactMap { $0 }.joined(separator: "-")
        return ["en", "fr-FR", "de", "es", "ja", "ar"].contains(candidate) ? candidate : "en"
    }
    private static let ids: [MilaMessage: String] = [
        .appName: "appTitle", .sharePrincipal: "sharePrincipal", .shareAdd: "shareAdd", .shareRemove: "shareRemove", .shareAdded: "shareAdded", .shareRemoved: "shareRemoved", .machines: "machinesTitle", .threads: "tabThreads", .settings: "settingsTitle",
        .ready: "ready", .refresh: "refresh", .connecting: "signInConnecting", .connected: "connected",
        .runtimeUnavailable: "runtimeUnavailable", .noAction: "noAction", .snapshotLoaded: "snapshotLoaded", .noSnapshotLoaded: "noSnapshotLoaded", .machinesEmpty: "machinesEmpty", .machinesHint: "machinesEmptyHint", .openTerminal: "terminalAttach", .actionSubmitted: "requestSucceeded", .actionNotSubmitted: "requestFailed", .rejectedByRust: "linkRefused", .machineUnavailable: "machineNotFound", .commandsRust: "threadEventTool", .noThreads: "threadsEmpty", .threadsHint: "threadsEmptyHint", .unavailable: "runtimeUnavailable", .terminal: "tabTerminals", .input: "threadAnswerHint", .send: "threadSend", .reconnect: "signInReconnect", .appearance: "appearance", .appearanceSystem: "appearanceSystem", .appearanceLight: "appearanceLight", .appearanceDark: "appearanceDark", .lockTitle: "lockTitle", .lockExplain: "lockExplain", .lockUnavailable: "lockUnavailable", .lockUnlock: "lockUnlock", .lockFailed: "lockFailed", .notificationsTitle: "notificationsTitle", .notificationsExplain: "notificationsExplain", .notificationsTurnOn: "notificationsTurnOn", .notificationsTurnOff: "notificationsTurnOff", .pushUnsupported: "pushUnsupported", .sshKeysTitle: "sshKeysTitle", .sshKeysExplain: "sshKeysExplain", .sshKeysEmpty: "sshKeysEmpty", .sshKeyRevoke: "sshKeyRevoke", .sshKeyAlgorithm: "sshKeyAlgorithm", .sshKeyThisDevice: "sshKeyThisDevice", .webOpen: "webOpen", .webInvalid: "webInvalid", .webPlaceholder: "webPlaceholder"
    ]

    public static func text(_ message: MilaMessage, locale: Locale = .current) -> String {
        let candidates: [String] = [
            locale.identifier.replacingOccurrences(of: "_", with: "-"),
            locale.language.languageCode?.identifier ?? "en",
            "en",
        ]
        for candidate in candidates {
            if let value = resourceValue(message, locale: candidate) { return value }
        }
        switch message {
        case .appName: return "Mila"; case .sharePrincipal: return "Share principal"; case .shareAdd: return "Share"; case .shareRemove: return "Remove share"; case .shareAdded: return "Share added"; case .shareRemoved: return "Share removed"; case .machines: return "Machines"; case .threads: return "Threads"; case .settings: return "Settings"
        case .ready: return "Ready"; case .refresh: return "Refresh"; case .connecting: return "Connecting…"; case .connected: return "Connected"
        case .runtimeUnavailable: return "Native runtime unavailable"; case .appearance: return "Appearance"; case .appearanceSystem: return "System"; case .appearanceLight: return "Light"; case .appearanceDark: return "Dark"; case .lockTitle: return "App lock"; case .lockExplain: return "Ask for your fingerprint, face or device passcode before showing Mila."; case .lockUnavailable: return "App lock is not available on this device."; case .lockUnlock: return "Unlock Mila"; case .lockFailed: return "Authentication failed."; case .noAction: return "No action selected"; case .snapshotLoaded: return "Snapshot loaded"; case .noSnapshotLoaded: return "No snapshot loaded"; case .machinesEmpty: return "No machines"; case .machinesHint: return "Connect to a deployment to load a validated snapshot."; case .openTerminal: return "Open terminal"; case .actionSubmitted: return "Action submitted"; case .actionNotSubmitted: return "Action not submitted"; case .rejectedByRust: return "Rejected by Rust"; case .machineUnavailable: return "Machine unavailable"; case .commandsRust: return "Commands are classified by Rust before execution."; case .noThreads: return "No threads"; case .threadsHint: return "Connect to a deployment to load threads."; case .unavailable: return "Unavailable"; case .terminal: return "Terminal"; case .input: return "Input"; case .send: return "Send"; case .reconnect: return "Reconnect"; case .notificationsTitle: return "Notifications"; case .notificationsExplain: return "Notifications tell you when an agent needs your input."; case .notificationsTurnOn: return "Turn on"; case .notificationsTurnOff: return "Turn off"; case .pushUnsupported: return "Notifications are not available on this platform."; case .webOpen: return "Open web"; case .webInvalid: return "Invalid HTTPS URL"; case .webPlaceholder: return "https://machine.example"; case .sshKeysTitle: return "SSH keys"; case .sshKeysExplain: return "Keys approved to sign in to your account on this deployment."; case .sshKeysEmpty: return "No approved keys."; case .sshKeyRevoke: return "Revoke"; case .sshKeyAlgorithm: return "Type"; case .sshKeyThisDevice: return "This device"
        }
    }

    private static func resourceValue(_ message: MilaMessage, locale: String) -> String? {
        guard let url = Bundle.module.url(forResource: locale, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let domains = root["domains"] as? [String: Any],
              let mila = domains["mila"] as? [String: Any],
              let messages = mila["messages"] as? [[String: Any]] else { return nil }
        guard let entry = messages.first(where: { $0["id"] as? String == ids[message] }),
              let forms = entry["forms"] as? [Any],
              let first = forms.first as? String else { return nil }
        return first
    }
}
