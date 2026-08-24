import Foundation

/// Decides which hosts may receive a bearer credential.
///
/// The production policy is fixed to the Google service hosts confirmed against
/// the discovery documents in `design-docs/references/` on 2026-08-24. Tests
/// construct a loopback policy directly; no production binary exposes a flag or
/// environment variable that widens the allowlist.
public struct GoogleHostPolicy: Sendable, Equatable {
  /// Approved Google API hosts. Every `GoogleAPIService.host` must appear here;
  /// `unapprovedServiceHosts` proves the two lists agree.
  public static let approvedAPIHosts: [String] = [
    "analyticsadmin.googleapis.com",
    "analyticsdata.googleapis.com",
    "tagmanager.googleapis.com"
  ]

  /// Approved Google OAuth token host. It receives the client secret and the
  /// refresh token, so it is deliberately not an API host.
  public static let approvedTokenHost = "oauth2.googleapis.com"

  /// Approved Google authorization host. Only the browser leg of the desktop
  /// PKCE flow addresses it; no gateway request ever carries a credential here.
  public static let approvedAuthorizationHost = "accounts.google.com"

  public let allowedHosts: Set<String>
  public let requiresHTTPS: Bool
  /// True when a validated URL must be a bare origin with no path segments.
  ///
  /// This replaces Wrike's fixed `/api/v4` prefix check. A Google service origin
  /// carries no version: the version prefix belongs to the capability's path
  /// template, so a base URL with any path at all is a misconfiguration that
  /// would silently double a segment into every route.
  public let requiresEmptyPath: Bool

  public init(allowedHosts: Set<String>, requiresHTTPS: Bool, requiresEmptyPath: Bool) {
    self.allowedHosts = allowedHosts
    self.requiresHTTPS = requiresHTTPS
    self.requiresEmptyPath = requiresEmptyPath
  }

  public static let production = GoogleHostPolicy(
    allowedHosts: Set(approvedAPIHosts),
    requiresHTTPS: true,
    requiresEmptyPath: true
  )

  /// The policy for the OAuth endpoints.
  ///
  /// It is deliberately separate from `production`: the token endpoint lives on
  /// `oauth2.googleapis.com` with the path `/token`, so the API policy rejects
  /// it on both the host and the empty-path rule. Widening `production` instead
  /// would let an ordinary capability request address the host that receives the
  /// client secret.
  public static let oauth = GoogleHostPolicy(
    allowedHosts: [approvedTokenHost, approvedAuthorizationHost],
    requiresHTTPS: true,
    requiresEmptyPath: false
  )

  /// Service hosts that the production policy does not approve. It is always
  /// empty; the registry coherence test asserts so, which is what keeps a newly
  /// added `GoogleAPIService` from reaching a host nobody reviewed.
  public static var unapprovedServiceHosts: [String] {
    let approved = Set(approvedAPIHosts)
    return GoogleAPIService.allCases
      .map(\.host)
      .filter { !approved.contains($0) }
      .sorted()
  }

  public func allows(host: String?) -> Bool {
    guard let host else { return false }
    return allowedHosts.contains(host.lowercased())
  }

  /// Validates a service origin before any credential can be attached to a
  /// request. Failures are local and never reach the network.
  public func validateBaseURL(_ raw: String, source: String) throws -> URL {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw GatewayError.authentication(
        "\(source) is empty.",
        recovery: "Set \(source) to an approved Google API origin such as "
          + "https://analyticsadmin.googleapis.com."
      )
    }
    guard var components = URLComponents(string: trimmed) else {
      throw GatewayError.authentication(
        "\(source) is not a valid URL.",
        recovery: "Use an https URL such as https://analyticsadmin.googleapis.com."
      )
    }
    if requiresHTTPS, components.scheme?.lowercased() != "https" {
      throw GatewayError.authentication(
        "\(source) must use https.",
        recovery: "Use an https URL such as https://analyticsadmin.googleapis.com."
      )
    }
    guard components.user == nil, components.password == nil else {
      throw GatewayError.authentication("\(source) must not contain user information.")
    }
    guard components.query == nil, components.fragment == nil else {
      throw GatewayError.authentication("\(source) must not contain a query or fragment.")
    }
    guard allows(host: components.host) else {
      let approved = allowedHosts.sorted().joined(separator: ", ")
      throw GatewayError.authentication(
        "\(source) host is not an approved Google API host.",
        recovery: "Approved hosts: \(approved)."
      )
    }

    var path = components.path
    while path.count > 1, path.hasSuffix("/") {
      path.removeLast()
    }
    if path == "/" { path = "" }
    if requiresEmptyPath, !path.isEmpty {
      throw GatewayError.authentication(
        "\(source) must be a bare origin with no path.",
        recovery: "Use the host alone; the API version prefix comes from the capability route."
      )
    }
    components.path = path

    guard let url = components.url else {
      throw GatewayError.authentication("\(source) is not a valid URL.")
    }
    return url
  }

  /// True when a redirect target may continue to carry the authorization
  /// header. A different host always drops the credential and fails the request.
  public func permitsCredentialForwarding(to url: URL, from origin: URL) -> Bool {
    guard let target = url.host?.lowercased(), let source = origin.host?.lowercased() else {
      return false
    }
    guard url.scheme?.lowercased() == "https" else { return false }
    return target == source && allows(host: target)
  }
}
