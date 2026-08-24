import Foundation

/// Bridges a selected credential profile to the executor's credential seam.
///
/// Granted scopes are reported as the profile's validated scope bundle when the
/// token came from the profile's token store (login verified store scopes equal
/// the bundle), and as empty when the token was injected through the profile's
/// environment variable — an injected token carries no inspectable scope
/// metadata, so Google stays authoritative rather than the planner guessing.
public struct ProfileCredentialProvider: CredentialProvider {
  private let profile: CredentialProfile
  private let environment: [String: String]
  private let resolver: any CredentialResolving

  public init(
    profile: CredentialProfile,
    environment: [String: String],
    resolver: any CredentialResolving = CredentialResolver(refresher: OAuthClient())
  ) {
    self.profile = profile
    self.environment = environment
    self.resolver = resolver
  }

  public func credential() async throws -> ResolvedCredential {
    let token = try resolver.accessToken(profile: profile, environment: environment)
    let injected = !(environment[profile.accessTokenEnvironmentVariable] ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    return ResolvedCredential(
      token: SecretValue(token),
      grantedScopes: injected ? [] : profile.oauthScopes
    )
  }

  /// The resolver already refreshes near-expiry store tokens under its lock, so
  /// a 401 on a token it just returned means the grant was revoked or the store
  /// is stale in a way a second refresh cannot repair; re-resolving would loop.
  /// Environment-injected tokens have no refresh state at all.
  public func refreshedCredential(after stale: ResolvedCredential) async throws -> ResolvedCredential? {
    nil
  }
}
