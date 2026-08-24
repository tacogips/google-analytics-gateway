import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// The unsupported-syntax contract from `design-docs/specs/graphql-schema.md`.
///
/// Every case asserts two things: the document is refused with
/// `VALIDATION_ERROR`, and neither the transport nor the credential provider was
/// touched. The second half is the part that matters — widening the syntax must
/// never widen capability access, so an unsupported document must fail before
/// anything can resolve a credential or reach Google.
@Suite("GraphQL rejection matrix")
struct GraphQLRejectionTests {
  static let getDocument = """
    { sampleDataStream(name: "properties/123456/dataStreams/789") { name } }
    """

  /// One unsupported document and the fragment of the refusal that names the
  /// reason. The reason is asserted so a case cannot pass for an unrelated
  /// validation failure, such as an unknown field standing in for a syntax cap.
  struct RejectedDocument: Sendable, CustomStringConvertible {
    let label: String
    let document: String
    let reason: String

    init(_ label: String, _ document: String, _ reason: String) {
      self.label = label
      self.document = document
      self.reason = reason
    }

    var description: String { label }
  }

  static let rejectedDocuments: [RejectedDocument] = [
    RejectedDocument(
      "bare fragment definition",
      "fragment Extra on SampleDataStream { displayName }",
      "Fragment definitions are not supported"
    ),
    RejectedDocument(
      "operation followed by a fragment definition",
      """
      query Named { sampleDataStream(name: "properties/1/dataStreams/2") { name } }
      fragment Extra on SampleDataStream { displayName }
      """,
      "exactly one executable operation"
    ),
    RejectedDocument(
      "fragment spread",
      "{ sampleDataStream(name: \"properties/1/dataStreams/2\") { ...Extra } }",
      "Fragment spreads are not supported"
    ),
    RejectedDocument(
      "field alias",
      "{ stream: sampleDataStream(name: \"properties/1/dataStreams/2\") { name } }",
      "Field aliases are not supported"
    ),
    RejectedDocument(
      "directive",
      "{ sampleDataStream(name: \"properties/1/dataStreams/2\") @include(if: true) { name } }",
      "Directives are not supported"
    ),
    RejectedDocument(
      "subscription operation",
      "subscription Watch { sampleDataStream(name: \"properties/1/dataStreams/2\") { name } }",
      "Subscriptions are not supported"
    ),
    RejectedDocument(
      "schema introspection",
      "{ __schema { queryType { name } } }",
      "Unknown query field __schema"
    ),
    RejectedDocument(
      "typename introspection",
      "{ sampleDataStream(name: \"properties/1/dataStreams/2\") { __typename } }",
      "__typename is not part of type SampleDataStream"
    ),
    RejectedDocument(
      "variable default value",
      """
      query Named($name: String = "properties/1/dataStreams/2") {
        sampleDataStream(name: $name) { name }
      }
      """,
      "Default variable values are not supported"
    ),
    RejectedDocument(
      "multiple operations",
      """
      query First { sampleDataStream(name: "properties/1/dataStreams/2") { name } }
      query Second { sampleDataStream(name: "properties/1/dataStreams/3") { name } }
      """,
      "exactly one executable operation"
    ),
    RejectedDocument(
      "multi-field mutation",
      """
      mutation {
        sampleCreateDataStream(parent: "properties/1", dataStream: {
          displayName: "One", streamKind: WEB_DATA_STREAM
        }) { dataStream { name } }
        sampleDeleteDataStream(
          name: "properties/1/dataStreams/2", confirmName: "properties/1/dataStreams/2"
        ) { deletedName }
      }
      """,
      "exactly one top-level field"
    ),
    RejectedDocument(
      "eleven top-level query fields",
      "{ \((0..<11).map { "field\($0)" }.joined(separator: " ")) }",
      "at most 10 top-level fields"
    ),
    RejectedDocument(
      "selection nested nine levels deep",
      "{ a { b { c { d { e { f { g { h { i } } } } } } } } }",
      "nest at most 8 levels deep"
    ),
    RejectedDocument(
      "document larger than 64KB",
      "{ sampleDataStreams(parent: \"properties/1\") { nodes { name } } }\n"
        + String(repeating: "# padding comment line\n", count: 3_000),
      "exceeds the \(GraphQLParser.maximumDocumentLength) character limit"
    )
  ]

  @Test("Unsupported syntax fails validation before any credential or transport use", arguments: rejectedDocuments)
  func rejectsUnsupportedSyntax(_ rejected: RejectedDocument) async throws {
    let label = rejected.label
    let transport = RecordingTransport()
    let credentials = RecordingCredentialProvider()
    let runtime = try SampleCapabilities.runtime(transport: transport, credentials: credentials)

    let response = await runtime.execute(document: rejected.document)

    #expect(response.data == nil, "\(label) produced data")
    #expect(response.errors.count == 1, "\(label) produced \(response.errors.count) errors")
    #expect(response.errors.first?.code == .validationError, "\(label): \(response.errors)")
    #expect(
      response.errors.first?.message.contains(rejected.reason) == true,
      "\(label) was refused for the wrong reason: \(response.errors.first?.message ?? "none")"
    )
    #expect(response.exitCode == .usage, "\(label) did not map to the usage exit code")
    #expect(await transport.requestCount == 0, "\(label) reached the transport")
    #expect(credentials.resolutionCount == 0, "\(label) resolved a credential")
    #expect(credentials.refreshCount == 0, "\(label) refreshed a credential")
  }

  @Test("The document size cap is measured in characters, not requests")
  func documentSizeCapIsExact() throws {
    let parser = GraphQLParser()
    let padding = String(repeating: " ", count: GraphQLParser.maximumDocumentLength - Self.getDocument.count)
    #expect(throws: Never.self) { try parser.parse(Self.getDocument + padding) }
    #expect(throws: GatewayError.self) { try parser.parse(Self.getDocument + padding + " ") }
  }

  @Test("A mutation field is unknown to a reader binary rather than dispatchable")
  func readerRuntimeRefusesSampleMutation() async throws {
    let transport = RecordingTransport()
    let credentials = RecordingCredentialProvider()
    let runtime = try SampleCapabilities.runtime(
      transport: transport, tier: .reader, credentials: credentials
    )

    let response = await runtime.execute(document: """
      mutation {
        sampleCreateDataStream(parent: "properties/1", dataStream: {
          displayName: "One", streamKind: WEB_DATA_STREAM
        }) { dataStream { name } }
      }
      """)

    #expect(response.errors.first?.code == .validationError)
    #expect(response.errors.first?.message.contains("sampleCreateDataStream") == true)
    #expect(await transport.requestCount == 0)
    #expect(credentials.resolutionCount == 0)
  }

  @Test("An undeclared variable is refused before the capability is invoked")
  func undeclaredVariableIsRefused() async throws {
    let transport = RecordingTransport()
    let credentials = RecordingCredentialProvider()
    let runtime = try SampleCapabilities.runtime(transport: transport, credentials: credentials)

    let response = await runtime.execute(
      document: "{ sampleDataStream(name: $name) { name } }",
      variables: ["name": .string("properties/1/dataStreams/2")]
    )

    #expect(response.errors.first?.code == .validationError)
    #expect(await transport.requestCount == 0)
    #expect(credentials.resolutionCount == 0)
  }

  @Test("An unknown selection field is refused before the capability is invoked")
  func unknownSelectionFieldIsRefused() async throws {
    let transport = RecordingTransport()
    let credentials = RecordingCredentialProvider()
    let runtime = try SampleCapabilities.runtime(transport: transport, credentials: credentials)

    let response = await runtime.execute(
      document: "{ sampleDataStream(name: \"properties/1/dataStreams/2\") { unknownField } }"
    )

    #expect(response.errors.first?.code == .validationError)
    #expect(response.errors.first?.message.contains("SampleDataStream") == true)
    #expect(await transport.requestCount == 0)
    #expect(credentials.resolutionCount == 0)
  }
}
