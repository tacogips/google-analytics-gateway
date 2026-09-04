@_exported import GoogleAnalyticsGatewayCore

public extension GoogleAnalyticsGatewaySDK {
  static func writer() throws -> GoogleAnalyticsGatewaySDK {
    try GoogleAnalyticsGatewaySDK(role: .writer, definitions: WriteCapabilities.cumulative)
  }
}
