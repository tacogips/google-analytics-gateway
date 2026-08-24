import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayWrite

/// Admin-tier capability registry.
public enum AdminCapabilities {
  public static let all: [CapabilityDefinition] = GAAdminCapabilities.all + GTMAdminCapabilities.all
}
