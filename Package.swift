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
  dependencies: [
    .package(url: "https://github.com/tacogips/google-gateway-auth.git", revision: "2951cd8829d94d0b16e2a3bfdca301e57bb1f862"),
    .package(url: "https://github.com/tacogips/gateway-sdk-kit.git", exact: "0.1.0")
  ],
  targets: [
    .target(
      name: "GoogleAnalyticsGatewayCore",
      dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), .product(name: "GatewaySDKKit", package: "gateway-sdk-kit")]
    ),
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
      dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"), "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead"]
    ),
    .executableTarget(
      name: "GoogleAnalyticsGatewayWriterCLI",
      dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"),
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead", "GoogleAnalyticsGatewayWrite"
      ]
    ),
    .executableTarget(
      name: "GoogleAnalyticsGatewayAdminCLI",
      dependencies: [.product(name: "GoogleGatewayAuth", package: "google-gateway-auth"),
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
    ),
    // These targets compile the README import contract without directly
    // importing Core. GatewaySDKKit is intentional here: consumers import the
    // neutral kit alongside exactly one tier product.
    .testTarget(
      name: "GoogleAnalyticsGatewayReadConsumerTests",
      dependencies: [
        .product(name: "GatewaySDKKit", package: "gateway-sdk-kit"),
        "GoogleAnalyticsGatewayRead"
      ]
    ),
    .testTarget(
      name: "GoogleAnalyticsGatewayWriteConsumerTests",
      dependencies: [
        .product(name: "GatewaySDKKit", package: "gateway-sdk-kit"),
        "GoogleAnalyticsGatewayWrite"
      ]
    ),
    .testTarget(
      name: "GoogleAnalyticsGatewayAdminConsumerTests",
      dependencies: [
        .product(name: "GatewaySDKKit", package: "gateway-sdk-kit"),
        "GoogleAnalyticsGatewayAdmin"
      ]
    ),
    // Depends on the three executable targets so `swift test` builds the real
    // binaries, then asserts their link boundaries and end-to-end CLI behavior.
    .testTarget(
      name: "GoogleAnalyticsGatewayCLITests",
      dependencies: [
        "GoogleAnalyticsGatewayCore", "GoogleAnalyticsGatewayRead",
        "GoogleAnalyticsGatewayWrite", "GoogleAnalyticsGatewayAdmin",
        "GoogleAnalyticsGatewayReaderCLI", "GoogleAnalyticsGatewayWriterCLI",
        "GoogleAnalyticsGatewayAdminCLI"
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
