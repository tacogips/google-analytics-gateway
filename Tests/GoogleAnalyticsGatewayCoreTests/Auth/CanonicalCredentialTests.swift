import Foundation
import GoogleAnalyticsGatewayTestSupport
import Testing
@testable import GoogleAnalyticsGatewayCore

@Test func analyticsCanonicalTokenAndLegacyAliasWorkWithoutClient() async throws {
  let profile = canonicalAnalyticsProfile()
  let resolver = CredentialResolver()
  #expect(try resolver.accessToken(profile: profile, environment: ["GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN": "external-token"]) == "external-token")
  #expect(try resolver.accessToken(profile: profile, environment: ["LEGACY_TOKEN": "legacy-token"]) == "legacy-token")
  let provider = ProfileCredentialProvider(profile: profile, environment: ["GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN": "external-token"])
  #expect(try await provider.credential().grantedScopes.isEmpty)
  #expect(resolver.status(profile: profile, environment: ["GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN": "external-token"]).state == "ready")
}

@Test func synthesizedAnalyticsProfileAcceptsProfileTokenOverride() throws {
  let resolution = try ProfileSelector.resolve(selection: .init(configPath: nil, profileID: nil), tier: .reader, environment: [:])
  #expect(try CredentialResolver().accessToken(profile: resolution.profile, environment: [
    "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN": "default-token",
    "GOOGLE_ANALYTICS_GATEWAY_CREDENTIAL_DEFAULT_ENV_ACCESS_TOKEN": "selected-token"
  ]) == "selected-token")
}

@Test func analyticsInlineTokenStoreRetainsScopeAndProfileBinding() throws {
  let profile = canonicalAnalyticsProfile()
  let token = try OAuthToken(profile: profile, accessToken: "json-token", refreshToken: nil,
                             tokenType: "Bearer", expiry: Date().addingTimeInterval(3600), scopes: profile.oauthScopes)
  let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
  let json = try #require(String(data: encoder.encode(token), encoding: .utf8))
  let env = ["GOOGLE_ANALYTICS_GATEWAY_TOKEN_STORE_JSON": json]
  #expect(try CredentialResolver().accessToken(profile: profile, environment: env) == "json-token")
  #expect(CredentialResolver().status(profile: profile, environment: env).tokenSource == "ENVIRONMENT_JSON")
  #expect(throws: GatewayError.self) {
    _ = try CredentialResolver().accessToken(profile: canonicalAnalyticsProfile(id: "other"), environment: env)
  }
}

@Test func analyticsTokenPathNeedsNoApplication() throws {
  let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("token.json").path
  let profile = canonicalAnalyticsProfile()
  let token = try OAuthToken(profile: profile, accessToken: "file-token", refreshToken: nil,
                             tokenType: "Bearer", expiry: Date().addingTimeInterval(3600), scopes: profile.oauthScopes)
  try OAuthTokenStore().write(token, path: path, profile: profile)
  let env = ["GOOGLE_ANALYTICS_GATEWAY_TOKEN_STORE_PATH": path]
  #expect(try CredentialResolver().accessToken(profile: profile, environment: env) == "file-token")
  #expect(CredentialResolver().status(profile: profile, environment: env).tokenStorePath == path)
}

@Test func analyticsCanonicalConflictsAreRejectedWithoutSecrets() throws {
  do {
    _ = try CredentialResolver().accessToken(profile: canonicalAnalyticsProfile(), environment: [
      "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN": "canonical-secret", "LEGACY_TOKEN": "legacy-secret"
    ])
    Issue.record("Expected conflicting aliases to fail")
  } catch let error as GatewayError {
    #expect(error.code == .validationError)
    #expect(!error.message.contains("canonical-secret"))
    #expect(!error.message.contains("legacy-secret"))
  }
  #expect(throws: GatewayError.self) {
    _ = try AnalyticsCredentialInput(profile: canonicalAnalyticsProfile(), environment: [
      "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN": "token", "GOOGLE_ANALYTICS_GATEWAY_TOKEN_STORE_PATH": "/tmp/token.json"
    ])
  }
  #expect(throws: GatewayError.self) {
    _ = try CredentialProfileConfiguration(profiles: [canonicalAnalyticsProfile(id: "work-mail"), canonicalAnalyticsProfile(id: "work_mail")])
  }
}

private func canonicalAnalyticsProfile(id: String = "analytics") -> CredentialProfile {
  CredentialProfile(id: id, product: .analytics, capability: .reader,
                    oauthScopes: GatewayProduct.analytics.oauthScopes(for: .reader), accessTokenEnvironmentVariable: "LEGACY_TOKEN")
}

@Test func analyticsProfileSourcesReplaceProductDefaultsAcrossInputTypes() throws {
  let profile = canonicalAnalyticsProfile()
  let environment = [
    "GOOGLE_ANALYTICS_GATEWAY_TOKEN_STORE_PATH": "/unused/default-token.json",
    "GOOGLE_ANALYTICS_GATEWAY_CREDENTIAL_ANALYTICS_ACCESS_TOKEN": "selected-token",
    "GOOGLE_ANALYTICS_GATEWAY_OAUTH_CLIENT_PATH": "/unused/default-client.json",
    "GOOGLE_ANALYTICS_GATEWAY_CREDENTIAL_ANALYTICS_OAUTH_CLIENT_JSON": "inline-application"
  ]
  let input = try AnalyticsCredentialInput(profile: profile, environment: environment)
  #expect(input.accessToken == "selected-token")
  #expect(input.tokenStorePath == nil)
  let selected = try analyticsProfilePaths(profile, environment: environment)
  #expect(selected.oauthClientJSON == "inline-application")
  #expect(selected.oauthClientJSONPath == nil)
}

@Test func analyticsSynthesizedProfileRejectsClientAndTokenPathCollision() throws {
  #expect(throws: GatewayError.self) {
    _ = try ProfileSelector.resolve(selection: .init(configPath: nil, profileID: nil), tier: .reader, environment: [
      "GOOGLE_ANALYTICS_GATEWAY_TOKEN_STORE_PATH": "/private/tmp/same-file.json",
      "GOOGLE_ANALYTICS_GATEWAY_OAUTH_CLIENT_PATH": "/private/tmp/same-file.json"
    ])
  }
}
