import GoogleAnalyticsGatewayCore

/// Reader-tier capability registry: every field the reader binary serves.
public enum ReadCapabilities {
  public static let all: [CapabilityDefinition] = GAReadCapabilities.all + GTMReadCapabilities.all
}
