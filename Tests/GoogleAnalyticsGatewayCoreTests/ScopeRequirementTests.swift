import Foundation
import Testing

import GoogleAnalyticsGatewayCore

/// The expected scope sets are written out as literals rather than read back
/// from the discovery documents in `design-docs/references/`. A test that
/// derived them from the same source the presets were built from would restate
/// the implementation instead of checking it, and it would need to read files at
/// run time; these stay offline and self-contained, so a preset that silently
/// widens fails here.
@Suite("Google OAuth scope requirements")
struct ScopeRequirementTests {
  private static let analyticsReadonly = "https://www.googleapis.com/auth/analytics.readonly"
  private static let analyticsEdit = "https://www.googleapis.com/auth/analytics.edit"
  private static let analytics = "https://www.googleapis.com/auth/analytics"
  private static let analyticsManageUsers = "https://www.googleapis.com/auth/analytics.manage.users"
  private static let analyticsManageUsersReadonly =
    "https://www.googleapis.com/auth/analytics.manage.users.readonly"
  private static let tagManagerReadonly = "https://www.googleapis.com/auth/tagmanager.readonly"
  private static let tagManagerEditContainers =
    "https://www.googleapis.com/auth/tagmanager.edit.containers"
  private static let tagManagerEditContainerVersions =
    "https://www.googleapis.com/auth/tagmanager.edit.containerversions"
  private static let tagManagerPublish = "https://www.googleapis.com/auth/tagmanager.publish"
  private static let tagManagerDeleteContainers =
    "https://www.googleapis.com/auth/tagmanager.delete.containers"
  private static let tagManagerManageAccounts =
    "https://www.googleapis.com/auth/tagmanager.manage.accounts"
  private static let tagManagerManageUsers =
    "https://www.googleapis.com/auth/tagmanager.manage.users"

  struct Preset: Sendable, CustomTestStringConvertible {
    let name: String
    let requirement: ScopeRequirement
    var testDescription: String { name }
  }

  static let allPresets: [Preset] = [
    Preset(name: "analyticsReadonly", requirement: .analyticsReadonly),
    Preset(name: "analyticsEdit", requirement: .analyticsEdit),
    Preset(name: "analyticsFull", requirement: .analyticsFull),
    Preset(name: "analyticsManageUsers", requirement: .analyticsManageUsers),
    Preset(name: "analyticsManageUsersReadonly", requirement: .analyticsManageUsersReadonly),
    Preset(name: "tagManagerReadonly", requirement: .tagManagerReadonly),
    Preset(name: "tagManagerEditContainers", requirement: .tagManagerEditContainers),
    Preset(name: "tagManagerEditContainerVersions", requirement: .tagManagerEditContainerVersions),
    Preset(name: "tagManagerPublish", requirement: .tagManagerPublish),
    Preset(name: "tagManagerDeleteContainers", requirement: .tagManagerDeleteContainers),
    Preset(name: "tagManagerManageAccounts", requirement: .tagManagerManageAccounts),
    Preset(name: "tagManagerManageUsers", requirement: .tagManagerManageUsers)
  ]

  // MARK: - Declared scope sets

  @Test("Analytics read accepts the readonly, edit, and full scopes")
  func analyticsReadScopes() throws {
    #expect(
      ScopeRequirement.analyticsReadonly.accepted
        == [Self.analyticsReadonly, Self.analyticsEdit, Self.analytics]
    )
    #expect(ScopeRequirement.analyticsReadonly.recommended == Self.analyticsReadonly)
  }

  @Test("Analytics edit accepts only the edit scope")
  func analyticsEditScopes() throws {
    #expect(ScopeRequirement.analyticsEdit.accepted == [Self.analyticsEdit])
    #expect(ScopeRequirement.analyticsEdit.recommended == Self.analyticsEdit)
  }

  @Test("The full analytics scope stands alone")
  func analyticsFullScopes() throws {
    #expect(ScopeRequirement.analyticsFull.accepted == [Self.analytics])
    #expect(ScopeRequirement.analyticsFull.recommended == Self.analytics)
  }

  @Test("Access-binding reads accept the readonly and broader manage-users scopes")
  func analyticsManageUsersScopes() throws {
    #expect(
      ScopeRequirement.analyticsManageUsersReadonly.accepted
        == [Self.analyticsManageUsersReadonly, Self.analyticsManageUsers]
    )
    #expect(
      ScopeRequirement.analyticsManageUsersReadonly.recommended == Self.analyticsManageUsersReadonly
    )
    #expect(ScopeRequirement.analyticsManageUsers.accepted == [Self.analyticsManageUsers])
  }

  @Test("Tag Manager reads accept the readonly, edit, and account management scopes")
  func tagManagerReadScopes() throws {
    #expect(
      ScopeRequirement.tagManagerReadonly.accepted == [
        Self.tagManagerReadonly,
        Self.tagManagerEditContainers,
        Self.tagManagerEditContainerVersions,
        Self.tagManagerManageAccounts
      ]
    )
    #expect(ScopeRequirement.tagManagerReadonly.recommended == Self.tagManagerReadonly)
  }

  @Test("Each Tag Manager write scope stands alone")
  func tagManagerWriteScopes() throws {
    #expect(ScopeRequirement.tagManagerEditContainers.accepted == [Self.tagManagerEditContainers])
    #expect(
      ScopeRequirement.tagManagerEditContainerVersions.accepted
        == [Self.tagManagerEditContainerVersions]
    )
    #expect(ScopeRequirement.tagManagerPublish.accepted == [Self.tagManagerPublish])
    #expect(ScopeRequirement.tagManagerDeleteContainers.accepted == [Self.tagManagerDeleteContainers])
    #expect(ScopeRequirement.tagManagerManageAccounts.accepted == [Self.tagManagerManageAccounts])
    #expect(ScopeRequirement.tagManagerManageUsers.accepted == [Self.tagManagerManageUsers])
  }

  // MARK: - Invariants across every preset

  @Test("Every preset recommends a scope it accepts", arguments: allPresets)
  func recommendsAnAcceptedScope(preset: Preset) throws {
    #expect(preset.requirement.accepted.contains(preset.requirement.recommended))
  }

  /// Google compares the returned scope set exactly, so an abbreviated spelling
  /// would pass local checks and then fail the post-authorization comparison.
  @Test("Every scope is a full googleapis.com URL", arguments: allPresets)
  func scopesAreFullURLs(preset: Preset) throws {
    for scope in preset.requirement.accepted {
      #expect(scope.hasPrefix("https://www.googleapis.com/auth/"), "\(scope) is not a full scope URL")
      #expect(!scope.hasSuffix("/"), "\(scope) has a trailing slash")
    }
  }

  @Test("No preset declares a duplicate accepted scope", arguments: allPresets)
  func acceptedScopesAreUnique(preset: Preset) throws {
    #expect(Set(preset.requirement.accepted).count == preset.requirement.accepted.count)
  }

  @Test("No preset accepts an empty scope list", arguments: allPresets)
  func acceptedScopesAreNonEmpty(preset: Preset) throws {
    #expect(!preset.requirement.accepted.isEmpty)
  }

  // MARK: - Satisfaction

  @Test("A granted scope on the accepted list satisfies the requirement")
  func acceptedScopeSatisfies() throws {
    #expect(ScopeRequirement.analyticsReadonly.isSatisfied(byGranted: [Self.analyticsReadonly]))
    #expect(ScopeRequirement.analyticsReadonly.isSatisfied(byGranted: [Self.analyticsEdit]))
    #expect(ScopeRequirement.analyticsReadonly.isSatisfied(byGranted: [Self.analytics]))
  }

  @Test("An unrelated granted scope does not satisfy the requirement")
  func unrelatedScopeDoesNotSatisfy() throws {
    #expect(!ScopeRequirement.analyticsReadonly.isSatisfied(byGranted: [Self.tagManagerReadonly]))
    #expect(!ScopeRequirement.tagManagerManageUsers.isSatisfied(byGranted: [Self.tagManagerPublish]))
  }

  /// A read-only grant must never authorize a write. This is the boundary the
  /// role-split binaries depend on, so it is asserted directly rather than left
  /// implicit in the accepted lists.
  @Test("A readonly grant does not satisfy a write requirement")
  func readonlyDoesNotSatisfyWrite() throws {
    #expect(!ScopeRequirement.analyticsEdit.isSatisfied(byGranted: [Self.analyticsReadonly]))
    #expect(!ScopeRequirement.tagManagerEditContainers.isSatisfied(byGranted: [Self.tagManagerReadonly]))
    #expect(
      !ScopeRequirement.analyticsManageUsers.isSatisfied(byGranted: [Self.analyticsManageUsersReadonly])
    )
  }

  /// Google does not document the publish scope as sufficient for any read, so
  /// a publish-only grant must not pass a read check even though it is the
  /// broader-sounding permission.
  @Test("A publish grant alone does not satisfy a Tag Manager read")
  func publishDoesNotSatisfyRead() throws {
    #expect(!ScopeRequirement.tagManagerReadonly.isSatisfied(byGranted: [Self.tagManagerPublish]))
    #expect(
      !ScopeRequirement.tagManagerReadonly.isSatisfied(byGranted: [Self.tagManagerDeleteContainers])
    )
  }

  @Test("One accepted scope among several granted is enough")
  func anyAcceptedScopeSuffices() throws {
    #expect(
      ScopeRequirement.tagManagerReadonly.isSatisfied(
        byGranted: [Self.analyticsReadonly, Self.tagManagerEditContainers]
      )
    )
  }

  /// An empty granted list means the scope set is unknown, not that nothing was
  /// granted: a credential source that does not report scopes must not have
  /// every capability denied. The upstream authorization check remains the real
  /// boundary in that case.
  @Test("An unknown granted scope set passes through rather than denying")
  func emptyGrantedSetPassesThrough() throws {
    for preset in Self.allPresets {
      #expect(preset.requirement.isSatisfied(byGranted: []), "\(preset.name) denied an unknown grant")
    }
  }

  @Test("A requirement constructed directly behaves like a preset")
  func customRequirementBehavesConsistently() throws {
    let requirement = ScopeRequirement(accepted: ["a", "b"], recommended: "a")
    #expect(requirement.isSatisfied(byGranted: ["b"]))
    #expect(!requirement.isSatisfied(byGranted: ["c"]))
    #expect(requirement.isSatisfied(byGranted: []))
  }
}
