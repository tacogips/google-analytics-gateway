import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin + Data API writer capabilities (see design-docs/references/field-catalog.json).
public enum GAWriteCapabilities {
  public static let all: [CapabilityDefinition] =
    GAAccountWriteCapabilities.all
    + GAPropertyWriteCapabilities.all
    + GADataStreamWriteCapabilities.all
    + GADefinitionWriteCapabilities.all
    + GALinkWriteCapabilities.all
    + GAAudienceExportWriteCapabilities.all
    + GAAlphaWriteCapabilities.all
}
