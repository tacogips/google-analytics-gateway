import GoogleAnalyticsGatewayCore

/// GA4 Admin + Data API read capabilities (see design-docs/references/field-catalog.json).
public enum GAReadCapabilities {
  public static let all: [CapabilityDefinition] =
    GAAccountCapabilities.all
    + GAPropertyCapabilities.all
    + GADataStreamCapabilities.all
    + GADefinitionCapabilities.all
    + GALinkCapabilities.all
    + GAReportCapabilities.all
    + GAAudienceExportCapabilities.all
    + GAAlphaReadCapabilities.all
}
