import Foundation

/// Resolves the credential profile a command runs with.
///
/// Resolution never widens capability: a profile above the binary's tier is
/// rejected here, before any credential or network activity, and the
/// synthesized fallback profile carries exactly the binary tier's scope
/// bundle. The synthesized profile exists so a fresh machine can run
/// `graphql schema`, `doctor`, and env-token-injected queries without a config
/// file, mirroring gmail-gateway's synthesized default configuration.
public enum ProfileSelector {
  /// The env var read by the synthesized fallback profile.
  public static let fallbackAccessTokenVariable = "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN"
  public static let fallbackProfileID = "default-env"

  public struct Resolution: Sendable, Equatable {
    public let profile: CredentialProfile
    /// True when no configuration document was involved.
    public let isSynthesized: Bool
    public let configPath: String?
  }

  public static func resolve(
    selection: CredentialSelection,
    tier: CapabilityTier,
    environment: [String: String]
  ) throws -> Resolution {
    let environmentPath = environment[CredentialProfileConfiguration.pathEnvironmentVariable]
    guard selection.configPath != nil || environmentPath != nil else {
      guard selection.profileID == nil || selection.profileID == fallbackProfileID else {
        throw GatewayError.validation(
          "Option --profile requires a configuration document.",
          recovery: "Pass --config or set \(CredentialProfileConfiguration.pathEnvironmentVariable)."
        )
      }
      return Resolution(
        profile: try analyticsProfilePaths(synthesizedProfile(tier: tier, environment: environment), environment: environment),
        isSynthesized: true,
        configPath: nil
      )
    }

    let path = try CredentialProfileConfiguration.resolvePath(
      explicit: selection.configPath,
      environment: environment
    )
    let configuration = try CredentialProfileConfiguration.load(path: path)
    let effectiveProfiles = try configuration.profiles.map { try analyticsProfilePaths($0, environment: environment) }
    try configuration.validateResolvedPaths(profiles: effectiveProfiles, configURL: URL(fileURLWithPath: path).standardizedFileURL)
    let effectiveConfiguration = try CredentialProfileConfiguration(profiles: effectiveProfiles)
    let profile = try select(from: effectiveConfiguration, id: selection.profileID, tier: tier)
    guard tier.includes(profile.capability) else {
      throw GatewayError(
        code: .capabilityDenied,
        message: "Profile \(profile.id) requires the \(profile.capability.rawValue) tier.",
        requiredTier: profile.capability,
        recoveryGuidance: "Use the \(profile.capability.rawValue) binary, or select a \(tier.rawValue) profile."
      )
    }
    return Resolution(profile: profile, isSynthesized: false, configPath: path)
  }

  private static func select(
    from configuration: CredentialProfileConfiguration,
    id: String?,
    tier: CapabilityTier
  ) throws -> CredentialProfile {
    if let id { return try configuration.profile(id: id) }
    let eligible = configuration.profiles.filter { tier.includes($0.capability) }
    if eligible.count == 1, let only = eligible.first { return only }
    let exact = eligible.filter { $0.capability == tier }
    if exact.count == 1, let only = exact.first { return only }
    throw GatewayError.validation(
      "The configuration does not name a unique profile for the \(tier.rawValue) tier.",
      recovery: "Pass --profile <id>. Available: \(configuration.profiles.map(\.id).sorted().joined(separator: ", "))."
    )
  }

  private static func synthesizedProfile(tier: CapabilityTier, environment: [String: String]) throws -> CredentialProfile {
    let root: URL
    if let state = environment["XDG_STATE_HOME"], !state.isEmpty {
      guard state.hasPrefix("/"), SecureLocalFiles.isSafePath(state) else {
        throw GatewayError.validation("XDG_STATE_HOME must be an absolute safe path")
      }
      root = URL(fileURLWithPath: state)
    } else { root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/state") }
    let path = root.appendingPathComponent("google-analytics-gateway/credentials")
      .appendingPathComponent(tier.rawValue).appendingPathComponent(fallbackProfileID + ".json").path
    return CredentialProfile(
      id: fallbackProfileID,
      product: .combined,
      capability: tier,
      oauthScopes: GatewayProduct.combined.oauthScopes(for: tier),
      accessTokenEnvironmentVariable: fallbackAccessTokenVariable,
      oauthClientJSONPath: nil,
      tokenStorePath: path
    )
  }
}
