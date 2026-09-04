import GatewaySDKKit
import GoogleAnalyticsGatewayRead
import Testing

@Suite("Reader SDK consumer import")
struct ReaderImportTests {
  @Test("The documented reader imports expose the facade")
  func constructsReaderSDK() throws {
    let sdk = try GoogleAnalyticsGatewaySDK.reader()
    #expect(sdk.tier == "reader")
  }
}
