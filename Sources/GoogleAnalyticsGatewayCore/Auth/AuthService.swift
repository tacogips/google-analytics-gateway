#if canImport(AppKit)
import AppKit
#endif
import Foundation

public protocol AuthManaging: Sendable {
  func status(profile: CredentialProfile, environment: [String: String]) -> AuthStatus
  func logout(profile: CredentialProfile) throws -> Bool
  func login(
    profile: CredentialProfile,
    noBrowser: Bool,
    redirectURI: String?,
    timeoutSeconds: Int32
  ) throws -> AuthLoginOutput
}

public struct AuthLoginOutput: Encodable, Equatable, Sendable {
  public let profileId: String
  public let state: String
  public let authorizationURL: String?

  public init(profileId: String, state: String, authorizationURL: String?) {
    self.profileId = profileId
    self.state = state
    self.authorizationURL = authorizationURL
  }
}

/// The `auth login|logout|status` operations for any capability tier.
///
/// The browser opener and the loopback listener are injected seams so the whole
/// flow can be exercised without a browser or a live Google endpoint; the
/// defaults are the real ones.
public struct AuthService: AuthManaging, Sendable {
  private let resolver: CredentialResolver
  private let oauth: OAuthClient
  private let openURL: @Sendable (URL) -> Bool
  private let makeReceiver: @Sendable (String?) throws -> any OAuthLoopbackReceiving
  private let randomString: @Sendable (Int) throws -> String
  private let tokenStore: any OAuthTokenStoring
  /// The tier this binary links. A login is refused for a profile above it, so
  /// `auth login` in the reader binary cannot bootstrap writer or admin scopes.
  private let supportedTier: CapabilityTier?

  public init(
    resolver: CredentialResolver = CredentialResolver(refresher: OAuthClient()),
    oauth: OAuthClient = OAuthClient(),
    openURL: @escaping @Sendable (URL) -> Bool = AuthService.defaultOpenURL,
    makeReceiver: @escaping @Sendable (String?) throws -> any OAuthLoopbackReceiving = {
      try OAuthLoopbackReceiver(redirectURI: $0)
    },
    randomString: @escaping @Sendable (Int) throws -> String = AuthService.defaultRandomString,
    tokenStore: any OAuthTokenStoring = OAuthTokenStore(),
    supportedTier: CapabilityTier? = nil
  ) {
    self.resolver = resolver
    self.oauth = oauth
    self.openURL = openURL
    self.makeReceiver = makeReceiver
    self.randomString = randomString
    self.tokenStore = tokenStore
    self.supportedTier = supportedTier
  }

  public func status(profile: CredentialProfile, environment: [String: String]) -> AuthStatus {
    resolver.status(profile: profile, environment: environment)
  }

  public func logout(profile: CredentialProfile) throws -> Bool {
    try resolver.logout(profile: profile)
  }

  public func login(
    profile: CredentialProfile,
    noBrowser: Bool,
    redirectURI: String? = nil,
    timeoutSeconds: Int32 = 300
  ) throws -> AuthLoginOutput {
    if let supportedTier, !supportedTier.includes(profile.capability) {
      throw GatewayError(
        code: .capabilityDenied,
        message: "This binary cannot bootstrap credentials for a higher capability tier",
        requiredTier: profile.capability
      )
    }
    guard let clientPath = profile.oauthClientJSONPath, let storePath = profile.tokenStorePath else {
      throw GatewayError(
        code: .validationError,
        message: "Selected profile does not support installed OAuth login",
        recoveryGuidance: "Configure oauthClientJSONPath and tokenStorePath for this profile"
      )
    }
    let client = try oauth.loadClient(path: clientPath)
    // The token-store destination is validated (and its missing ancestors
    // created, 0700) before the browser opens: the authorization code is
    // single-use, so discovering an unwritable store only after the exchange
    // would discard a grant the operator cannot recover.
    try SecureLocalFiles.ensurePrivateParent(ofPath: storePath)
    let receiver = try makeReceiver(redirectURI)
    // 43 URL-safe characters is the shape the callback validator requires of
    // the state, and 64 sits inside the PKCE verifier's 43...128 range.
    let state = try randomString(43)
    let verifier = try randomString(64)
    let url = try OAuthPKCE.authorizationURL(
      client: client,
      scopes: profile.oauthScopes,
      redirectURI: receiver.redirectURI,
      state: state,
      verifier: verifier
    )
    if noBrowser {
      // stderr, never stdout: stdout carries the machine-readable envelope,
      // and the URL must be visible while this call blocks on the callback.
      // The same URL is returned in `AuthLoginOutput.authorizationURL` for
      // library callers.
      FileHandle.standardError.write(
        Data(("Open this URL to authorize:\n" + url.absoluteString + "\n").utf8)
      )
    } else if !openURL(url) {
      throw GatewayError(
        code: .internalError,
        message: "Unable to open OAuth authorization URL",
        recoveryGuidance: "Re-run with --no-browser and open the printed URL manually"
      )
    }
    let code = try receiver.waitForCode(expectedState: state, timeoutSeconds: timeoutSeconds)
    let token = try oauth.exchange(
      clientPath: clientPath,
      code: code,
      verifier: verifier,
      redirectURI: receiver.redirectURI,
      profile: profile
    )
    try tokenStore.write(token, path: storePath, profile: profile)
    return AuthLoginOutput(
      profileId: profile.id,
      state: "ready",
      authorizationURL: noBrowser ? url.absoluteString : nil
    )
  }

  public static let defaultOpenURL: @Sendable (URL) -> Bool = { url in
    #if canImport(AppKit)
    return NSWorkspace.shared.open(url)
    #else
    return false
    #endif
  }

  public static func defaultRandomString(length: Int) throws -> String {
    guard length > 0 else {
      throw GatewayError(code: .validationError, message: "OAuth random value length is invalid")
    }
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    var generator = SystemRandomNumberGenerator()
    return String((0..<length).map { _ in alphabet[Int.random(in: alphabet.indices, using: &generator)] })
  }
}
