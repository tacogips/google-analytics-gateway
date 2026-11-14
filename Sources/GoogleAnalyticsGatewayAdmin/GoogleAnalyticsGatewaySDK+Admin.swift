@_exported import GoogleAnalyticsGatewayCore

public extension GoogleAnalyticsGatewaySDK {
  static func admin() throws -> GoogleAnalyticsGatewaySDK {
    try GoogleAnalyticsGatewaySDK(role: .admin, definitions: AdminCapabilities.cumulative)
  }
}
