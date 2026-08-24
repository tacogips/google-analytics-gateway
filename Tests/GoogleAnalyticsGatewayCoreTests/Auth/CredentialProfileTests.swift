import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// Profile loading is a security boundary: it decides which scope bundle a
/// binary may request and which local files it may read. A misspelled key must
/// fail loudly rather than be ignored, and a scope set must match its tier
/// exactly rather than merely be contained by it.
@Suite("Credential profiles")
struct CredentialProfileTests {
  static func decode(_ json: String) throws -> CredentialProfileConfiguration {
    try CredentialProfileConfiguration.decode(Data(json.utf8))
  }

  @Test("A well-formed document decodes into its profiles")
  func decodesValidConfiguration() throws {
    let configuration = try Self.decode(SampleProfiles.configurationJSON([
      SampleProfiles.profile(id: "analytics-reader", product: .analytics, capability: .reader),
      SampleProfiles.profile(id: "combined-admin", product: .combined, capability: .admin)
    ]))

    #expect(configuration.profiles.map(\.id) == ["analytics-reader", "combined-admin"])
    #expect(try configuration.profile(id: "combined-admin").capability == .admin)
  }

  @Test("An unknown field in a profile is rejected rather than ignored")
  func rejectsUnknownProfileField() throws {
    let json = """
      { "profiles": [ {
        "id": "analytics-reader",
        "product": "analytics",
        "capability": "reader",
        "oauthScopes": ["https://www.googleapis.com/auth/analytics.readonly"],
        "accessTokenEnvironmentVariable": "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN",
        "allowInsecureTransport": true
      } ] }
      """

    do {
      _ = try Self.decode(json)
      Issue.record("Expected an unsupported profile field to be rejected")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
    }
  }

  @Test("An unknown top-level field is rejected rather than ignored")
  func rejectsUnknownTopLevelField() throws {
    let json = """
      { "profiles": [], "defaultProfile": "analytics-reader" }
      """
    #expect(throws: GatewayError.self) { try Self.decode(json) }
  }

  @Test("A document with no profiles is rejected")
  func rejectsEmptyConfiguration() throws {
    #expect(throws: GatewayError.self) { try Self.decode("{ \"profiles\": [] }") }
  }

  @Test("Malformed JSON is a validation error, not a crash")
  func rejectsMalformedJSON() throws {
    #expect(throws: GatewayError.self) { try Self.decode("{ \"profiles\": ") }
  }

  static let productTierPairs: [(GatewayProduct, CapabilityTier)] = GatewayProduct.allCases.flatMap { product in
    CapabilityTier.allCases.map { (product, $0) }
  }

  @Test("Each product and tier accepts exactly its documented scope bundle", arguments: productTierPairs)
  func acceptsExactScopeBundle(product: GatewayProduct, capability: CapabilityTier) throws {
    let bundle = product.oauthScopes(for: capability)
    #expect(!bundle.isEmpty)
    #expect(Set(bundle).count == bundle.count, "The bundle repeats a scope")

    let configuration = try Self.decode(SampleProfiles.configurationJSON([
      SampleProfiles.profile(id: "fixture-profile", product: product, capability: capability)
    ]))
    #expect(configuration.profiles.first?.oauthScopes == bundle)
  }

  @Test("A scope bundle with one extra scope is rejected", arguments: productTierPairs)
  func rejectsWidenedScopeBundle(product: GatewayProduct, capability: CapabilityTier) throws {
    let widened = product.oauthScopes(for: capability) + [GoogleOAuthScope.tagManagerManageUsers]
    guard Set(widened).count == widened.count else { return }

    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "fixture-profile", product: product, capability: capability, scopes: widened
        )
      ]))
    }
  }

  @Test("A scope bundle missing one scope is rejected", arguments: productTierPairs)
  func rejectsNarrowedScopeBundle(product: GatewayProduct, capability: CapabilityTier) throws {
    let narrowed = product.oauthScopes(for: capability).dropLast()
    guard !narrowed.isEmpty else { return }

    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "fixture-profile", product: product, capability: capability, scopes: Array(narrowed)
        )
      ]))
    }
  }

  @Test("A reader profile may not carry the writer bundle")
  func rejectsMismatchedTierBundle() throws {
    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "analytics-reader",
          product: .analytics,
          capability: .reader,
          scopes: GatewayProduct.analytics.oauthScopes(for: .writer)
        )
      ]))
    }
  }

  @Test("Admin bundles include every scope the tiers below them need")
  func adminBundlesAreCumulative() throws {
    for product in GatewayProduct.allCases {
      let admin = Set(product.oauthScopes(for: .admin))
      #expect(admin.isSuperset(of: Set(product.oauthScopes(for: .reader))), "\(product) admin ⊉ reader")
      #expect(admin.isSuperset(of: Set(product.oauthScopes(for: .writer))), "\(product) admin ⊉ writer")
    }
    // The combined product is the union of the two single-product bundles.
    for tier in CapabilityTier.allCases {
      let combined = Set(GatewayProduct.combined.oauthScopes(for: tier))
      let union = Set(GatewayProduct.analytics.oauthScopes(for: tier))
        .union(GatewayProduct.tagManager.oauthScopes(for: tier))
      #expect(combined == union, "combined \(tier) bundle is not the union")
    }
  }

  @Test("A repeated scope is rejected even when the set matches")
  func rejectsRepeatedScope() throws {
    let scopes = GatewayProduct.analytics.oauthScopes(for: .reader)
    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "analytics-reader", product: .analytics, capability: .reader, scopes: scopes + scopes
        )
      ]))
    }
  }

  @Test("A duplicated profile id is rejected")
  func rejectsDuplicateProfileID() throws {
    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics),
        SampleProfiles.profile(id: "analytics-reader", product: .analytics)
      ]))
    }
  }

  static let unsafeEnvironmentVariableNames = [
    "lowercase_name",
    "1LEADING_DIGIT",
    "HAS-DASH",
    "HAS SPACE",
    ""
  ]

  @Test(
    "An environment-variable name outside the POSIX shape is rejected",
    arguments: unsafeEnvironmentVariableNames
  )
  func rejectsUnsafeEnvironmentVariableName(name: String) throws {
    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics, environmentVariable: name)
      ]))
    }
  }

  @Test("An OAuth client path without a token-store path is rejected")
  func rejectsHalfConfiguredOAuthPaths() throws {
    #expect(throws: GatewayError.self) {
      try Self.decode(SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "analytics-reader", product: .analytics, oauthClientJSONPath: "/fixtures/client.json"
        )
      ]))
    }
  }

  @Test("Relative paths resolve against the configuration directory")
  func resolvesRelativePaths() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "analytics-reader",
          product: .analytics,
          oauthClientJSONPath: "oauth-client.json",
          tokenStorePath: "token-store.json"
        )
      ]),
      to: "config.json"
    )

    let configuration = try CredentialProfileConfiguration.load(path: configPath)
    let profile = try configuration.profile(id: "analytics-reader")

    // The contract is "relative to the configuration document", so the
    // expectation is built from the standardized configuration directory. It is
    // not the same string as the raw fixture path: Foundation standardizes an
    // existing `/private/var` path back to `/var`.
    let configDirectory = URL(fileURLWithPath: configPath).standardizedFileURL
      .deletingLastPathComponent()
    #expect(profile.oauthClientJSONPath == configDirectory.appendingPathComponent("oauth-client.json").path)
    #expect(profile.tokenStorePath == configDirectory.appendingPathComponent("token-store.json").path)
  }

  @Test("Two profiles may not share a token store")
  func rejectsCollidingTokenStores() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "analytics-reader",
          product: .analytics,
          capability: .reader,
          oauthClientJSONPath: "client-one.json",
          tokenStorePath: "shared-store.json"
        ),
        SampleProfiles.profile(
          id: "analytics-writer",
          product: .analytics,
          capability: .writer,
          oauthClientJSONPath: "client-two.json",
          tokenStorePath: "shared-store.json"
        )
      ]),
      to: "config.json"
    )

    #expect(throws: GatewayError.self) {
      try CredentialProfileConfiguration.load(path: configPath)
    }
  }

  @Test("A token store may not alias the configuration document")
  func rejectsTokenStoreAliasingConfig() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(
          id: "analytics-reader",
          product: .analytics,
          oauthClientJSONPath: "client.json",
          tokenStorePath: "config.json"
        )
      ]),
      to: "config.json"
    )

    #expect(throws: GatewayError.self) {
      try CredentialProfileConfiguration.load(path: configPath)
    }
  }
}
