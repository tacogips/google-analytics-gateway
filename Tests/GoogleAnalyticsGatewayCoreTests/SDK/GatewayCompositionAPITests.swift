import GoogleAnalyticsGatewayCore
import Testing

@Suite("Gateway composition public API")
struct GatewayCompositionAPITests {
  @Test("The SDK runtime factory has the required public signature")
  func exposesRuntimeFactory() {
    let factory: (RoleDescriptor, [CapabilityDefinition], [String: String]) throws -> GraphQLRuntime =
      GatewayComposition.makeRuntime(role:definitions:environment:)
    _ = factory
  }
}
