import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite

/// GA4 admin-tier capabilities (deletes, provisioning, acknowledgements, and
/// the v1alpha access-binding and user-deletion surface).
public enum GAAdminCapabilities {
  public static let all: [CapabilityDefinition] =
    GADeleteCapabilities.all
    + GAProvisioningCapabilities.all
    + GAAlphaAdminCapabilities.all
}
