import GoogleGatewayAuth
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite

// The writer entry point links Core, Read, and Write; the admin module is not
// reachable from this binary at link time.
let gatewayInvocation = GatewayAuthBootstrap.prepareOrExit(product: .analytics, role: "writer")

await GatewayComposition.runMain(
  role: .writer,
  definitions: WriteCapabilities.cumulative,
  arguments: gatewayInvocation.arguments, environment: gatewayInvocation.environment, completion: gatewayInvocation.complete
)
