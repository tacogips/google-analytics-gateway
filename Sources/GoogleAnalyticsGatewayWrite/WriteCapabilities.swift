import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Writer-tier capability registry.
public enum WriteCapabilities {
  public static let all: [CapabilityDefinition] = GAWriteCapabilities.all + GTMWriteCapabilities.all
}
