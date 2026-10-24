import Foundation
import Combine

/// The bounded result of the authenticated `whoami --json` approval envelope.
public struct MilaApprovalInfo: Equatable, Sendable {
    public let url: URL
    public let fingerprint: String
    public init(url: URL, fingerprint: String) { self.url = url; self.fingerprint = fingerprint }
}

public enum MilaApprovalResult: Equatable, Sendable {
    case approved
    case pending(MilaApprovalInfo)
}

public enum MilaApprovalDecoder {
    public static func decode(_ data: Data, expectedHost: String? = nil) throws -> MilaApprovalResult {
        guard data.count <= 64 * 1024 else { throw MilaFFIError.outputTooSmall }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let value = object as? [String: Any], value["version"] as? Int == 1,
              let status = value["status"] as? String else { throw MilaFFIError.incompatibleABI }
        switch status {
        case "approved": return .approved
        case "approval_required":
            guard let rawURL = value["approval_url"] as? String, rawURL.utf8.count <= 2048,
                  let url = URL(string: rawURL), url.scheme?.lowercased() == "https",
                  url.user == nil, url.fragment == nil, let host = url.host, !host.isEmpty,
                  let fingerprint = value["fingerprint"] as? String,
                  fingerprint.range(of: "^[A-Fa-f0-9:]{16,128}$", options: .regularExpression) != nil,
                  expectedHost == nil || host.caseInsensitiveCompare(expectedHost!) == .orderedSame
            else { throw MilaFFIError.incompatibleABI }
            return .pending(MilaApprovalInfo(url: url, fingerprint: fingerprint))
        default: throw MilaFFIError.incompatibleABI
        }
    }
}

/// Approval polling deliberately reuses the authenticated adapter/session.
@MainActor public final class MilaApprovalController: ObservableObject {
    @Published public private(set) var result: MilaApprovalResult?
    @Published public private(set) var error = false
    public init() {}
    public func inspect(_ adapter: any MilaFFIAdapter, expectedHost: String) async {
        do { result = try MilaApprovalDecoder.decode(await adapter.checkApproval(), expectedHost: expectedHost); error = false }
        catch { error = true }
    }
}
