import Foundation
import Testing

import GoogleAnalyticsGatewayCore

/// Selection validation runs before authentication and transport, so these
/// assert that an unsupported field fails locally rather than becoming a Google
/// request that returns a confusing error.
@Suite("GraphQL selection validation and projection")
struct GraphQLSelectionProjectionTests {
  private static let webStreamShape = ModelShape(
    typeName: "WebStreamData",
    fields: [
      ModelField("measurementId", .string),
      ModelField("defaultUri", upstream: "defaultUri", .string)
    ]
  )

  private static let dataStreamShape = ModelShape(
    typeName: "DataStream",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("createTime", .dateTime),
      ModelField("webStreamData", .object(webStreamShape))
    ]
  )

  private func field(
    _ name: String,
    _ selections: [GraphQLField] = [],
    arguments: [String: GraphQLInputValue] = [:]
  ) -> GraphQLField {
    GraphQLField(name: name, arguments: arguments, selections: selections)
  }

  // MARK: - Single, list, and file-output results

  @Test("A selection of declared fields validates")
  func acceptsDeclaredFields() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("name"), self.field("displayName")],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
  }

  @Test("An undeclared field is rejected and the schema command is named")
  func rejectsUndeclaredField() throws {
    let error = #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("secretInternalField")],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
    #expect(error?.code == .validationError)
    #expect(error?.recoveryGuidance?.contains("graphql schema") == true)
  }

  @Test("An empty selection set on an object result is rejected")
  func rejectsEmptySelection() throws {
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
  }

  @Test("A scalar field cannot carry a selection set")
  func rejectsSelectionOnScalar() throws {
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("displayName", [self.field("name")])],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
  }

  @Test("A composite field requires a selection set")
  func rejectsBareComposite() throws {
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("webStreamData")],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
  }

  @Test("A nested composite field validates against its own shape")
  func validatesNestedShape() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("webStreamData", [self.field("measurementId")])],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("webStreamData", [self.field("nope")])],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
  }

  @Test("An output field never accepts arguments")
  func rejectsArgumentsOnOutputField() throws {
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("displayName", arguments: ["first": .int(1)])],
        for: .single(Self.dataStreamShape),
        fieldName: "dataStream"
      )
    }
  }

  @Test("A list result validates against the element shape")
  func validatesListResult() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("name")],
        for: .list(collection: "dataStreams", Self.dataStreamShape),
        fieldName: "dataStreams"
      )
    }
  }

  @Test("A file-output result validates against the written-file shape")
  func validatesFileOutputResult() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("path"), self.field("byteCount")],
        for: .fileOutput(FileOutputShape.shape),
        fieldName: "download"
      )
    }
  }

  // MARK: - Connections

  @Test("A connection accepts nodes and pageInfo")
  func acceptsConnectionFields() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [
          self.field("nodes", [self.field("name")]),
          self.field("pageInfo", [self.field("resultCount"), self.field("nextPageToken")])
        ],
        for: .connection(collection: "dataStreams", Self.dataStreamShape),
        fieldName: "dataStreams"
      )
    }
  }

  @Test("A connection rejects a field that is neither nodes nor pageInfo")
  func rejectsUnknownConnectionField() throws {
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("edges", [self.field("name")])],
        for: .connection(collection: "dataStreams", Self.dataStreamShape),
        fieldName: "dataStreams"
      )
    }
  }

  @Test("pageInfo exposes only its two documented scalars")
  func restrictsPageInfoFields() throws {
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("pageInfo", [self.field("totalCount")])],
        for: .connection(collection: "dataStreams", Self.dataStreamShape),
        fieldName: "dataStreams"
      )
    }
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("pageInfo", [self.field("resultCount", [self.field("x")])])],
        for: .connection(collection: "dataStreams", Self.dataStreamShape),
        fieldName: "dataStreams"
      )
    }
  }

  // MARK: - Payloads and deletions

  @Test("A payload exposes only its wrapper field")
  func restrictsPayloadFields() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("dataStream", [self.field("name")])],
        for: .payload(field: "dataStream", Self.dataStreamShape),
        fieldName: "createDataStream"
      )
    }
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("other", [self.field("name")])],
        for: .payload(field: "dataStream", Self.dataStreamShape),
        fieldName: "createDataStream"
      )
    }
  }

  /// A Google delete is confirmed by the resource name it removed, so the
  /// payload carries `deletedName` and nothing else. Accepting any other field
  /// here would validate a selection the projection cannot answer.
  @Test("A deletion payload exposes only the confirmed resource name")
  func restrictsDeletionFields() throws {
    #expect(throws: Never.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("deletedName")],
        for: .deletion,
        fieldName: "deleteProperty"
      )
    }
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [self.field("deletedId")],
        for: .deletion,
        fieldName: "deleteProperty"
      )
    }
    #expect(throws: GatewayError.self) {
      try GraphQLSelectionProjection.validate(
        selections: [],
        for: .deletion,
        fieldName: "deleteProperty"
      )
    }
  }

  // MARK: - Projection

  @Test("Projection keeps only the selected fields")
  func projectsSelectedFields() throws {
    let value = JSONValue.object([
      "name": .string("properties/1/dataStreams/2"),
      "displayName": .string("Web"),
      "createTime": .string("2026-01-01T00:00:00Z")
    ])
    let projected = GraphQLSelectionProjection.project(value, selections: [field("name")])
    #expect(projected == .object(["name": .string("properties/1/dataStreams/2")]))
  }

  @Test("A selected field the result omits projects as null")
  func projectsMissingFieldAsNull() throws {
    let projected = GraphQLSelectionProjection.project(
      .object(["name": .string("properties/1")]),
      selections: [field("name"), field("displayName")]
    )
    #expect(projected == .object(["name": .string("properties/1"), "displayName": .null]))
  }

  @Test("Projection maps across a list, narrowing every element")
  func projectsAcrossList() throws {
    let value = JSONValue.array([
      .object(["name": .string("a"), "displayName": .string("A")]),
      .object(["name": .string("b"), "displayName": .string("B")])
    ])
    let projected = GraphQLSelectionProjection.project(value, selections: [field("name")])
    #expect(projected == .array([.object(["name": .string("a")]), .object(["name": .string("b")])]))
  }

  @Test("Projection recurses into a nested selection")
  func projectsNestedSelection() throws {
    let value = JSONValue.object([
      "name": .string("properties/1"),
      "webStreamData": .object([
        "measurementId": .string("G-ABC"),
        "defaultUri": .string("https://example.test")
      ])
    ])
    let projected = GraphQLSelectionProjection.project(
      value,
      selections: [field("webStreamData", [field("measurementId")])]
    )
    #expect(projected == .object(["webStreamData": .object(["measurementId": .string("G-ABC")])]))
  }

  @Test("An empty selection set returns the value unchanged")
  func projectsEmptySelectionAsIdentity() throws {
    let value = JSONValue.object(["name": .string("properties/1")])
    #expect(GraphQLSelectionProjection.project(value, selections: []) == value)
  }

  @Test("A scalar value projects as itself")
  func projectsScalarAsIdentity() throws {
    #expect(GraphQLSelectionProjection.project(.int(7), selections: [field("name")]) == .int(7))
  }
}
