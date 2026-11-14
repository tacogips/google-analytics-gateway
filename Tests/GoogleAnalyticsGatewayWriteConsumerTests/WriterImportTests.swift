import GatewaySDKKit
import GoogleAnalyticsGatewayWrite
import Testing

@Suite("Writer SDK consumer import")
struct WriterImportTests {
  @Test("The documented writer imports expose the facade")
  func constructsWriterSDK() throws {
    let sdk = try GoogleAnalyticsGatewaySDK.writer()
    #expect(sdk.tier == "writer")
  }
}
