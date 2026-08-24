import Foundation

/// The tier that owns each published GraphQL field name.
///
/// This is a name-only table. It links no write or admin code, so a reader
/// binary can still answer "that mutation requires the admin tier" with
/// `CAPABILITY_DENIED` instead of "unknown field", exactly as
/// `design-docs/specs/graphql-schema.md` requires of the reader executable
/// rejecting a mutation root field.
///
/// Every entry must match a real registration in its owning module, and every
/// mutation registered by the writer and admin modules must appear here. The
/// CLI tests assert the two agree in both directions, so a capability added to
/// a module without a matching entry fails the build rather than silently
/// reporting itself as an unknown field to reader callers.
public enum CapabilityCatalog {
  /// Field names owned by the writer tier: creates, updates, patches, archives,
  /// Tag Manager workspace mutations, version create/publish/set-latest, Google
  /// tag configuration writes, and built-in variable writes.
  ///
  /// Populated by the capability modules as they are registered; the coherence
  /// test in the CLI target is what keeps it complete.
  public static let writerMutationFields: [String] = [
    "gaArchiveCustomDimension",
    "gaArchiveCustomMetric",
    "gaCreateAudienceExport",
    "gaCreateConversionEvent",
    "gaCreateCustomDimension",
    "gaCreateCustomMetric",
    "gaCreateDataStream",
    "gaCreateFirebaseLink",
    "gaCreateGoogleAdsLink",
    "gaCreateKeyEvent",
    "gaCreateMeasurementProtocolSecret",
    "gaCreateProperty",
    "gaUpdateAccount",
    "gaUpdateConversionEvent",
    "gaUpdateCustomDimension",
    "gaUpdateCustomMetric",
    "gaUpdateDataRetentionSettings",
    "gaUpdateDataStream",
    "gaUpdateGoogleAdsLink",
    "gaUpdateKeyEvent",
    "gaUpdateMeasurementProtocolSecret",
    "gaUpdateProperty",
    "gtmBulkUpdateWorkspace",
    "gtmCreateBuiltInVariable",
    "gtmCreateClient",
    "gtmCreateContainer",
    "gtmCreateEnvironment",
    "gtmCreateFolder",
    "gtmCreateGtagConfig",
    "gtmCreateTag",
    "gtmCreateTemplate",
    "gtmCreateTransformation",
    "gtmCreateTrigger",
    "gtmCreateVariable",
    "gtmCreateVersion",
    "gtmCreateWorkspace",
    "gtmCreateZone",
    "gtmFolderEntities",
    "gtmImportFromGallery",
    "gtmMoveEntitiesToFolder",
    "gtmPublishVersion",
    "gtmQuickPreviewWorkspace",
    "gtmResolveConflictWorkspace",
    "gtmRevertBuiltInVariable",
    "gtmRevertClient",
    "gtmRevertFolder",
    "gtmRevertTag",
    "gtmRevertTemplate",
    "gtmRevertTransformation",
    "gtmRevertTrigger",
    "gtmRevertVariable",
    "gtmRevertZone",
    "gtmSetLatestVersion",
    "gtmSyncWorkspace",
    "gtmUpdateAccount",
    "gtmUpdateClient",
    "gtmUpdateContainer",
    "gtmUpdateEnvironment",
    "gtmUpdateFolder",
    "gtmUpdateGtagConfig",
    "gtmUpdateTag",
    "gtmUpdateTemplate",
    "gtmUpdateTransformation",
    "gtmUpdateTrigger",
    "gtmUpdateVariable",
    "gtmUpdateVersion",
    "gtmUpdateWorkspace",
    "gtmUpdateZone"
  ]

  /// Field names owned by the admin tier: deletes, Tag Manager user
  /// permissions, GA4 access bindings, account provisioning, destination
  /// linking, and container combine/move operations.
  public static let adminMutationFields: [String] = [
    "gaAcknowledgeUserDataCollection",
    "gaDeleteAccount",
    "gaDeleteConversionEvent",
    "gaDeleteDataStream",
    "gaDeleteFirebaseLink",
    "gaDeleteGoogleAdsLink",
    "gaDeleteKeyEvent",
    "gaDeleteMeasurementProtocolSecret",
    "gaDeleteProperty",
    "gaProvisionAccountTicket",
    "gtmCombineContainers",
    "gtmCreateUserPermission",
    "gtmDeleteBuiltInVariable",
    "gtmDeleteClient",
    "gtmDeleteContainer",
    "gtmDeleteEnvironment",
    "gtmDeleteFolder",
    "gtmDeleteGtagConfig",
    "gtmDeleteTag",
    "gtmDeleteTemplate",
    "gtmDeleteTransformation",
    "gtmDeleteTrigger",
    "gtmDeleteUserPermission",
    "gtmDeleteVariable",
    "gtmDeleteVersion",
    "gtmDeleteWorkspace",
    "gtmDeleteZone",
    "gtmLinkDestination",
    "gtmMoveTagId",
    "gtmReauthorizeEnvironment",
    "gtmUndeleteVersion",
    "gtmUpdateUserPermission"
  ]

  /// Query field names owned by the admin tier. Tag Manager user-permission
  /// reads are administrative even though they are HTTP GETs, so a reader
  /// binary must answer `CAPABILITY_DENIED` for them rather than
  /// "unknown field".
  public static let adminQueryFields: [String] = [
    "gtmUserPermission",
    "gtmUserPermissions"
  ]

  /// Returns the tier that owns a field name, or `nil` when the name is not
  /// part of the published contract at all.
  public static func knownTier(field: String, isMutation: Bool) -> CapabilityTier? {
    guard isMutation else {
      return adminQueryFields.contains(field) ? .admin : nil
    }
    if adminMutationFields.contains(field) { return .admin }
    if writerMutationFields.contains(field) { return .writer }
    return nil
  }
}
