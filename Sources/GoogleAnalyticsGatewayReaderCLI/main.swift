import GoogleGatewayAuth
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

// The reader entry point selects a role and delegates to the shared command
// frame. It links Core and Read only; no write or admin module is reachable
// from this binary at link time.
let gatewayInvocation = GatewayAuthBootstrap.prepareOrExit(product: .analytics, role: "reader")

await GatewayComposition.runMain(role: .reader, definitions: ReadCapabilities.all, arguments: gatewayInvocation.arguments, environment: gatewayInvocation.environment, completion: gatewayInvocation.complete)
