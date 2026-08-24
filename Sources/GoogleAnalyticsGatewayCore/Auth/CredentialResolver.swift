import Foundation

public protocol CredentialResolving: Sendable {
  func accessToken(profile: CredentialProfile, environment: [String: String]) throws -> String
}

public protocol OAuthTokenRefreshing: Sendable {
  func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken
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
    if let token = environment[profile.accessTokenEnvironmentVariable]?
      .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
      return token
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
      guard let clientPath = profile.oauthClientJSONPath, let refresher else {
        throw GatewayError(
          code: .authenticationFailed,
          message: "OAuth token requires refresh",
          recoveryGuidance: "Run auth login for this profile"
        )
      }
      let refreshed = try refresher.refresh(
        clientPath: clientPath,
        token: token,
        requiredScopes: profile.oauthScopes
      )
      try tokenStore.write(refreshed, path: storePath, profile: profile)
      return refreshed.accessToken
    }
    return token.accessToken
  }

  /// Reports credential readiness without ever returning a token value.
  public func status(profile: CredentialProfile, environment: [String: String]) -> AuthStatus {
    let environmentTokenAvailable = !(environment[profile.accessTokenEnvironmentVariable] ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

  init(
    profile: CredentialProfile,
    environmentTokenAvailable: Bool,
    tokenStoreExists: Bool,
    state: String,
    expiresAt: Date?,
    hasRefreshToken: Bool
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
  }
}
