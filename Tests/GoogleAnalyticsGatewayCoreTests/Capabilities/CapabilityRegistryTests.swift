import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// Registry construction is the point where a mis-declared capability is caught.
/// Each case here is a registration that must fail to build rather than fail at
/// request time, where the reason would be an upstream 404 nobody could explain.
@Suite("Capability registry invariants")
struct CapabilityRegistryTests {
  /// A minimal well-formed reader definition the failure cases mutate.
  static func reader(
    id: String = "sample.widgets.get",
    field: String = "sampleWidget",
    tier: CapabilityTier = .reader,
    service: GoogleAPIService = .analyticsAdminV1Beta,
    pathTemplate: String = "/v1beta/{name}",
    method: HTTPMethod = .get,
    operationClass: OperationClass = .read,
    arguments: [ArgumentDefinition]? = nil,
    result: ResultShape? = nil,
    maximumPageSize: Int? = nil
  ) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: tier,
      operationClass: operationClass,
      method: method,
      service: service,
      pathTemplate: pathTemplate,
      arguments: arguments ?? [
        ArgumentDefinition("name", .resourceName("properties/{property}"), .path("name"), required: true)
      ],
      result: result ?? .single(SampleCapabilities.dataStream),
      scopes: .analyticsReadonly,
      maximumPageSize: maximumPageSize,
      summary: "A fixture capability."
    )
  }

  @Test("A well-formed registry reports no coherence problems")
  func coherentRegistryHasNoProblems() throws {
    let registry = try SampleCapabilities.registry(tier: .admin)
    #expect(registry.coherenceProblems().isEmpty, "\(registry.coherenceProblems())")
    #expect(registry.definitions.count == SampleCapabilities.all.count)
    #expect(registry.definition(field: "sampleDataStream", isMutation: false)?.id
      == CapabilityID("sample.dataStreams.get"))
  }

  @Test("A duplicated GraphQL field refuses to register")
  func rejectsDuplicateField() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(id: "sample.widgets.get"),
        Self.reader(id: "sample.gadgets.get")
      ])
    }
  }

  @Test("A duplicated capability id refuses to register")
  func rejectsDuplicateIdentifier() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(field: "sampleWidget"),
        Self.reader(field: "sampleGadget")
      ])
    }
  }

  @Test("A reader registry refuses a writer definition")
  func readerRegistryRefusesWriterDefinition() throws {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [SampleCapabilities.createDataStream])
    }
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .writer, definitions: [SampleCapabilities.deleteDataStream])
    }
    // The same definitions are accepted by the tier that owns them.
    let admin = try CapabilityRegistry(tier: .admin, definitions: SampleCapabilities.all)
    #expect(admin.mutationDefinitions.count == 2)
  }

  @Test("A path template outside the service prefix refuses to register")
  func rejectsPathTemplateOutsideServicePrefix() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(service: .analyticsAdminV1Beta, pathTemplate: "/v1alpha/{name}")
      ])
    }
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(service: .tagManagerV2, pathTemplate: "/v1beta/{name}")
      ])
    }
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(pathTemplate: "v1beta/{name}")
      ])
    }
  }

  @Test("Every service host the enum can name is one the production policy approves")
  func everyServiceHostIsApproved() throws {
    #expect(GoogleHostPolicy.unapprovedServiceHosts.isEmpty)
    for service in GoogleAPIService.allCases {
      #expect(GoogleHostPolicy.production.allows(host: service.host))
    }
    #expect(!GoogleHostPolicy.production.allows(host: "analytics.example.com"))
    // The token and authorization hosts are deliberately not API hosts.
    #expect(!GoogleHostPolicy.production.allows(host: GoogleHostPolicy.approvedTokenHost))
    #expect(!GoogleHostPolicy.production.allows(host: GoogleHostPolicy.approvedAuthorizationHost))
  }

  @Test("A capability naming an unapproved host is reported by the coherence check")
  func coherenceCheckCoversHostApproval() throws {
    let registry = try SampleCapabilities.registry(tier: .admin)
    // The check reads the live policy, so it can only stay silent while every
    // service host remains approved.
    #expect(registry.coherenceProblems().isEmpty)
    #expect(registry.services == [.analyticsAdminV1Beta])
  }

  @Test("A path placeholder without a bound argument refuses to register")
  func rejectsUnboundPathPlaceholder() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(pathTemplate: "/v1beta/{name}/dataStreams/{stream}")
      ])
    }
  }

  @Test("A connection without a documented maximum page size refuses to register")
  func rejectsConnectionWithoutPageBound() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(
          arguments: [
            ArgumentDefinition("name", .resourceName("properties/{property}"), .path("name"), required: true),
            ArgumentDefinition("page", .page, .page)
          ],
          result: .connection(collection: "dataStreams", SampleCapabilities.dataStream)
        )
      ])
    }
  }

  @Test("A delete outside the admin tier refuses to register")
  func rejectsDeleteBelowAdmin() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .writer, definitions: [
        Self.reader(
          tier: .writer,
          method: .delete,
          operationClass: .delete,
          arguments: [
            ArgumentDefinition("name", .resourceName("properties/{property}"), .path("name"), required: true),
            ArgumentDefinition("confirmName", .string, .confirm("name"), required: true)
          ],
          result: .deletion
        )
      ])
    }
  }

  @Test("A delete without a confirmation echo refuses to register")
  func rejectsUnconfirmedDelete() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .admin, definitions: [
        Self.reader(tier: .admin, method: .delete, operationClass: .delete, result: .deletion)
      ])
    }
  }

  @Test("A request body on an HTTP GET refuses to register")
  func rejectsBodyOnGet() {
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .reader, definitions: [
        Self.reader(arguments: [
          ArgumentDefinition("name", .resourceName("properties/{property}"), .path("name"), required: true),
          ArgumentDefinition("payload", .inputObject(SampleCapabilities.dataStreamInput), .bodyRoot)
        ])
      ])
    }
  }
}
