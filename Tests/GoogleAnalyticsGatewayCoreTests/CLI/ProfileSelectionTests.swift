import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// Profile resolution decides which credential a command runs with, so it is
/// also where a binary could accidentally be handed authority above its tier.
/// Every widening path is asserted closed here, before any credential or
/// network activity.
@Suite("Profile selection")
struct ProfileSelectionTests {
  @Test("With no configuration the binary synthesizes its own tier's profile")
  func synthesizesFallbackProfile() throws {
    for tier in CapabilityTier.allCases {
      let resolution = try ProfileSelector.resolve(
        selection: CredentialSelection(configPath: nil, profileID: nil),
        tier: tier,
        environment: [:]
      )

      #expect(resolution.isSynthesized)
      #expect(resolution.configPath == nil)
      #expect(resolution.profile.id == ProfileSelector.fallbackProfileID)
      #expect(resolution.profile.product == .combined)
      #expect(resolution.profile.capability == tier)
      #expect(resolution.profile.oauthScopes == GatewayProduct.combined.oauthScopes(for: tier))
      #expect(resolution.profile.accessTokenEnvironmentVariable
        == ProfileSelector.fallbackAccessTokenVariable)
      #expect(resolution.profile.oauthClientJSONPath == nil)
      #expect(resolution.profile.tokenStorePath == nil)
    }
  }

  @Test("--profile without a configuration document is refused")
  func refusesProfileWithoutConfiguration() throws {
    do {
      _ = try ProfileSelector.resolve(
        selection: CredentialSelection(configPath: nil, profileID: "analytics-reader"),
        tier: .reader,
        environment: [:]
      )
      Issue.record("Expected --profile without a config to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.recoveryGuidance?.contains(CredentialProfileConfiguration.pathEnvironmentVariable) == true)
    }
  }

  @Test("A profile above the binary's tier is denied with the tier it requires")
  func refusesProfileAboveTier() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-admin", capability: .admin)
      ]),
      to: "config.json"
    )

    do {
      _ = try ProfileSelector.resolve(
        selection: CredentialSelection(configPath: configPath, profileID: "analytics-admin"),
        tier: .reader,
        environment: [:]
      )
      Issue.record("Expected an admin profile to be denied in a reader binary")
    } catch let error as GatewayError {
      #expect(error.code == .capabilityDenied)
      #expect(error.requiredTier == .admin)
      #expect(error.exitCode == .usage)
    }
  }

  @Test("An ambiguous configuration is refused rather than resolved arbitrarily")
  func refusesAmbiguousConfiguration() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics),
        SampleProfiles.profile(id: "tag-manager-reader", product: .tagManager)
      ]),
      to: "config.json"
    )

    do {
      _ = try ProfileSelector.resolve(
        selection: CredentialSelection(configPath: configPath, profileID: nil),
        tier: .reader,
        environment: [:]
      )
      Issue.record("Expected an ambiguous configuration to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.recoveryGuidance?.contains("analytics-reader") == true)
      #expect(error.recoveryGuidance?.contains("tag-manager-reader") == true)
    }
  }

  @Test("A single eligible profile resolves without being named")
  func resolvesTheOnlyEligibleProfile() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics)
      ]),
      to: "config.json"
    )

    let resolution = try ProfileSelector.resolve(
      selection: CredentialSelection(configPath: configPath, profileID: nil),
      tier: .reader,
      environment: [:]
    )

    #expect(!resolution.isSynthesized)
    #expect(resolution.profile.id == "analytics-reader")
    #expect(resolution.configPath == configPath)
  }

  @Test("The exact-tier profile wins when a lower-tier one is also eligible")
  func prefersTheExactTierProfile() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics, capability: .reader),
        SampleProfiles.profile(id: "analytics-writer", product: .analytics, capability: .writer)
      ]),
      to: "config.json"
    )

    let resolution = try ProfileSelector.resolve(
      selection: CredentialSelection(configPath: configPath, profileID: nil),
      tier: .writer,
      environment: [:]
    )

    #expect(resolution.profile.id == "analytics-writer")
  }

  @Test("The config path environment variable is the fallback for --config")
  func readsConfigPathFromEnvironment() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics)
      ]),
      to: "config.json"
    )

    let resolution = try ProfileSelector.resolve(
      selection: CredentialSelection(configPath: nil, profileID: nil),
      tier: .reader,
      environment: [CredentialProfileConfiguration.pathEnvironmentVariable: configPath]
    )

    #expect(resolution.profile.id == "analytics-reader")
    #expect(resolution.configPath == configPath)
  }

  @Test("An unknown profile id names the ids the document does define")
  func refusesUnknownProfileID() throws {
    let directory = try TemporaryDirectory()
    defer { directory.keepAlive() }
    let configPath = try directory.write(
      SampleProfiles.configurationJSON([
        SampleProfiles.profile(id: "analytics-reader", product: .analytics)
      ]),
      to: "config.json"
    )

    do {
      _ = try ProfileSelector.resolve(
        selection: CredentialSelection(configPath: configPath, profileID: "absent-profile"),
        tier: .reader,
        environment: [:]
      )
      Issue.record("Expected an unknown profile id to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.recoveryGuidance?.contains("analytics-reader") == true)
    }
  }
}
