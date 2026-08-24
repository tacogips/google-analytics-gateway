import GoogleAnalyticsGatewayCore

/// Local pagination bounds for the Tag Manager v2 list methods.
enum GTMPagination {
  /// Tag Manager documents `pageToken` on its list methods but no `pageSize`,
  /// and publishes no page-size cap. The registry still bounds the value it
  /// will assemble, so an unreasonable request fails locally with a named
  /// validation error instead of travelling upstream to be ignored.
  static let maximumPageSize = 300
}

/// Tag Manager read capabilities (see design-docs/references/field-catalog.json).
public enum GTMReadCapabilities {
  public static let all: [CapabilityDefinition] =
    GTMAccountCapabilities.all
    + GTMContainerCapabilities.all
    + GTMWorkspaceCapabilities.all
    + GTMTagCapabilities.all
    + GTMTriggerCapabilities.all
    + GTMVariableCapabilities.all
    + GTMClientCapabilities.all
    + GTMFolderCapabilities.all
    + GTMTemplateCapabilities.all
    + GTMTransformationCapabilities.all
    + GTMZoneCapabilities.all
    + GTMGtagConfigCapabilities.all
    + GTMEnvironmentCapabilities.all
    + GTMVersionCapabilities.all
    + GTMDestinationCapabilities.all
}
