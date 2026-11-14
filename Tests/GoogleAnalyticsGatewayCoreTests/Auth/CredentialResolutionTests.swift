import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// Credential resolution has a fixed order — environment token first, token
/// store second — because a non-interactive caller piping a token in must never
/// cause a file to be opened. The token store additionally binds a grant to the
/// profile that obtained it, so a file cannot be moved between tiers.
@Suite("Credential resolution")
struct CredentialResolutionTests {
  static let storePath = "/fixtures/token-store.json"
  static let readerProfile = SampleProfiles.profile(
    id: "analytics-reader",
    product: .analytics,
    capability: .reader,
    tokenStorePath: storePath
  )
  static let now = Date(timeIntervalSince1970: 1_800_000_000)

  static func token(
    profile: CredentialProfile = readerProfile,
    accessToken: String = fixtureAccessToken,
    refreshToken: String? = "fixture-refresh-token-not-a-secret",
    expiresIn: TimeInterval = 3_600
  ) throws -> OAuthToken {
    try OAuthToken(
      profile: profile,
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: "Bearer",
      expiry: now.addingTimeInterval(expiresIn),
      updatedAt: now,
      scopes: profile.oauthScopes
    )
  }

  static func resolver(
    store: RecordingTokenStore,
    refresher: (any OAuthTokenRefreshing)? = nil
  ) -> CredentialResolver {
    CredentialResolver(tokenStore: store, refresher: refresher, now: { now })
  }

  @Test("An environment token wins and the token store is never opened")
  func environmentTokenTakesPrecedence() throws {
    let store = RecordingTokenStore(stored: [Self.storePath: try Self.token()])
    let resolved = try Self.resolver(store: store).accessToken(
      profile: Self.readerProfile,
      environment: [Self.readerProfile.accessTokenEnvironmentVariable: "fixture-token-not-a-secret-env"]
    )

    #expect(resolved == "fixture-token-not-a-secret-env")
    #expect(store.readCount == 0)
  }

  @Test("An environment token is trimmed and an empty one falls through to the store")
  func emptyEnvironmentTokenFallsThrough() throws {
    let store = RecordingTokenStore(stored: [Self.storePath: try Self.token()])
    let resolver = Self.resolver(store: store)
    let variable = Self.readerProfile.accessTokenEnvironmentVariable

    #expect(try resolver.accessToken(
      profile: Self.readerProfile, environment: [variable: "  padded-fixture-token  "]
    ) == "padded-fixture-token")
    #expect(try resolver.accessToken(
      profile: Self.readerProfile, environment: [variable: "   "]
    ) == fixtureAccessToken)
    #expect(store.readCount == 1)
  }

  @Test("A profile with neither an environment token nor a store fails as an auth error")
  func reportsMissingCredential() throws {
    let profile = SampleProfiles.profile(id: "analytics-reader", product: .analytics)
    do {
      _ = try Self.resolver(store: RecordingTokenStore()).accessToken(profile: profile, environment: [:])
      Issue.record("Expected a missing credential to fail")
    } catch let error as GatewayError {
      #expect(error.code == .authenticationFailed)
      #expect(error.exitCode == .credential)
      #expect(error.recoveryGuidance?.contains(profile.accessTokenEnvironmentVariable) == true)
    }
  }

  @Test("A near-expiry token with no refresher is refused rather than sent")
  func refusesNearExpiryTokenWithoutRefresher() throws {
    let store = RecordingTokenStore(stored: [Self.storePath: try Self.token(expiresIn: 30)])

    do {
      _ = try Self.resolver(store: store).accessToken(profile: Self.readerProfile, environment: [:])
      Issue.record("Expected a near-expiry token to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .authenticationFailed)
      #expect(error.recoveryGuidance?.contains("auth login") == true)
    }
  }

  @Test("A near-expiry token is refreshed once and the refreshed grant is persisted")
  func refreshesNearExpiryToken() throws {
    let profile = SampleProfiles.profile(
      id: "analytics-reader",
      product: .analytics,
      capability: .reader,
      oauthClientJSONPath: "/fixtures/client.json",
      tokenStorePath: Self.storePath
    )
    let refreshed = try Self.token(
      profile: profile, accessToken: "fixture-token-not-a-secret-refreshed", expiresIn: 3_600
    )
    let store = RecordingTokenStore(stored: [
      Self.storePath: try Self.token(profile: profile, expiresIn: 30)
    ])

    let resolved = try Self.resolver(store: store, refresher: StubTokenRefresher(token: refreshed))
      .accessToken(profile: profile, environment: [:])

    #expect(resolved == "fixture-token-not-a-secret-refreshed")
    #expect(store.writeCount == 1)
  }

  @Test("Status reports presence flags only")
  func reportsStatusWithoutTokenValues() throws {
    let store = RecordingTokenStore(stored: [Self.storePath: try Self.token()])
    let resolver = Self.resolver(store: store)
    let variable = Self.readerProfile.accessTokenEnvironmentVariable

    let withEnvironment = resolver.status(
      profile: Self.readerProfile, environment: [variable: fixtureAccessToken]
    )
    #expect(withEnvironment.environmentTokenAvailable)
    #expect(withEnvironment.profileId == "analytics-reader")
    #expect(withEnvironment.oauthScopes == Self.readerProfile.oauthScopes)

    let encoded = try #require(String(data: try JSONEncoder().encode(withEnvironment), encoding: .utf8))
    #expect(!encoded.contains(fixtureAccessToken))

    // No store file exists at the fixture path, so the state is reported missing
    // rather than read from the in-memory double.
    #expect(resolver.status(profile: Self.readerProfile, environment: [:]).state == "missing")
  }

  @Test("Logout removes the stored grant and reports whether one was there")
  func logoutRemovesStoredGrant() throws {
    let store = RecordingTokenStore(stored: [Self.storePath: try Self.token()])
    let resolver = Self.resolver(store: store)

    #expect(try resolver.logout(profile: Self.readerProfile))
    #expect(try resolver.logout(profile: Self.readerProfile) == false)
    // A profile with no configured store has nothing to remove.
    #expect(try resolver.logout(
      profile: SampleProfiles.profile(id: "analytics-reader", product: .analytics)
    ) == false)
  }

  @Test("The profile credential provider reports scopes only for a store-backed token")
  func providerReportsScopesForStoreBackedTokensOnly() async throws {
    let store = RecordingTokenStore(stored: [Self.storePath: try Self.token()])
    let variable = Self.readerProfile.accessTokenEnvironmentVariable

    let injected = ProfileCredentialProvider(
      profile: Self.readerProfile,
      environment: [variable: fixtureAccessToken],
      resolver: Self.resolver(store: store)
    )
    let injectedCredential = try await injected.credential()
    #expect(injectedCredential.grantedScopes.isEmpty, "An injected token carries no scope metadata")
    #expect(injectedCredential.token.reveal() == fixtureAccessToken)

    let stored = ProfileCredentialProvider(
      profile: Self.readerProfile,
      environment: [:],
      resolver: Self.resolver(store: store)
    )
    let storedCredential = try await stored.credential()
    #expect(storedCredential.grantedScopes == Self.readerProfile.oauthScopes)

    // Re-resolving after a 401 would loop: the resolver already refreshed a
    // near-expiry token before handing this one out.
    let refreshed = try await stored.refreshedCredential(after: storedCredential)
    #expect(refreshed == nil)
  }
}

/// The on-disk half of the token store: the file it writes, the checks it makes
/// before trusting one, and the permissions it leaves behind.
@Suite("OAuth token store")
struct OAuthTokenStoreTests {
  static let now = Date(timeIntervalSince1970: 1_800_000_000)

  static func profile(
    id: String,
    product: GatewayProduct = .analytics,
    capability: CapabilityTier = .reader,
    storePath: String
  ) -> CredentialProfile {
    SampleProfiles.profile(
      id: id,
      product: product,
      capability: capability,
      oauthClientJSONPath: "\(storePath).client",
      tokenStorePath: storePath
    )
  }

  static func token(for profile: CredentialProfile) throws -> OAuthToken {
    try OAuthToken(
      profile: profile,
      accessToken: fixtureAccessToken,
      refreshToken: "fixture-refresh-token-not-a-secret",
      tokenType: "Bearer",
      expiry: now.addingTimeInterval(3_600),
      updatedAt: now,
      scopes: profile.oauthScopes
    )
  }

  @Test("A written grant reads back and the file is private to its owner")
  func writesAndReadsPrivateFile() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let path = directory.path("token-store.json")
    let profile = Self.profile(id: "analytics-reader", storePath: path)
    let store = OAuthTokenStore()

    try store.write(try Self.token(for: profile), path: path, profile: profile)
    let read = try store.read(path: path, profile: profile)

    #expect(read.accessToken == fixtureAccessToken)
    #expect(read.profileId == "analytics-reader")
    #expect(read.scopes == profile.oauthScopes)

    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.int16Value == 0o600)
  }

  @Test("A grant written for one profile is refused for another")
  func refusesGrantFromAnotherProfile() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let path = directory.path("token-store.json")
    let owner = Self.profile(id: "analytics-reader", storePath: path)
    let store = OAuthTokenStore()
    try store.write(try Self.token(for: owner), path: path, profile: owner)

    let otherID = Self.profile(id: "analytics-reader-two", storePath: path)
    #expect(throws: GatewayError.self) { try store.read(path: path, profile: otherID) }

    let otherProduct = Self.profile(id: "analytics-reader", product: .tagManager, storePath: path)
    #expect(throws: GatewayError.self) { try store.read(path: path, profile: otherProduct) }

    let otherTier = Self.profile(id: "analytics-reader", capability: .writer, storePath: path)
    #expect(throws: GatewayError.self) { try store.read(path: path, profile: otherTier) }
  }

  @Test("A grant may not be written under a profile it does not belong to")
  func refusesWritingUnderAnotherProfile() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let path = directory.path("token-store.json")
    let owner = Self.profile(id: "analytics-reader", storePath: path)
    let other = Self.profile(id: "analytics-reader-two", storePath: path)

    #expect(throws: GatewayError.self) {
      try OAuthTokenStore().write(try Self.token(for: owner), path: path, profile: other)
    }
  }

  @Test("A store document with an unsupported field is refused")
  func refusesUnsupportedStoreField() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let profile = Self.profile(id: "analytics-reader", storePath: directory.path("token-store.json"))
    let path = try directory.write("""
      {"schemaVersion":1,"profileId":"analytics-reader","product":"analytics",\
      "accessToken":"\(fixtureAccessToken)","tokenType":"Bearer",\
      "expiresAt":"2099-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z",\
      "scopes":["https://www.googleapis.com/auth/analytics.readonly"],\
      "identity":"someone@example.com"}
      """, to: "token-store.json")

    #expect(throws: GatewayError.self) {
      try OAuthTokenStore().read(path: path, profile: profile)
    }
  }

  @Test("A non-Bearer token type is refused")
  func refusesNonBearerToken() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let profile = Self.profile(id: "analytics-reader", storePath: directory.path("token-store.json"))

    #expect(throws: GatewayError.self) {
      _ = try OAuthToken(
        profile: profile,
        accessToken: fixtureAccessToken,
        refreshToken: nil,
        tokenType: "MAC",
        expiry: Self.now,
        updatedAt: Self.now,
        scopes: profile.oauthScopes
      )
    }
  }

  @Test("A grant whose scope set differs from the profile bundle is refused")
  func refusesMismatchedScopes() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let profile = Self.profile(id: "analytics-reader", storePath: directory.path("token-store.json"))

    #expect(throws: GatewayError.self) {
      _ = try OAuthToken(
        profile: profile,
        accessToken: fixtureAccessToken,
        refreshToken: nil,
        tokenType: "Bearer",
        expiry: Self.now,
        updatedAt: Self.now,
        scopes: profile.oauthScopes + [GoogleOAuthScope.analyticsEdit]
      )
    }
  }

  @Test("A world-readable store file is refused rather than trusted")
  func refusesWorldReadableStore() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let path = directory.path("token-store.json")
    let profile = Self.profile(id: "analytics-reader", storePath: path)
    try OAuthTokenStore().write(try Self.token(for: profile), path: path, profile: profile)
    try FileManager.default.setAttributes(
      [.posixPermissions: NSNumber(value: Int16(0o644))], ofItemAtPath: path
    )

    #expect(throws: GatewayError.self) { try OAuthTokenStore().read(path: path, profile: profile) }
  }

  @Test("Deleting reports whether a grant was present")
  func deleteReportsPresence() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let path = directory.path("token-store.json")
    let profile = Self.profile(id: "analytics-reader", storePath: path)
    let store = OAuthTokenStore()
    try store.write(try Self.token(for: profile), path: path, profile: profile)

    #expect(try store.delete(path: path, profile: profile))
    #expect(try store.delete(path: path, profile: profile) == false)
  }
}

/// Login is the only command that can widen a binary's authority, so it is
/// refused for a profile above the tier the binary links.
@Suite("Auth service")
struct AuthServiceTests {
  @Test("A login above the binary's tier is denied before any OAuth activity")
  func refusesLoginAboveSupportedTier() throws {
    let service = AuthService(supportedTier: .reader)
    let profile = SampleProfiles.profile(
      id: "analytics-admin",
      product: .analytics,
      capability: .admin,
      oauthClientJSONPath: "/fixtures/client.json",
      tokenStorePath: "/fixtures/token-store.json"
    )

    do {
      _ = try service.login(profile: profile, noBrowser: true, redirectURI: nil, timeoutSeconds: 5)
      Issue.record("Expected the login to be denied")
    } catch let error as GatewayError {
      #expect(error.code == .capabilityDenied)
      #expect(error.requiredTier == .admin)
      #expect(error.exitCode == .usage)
    }
  }

  @Test("A login for a profile with no OAuth client is a configuration error")
  func refusesLoginWithoutOAuthClient() throws {
    let service = AuthService(supportedTier: .admin)
    let profile = SampleProfiles.profile(id: "analytics-reader", product: .analytics)

    do {
      _ = try service.login(profile: profile, noBrowser: true, redirectURI: nil, timeoutSeconds: 5)
      Issue.record("Expected the login to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.recoveryGuidance?.contains("oauthClientJSONPath") == true)
    }
  }

  @Test("A login at or below the binary's tier passes the tier gate")
  func acceptsLoginAtSupportedTier() throws {
    let service = AuthService(supportedTier: .admin)
    let profile = SampleProfiles.profile(id: "analytics-reader", product: .analytics)

    // The tier gate passes, so the refusal that follows is about configuration
    // rather than capability. That is what proves the gate is tier-based and
    // not a blanket refusal.
    do {
      _ = try service.login(profile: profile, noBrowser: true, redirectURI: nil, timeoutSeconds: 5)
      Issue.record("Expected the unconfigured profile to be refused")
    } catch let error as GatewayError {
      #expect(error.code != .capabilityDenied)
    }
  }
}
