import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite
import GoogleAnalyticsGatewayAdmin

// The admin entry point links every tier; it is the only binary from which
// destructive and account-level capabilities are reachable.
await GatewayComposition.runMain(
  role: .admin,
  definitions: ReadCapabilities.all + WriteCapabilities.all + AdminCapabilities.all
)
