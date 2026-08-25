import CryptoKit
import Foundation

/// A Google desktop ("installed") OAuth client, loaded from the JSON Google
/// hands out in the Cloud console.
///
/// The authorization and token endpoints are pinned constants, and the client
/// file must name exactly those two URLs. A client JSON that points anywhere
/// else is rejected rather than followed, so a swapped-in file cannot redirect
/// the consent screen or the code exchange to a host of the attacker's choosing.
public struct OAuthDesktopClient: Decodable, Equatable, Sendable {
  public static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
  public static let tokenEndpoint = "https://oauth2.googleapis.com/token"

  public let clientId: String
  public let clientSecret: String?
  public let authUri: String
  public let tokenUri: String
  public let redirectUris: [String]

  enum RootKeys: String, CodingKey { case installed }
  enum CodingKeys: String, CodingKey {
    case clientId = "client_id"
    case clientSecret = "client_secret"
    case authUri = "auth_uri"
    case tokenUri = "token_uri"
    case redirectUris = "redirect_uris"
  }

  public init(from decoder: any Decoder) throws {
    let rawRoot = try decoder.container(keyedBy: AuthAnyCodingKey.self)
    guard Set(rawRoot.allKeys.map(\.stringValue)) == Set([RootKeys.installed.rawValue]) else {
      throw GatewayError(code: .validationError, message: "OAuth client file contains unsupported fields")
    }
    let root = try decoder.container(keyedBy: RootKeys.self)
    let rawInstalled = try root.nestedContainer(keyedBy: AuthAnyCodingKey.self, forKey: .installed)
    // The console's real download also carries informational metadata
    // (project_id, auth_provider_x509_cert_url); both are inert here but must
    // not fail the unknown-field check.
    let allowed = Set([
      "client_id", "client_secret", "auth_uri", "token_uri", "redirect_uris",
      "project_id", "auth_provider_x509_cert_url"
    ])
    guard rawInstalled.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw GatewayError(code: .validationError, message: "OAuth client file contains unsupported fields")
    }
    let installed = try root.nestedContainer(keyedBy: CodingKeys.self, forKey: .installed)
    clientId = try installed.decode(String.self, forKey: .clientId)
    clientSecret = try installed.decodeIfPresent(String.self, forKey: .clientSecret)
    authUri = try installed.decode(String.self, forKey: .authUri)
    tokenUri = try installed.decode(String.self, forKey: .tokenUri)
    redirectUris = try installed.decode([String].self, forKey: .redirectUris)
    guard Self.isSafeField(clientId, maximum: 4_096),
      clientSecret.map({ Self.isSafeField($0, maximum: 16_384) }) ?? true,
      // The console downloads desktop clients with the legacy spelling
      // `/o/oauth2/auth`; both spellings are Google's own endpoint, and the
      // authorization URL is always built from the pinned v2 constant, so
      // accepting either does not widen where the flow can be sent.
      authUri == Self.authorizationEndpoint
        || authUri == "https://accounts.google.com/o/oauth2/auth",
      tokenUri == Self.tokenEndpoint,
      redirectUris.count <= 32,
      redirectUris.allSatisfy({ Self.isSafeField($0, maximum: 1_024) }) else {
      throw GatewayError(
        code: .validationError,
        message: "OAuth client file is not an accepted desktop client",
        recoveryGuidance: "Download a Desktop app OAuth client from the Google Cloud console"
      )
    }
  }

  private static func isSafeField(_ value: String, maximum: Int) -> Bool {
    !value.isEmpty && value.utf8.count <= maximum && !value.utf8.contains(where: { $0 < 32 || $0 == 127 })
  }
}

/// Authorization-code flow with PKCE (S256).
public enum OAuthPKCE {
  public static func challenge(for verifier: String) throws -> String {
    guard (43...128).contains(verifier.utf8.count), verifier.utf8.allSatisfy({
      (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || "-._~".utf8.contains($0)
    }) else {
      throw GatewayError(code: .validationError, message: "OAuth verifier is invalid")
    }
    return Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
  }

  /// Builds the consent URL against the pinned authorization endpoint.
  ///
  /// The redirect is constrained to a literal loopback address with no
  /// userinfo, query, or fragment, and the state must be a 43-character
  /// URL-safe token, so nothing caller-supplied can smuggle extra parameters
  /// into the authorization request.
  public static func authorizationURL(
    client: OAuthDesktopClient,
    scopes: [String],
    redirectURI: String,
    state: String,
    verifier: String
  ) throws -> URL {
    guard let redirect = URLComponents(string: redirectURI), redirect.scheme == "http",
      redirect.host == "127.0.0.1",
      redirect.port != nil, redirect.user == nil, redirect.password == nil, redirect.query == nil,
      redirect.fragment == nil,
      redirect.path.hasPrefix("/"), redirect.path.utf8.count <= 1_024, !redirect.path.contains(".."),
      !redirect.path.utf8.contains(where: { $0 < 33 || $0 > 126 }), !redirectURI.contains("%"),
      state.range(of: #"^[A-Za-z0-9_-]{43}$"#, options: .regularExpression) != nil else {
      throw GatewayError(code: .validationError, message: "OAuth callback configuration is invalid")
    }
    guard var components = URLComponents(string: OAuthDesktopClient.authorizationEndpoint) else {
      throw GatewayError(code: .internalError, message: "Unable to create OAuth authorization URL")
    }
    components.queryItems = [
      URLQueryItem(name: "client_id", value: client.clientId),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code_challenge", value: try challenge(for: verifier)),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "access_type", value: "offline"),
      // The grant must carry exactly the requested bundle; incremental
      // authorization would let previously granted scopes ride along and break
      // the exact scope-set match performed on the token response.
      URLQueryItem(name: "include_granted_scopes", value: "false"),
      URLQueryItem(name: "prompt", value: "consent")
    ]
    guard let url = components.url else {
      throw GatewayError(code: .internalError, message: "Unable to create OAuth authorization URL")
    }
    return url
  }
}

private extension Data {
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
