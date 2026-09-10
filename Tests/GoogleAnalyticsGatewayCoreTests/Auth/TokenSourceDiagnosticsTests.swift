import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

@Test func statusFollowsEnvironmentPrecedenceOverMissingStoredToken() throws {
  let profile = SampleProfiles.profile(id: "analytics-reader", product: .analytics, tokenStorePath: "/missing/selected-token.json")
  let store = RecordingTokenStore()
  let resolver = CredentialResolver(tokenStore: store)
  let environment = [profile.accessTokenEnvironmentVariable: "local-test-token"]
  let status = resolver.status(profile: profile, environment: environment)
  #expect(status.state == "ready")
  #expect(status.tokenSource == "ENVIRONMENT_TOKEN")
  #expect(status.tokenEnvironmentVariable == profile.accessTokenEnvironmentVariable)
  #expect(status.tokenStorePath == nil)
  #expect(store.readCount == 0)
  #expect(try resolver.accessToken(profile: profile, environment: environment) == "local-test-token")
  do {
    _ = try resolver.accessToken(profile: profile, environment: [:])
    Issue.record("Expected missing file credentials to fail")
  } catch let error as GatewayError {
    #expect(error.message.contains("tokenSource=FILE"))
    #expect(error.message.contains("/missing/selected-token.json"))
    #expect(error.recoveryGuidance?.contains(profile.accessTokenEnvironmentVariable) == true)
  }
}
