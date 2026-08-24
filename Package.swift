// swift-tools-version: 6.0

import PackageDescription

// Capability tiers are cumulative and separated at link boundaries.
// `GoogleAnalyticsGatewayReaderCLI` must never depend on
// `GoogleAnalyticsGatewayWrite` or `GoogleAnalyticsGatewayAdmin`, and
// `GoogleAnalyticsGatewayWriterCLI` must never depend on
// `GoogleAnalyticsGatewayAdmin`. Tests assert both the manifest structure and
// the linked symbols of the produced executables.
let package = Package(
  name: "google-analytics-gateway",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "GoogleAnalyticsGatewayCore", targets: ["GoogleAnalyticsGatewayCore"]),
    .library(
      name: "GoogleAnalyticsGatewayRead",
      targets: ["GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead"]
    ),
    .library(
      name: "GoogleAnalyticsGatewayWrite",
      targets: ["GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead", "GoogleAnalyticsGatewayWrite"]
    ),
    .library(
      name: "GoogleAnalyticsGatewayAdmin",
      targets: [
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead",
        "GoogleAnalyticsGatewayWrite", "GoogleAnalyticsGatewayAdmin"
      ]
    ),
    .executable(name: "google-analytics-gateway-reader", targets: ["GoogleAnalyticsGatewayReaderCLI"]),
    .executable(name: "google-analytics-gateway-writer", targets: ["GoogleAnalyticsGatewayWriterCLI"]),
    .executable(name: "google-analytics-gateway-admin", targets: ["GoogleAnalyticsGatewayAdminCLI"])
  ],
  targets: [
    .target(name: "GoogleAnalyticsGatewayCore"),
    .target(name: "GoogleAnalyticsGatewayRead", dependencies: ["GoogleAnalyticsGatewayCore"]),
    .target(
      name: "GoogleAnalyticsGatewayWrite",
      dependencies: ["GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead"]
    ),
    .target(
      name: "GoogleAnalyticsGatewayAdmin",
      dependencies: [
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead", "GoogleAnalyticsGatewayWrite"
      ]
    ),
    .executableTarget(
      name: "GoogleAnalyticsGatewayReaderCLI",
      dependencies: ["GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead"]
    ),
    .executableTarget(
      name: "GoogleAnalyticsGatewayWriterCLI",
      dependencies: [
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead", "GoogleAnalyticsGatewayWrite"
      ]
    ),
    .executableTarget(
      name: "GoogleAnalyticsGatewayAdminCLI",
      dependencies: [
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead",
        "GoogleAnalyticsGatewayWrite", "GoogleAnalyticsGatewayAdmin"
      ]
    ),
    // Test-only support: recording transport, loopback helpers, injected seams.
    // No executable target depends on it, so no production binary can contain a
    // mock or fixture path.
    .target(
      name: "GoogleAnalyticsGatewayTestSupport",
      dependencies: ["GoogleAnalyticsGatewayCore"],
      path: "Tests/GoogleAnalyticsGatewayTestSupport"
    ),
    .testTarget(
      name: "GoogleAnalyticsGatewayCoreTests",
      dependencies: [
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead",
        "GoogleAnalyticsGatewayWrite", "GoogleAnalyticsGatewayAdmin",
        "GoogleAnalyticsGatewayTestSupport"
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
