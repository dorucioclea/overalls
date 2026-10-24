import Foundation
import SwiftUI

/// A validated HTTPS endpoint exposed by a machine's web control.
public struct MilaWebEndpoint: Equatable, Sendable {
    public let url: URL
    public init(_ value: String) throws {
        guard let parsed = URL(string: value), parsed.scheme?.lowercased() == "https",
              parsed.user == nil, parsed.password == nil, parsed.fragment == nil,
              parsed.host != nil else { throw MilaWebEndpointError.invalid }
        self.url = parsed
    }
}

public enum MilaWebEndpointError: Error, Equatable, Sendable {
    case invalid
    case unavailable
}

/// Authenticated projection returned by Rust's `web show --json` command.
/// The endpoint is bound to the requested machine before it can reach WebKit.
public struct MilaWebEndpointProjection: Codable, Equatable, Sendable {
    public let machineID: UUID
    public let label: String
    public let port: UInt16
    public let visibility: String
    public let policyRevision: UInt64
    public let url: String?
    public let route: String

    enum CodingKeys: String, CodingKey {
        case machineID = "machine_id"
        case label, port, visibility
        case policyRevision = "policy_revision"
        case url, route
    }

    public func endpoint(for machine: UUID) throws -> MilaWebEndpoint {
        guard machineID == machine, !label.isEmpty, label.utf8.count <= 256,
              (visibility == "private" || visibility == "public"),
              route == "overalls://machines/\(machine.uuidString.lowercased())/web",
              let value = url else { throw MilaWebEndpointError.unavailable }
        return try MilaWebEndpoint(value)
    }
}

@MainActor public final class MilaWebControlsController: ObservableObject {
    @Published public private(set) var endpoint: MilaWebEndpoint?
    @Published public private(set) var error: MilaWebEndpointError?
    public init() {}
    @discardableResult public func set(_ value: String) -> Bool {
        do { endpoint = try MilaWebEndpoint(value); error = nil; return true }
        catch { endpoint = nil; self.error = MilaWebEndpointError.invalid; return false }
    }
    public func open(_ endpoint: MilaWebEndpoint) { self.endpoint = endpoint; error = nil }
    /// Commits an endpoint only while the authenticated session is still active.
    /// A reconnect/sign-out race therefore cannot publish stale WebView state.
    @discardableResult public func openAuthenticated(_ endpoint: MilaWebEndpoint, sessionActive: Bool) -> Bool {
        guard sessionActive else { clear(); error = MilaWebEndpointError.unavailable; return false }
        open(endpoint)
        return true
    }
    public func clear() { endpoint = nil; error = nil }
}

#if canImport(WebKit)
import WebKit

/// Native embedded web controls for iOS and macOS. Navigation remains HTTPS-only.
public struct MilaWebView: View {
    public let endpoint: MilaWebEndpoint
    public init(endpoint: MilaWebEndpoint) { self.endpoint = endpoint }
    public var body: some View { MilaWebViewRepresentable(url: endpoint.url) }
}

#if os(iOS)
struct MilaWebViewRepresentable: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView(frame: .zero) }
    func updateUIView(_ view: WKWebView, context: Context) { view.load(URLRequest(url: url)) }
}
#elseif os(macOS)
struct MilaWebViewRepresentable: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView { WKWebView(frame: .zero) }
    func updateNSView(_ view: WKWebView, context: Context) { view.load(URLRequest(url: url)) }
}
#endif
#endif
