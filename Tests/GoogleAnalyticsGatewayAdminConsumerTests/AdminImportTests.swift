import GatewaySDKKit
import GoogleAnalyticsGatewayAdmin
import Testing

@Suite("Admin SDK consumer import")
struct AdminImportTests {
  @Test("The documented admin imports expose the facade")
  func constructsAdminSDK() throws {
    let sdk = try GoogleAnalyticsGatewaySDK.admin()
    #expect(sdk.tier == "admin")
  }
}
