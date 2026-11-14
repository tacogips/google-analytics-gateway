import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// The supported half of the GraphQL contract: a document that parses is planned
/// through the same capability planner the typed SDK uses, executed against the
/// injected transport, and projected down to exactly the fields the caller asked
/// for.
@Suite("GraphQL execution")
struct GraphQLExecutionTests {
  @Test("A query returns only the selected fields of the projected entity")
  func projectsSelectedFields() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(document: """
      { sampleDataStream(name: "properties/123456/dataStreams/789") {
          name
          webStreamData { defaultUri }
        } }
      """)

    #expect(response.errors.isEmpty, "\(response.errors)")
    let stream = try #require(response.data?["sampleDataStream"]?.objectValue)
    #expect(stream.keys.sorted() == ["name", "webStreamData"])
    #expect(stream["name"]?.stringValue == "properties/123456/dataStreams/789")
    let nested = try #require(stream["webStreamData"]?.objectValue)
    #expect(nested.keys.sorted() == ["defaultUri"])
    #expect(nested["defaultUri"]?.stringValue == "https://example.com")
  }

  @Test("An upstream field name never reaches the projected result")
  func projectsStableFieldNames() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(document: """
      { sampleDataStream(name: "properties/123456/dataStreams/789") { streamKind } }
      """)

    let stream = try #require(response.data?["sampleDataStream"]?.objectValue)
    #expect(stream["streamKind"]?.stringValue == "WEB_DATA_STREAM")
    #expect(stream["type"] == nil)
  }

  @Test("The success envelope carries the request id and no errors key")
  func successEnvelopeShape() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(document: """
      { sampleDataStream(name: "properties/123456/dataStreams/789") { name } }
      """)

    #expect(response.requestID == fixtureRequestID)
    let envelope = try #require(response.stableValue.objectValue)
    #expect(envelope.keys.sorted() == ["data", "extensions"])
    #expect(envelope["extensions"]?["requestId"]?.stringValue == fixtureRequestID)
    #expect(response.exitCode == .success)
  }

  @Test("The failure envelope carries a null data field and a stable error code")
  func failureEnvelopeShape() async throws {
    let transport = RecordingTransport(outcomes: [
      .response(UpstreamResponse(statusCode: 404, body: Data(SampleFixtures.errorEnvelope.utf8)))
    ])
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(document: """
      { sampleDataStream(name: "properties/123456/dataStreams/789") { name } }
      """)

    let envelope = try #require(response.stableValue.objectValue)
    #expect(envelope["data"]?.isNull == true)
    let errors = try #require(envelope["errors"]?.arrayValue)
    #expect(errors.count == 1)
    #expect(errors.first?["extensions"]?["code"]?.stringValue == "NOT_FOUND")
    #expect(errors.first?["extensions"]?["requestId"]?.stringValue == fixtureRequestID)
    #expect(response.exitCode == .rejectedRequest)
  }

  @Test("A connection query maps pagination arguments and returns nodes with page info")
  func projectsConnection() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStreamPage)
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(document: """
      { sampleDataStreams(parent: "properties/123456", page: { pageSize: 50 }) {
          nodes { name }
          pageInfo { resultCount nextPageToken }
        } }
      """)

    #expect(response.errors.isEmpty, "\(response.errors)")
    let connection = try #require(response.data?["sampleDataStreams"]?.objectValue)
    let nodes = try #require(connection["nodes"]?.arrayValue)
    #expect(nodes.count == 1)
    #expect(nodes.first?["name"]?.stringValue == "properties/123456/dataStreams/789")
    #expect(nodes.first?.objectValue?.keys.sorted() == ["name"])
    #expect(connection["pageInfo"]?["resultCount"]?.intValue == 1)
    #expect(connection["pageInfo"]?["nextPageToken"]?.stringValue == "opaque-next-page-token")

    let recorded = try await transport.firstRequest()
    #expect(recorded.query["pageSize"] == "50")
    #expect(recorded.query["pageToken"] == nil)
  }

  @Test("A mutation sends the declared upstream body and projects its payload")
  func executesMutation() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(document: """
      mutation {
        sampleCreateDataStream(parent: "properties/123456", dataStream: {
          displayName: "Web stream"
          streamKind: WEB_DATA_STREAM
          webStreamData: { defaultUri: "https://example.com" }
        }) { dataStream { name displayName } }
      }
      """)

    #expect(response.errors.isEmpty, "\(response.errors)")
    let payload = try #require(response.data?["sampleCreateDataStream"]?.objectValue)
    let stream = try #require(payload["dataStream"]?.objectValue)
    #expect(stream.keys.sorted() == ["displayName", "name"])

    let recorded = try await transport.firstRequest()
    #expect(recorded.method == .post)
    #expect(recorded.path == "/v1beta/properties/123456/dataStreams")
    #expect(recorded.bodyDescription == """
      json:{"displayName":"Web stream","type":"WEB_DATA_STREAM",\
      "webStreamData":{"defaultUri":"https://example.com"}}
      """)
    #expect(recorded.hasAuthorization)
    #expect(!recorded.headerNames.contains("Authorization"))
  }

  @Test("Variables supply argument values without widening what a field accepts")
  func resolvesVariables() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let runtime = try SampleCapabilities.runtime(transport: transport)

    let response = await runtime.execute(
      document: """
        query Named($name: String!) { sampleDataStream(name: $name) { name } }
        """,
      variables: ["name": .string("properties/123456/dataStreams/789")]
    )

    #expect(response.errors.isEmpty, "\(response.errors)")
    let recorded = try await transport.firstRequest()
    #expect(recorded.path == "/v1beta/properties/123456/dataStreams/789")
  }

  @Test("The printed schema describes only the fields this registry can execute")
  func printsSchemaFromRegistry() throws {
    let runtime = try SampleCapabilities.runtime(transport: RecordingTransport(), tier: .reader)
    let schema = runtime.printedSchema()

    #expect(schema.contains("type Query {"))
    #expect(schema.contains("sampleDataStreams("))
    #expect(schema.contains("sampleDataStream("))
    #expect(!schema.contains("type Mutation {"))
    #expect(!schema.contains("sampleCreateDataStream"))
    #expect(!schema.contains("sampleDeleteDataStream"))
  }
}
