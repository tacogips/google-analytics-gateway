import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite

// The writer entry point links Core, Read, and Write; the admin module is not
// reachable from this binary at link time.
await GatewayComposition.runMain(
  role: .writer,
  definitions: ReadCapabilities.all + WriteCapabilities.all
)
