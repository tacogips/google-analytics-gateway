import Foundation

/// The credential selected for a single process, resolved once.
///
/// It carries no base URL. Wrike reports a per-account data-center host, so its
/// credential had to name the origin every request resolved against. Google
/// splits the same product across fixed service hosts, so the origin comes from
/// the capability's `GoogleAPIService` instead: one credential can address the
/// Admin, Data, and Tag Manager APIs without any of them being reachable by a
/// request that did not declare it.
public struct ResolvedCredential: Sendable {
  /// The OAuth access token, held as a `SecretValue` so that logging,
  /// mirroring, or interpolating this record cannot disclose it. It is revealed
  /// only where the transport formats the `Authorization` header.
  public let token: SecretValue
  /// The scopes the authorization actually granted.
  ///
  /// An empty list means the credential exposes no inspectable scope metadata;
  /// the planner then lets Google stay authoritative rather than refusing a
  /// request it cannot prove is under-scoped.
  public let grantedScopes: [String]

  public init(token: SecretValue, grantedScopes: [String]) {
    self.token = token
    self.grantedScopes = grantedScopes
  }
}

/// The injectable credential boundary.
///
/// The executor depends on this protocol rather than on a credential store, an
/// environment reader, or a global, so a test can supply a fixed credential and
/// the profile-backed resolver stays an authentication concern.
public protocol CredentialProvider: Sendable {
  func credential() async throws -> ResolvedCredential
  /// Refreshes after an upstream 401, returning `nil` when no refresh state
  /// exists. Only one refresh is attempted per request.
  func refreshedCredential(after stale: ResolvedCredential) async throws -> ResolvedCredential?
}
