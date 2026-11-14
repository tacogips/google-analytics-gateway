import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// Planning is entirely local, so every check here happens before a credential
/// is resolved or a request is sent. The exact URL assertions are literal on
/// purpose: a route is the one thing a caller cannot inspect after the fact.
@Suite("Capability planner")
struct CapabilityPlannerTests {
  static let credential = ResolvedCredential(
    token: SecretValue(fixtureAccessToken),
    grantedScopes: []
  )

  static func url(_ plan: CapabilityPlan) throws -> String {
    try CapabilityExecutor.prepare(plan.request, credential: credential, requestID: fixtureRequestID)
      .url.absoluteString
  }

  @Test("A list plan produces the exact upstream URL, method, and query")
  func plansListRequest() throws {
    let planner = try SampleCapabilities.planner()
    let plan = try planner.plan(SampleCapabilities.invocation(
      SampleCapabilities.listDataStreams,
      [
        "parent": .string("properties/123456"),
        "page": .object(["pageSize": .int(50), "nextPageToken": .string("opaque-token")])
      ]
    ))

    #expect(plan.request.method == .get)
    #expect(plan.request.path == "/v1beta/properties/123456/dataStreams")
    #expect(plan.request.body == .none)
    #expect(plan.request.service == .analyticsAdminV1Beta)

    let url = try Self.url(plan)
    #expect(url == "https://analyticsadmin.googleapis.com/v1beta/properties/123456"
      + "/dataStreams?pageSize=50&pageToken=opaque-token")
  }

  @Test("A get plan renders a multi-segment resource name into one placeholder")
  func plansGetRequest() throws {
    let planner = try SampleCapabilities.planner()
    let plan = try planner.plan(SampleCapabilities.invocation(
      SampleCapabilities.getDataStream,
      ["name": .string("properties/123456/dataStreams/789")]
    ))

    let url = try Self.url(plan)
    #expect(url == "https://analyticsadmin.googleapis.com/v1beta/properties/123456/dataStreams/789")
  }

  @Test("A list argument bound to a single query parameter is comma joined")
  func joinsQueryList() throws {
    let planner = try SampleCapabilities.planner()
    let plan = try planner.plan(SampleCapabilities.invocation(
      SampleCapabilities.getDataStream,
      [
        "name": .string("properties/123456/dataStreams/789"),
        "fields": .array([.string("name"), .string("displayName")])
      ]
    ))

    #expect(plan.request.queryItems == [UpstreamQueryItem(name: "fields", value: "name,displayName")])
  }

  @Test("A create plan sends the declared body root with its upstream keys")
  func plansCreateRequest() throws {
    let planner = try SampleCapabilities.planner()
    let plan = try planner.plan(SampleCapabilities.invocation(
      SampleCapabilities.createDataStream,
      [
        "parent": .string("properties/123456"),
        "dataStream": .object([
          "displayName": .string("Web stream"),
          "streamKind": .string("WEB_DATA_STREAM")
        ])
      ]
    ))

    #expect(plan.request.method == .post)
    #expect(plan.request.body == .json(.object([
      "displayName": .string("Web stream"),
      "type": .string("WEB_DATA_STREAM")
    ])))
  }

  @Test("An unknown field is a validation error naming the schema command")
  func rejectsUnknownField() throws {
    let planner = try SampleCapabilities.planner()
    do {
      _ = try planner.definition(field: "sampleUnknown", isMutation: false)
      Issue.record("Expected an unknown field to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.recoveryGuidance?.contains("graphql schema") == true)
    }
  }

  @Test("An unknown argument is a validation error")
  func rejectsUnknownArgument() throws {
    let planner = try SampleCapabilities.planner()
    do {
      _ = try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.getDataStream,
        ["name": .string("properties/123456/dataStreams/789"), "expand": .bool(true)]
      ))
      Issue.record("Expected an unknown argument to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.message.contains("expand"))
    }
  }

  @Test("A missing required argument is a validation error")
  func rejectsMissingRequiredArgument() throws {
    let planner = try SampleCapabilities.planner()
    #expect(throws: GatewayError.self) {
      try planner.plan(SampleCapabilities.invocation(SampleCapabilities.getDataStream))
    }
  }

  static let malformedResourceNames: [String] = [
    "properties/123456/../789",
    "properties/1/../2",
    "properties//123456",
    "properties/123456/dataStreams",
    "https://analyticsadmin.googleapis.com/v1beta/properties/1",
    "properties/123456?alt=json",
    "properties/123 456",
    ""
  ]

  @Test("A malformed resource name is refused before any request is built", arguments: malformedResourceNames)
  func rejectsMalformedResourceName(name: String) throws {
    let planner = try SampleCapabilities.planner()
    do {
      let plan = try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.listDataStreams,
        ["parent": .string(name)]
      ))
      Issue.record("Expected \(name) to be refused, produced \(plan.request.path)")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.recoveryGuidance?.contains("properties/{property}") == true)
    }
  }

  @Test("A page size above the capability maximum is rejected rather than clamped")
  func rejectsOversizedPageSize() throws {
    let planner = try SampleCapabilities.planner()
    do {
      _ = try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.listDataStreams,
        ["parent": .string("properties/123456"), "page": .object(["pageSize": .int(5_000)])]
      ))
      Issue.record("Expected an oversized page size to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.message.contains("exceeds the maximum of 200"))
    }

    // The maximum itself is accepted, so the bound is a limit and not an offset.
    let plan = try planner.plan(SampleCapabilities.invocation(
      SampleCapabilities.listDataStreams,
      ["parent": .string("properties/123456"), "page": .object(["pageSize": .int(200)])]
    ))
    #expect(plan.request.queryItems.contains(UpstreamQueryItem(name: "pageSize", value: "200")))
  }

  @Test("A page size on a capability without pagination is refused")
  func rejectsPageSizeWithoutPagination() throws {
    let planner = try SampleCapabilities.planner()
    #expect(throws: GatewayError.self) {
      try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.getDataStream,
        [
          "name": .string("properties/123456/dataStreams/789"),
          "page": .object(["pageSize": .int(10)])
        ]
      ))
    }
  }

  @Test("A destructive request whose confirmation does not match is refused")
  func rejectsMismatchedConfirmation() throws {
    let planner = try SampleCapabilities.planner()
    do {
      _ = try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.deleteDataStream,
        [
          "name": .string("properties/123456/dataStreams/789"),
          "confirmName": .string("properties/123456/dataStreams/790")
        ]
      ))
      Issue.record("Expected a mismatched confirmation to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.message.contains("confirmName"))
      #expect(error.recoveryGuidance?.contains("exactly") == true)
    }
  }

  @Test("A destructive request without a confirmation is refused")
  func rejectsMissingConfirmation() throws {
    let planner = try SampleCapabilities.planner()
    #expect(throws: GatewayError.self) {
      try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.deleteDataStream,
        ["name": .string("properties/123456/dataStreams/789")]
      ))
    }
  }

  @Test("A matching confirmation plans the delete and never reaches the request")
  func acceptsMatchingConfirmation() throws {
    let planner = try SampleCapabilities.planner()
    let plan = try planner.plan(SampleCapabilities.invocation(
      SampleCapabilities.deleteDataStream,
      [
        "name": .string("properties/123456/dataStreams/789"),
        "confirmName": .string("properties/123456/dataStreams/789")
      ]
    ))

    #expect(plan.request.method == .delete)
    #expect(plan.request.path == "/v1beta/properties/123456/dataStreams/789")
    #expect(plan.request.body == .none)
    #expect(plan.request.queryItems.isEmpty)
  }

  @Test("A capability the registry does not link is denied, not reported as unknown")
  func deniesUnlinkedCapability() throws {
    let planner = try SampleCapabilities.planner(tier: .reader)
    do {
      _ = try planner.plan(SampleCapabilities.invocation(
        SampleCapabilities.createDataStream,
        ["parent": .string("properties/1"), "dataStream": .object(["displayName": .string("One")])]
      ))
      Issue.record("Expected an unlinked capability to be denied")
    } catch let error as GatewayError {
      #expect(error.code == .capabilityDenied)
      #expect(error.exitCode == .usage)
    }
  }

  @Test("A credential missing an accepted scope is refused before transport")
  func rejectsMissingScope() throws {
    let planner = try SampleCapabilities.planner()
    do {
      try planner.validateScopes(
        for: SampleCapabilities.createDataStream,
        grantedScopes: [ScopeRequirement.Scope.analyticsReadonly]
      )
      Issue.record("Expected a missing scope to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .authorizationFailed)
      #expect(error.recoveryGuidance?.contains(ScopeRequirement.Scope.analyticsEdit) == true)
    }
    // An empty granted set means the credential exposes no scope metadata, and
    // Google stays authoritative.
    #expect(throws: Never.self) {
      try planner.validateScopes(for: SampleCapabilities.createDataStream, grantedScopes: [])
    }
  }
}
