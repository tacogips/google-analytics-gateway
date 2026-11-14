import Foundation
import GoogleAnalyticsGatewayCore

/// Synthetic capability definitions used to exercise the registry, planner,
/// executor, and GraphQL engine.
///
/// They are deliberately not production registrations: the field names carry a
/// `sample` prefix that no published contract uses, so a change to the real
/// catalog cannot silently change what these tests assert. They are declared
/// against `analyticsAdminV1Beta` because that service's `/v1beta` prefix is the
/// one the route coherence check enforces.
public enum SampleCapabilities {
  public static let webStreamData = ModelShape(
    typeName: "SampleWebStreamData",
    fields: [
      ModelField("defaultUri", .string),
      ModelField("measurementId", .string)
    ]
  )

  /// `streamKind` is spelled `type` upstream, so a projection test can prove the
  /// upstream name stays an adapter detail.
  public static let dataStream = ModelShape(
    typeName: "SampleDataStream",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("streamKind", upstream: "type", .string),
      ModelField("createTime", .dateTime),
      ModelField("webStreamData", .object(webStreamData))
    ]
  )

  public static let dataStreamInput = InputObjectShape(
    typeName: "SampleDataStreamInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition(
        "streamKind",
        .enumeration("SampleStreamKind", ["WEB_DATA_STREAM", "IOS_APP_DATA_STREAM"]),
        .bodyJSON("type"),
        required: true
      ),
      ArgumentDefinition(
        "webStreamData",
        .inputObject(InputObjectShape(
          typeName: "SampleWebStreamDataInput",
          fields: [ArgumentDefinition("defaultUri", .string, .bodyJSON("defaultUri"))]
        )),
        .bodyJSON("webStreamData")
      )
    ]
  )

  public static let listDataStreams = CapabilityDefinition(
    id: CapabilityID("sample.dataStreams.list"),
    field: "sampleDataStreams",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .analyticsAdminV1Beta,
    pathTemplate: "/v1beta/{parent}/dataStreams",
    arguments: [
      ArgumentDefinition("parent", .resourceName("properties/{property}"), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "dataStreams", dataStream),
    scopes: .analyticsReadonly,
    maximumPageSize: 200,
    summary: "Lists the data streams of a property."
  )

  public static let getDataStream = CapabilityDefinition(
    id: CapabilityID("sample.dataStreams.get"),
    field: "sampleDataStream",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .analyticsAdminV1Beta,
    pathTemplate: "/v1beta/{name}",
    arguments: [
      ArgumentDefinition(
        "name",
        .resourceName("properties/{property}/dataStreams/{stream}"),
        .path("name"),
        required: true
      ),
      ArgumentDefinition("fields", .stringList, .query("fields"), maximumCount: 4)
    ],
    result: .single(dataStream),
    scopes: .analyticsReadonly,
    summary: "Returns one data stream."
  )

  public static let createDataStream = CapabilityDefinition(
    id: CapabilityID("sample.dataStreams.create"),
    field: "sampleCreateDataStream",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .analyticsAdminV1Beta,
    pathTemplate: "/v1beta/{parent}/dataStreams",
    arguments: [
      ArgumentDefinition("parent", .resourceName("properties/{property}"), .path("parent"), required: true),
      ArgumentDefinition("dataStream", .inputObject(dataStreamInput), .bodyRoot, required: true)
    ],
    result: .payload(field: "dataStream", dataStream),
    scopes: .analyticsEdit,
    summary: "Creates a data stream."
  )

  public static let deleteDataStream = CapabilityDefinition(
    id: CapabilityID("sample.dataStreams.delete"),
    field: "sampleDeleteDataStream",
    tier: .admin,
    operationClass: .delete,
    method: .delete,
    service: .analyticsAdminV1Beta,
    pathTemplate: "/v1beta/{name}",
    arguments: [
      ArgumentDefinition(
        "name",
        .resourceName("properties/{property}/dataStreams/{stream}"),
        .path("name"),
        required: true
      ),
      ArgumentDefinition("confirmName", .string, .confirm("name"), required: true)
    ],
    result: .deletion,
    scopes: .analyticsEdit,
    summary: "Deletes a data stream."
  )

  public static let all: [CapabilityDefinition] = [
    listDataStreams, getDataStream, createDataStream, deleteDataStream
  ]

  /// Every definition the given tier may link, matching how a role module
  /// contributes only its own fragment.
  public static func definitions(upTo tier: CapabilityTier) -> [CapabilityDefinition] {
    all.filter { tier.includes($0.tier) }
  }

  public static func registry(tier: CapabilityTier = .admin) throws -> CapabilityRegistry {
    try CapabilityRegistry(tier: tier, definitions: definitions(upTo: tier))
  }

  public static func planner(tier: CapabilityTier = .admin) throws -> CapabilityPlanner {
    CapabilityPlanner(registry: try registry(tier: tier))
  }

  public static func executor(
    transport: RecordingTransport,
    tier: CapabilityTier = .admin,
    clock: TestClock = TestClock(),
    retryPolicy: RetryPolicy = RetryPolicy(jitterFraction: 0),
    credentials: any CredentialProvider = RecordingCredentialProvider(),
    requestID: String = fixtureRequestID
  ) throws -> CapabilityExecutor {
    CapabilityExecutor(
      planner: try planner(tier: tier),
      transport: transport,
      credentials: credentials,
      clock: clock,
      retryPolicy: retryPolicy,
      requestIDFactory: { requestID }
    )
  }

  public static func runtime(
    transport: RecordingTransport,
    tier: CapabilityTier = .admin,
    credentials: any CredentialProvider = RecordingCredentialProvider(),
    clock: TestClock = TestClock(),
    requestID: String = fixtureRequestID
  ) throws -> GraphQLRuntime {
    GraphQLRuntime(
      executor: try executor(
        transport: transport,
        tier: tier,
        clock: clock,
        credentials: credentials,
        requestID: requestID
      ),
      requestIDFactory: { requestID }
    )
  }

  public static func invocation(
    _ definition: CapabilityDefinition,
    _ arguments: [String: JSONValue] = [:]
  ) -> CapabilityInvocation {
    CapabilityInvocation(capabilityID: definition.id, arguments: arguments)
  }
}

/// Synthetic definitions for the open-JSON passthrough contract.
///
/// They are kept out of `SampleCapabilities.all` on purpose: the schema printer
/// emits `scalar JSON` only for a registry that uses it, so a registry that does
/// not is needed to prove the omission.
public enum SampleJSONCapabilities {
  /// A Tag Manager tag carries a recursive `parameter` tree that no fixed shape
  /// can describe, which is what the open JSON leaf exists for.
  public static let tag = ModelShape(
    typeName: "SampleTag",
    fields: [
      ModelField("path", .resourceName, required: true),
      ModelField("name", .string),
      ModelField("parameter", .json)
    ]
  )

  public static let createTag = CapabilityDefinition(
    id: CapabilityID("sample.tags.create"),
    field: "sampleCreateTag",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/tags",
    arguments: [
      ArgumentDefinition(
        "parent",
        .resourceName("accounts/{account}/containers/{container}/workspaces/{workspace}"),
        .path("parent"),
        required: true
      ),
      ArgumentDefinition("tag", .json, .bodyRoot, required: true)
    ],
    result: .payload(field: "tag", tag),
    scopes: .tagManagerEditContainers,
    summary: "Creates a Tag Manager tag."
  )

  public static let all: [CapabilityDefinition] = [createTag]

  public static func registry(tier: CapabilityTier = .writer) throws -> CapabilityRegistry {
    try CapabilityRegistry(tier: tier, definitions: all)
  }

  /// An arbitrary document: a recursive parameter tree plus one value of every
  /// JSON kind, including a null, so the round trip cannot be satisfied by a
  /// re-encoding that drops or coerces anything.
  public static let arbitraryDocument: JSONValue = .object([
    "name": .string("ga4-config"),
    "type": .string("gaawc"),
    "parameter": .array([
      .object([
        "type": .string("template"), "key": .string("measurementId"), "value": .string("G-FIXTURE")
      ]),
      .object([
        "type": .string("list"),
        "key": .string("fields"),
        "list": .array([
          .object([
            "type": .string("map"),
            "map": .array([
              .object([
                "type": .string("template"), "key": .string("name"),
                "value": .string("send_page_view")
              ]),
              .object(["type": .string("boolean"), "key": .string("value"), "value": .bool(true)])
            ])
          ])
        ])
      ])
    ]),
    "absent": .null,
    "count": .int(7),
    "ratio": .double(0.5),
    "enabled": .bool(true),
    "tags": .array([.string("one"), .string("two")])
  ])

  /// An upstream tag body whose `parameter` subtree is the same document.
  public static let upstreamTagBody = """
    {"path":"accounts/1/containers/2/workspaces/3/tags/9","name":"GA4 configuration",\
    "parameter":[{"type":"template","key":"measurementId","value":"G-FIXTURE"},\
    {"type":"list","key":"fields","list":[{"type":"map","map":[]}]}],\
    "unmodelledUpstreamField":"ignored"}
    """
}

/// The fixed request id every fixture runtime stamps, so envelope assertions are
/// exact rather than "some uuid".
public let fixtureRequestID = "fixture-request-id"

/// Canned upstream bodies.
public enum SampleFixtures {
  public static let dataStream = """
    {"name":"properties/123456/dataStreams/789","displayName":"Web stream",\
    "type":"WEB_DATA_STREAM","createTime":"2026-01-02T03:04:05Z",\
    "webStreamData":{"defaultUri":"https://example.com","measurementId":"G-FIXTURE"}}
    """

  public static let dataStreamPage = """
    {"dataStreams":[\(dataStream)],"nextPageToken":"opaque-next-page-token"}
    """

  /// A Google error envelope whose free-text message echoes request content. No
  /// part of it may appear in a mapped error message.
  public static let errorEnvelope = """
    {"error":{"code":403,"message":"Caller does not have permission on properties/123456 \
    using token fixture-token-not-a-secret","status":"PERMISSION_DENIED",\
    "details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"ACCESS_DENIED"}]}}
    """

  /// The distinctive fragments of the free-text message, asserted absent from
  /// every error a caller can see.
  public static let leakMarkers = ["fixture-token-not-a-secret", "properties/123456", "ACCESS_DENIED"]
}
