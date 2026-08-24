import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite

/// GA4 admin-tier capabilities (deletes, provisioning, acknowledgements).
public enum GAAdminCapabilities {
  public static let all: [CapabilityDefinition] =
    GADeleteCapabilities.all
    + GAProvisioningCapabilities.all
}
