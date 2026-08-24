import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha writer capabilities (see
/// design-docs/references/field-catalog-v1alpha-extras.json).
///
/// They are separated from `GAWriteCapabilities` for the same reason
/// `GAAlphaModels` is separated from `GAModels`: every route here addresses
/// `/v1alpha`, which Google reserves the right to change in ways it never would
/// for `/v1beta`, and keeping the two apart makes that boundary visible at the
/// call site. The access-binding batch mutations on the same surface are
/// administrative and belong to the admin tier, not here.
public enum GAAlphaWriteCapabilities {
  public static let all: [CapabilityDefinition] =
    GAAlphaDefinitionWriteCapabilities.all
    + GAAlphaLinkWriteCapabilities.all
    + GAAlphaDataStreamWriteCapabilities.all
    + GAAlphaPropertyWriteCapabilities.all
}
