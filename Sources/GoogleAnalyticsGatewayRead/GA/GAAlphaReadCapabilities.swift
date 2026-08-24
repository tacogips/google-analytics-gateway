import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1alpha read capabilities: the resources Google exposes only
/// on the alpha surface, which the v1beta groups in `GAReadCapabilities` cannot
/// reach (see design-docs/references/field-catalog-v1alpha-extras.json).
public enum GAAlphaReadCapabilities {
  public static let all: [CapabilityDefinition] =
    GAAlphaDefinitionCapabilities.all
    + GAAlphaLinkCapabilities.all
    + GAAlphaStreamCapabilities.all
    + GAAlphaPropertySettingsCapabilities.all
}
