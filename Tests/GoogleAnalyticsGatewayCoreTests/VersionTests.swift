import Testing
@testable import GoogleAnalyticsGatewayCore

@Test func versionConstantIsSemver() {
  #expect(googleAnalyticsGatewayVersion.split(separator: ".").count == 3)
}
