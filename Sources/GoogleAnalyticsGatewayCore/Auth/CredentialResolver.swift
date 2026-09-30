import Foundation

public protocol CredentialResolving: Sendable {
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String
}

public protocol OAuthTokenRefreshing: Sendable {
  func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken
  func refresh(client: OAuthDesktopClient, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken
}

public extension OAuthTokenRefreshing {
  func refresh(client: OAuthDesktopClient, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken {
    throw GatewayError(code: .authenticationFailed, message: "This refresher does not support inline OAuth clients")
  }
}

/// Turns a credential profile into a usable access token.
///
/// Resolution order is fixed: an access token injected through the
/// profile-named environment variable wins, so a non-interactive caller (a
/// secret manager piping a token in) never touches disk. Only when no such
/// token is present does the resolver open the profile's token store.
public struct CredentialResolver: CredentialResolving, Sendable {
  private let tokenStore: any OAuthTokenStoring
  private let refresher: (any OAuthTokenRefreshing)?
  private let now: @Sendable () -> Date

  public init(
    tokenStore: any OAuthTokenStoring = OAuthTokenStore(),
    refresher: (any OAuthTokenRefreshing)? = nil,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.tokenStore = tokenStore
    self.refresher = refresher
    self.now = now
  }

  public func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String {
    do {
      return try selectedAccessToken(profile: profile, environment: environment)
    } catch let error as GatewayError {
      let input = try? AnalyticsCredentialInput(profile: profile, environment: environment)
      let hasEnvironmentToken = input?.accessToken != nil
      let source = input?.tokenStoreJSON != nil ? "ENVIRONMENT_JSON" : (hasEnvironmentToken ? "ENVIRONMENT_TOKEN" : "FILE")
      let selected = hasEnvironmentToken ? profile.accessTokenEnvironmentVariable : (input?.tokenStorePath ?? profile.tokenStorePath ?? "MISSING")
      throw GatewayError(
        code: error.code, message: "\(error.message) (tokenSource=\(source); selected=\(selected))",
        requestID: error.requestID, httpStatus: error.httpStatus, capabilityID: error.capabilityID,
        requiredTier: error.requiredTier, outcomeUnknown: error.outcomeUnknown, retryAfterSeconds: error.retryAfterSeconds,
        recoveryGuidance: "\(error.recoveryGuidance ?? "Run auth login for this profile.") Unset \(profile.accessTokenEnvironmentVariable) to select the configured token store."
      )
    }
  }

  private func selectedAccessToken(profile: CredentialProfile, environment: [String: String]) throws -> String {
    let input = try AnalyticsCredentialInput(profile: profile, environment: environment)
    let profile = try analyticsProfilePaths(profile, environment: environment)
    if let token = input.accessToken {
      // The same shape rule the token store enforces: an interior control
      // byte would corrupt the Authorization header it is destined for.
      guard OAuthToken.isCredential(token) else {
        throw GatewayError(
          code: .authenticationFailed,
          message: "Environment access token contains unsupported characters",
          recoveryGuidance: "Check the value of \(profile.accessTokenEnvironmentVariable)"
        )
      }
      return token
    }
    if let json = input.tokenStoreJSON {
      let token = try OAuthTokenStore().decode(Data(json.utf8), profile: profile)
      guard !token.isNearExpiry(now: now()) else {
        throw GatewayError(code: .authenticationFailed, message: "Inline token JSON is expired; supply replacement credentials")
      }
      return token.accessToken
    }
    guard let storePath = profile.tokenStorePath else {
      throw GatewayError(
        code: .authenticationFailed,
        message: "No environment access token or configured OAuth token store is available",
        recoveryGuidance: "Set \(profile.accessTokenEnvironmentVariable) or configure tokenStorePath and run auth login"
      )
    }
    // Refresh rotates the stored grant, so read, refresh, and write happen
    // under one lock keyed by the store path: two concurrent resolutions must
    // not both spend the same refresh token.
    let lock = TokenStoreRefreshLock.lock(for: storePath)
    lock.lock()
    defer { lock.unlock() }
    let token = try tokenStore.read(path: storePath, profile: profile)
    guard !token.isNearExpiry(now: now()) else {
      guard profile.oauthClientJSON != nil || profile.oauthClientJSONPath != nil, let refresher else {
        throw GatewayError(
          code: .authenticationFailed,
          message: "OAuth token requires refresh",
          recoveryGuidance: "Run auth login for this profile"
        )
      }
      let refreshed: OAuthToken
      if let json = profile.oauthClientJSON {
        refreshed = try refresher.refresh(client: OAuthClient().loadClient(json: json), token: token, requiredScopes: profile.oauthScopes)
      } else if let path = profile.oauthClientJSONPath {
        refreshed = try refresher.refresh(clientPath: path, token: token, requiredScopes: profile.oauthScopes)
      } else {
        throw GatewayError(code: .authenticationFailed, message: "OAuth application client is missing")
      }
      try tokenStore.write(refreshed, path: storePath, profile: profile)
      return refreshed.accessToken
    }
    return token.accessToken
  }

  /// Reports credential readiness without ever returning a token value.
  public func status(profile: CredentialProfile, environment: [String: String]) -> AuthStatus {
    guard let input = try? AnalyticsCredentialInput(profile: profile, environment: environment),
          let profile = try? analyticsProfilePaths(profile, environment: environment) else {
      return AuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false,
                        state: "invalid", expiresAt: nil, hasRefreshToken: false)
    }
    let environmentTokenAvailable = input.accessToken != nil
    if let json = input.tokenStoreJSON {
      let token = try? OAuthTokenStore().decode(Data(json.utf8), profile: profile)
      let state = token.map { $0.expiry <= now() ? "expired" : ($0.isNearExpiry(now: now()) ? "near-expiry" : "ready") } ?? "invalid"
      return AuthStatus(profile: profile, environmentTokenAvailable: false, tokenStoreExists: false,
                        state: state, expiresAt: token?.expiry, hasRefreshToken: token?.refreshToken != nil,
                        source: "ENVIRONMENT_JSON")
    }
    if environmentTokenAvailable {
      let token = input.accessToken ?? ""
      return AuthStatus(
        profile: profile, environmentTokenAvailable: true,
        tokenStoreExists: profile.tokenStorePath.map { SecureLocalFiles.pathEntryExists(path: $0) } ?? false,
        state: OAuthToken.isCredential(token) ? "ready" : "invalid", expiresAt: nil, hasRefreshToken: false
      )
    }
    guard let path = profile.tokenStorePath else {
      return AuthStatus(
        profile: profile,
        environmentTokenAvailable: environmentTokenAvailable,
        tokenStoreExists: false,
        state: environmentTokenAvailable ? "ready" : "missing",
        expiresAt: nil,
        hasRefreshToken: false
      )
    }
    guard SecureLocalFiles.pathEntryExists(path: path) else {
      return AuthStatus(
        profile: profile,
        environmentTokenAvailable: environmentTokenAvailable,
        tokenStoreExists: false,
        state: "missing",
        expiresAt: nil,
        hasRefreshToken: false
      )
    }
    guard let token = try? tokenStore.read(path: path, profile: profile) else {
      return AuthStatus(
        profile: profile,
        environmentTokenAvailable: environmentTokenAvailable,
        tokenStoreExists: true,
        state: "invalid",
        expiresAt: nil,
        hasRefreshToken: false
      )
    }
    let current = now()
    let state: String
    if token.expiry <= current {
      state = "expired"
    } else if token.isNearExpiry(now: current) {
      state = "near-expiry"
    } else {
      state = "ready"
    }
    return AuthStatus(
      profile: profile,
      environmentTokenAvailable: environmentTokenAvailable,
      tokenStoreExists: true,
      state: state,
      expiresAt: token.expiry,
      hasRefreshToken: token.refreshToken != nil
    )
  }

  /// Deletes the profile's token store, returning false when there was none.
  public func logout(profile: CredentialProfile) throws -> Bool {
    guard let path = profile.tokenStorePath else { return false }
    return try tokenStore.delete(path: path, profile: profile)
  }
}

/// One lock per token-store path, shared process-wide.
private enum TokenStoreRefreshLock {
  private static let registryLock = NSLock()
  nonisolated(unsafe) private static var locks: [String: NSLock] = [:]

  static func lock(for path: String) -> NSLock {
    registryLock.lock()
    defer { registryLock.unlock() }
    if let lock = locks[path] { return lock }
    let lock = NSLock()
    locks[path] = lock
    return lock
  }
}

/// Credential state for `auth status` and `doctor`.
///
/// Presence flags and an expiry instant only; no field of this type can carry a
/// token value.
public struct AuthStatus: Encodable, Equatable, Sendable {
  public let product: GatewayProduct
  public let capability: CapabilityTier
  public let oauthScopes: [String]
  public let profileId: String
  public let environmentTokenAvailable: Bool
  public let tokenStoreConfigured: Bool
  public let tokenStoreExists: Bool
  public let state: String
  public let expiresAt: Date?
  public let hasRefreshToken: Bool
  public let tokenSource: String
  public let tokenEnvironmentVariable: String?
  public let tokenStorePath: String?

  /// Public so external `AuthManaging` conformances (library callers and test
  /// doubles) can construct the value their `status` implementation returns.
  public init(
    profile: CredentialProfile,
    environmentTokenAvailable: Bool,
    tokenStoreExists: Bool,
    state: String,
    expiresAt: Date?,
    hasRefreshToken: Bool,
    source: String? = nil
  ) {
    product = profile.product
    capability = profile.capability
    oauthScopes = profile.oauthScopes
    profileId = profile.id
    self.environmentTokenAvailable = environmentTokenAvailable
    tokenStoreConfigured = profile.tokenStorePath != nil
    self.tokenStoreExists = tokenStoreExists
    self.state = state
    self.expiresAt = expiresAt
    self.hasRefreshToken = hasRefreshToken
    tokenSource = source ?? (environmentTokenAvailable ? "ENVIRONMENT_TOKEN" : "FILE")
    tokenEnvironmentVariable = environmentTokenAvailable ? profile.accessTokenEnvironmentVariable : nil
    tokenStorePath = environmentTokenAvailable || source == "ENVIRONMENT_JSON" ? nil : profile.tokenStorePath
  }
}
