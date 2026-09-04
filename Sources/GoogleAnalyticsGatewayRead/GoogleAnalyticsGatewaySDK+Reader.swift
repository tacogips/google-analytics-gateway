@_exported import GoogleAnalyticsGatewayCore

public extension GoogleAnalyticsGatewaySDK {
  static func reader() throws -> GoogleAnalyticsGatewaySDK {
    try GoogleAnalyticsGatewaySDK(role: .reader, definitions: ReadCapabilities.all)
  }
}
