import Foundation
import GoogleAnalyticsGatewayCore

/// The only token spelling any test fixture uses. It is not a credential and
/// never reaches a network.
public let fixtureAccessToken = "fixture-token-not-a-secret"

/// A deterministic clock. Sleeps advance the clock instead of waiting, so retry
/// and expiry tests are exact and fast.
public final class TestClock: GatewayClock, @unchecked Sendable {
  private let lock = NSLock()
  private var current: Date
  private var sleeps: [Double] = []

  public init(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
    self.current = now
  }

  public var now: Date {
    lock.lock()
    defer { lock.unlock() }
    return current
  }

  public func sleep(seconds: Double) async throws {
    record(sleep: seconds)
  }

  private func record(sleep seconds: Double) {
    lock.lock()
    sleeps.append(seconds)
    current = current.addingTimeInterval(seconds)
    lock.unlock()
  }

  public func advance(by seconds: Double) {
    lock.lock()
    current = current.addingTimeInterval(seconds)
    lock.unlock()
  }

  public var recordedSleeps: [Double] {
    lock.lock()
    defer { lock.unlock() }
    return sleeps
  }
}

/// A fixed credential that counts how often it was asked for one.
///
/// The counts are what let a validation test prove a rejection happened before
/// any credential was resolved, not merely before a request was sent.
public final class RecordingCredentialProvider: CredentialProvider, @unchecked Sendable {
  private let lock = NSLock()
  private let fixed: ResolvedCredential
  private let refreshed: ResolvedCredential?
  private var resolutions = 0
  private var refreshes = 0

  public init(
    token: String = fixtureAccessToken,
    grantedScopes: [String] = [],
    refreshed: ResolvedCredential? = nil
  ) {
    self.fixed = ResolvedCredential(token: SecretValue(token), grantedScopes: grantedScopes)
    self.refreshed = refreshed
  }

  /// A distinct credential a 401 may be retried with.
  public static func refreshable() -> RecordingCredentialProvider {
    RecordingCredentialProvider(
      refreshed: ResolvedCredential(
        token: SecretValue("fixture-token-not-a-secret-refreshed"),
        grantedScopes: []
      )
    )
  }

  public func credential() async throws -> ResolvedCredential {
    recordResolution()
    return fixed
  }

  public func refreshedCredential(after stale: ResolvedCredential) async throws -> ResolvedCredential? {
    recordRefresh()
    return refreshed
  }

  private func recordResolution() {
    lock.lock()
    resolutions += 1
    lock.unlock()
  }

  private func recordRefresh() {
    lock.lock()
    refreshes += 1
    lock.unlock()
  }

  public var resolutionCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return resolutions
  }

  public var refreshCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return refreshes
  }
}

/// A credential provider that always fails.
///
/// Used to prove that a local validation failure is reported as itself rather
/// than as the authentication failure a later stage would have produced.
public struct FailingCredentialProvider: CredentialProvider {
  public init() {}

  public func credential() async throws -> ResolvedCredential {
    throw GatewayError.authentication("No credential is configured for this fixture.")
  }

  public func refreshedCredential(after stale: ResolvedCredential) async throws -> ResolvedCredential? {
    nil
  }
}

/// An in-memory `OAuthTokenStoring` that records its reads, so a test can prove
/// that an environment-injected token never opened a store.
public final class RecordingTokenStore: OAuthTokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var stored: [String: OAuthToken]
  private var reads = 0
  private var writes = 0

  public init(stored: [String: OAuthToken] = [:]) {
    self.stored = stored
  }

  public func read(path: String, profile: CredentialProfile) throws -> OAuthToken {
    lock.lock()
    reads += 1
    let token = stored[path]
    lock.unlock()
    guard let token else {
      throw GatewayError(code: .validationError, message: "OAuth token store is invalid")
    }
    guard token.profileId == profile.id, token.product == profile.product,
      Set(token.scopes) == Set(profile.oauthScopes) else {
      throw GatewayError(code: .validationError, message: "OAuth token store does not match selected profile")
    }
    return token
  }

  public func write(_ token: OAuthToken, path: String, profile: CredentialProfile) throws {
    lock.lock()
    writes += 1
    stored[path] = token
    lock.unlock()
  }

  public func delete(path: String, profile: CredentialProfile) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return stored.removeValue(forKey: path) != nil
  }

  public var readCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return reads
  }

  public var writeCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return writes
  }
}

/// Returns a canned refreshed grant without contacting Google.
public struct StubTokenRefresher: OAuthTokenRefreshing {
  private let token: OAuthToken

  public init(token: OAuthToken) {
    self.token = token
  }

  public func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken {
    self.token
  }
}

/// A fixed `AuthManaging` for command-frame tests, so `auth` and `doctor` can be
/// exercised without a browser, a loopback socket, or a token file.
public struct StubAuthManager: AuthManaging {
  /// Status is answered by the production resolver over an in-memory store, so
  /// the reported shape is the one an operator actually sees.
  private let resolver: CredentialResolver
  private let loginError: GatewayError?

  public init(
    resolver: CredentialResolver = CredentialResolver(tokenStore: RecordingTokenStore()),
    loginError: GatewayError? = nil
  ) {
    self.resolver = resolver
    self.loginError = loginError
  }

  public func status(profile: CredentialProfile, environment: [String: String]) -> AuthStatus {
    resolver.status(profile: profile, environment: environment)
  }

  public func logout(profile: CredentialProfile) throws -> Bool { false }

  public func login(
    profile: CredentialProfile,
    noBrowser: Bool,
    redirectURI: String?,
    timeoutSeconds: Int32
  ) throws -> AuthLoginOutput {
    if let loginError { throw loginError }
    return AuthLoginOutput(profileId: profile.id, state: "ready", authorizationURL: nil)
  }
}
