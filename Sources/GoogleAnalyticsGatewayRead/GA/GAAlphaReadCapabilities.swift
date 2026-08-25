import GoogleAnalyticsGatewayCore

/// GA4 v1alpha read capabilities: the resources Google exposes only on the
/// alpha surface, which the v1beta groups in `GAReadCapabilities` cannot reach
/// (see design-docs/references/field-catalog-v1alpha-extras.json).
///
/// Most come from the Admin API's alpha surface; `GAAlphaDataCapabilities` adds
/// the Data API's, which is a different host under the same `/v1alpha` prefix.
public enum GAAlphaReadCapabilities {
  public static let all: [CapabilityDefinition] =
    GAAlphaDefinitionCapabilities.all
    + GAAlphaLinkCapabilities.all
    + GAAlphaStreamCapabilities.all
    + GAAlphaPropertySettingsCapabilities.all
    + GAAlphaDataCapabilities.all
}
