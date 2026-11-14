import GoogleGatewayAuth
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite
import GoogleAnalyticsGatewayAdmin

// The admin entry point links every tier; it is the only binary from which
// destructive and account-level capabilities are reachable.
let gatewayInvocation = GatewayAuthBootstrap.prepareOrExit(product: .analytics, role: "admin")

await GatewayComposition.runMain(
  role: .admin,
  definitions: AdminCapabilities.cumulative,
  arguments: gatewayInvocation.arguments, environment: gatewayInvocation.environment, completion: gatewayInvocation.complete
)
