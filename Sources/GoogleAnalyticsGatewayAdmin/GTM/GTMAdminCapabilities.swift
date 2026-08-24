import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite

/// Tag Manager admin-tier capabilities (deletes, user permissions, destinations, container surgery).
public enum GTMAdminCapabilities {
  public static let all: [CapabilityDefinition] =
    GTMDeleteCapabilities.all
    + GTMUserPermissionCapabilities.all
    + GTMContainerOperationCapabilities.all
}
