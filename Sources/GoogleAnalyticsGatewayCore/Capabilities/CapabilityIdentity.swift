import Foundation

/// A stable capability identifier such as `properties.get`.
///
/// The same value registers a GraphQL field, authorizes a tier, selects an SDK
/// adapter, and anchors test assertions. It never changes once published.
public struct CapabilityID: Sendable, Hashable, RawRepresentable, CustomStringConvertible, Comparable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public var description: String { rawValue }

  /// The plural resource namespace, for example `properties` in `properties.get`.
  public var namespace: String {
    String(rawValue.prefix(while: { $0 != "." }))
  }

  public static func < (lhs: CapabilityID, rhs: CapabilityID) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public enum CapabilityTier: String, Sendable, CaseIterable, Comparable, Codable {
  case reader
  case writer
  case admin

  private var rank: Int {
    switch self {
    case .reader: return 0
    case .writer: return 1
    case .admin: return 2
    }
  }

  /// Tiers are cumulative: an admin binary may execute reader capabilities.
  public func includes(_ other: CapabilityTier) -> Bool { rank >= other.rank }

  public static func < (lhs: CapabilityTier, rhs: CapabilityTier) -> Bool {
    lhs.rank < rhs.rank
  }
}

public enum OperationClass: String, Sendable, CaseIterable {
  case read
  case create
  case update
  case delete

  public var isMutation: Bool { self != .read }
}

/// Implementation state tracked per capability, mirroring the coverage states
/// in `design-docs/specs/design-capability-matrix.md#coverage-state`.
public enum CapabilityStatus: String, Sendable, CaseIterable {
  case planned
  case implemented
  case blockedByScope
  case blockedByPlan
  case unsupported

  public var isExecutable: Bool { self == .implemented }
}

/// Google OAuth scope metadata for a capability.
public struct ScopeRequirement: Sendable, Equatable {
  /// Every upstream scope Google documents as sufficient for the operation.
  ///
  /// The lists are taken from the `scopes` array each method declares in the
  /// service discovery document, so a broader bundle appears here only where
  /// Google actually accepts it. A scope that merely sounds broader, such as
  /// `tagmanager.publish` for a read, is not admitted.
  public let accepted: [String]
  /// The least-privilege scope recommended when requesting authorization.
  public let recommended: String

  public init(accepted: [String], recommended: String) {
    self.accepted = accepted
    self.recommended = recommended
  }

  /// The full scope URLs used by the Analytics and Tag Manager APIs. Scopes are
  /// always spelled out in full: Google compares the returned scope set exactly,
  /// so an abbreviated form would silently fail the post-authorization check.
  public enum Scope {
    public static let analyticsReadonly = "https://www.googleapis.com/auth/analytics.readonly"
    public static let analyticsEdit = "https://www.googleapis.com/auth/analytics.edit"
    public static let analytics = "https://www.googleapis.com/auth/analytics"
    public static let analyticsManageUsers = "https://www.googleapis.com/auth/analytics.manage.users"
    public static let analyticsManageUsersReadonly =
      "https://www.googleapis.com/auth/analytics.manage.users.readonly"
    public static let tagManagerReadonly = "https://www.googleapis.com/auth/tagmanager.readonly"
    public static let tagManagerEditContainers =
      "https://www.googleapis.com/auth/tagmanager.edit.containers"
    public static let tagManagerEditContainerVersions =
      "https://www.googleapis.com/auth/tagmanager.edit.containerversions"
    public static let tagManagerPublish = "https://www.googleapis.com/auth/tagmanager.publish"
    public static let tagManagerDeleteContainers =
      "https://www.googleapis.com/auth/tagmanager.delete.containers"
    public static let tagManagerManageAccounts =
      "https://www.googleapis.com/auth/tagmanager.manage.accounts"
    public static let tagManagerManageUsers =
      "https://www.googleapis.com/auth/tagmanager.manage.users"
  }

  /// Analytics reads. GA4 Admin read methods accept the readonly or edit scope;
  /// GA4 Data read methods accept the readonly or full analytics scope, so the
  /// union of the three is sufficient for any read this gateway performs.
  public static let analyticsReadonly = ScopeRequirement(
    accepted: [Scope.analyticsReadonly, Scope.analyticsEdit, Scope.analytics],
    recommended: Scope.analyticsReadonly
  )

  /// GA4 Admin mutations. Google documents `analytics.edit` as the only
  /// sufficient scope for them; the legacy full `analytics` scope is not listed.
  public static let analyticsEdit = ScopeRequirement(
    accepted: [Scope.analyticsEdit],
    recommended: Scope.analyticsEdit
  )

  /// The full Analytics scope, accepted by the GA4 Data API alongside the
  /// readonly scope. Capabilities that require it declare it explicitly.
  public static let analyticsFull = ScopeRequirement(
    accepted: [Scope.analytics],
    recommended: Scope.analytics
  )

  /// GA4 access-binding mutations (user management on the v1alpha surface).
  public static let analyticsManageUsers = ScopeRequirement(
    accepted: [Scope.analyticsManageUsers],
    recommended: Scope.analyticsManageUsers
  )

  /// GA4 access-binding reads, which the broader manage-users scope also covers.
  public static let analyticsManageUsersReadonly = ScopeRequirement(
    accepted: [Scope.analyticsManageUsersReadonly, Scope.analyticsManageUsers],
    recommended: Scope.analyticsManageUsersReadonly
  )

  /// Tag Manager reads. Container reads also accept the container edit scopes,
  /// and account reads additionally accept the account management scope.
  public static let tagManagerReadonly = ScopeRequirement(
    accepted: [
      Scope.tagManagerReadonly,
      Scope.tagManagerEditContainers,
      Scope.tagManagerEditContainerVersions,
      Scope.tagManagerManageAccounts
    ],
    recommended: Scope.tagManagerReadonly
  )

  /// Container, workspace, and workspace-entity mutations.
  public static let tagManagerEditContainers = ScopeRequirement(
    accepted: [Scope.tagManagerEditContainers],
    recommended: Scope.tagManagerEditContainers
  )

  /// Container version creation and maintenance.
  public static let tagManagerEditContainerVersions = ScopeRequirement(
    accepted: [Scope.tagManagerEditContainerVersions],
    recommended: Scope.tagManagerEditContainerVersions
  )

  /// Publishing a container version and reauthorizing an environment.
  public static let tagManagerPublish = ScopeRequirement(
    accepted: [Scope.tagManagerPublish],
    recommended: Scope.tagManagerPublish
  )

  /// Container and workspace deletion, which Google gates behind its own scope
  /// rather than the container edit scope.
  public static let tagManagerDeleteContainers = ScopeRequirement(
    accepted: [Scope.tagManagerDeleteContainers],
    recommended: Scope.tagManagerDeleteContainers
  )

  /// Tag Manager account updates.
  public static let tagManagerManageAccounts = ScopeRequirement(
    accepted: [Scope.tagManagerManageAccounts],
    recommended: Scope.tagManagerManageAccounts
  )

  /// Tag Manager account user-permission reads and mutations.
  public static let tagManagerManageUsers = ScopeRequirement(
    accepted: [Scope.tagManagerManageUsers],
    recommended: Scope.tagManagerManageUsers
  )

  /// Returns true when at least one accepted scope was granted.
  public func isSatisfied(byGranted granted: [String]) -> Bool {
    guard !granted.isEmpty else { return true }
    let grantedSet = Set(granted)
    return accepted.contains { grantedSet.contains($0) }
  }
}
