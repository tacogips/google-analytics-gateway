import Darwin
import Foundation
import GoogleAnalyticsGatewayCore

/// A private scratch directory for config and token-store fixtures.
///
/// The base path is resolved through `realpath` first: `SecureLocalFiles` walks
/// every path component with `O_NOFOLLOW`, and the system temporary directory
/// reaches the real one through the `/var` symlink, so an unresolved path would
/// fail the walk rather than the check under test. `URL.resolvingSymlinksInPath`
/// is not enough — it leaves `/var/folders/...` as it found it. The directory is
/// created 0700 because token-store reads and writes require a private parent.
public final class TemporaryDirectory {
  public let url: URL

  public init(name: String = UUID().uuidString) throws {
    let base = URL(fileURLWithPath: Self.realPath(NSTemporaryDirectory()))
    url = base.appendingPathComponent("google-analytics-gateway-tests").appendingPathComponent(name)
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
    )
    // `createDirectory` applies the mode only to the leaf it creates, so the
    // shared parent is tightened explicitly for the runs that created it.
    try? FileManager.default.setAttributes(
      [.posixPermissions: NSNumber(value: Int16(0o700))],
      ofItemAtPath: url.deletingLastPathComponent().path
    )
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }

  public var path: String { url.path }

  /// Keeps the directory alive until the end of the calling scope.
  ///
  /// The directory removes itself when it is released, and ARC may release it
  /// straight after its last use. A test that stops naming the fixture halfway
  /// through — the usual shape, where only the written path is used from then on
  /// — would otherwise have its files deleted underneath it. Call it from a
  /// `defer` at the top of the test.
  public func keepAlive() {}

  private static func realPath(_ path: String) -> String {
    guard let resolved = realpath(path, nil) else { return path }
    defer { free(resolved) }
    return String(cString: resolved)
  }

  public func path(_ name: String) -> String {
    url.appendingPathComponent(name).path
  }

  /// Writes a fixture file, defaulting to the 0600 mode a credential-bearing
  /// file must carry.
  @discardableResult
  public func write(
    _ contents: String,
    to name: String,
    permissions: Int16 = 0o600
  ) throws -> String {
    let destination = path(name)
    try Data(contents.utf8).write(to: URL(fileURLWithPath: destination))
    try FileManager.default.setAttributes(
      [.posixPermissions: NSNumber(value: permissions)],
      ofItemAtPath: destination
    )
    return destination
  }
}

/// Builds credential-profile configuration documents for CLI and auth tests.
public enum SampleProfiles {
  public static let tokenEnvironmentVariable = "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN"

  /// A profile carrying the exact scope bundle its product and capability
  /// document, which is the only shape the loader accepts.
  public static func profile(
    id: String,
    product: GatewayProduct = .analytics,
    capability: CapabilityTier = .reader,
    scopes: [String]? = nil,
    environmentVariable: String = tokenEnvironmentVariable,
    oauthClientJSONPath: String? = nil,
    tokenStorePath: String? = nil
  ) -> CredentialProfile {
    CredentialProfile(
      id: id,
      product: product,
      capability: capability,
      oauthScopes: scopes ?? product.oauthScopes(for: capability),
      accessTokenEnvironmentVariable: environmentVariable,
      oauthClientJSONPath: oauthClientJSONPath,
      tokenStorePath: tokenStorePath
    )
  }

  /// Renders a configuration document. Profiles are rendered by hand rather than
  /// encoded so a test can also produce documents the decoder must reject.
  public static func configurationJSON(_ profiles: [CredentialProfile]) -> String {
    let rendered = profiles.map { profile -> String in
      var fields = [
        "\"id\": \"\(profile.id)\"",
        "\"product\": \"\(profile.product.rawValue)\"",
        "\"capability\": \"\(profile.capability.rawValue)\"",
        "\"oauthScopes\": [\(profile.oauthScopes.map { "\"\($0)\"" }.joined(separator: ", "))]",
        "\"accessTokenEnvironmentVariable\": \"\(profile.accessTokenEnvironmentVariable)\""
      ]
      if let clientPath = profile.oauthClientJSONPath {
        fields.append("\"oauthClientJSONPath\": \"\(clientPath)\"")
      }
      if let storePath = profile.tokenStorePath {
        fields.append("\"tokenStorePath\": \"\(storePath)\"")
      }
      return "{ \(fields.joined(separator: ", ")) }"
    }
    return "{ \"profiles\": [\(rendered.joined(separator: ", "))] }"
  }
}
