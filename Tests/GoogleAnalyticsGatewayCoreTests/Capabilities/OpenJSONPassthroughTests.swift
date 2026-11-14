import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// The open JSON escape hatch. It exists for the Google structures that are
/// recursive or open by design, and its whole safety argument is structural:
/// the document is never inspected, so registration must confine it to a
/// request body, and the selection contract must treat it as a leaf. Both halves
/// are asserted here, along with the round trip that makes it worth having.
@Suite("Open JSON passthrough")
struct OpenJSONPassthroughTests {
  @Test("A registry using open JSON in a body is coherent")
  func jsonRegistryIsCoherent() throws {
    let registry = try SampleJSONCapabilities.registry()
    #expect(registry.coherenceProblems().isEmpty, "\(registry.coherenceProblems())")
    #expect(SampleJSONCapabilities.createTag.coherenceProblems().isEmpty)
  }

  @Test("An arbitrary JSON document reaches the request body verbatim")
  func jsonBodyRoundTripsVerbatim() throws {
    let planner = CapabilityPlanner(registry: try SampleJSONCapabilities.registry())
    let plan = try planner.plan(CapabilityInvocation(
      capabilityID: SampleJSONCapabilities.createTag.id,
      arguments: [
        "parent": .string("accounts/1/containers/2/workspaces/3"),
        "tag": SampleJSONCapabilities.arbitraryDocument
      ]
    ))

    guard case .json(let sent) = plan.request.body else {
      Issue.record("Expected a JSON request body, got \(plan.request.body)")
      return
    }
    #expect(sent == SampleJSONCapabilities.arbitraryDocument)
    // Nothing was dropped, coerced, or re-keyed on the way through.
    #expect(sent["absent"]?.isNull == true)
    #expect(sent["count"]?.intValue == 7)
    #expect(sent["ratio"]?.doubleValue == 0.5)
    #expect(sent["enabled"]?.boolValue == true)
    #expect(sent["parameter"]?.arrayValue?.count == 2)
    #expect(plan.request.path == "/tagmanager/v2/accounts/1/containers/2/workspaces/3/tags")
  }

  @Test("An open JSON model field is projected exactly as Google sent it")
  func jsonModelFieldIsVerbatim() throws {
    let projected = try ResponseProjection.result(
      for: SampleJSONCapabilities.createTag,
      body: Data(SampleJSONCapabilities.upstreamTagBody.utf8)
    )

    let tag = try #require(projected["tag"]?.objectValue)
    #expect(tag["path"]?.stringValue == "accounts/1/containers/2/workspaces/3/tags/9")
    #expect(tag["parameter"] == .array([
      .object([
        "type": .string("template"), "key": .string("measurementId"), "value": .string("G-FIXTURE")
      ]),
      .object([
        "type": .string("list"),
        "key": .string("fields"),
        "list": .array([.object(["type": .string("map"), "map": .array([])])])
      ])
    ]))
    // The open field does not widen the projection: an upstream key the shape
    // does not declare is still dropped.
    #expect(tag["unmodelledUpstreamField"] == nil)
  }

  @Test("An open JSON value of any kind survives the projection")
  func jsonModelFieldAcceptsEveryKind() throws {
    for document in ["null", "42", "\"text\"", "[1,2,3]", "{\"nested\":{\"deep\":true}}"] {
      let body = "{\"path\":\"accounts/1/containers/2/workspaces/3/tags/9\",\"parameter\":\(document)}"
      let projected = try ResponseProjection.result(
        for: SampleJSONCapabilities.createTag,
        body: Data(body.utf8)
      )
      let expected = try JSONValue.decodeJSON(Data(document.utf8))
      #expect(projected["tag"]?["parameter"] == expected, "\(document) did not survive")
    }
  }

  @Test("Selecting inside an open JSON field is a validation error")
  func rejectsSubSelectionOnJSONLeaf() throws {
    do {
      try GraphQLSelectionProjection.validate(
        selections: [
          GraphQLField(name: "tag", arguments: [:], selections: [
            GraphQLField(name: "parameter", arguments: [:], selections: [
              GraphQLField(name: "key", arguments: [:], selections: [])
            ])
          ])
        ],
        for: SampleJSONCapabilities.createTag.result,
        fieldName: "sampleCreateTag"
      )
      Issue.record("Expected a sub-selection on an open JSON leaf to be refused")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.message.contains("parameter"))
    }
  }

  @Test("Selecting the open JSON field itself is accepted")
  func acceptsSelectingTheJSONLeaf() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [
          GraphQLField(name: "tag", arguments: [:], selections: [
            GraphQLField(name: "path", arguments: [:], selections: []),
            GraphQLField(name: "parameter", arguments: [:], selections: [])
          ])
        ],
        for: SampleJSONCapabilities.createTag.result,
        fieldName: "sampleCreateTag"
      )
    }
  }

  @Test("An end-to-end mutation carries the document out and the subtree back")
  func executesJSONMutationThroughTheRuntime() async throws {
    let transport = RecordingTransport.succeeding(json: SampleJSONCapabilities.upstreamTagBody)
    let runtime = GraphQLRuntime(
      executor: CapabilityExecutor(
        planner: CapabilityPlanner(registry: try SampleJSONCapabilities.registry()),
        transport: transport,
        credentials: RecordingCredentialProvider(),
        clock: TestClock(),
        requestIDFactory: { fixtureRequestID }
      ),
      requestIDFactory: { fixtureRequestID }
    )

    let response = await runtime.execute(document: """
      mutation {
        sampleCreateTag(parent: "accounts/1/containers/2/workspaces/3", tag: {
          name: "ga4-config"
          parameter: [{ type: "template", key: "measurementId", value: "G-FIXTURE" }]
        }) { tag { path parameter } }
      }
      """)

    #expect(response.errors.isEmpty, "\(response.errors)")
    let tag = try #require(response.data?["sampleCreateTag"]?["tag"]?.objectValue)
    #expect(tag.keys.sorted() == ["parameter", "path"])
    #expect(tag["parameter"]?.arrayValue?.count == 2)

    let recorded = try await transport.firstRequest()
    #expect(recorded.bodyDescription == """
      json:{"name":"ga4-config","parameter":[{"key":"measurementId","type":"template",\
      "value":"G-FIXTURE"}]}
      """)
  }

  static func queryBoundJSON(binding: ArgumentBinding) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID("sample.tags.list"),
      field: "sampleTags",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/accounts/1/containers/2/workspaces/3/tags",
      arguments: [ArgumentDefinition("filter", .json, binding)],
      result: .single(SampleJSONCapabilities.tag),
      scopes: .tagManagerReadonly,
      summary: "Lists tags."
    )
  }

  @Test("Open JSON bound outside a request body refuses to register")
  func refusesOpenJSONOutsideARequestBody() throws {
    for binding in [ArgumentBinding.query("filter"), .queryList("filter"), .destinationPath] {
      let definition = Self.queryBoundJSON(binding: binding)
      #expect(
        definition.coherenceProblems().contains { $0.contains("outside a request body") },
        "\(binding) was not refused: \(definition.coherenceProblems())"
      )
      #expect(throws: GatewayError.self) {
        try CapabilityRegistry(tier: .reader, definitions: [definition])
      }
    }
  }

  @Test("Open JSON nested inside an input object is refused the same way")
  func refusesOpenJSONInsideAnInputObject() throws {
    let definition = CapabilityDefinition(
      id: CapabilityID("sample.tags.update"),
      field: "sampleUpdateTag",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}",
      arguments: [
        ArgumentDefinition(
          "path",
          .resourceName("accounts/{account}/containers/{container}/workspaces/{workspace}/tags/{tag}"),
          .path("path"),
          required: true
        ),
        ArgumentDefinition(
          "tag",
          .inputObject(InputObjectShape(
            typeName: "SampleTagInput",
            fields: [ArgumentDefinition("parameter", .json, .query("parameter"))]
          )),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "tag", SampleJSONCapabilities.tag),
      scopes: .tagManagerEditContainers,
      summary: "Updates a tag."
    )

    #expect(definition.coherenceProblems().contains { $0.contains("outside a request body") })
    #expect(throws: GatewayError.self) {
      try CapabilityRegistry(tier: .writer, definitions: [definition])
    }
  }

  @Test("The JSON scalar is printed only by a schema that uses it")
  func printsJSONScalarOnlyWhenUsed() throws {
    let jsonSchema = GraphQLSchemaPrinter(registry: try SampleJSONCapabilities.registry()).print()
    #expect(jsonSchema.contains("scalar JSON"))
    #expect(jsonSchema.contains("parameter: JSON"))

    let plainSchema = GraphQLSchemaPrinter(registry: try SampleCapabilities.registry()).print()
    #expect(!plainSchema.contains("scalar JSON"), "The scalar leaked into a schema that never uses it")
    #expect(!plainSchema.contains(": JSON"))
  }
}
