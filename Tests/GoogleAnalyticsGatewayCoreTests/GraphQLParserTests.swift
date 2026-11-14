import Foundation
import Testing

import GoogleAnalyticsGatewayCore

/// The parser is the whole rejection surface: every unsupported construct has to
/// fail here, before credential resolution or any Google request.
@Suite("GraphQL parser scope")
struct GraphQLParserScopeTests {
  private let parser = GraphQLParser()

  @Test("A single named query with variables parses")
  func parsesQuery() throws {
    let document = try parser.parse("""
      query Stream($name: String!) { dataStream(name: $name) { name displayName } }
      """)
    #expect(document.operation.type == .query)
    #expect(document.operation.name == "Stream")
    #expect(document.operation.variableDefinitions.map(\.name) == ["name"])
    #expect(document.operation.selections.first?.name == "dataStream")
    #expect(document.operation.selections.first?.selections.map(\.name) == ["name", "displayName"])
  }

  @Test("A required variable is distinguished from an optional one")
  func recordsVariableRequiredness() throws {
    let document = try parser.parse(
      "query Q($a: String!, $b: Int) { property(name: $a, limit: $b) { name } }"
    )
    let definitions = document.operation.variableDefinitions
    #expect(definitions.map(\.name) == ["a", "b"])
    #expect(definitions.map(\.isRequired) == [true, false])
    #expect(definitions.map(\.typeName) == ["String", "Int"])
  }

  @Test("A list variable type records its inner nullability")
  func parsesListVariableTypes() throws {
    let document = try parser.parse("query Q($a: [String!]!) { report(dimensions: $a) { name } }")
    let definition = try #require(document.operation.variableDefinitions.first)
    #expect(definition.typeName == "[String!]!")
    #expect(definition.isRequired)
  }

  @Test("An anonymous shorthand selection set parses as a query")
  func parsesShorthand() throws {
    let document = try parser.parse("{ account { name displayName } }")
    #expect(document.operation.type == .query)
    #expect(document.operation.name == nil)
  }

  @Test("A mutation is distinguished from a query")
  func parsesMutation() throws {
    let document = try parser.parse(
      #"mutation { createDataStream(parent: "properties/1") { dataStream { name } } }"#
    )
    #expect(document.operation.type == .mutation)
    #expect(document.operation.type.isMutation)
  }

  @Test("Enum values stay distinct from strings")
  func parsesEnumValues() throws {
    let document = try parser.parse("{ dataStreams(type: WEB_DATA_STREAM) { nodes { name } } }")
    let argument = document.operation.selections.first?.arguments["type"]
    #expect(argument == .enumeration("WEB_DATA_STREAM"))
    #expect(argument != .string("WEB_DATA_STREAM"))
  }

  @Test("Boolean and null literals are keywords, not enum values")
  func parsesKeywordLiterals() throws {
    let document = try parser.parse("{ f(a: true, b: false, c: null) { name } }")
    let arguments = document.operation.selections.first?.arguments
    #expect(arguments?["a"] == .bool(true))
    #expect(arguments?["b"] == .bool(false))
    #expect(arguments?["c"] == .null)
  }

  @Test("List and input object argument literals nest")
  func parsesCompositeLiterals() throws {
    let document = try parser.parse(
      #"{ report(ranges: [{start: "2026-01-01"}], limit: 5) { name } }"#
    )
    let arguments = try #require(document.operation.selections.first?.arguments)
    #expect(arguments["ranges"] == .list([.object(["start": .string("2026-01-01")])]))
    #expect(arguments["limit"] == .int(5))
  }

  /// Google display names carry real text, so a string argument has to survive
  /// escaping intact. A character outside the basic multilingual plane is
  /// expressed as a surrogate pair, which is only meaningful read as a pair.
  @Test("String escapes decode, including a surrogate pair")
  func decodesStringEscapes() throws {
    // A raw Swift literal, so every backslash below reaches the lexer as the
    // escape the GraphQL document actually contains rather than one Swift has
    // already decoded.
    let document = try parser.parse(
      #"{ property(name: "a\tb\"c\\dAé😀z") { name } }"#
    )
    let argument = document.operation.selections.first?.arguments["name"]
    // The last two escapes are one surrogate pair and must decode to the single
    // scalar they name, not to two unpaired halves.
    #expect(argument == .string("a\tb\"c\\dA\u{E9}\u{1F600}z"))
  }

  /// A document using syntax outside the constrained subset.
  struct UnsupportedDocument: Sendable, CustomTestStringConvertible {
    let name: String
    let document: String

    var testDescription: String { name }
  }

  static let unsupportedDocuments: [UnsupportedDocument] = [
    .init(
      name: "fragment definition",
      document: "fragment F on Property { name } query { property(name: \"1\") { ...F } }"
    ),
    .init(name: "fragment spread", document: "{ property(name: \"1\") { ...Fields } }"),
    .init(name: "directive", document: "{ property(name: \"1\") @include(if: true) { name } }"),
    .init(name: "alias", document: "{ renamed: property(name: \"1\") { name } }"),
    .init(name: "subscription", document: "subscription { property(name: \"1\") { name } }"),
    .init(
      name: "two operations",
      document: "query A { account { name } } query B { account { name } }"
    ),
    .init(name: "empty document", document: "   "),
    .init(name: "unterminated selection", document: "{ property(name: \"1\") { name "),
    .init(name: "duplicate field", document: "{ account { name name } }"),
    .init(name: "duplicate argument", document: "{ property(name: \"1\", name: \"2\") { name } }"),
    .init(
      name: "default variable value",
      document: "query Q($a: String! = \"x\") { property(name: $a) { name } }"
    ),
    .init(name: "block string", document: "{ property(name: \"\"\"x\"\"\") { name } }"),
    .init(name: "duplicate input object field", document: "{ f(a: {x: 1, x: 2}) { name } }"),
    .init(name: "unterminated list literal", document: "{ f(a: [1, 2) { name } }"),
    .init(name: "missing argument colon", document: "{ f(a 1) { name } }"),
    .init(name: "keyword before a selection set", document: "widget { name }")
  ]

  @Test("Unsupported syntax is rejected", arguments: unsupportedDocuments)
  func rejectsUnsupportedSyntax(testCase: UnsupportedDocument) throws {
    #expect(throws: GatewayError.self, "\(testCase.name) must be rejected") {
      _ = try self.parser.parse(testCase.document)
    }
  }

  @Test("A rejection is a validation error, so it exits as a usage failure")
  func rejectionsAreValidationErrors() throws {
    let error = #expect(throws: GatewayError.self) {
      _ = try self.parser.parse("{ renamed: property(name: \"1\") { name } }")
    }
    #expect(error?.code == .validationError)
    #expect(error?.exitCode == .usage)
  }

  @Test("A mutation document must contain exactly one top-level field")
  func mutationsAreSingleField() throws {
    #expect(throws: GatewayError.self) {
      _ = try self.parser.parse("""
        mutation { createDataStream(parent: "properties/1") { dataStream { name } }
                   createDataStream2(parent: "properties/2") { dataStream { name } } }
        """)
    }
  }

  @Test("An operation must select at least one field")
  func rejectsEmptySelectionSet() throws {
    #expect(throws: GatewayError.self) { _ = try self.parser.parse("{ }") }
  }

  @Test("Selection depth and top-level field count are bounded")
  func boundedDocuments() throws {
    let deep = String(repeating: "{ a ", count: 12) + String(repeating: "}", count: 12)
    #expect(throws: GatewayError.self) { _ = try self.parser.parse(deep) }

    let wide = "{ " + (1...12).map { "f\($0) { name }" }.joined(separator: " ") + " }"
    #expect(throws: GatewayError.self) { _ = try self.parser.parse(wide) }
  }

  @Test("A document at the depth and width limits is accepted")
  func acceptsDocumentsAtTheLimit() throws {
    let depth = GraphQLParser.maximumSelectionDepth
    let deep = String(repeating: "{ a ", count: depth) + String(repeating: "}", count: depth)
    #expect(throws: Never.self) { _ = try self.parser.parse(deep) }

    let width = GraphQLParser.maximumTopLevelQueryFields
    let wide = "{ " + (1...width).map { "f\($0) { name }" }.joined(separator: " ") + " }"
    #expect(throws: Never.self) { _ = try self.parser.parse(wide) }
  }

  @Test("An oversized document is rejected on length alone")
  func rejectsOversizedDocument() throws {
    let padding = String(repeating: " ", count: GraphQLParser.maximumDocumentLength + 1)
    #expect(throws: GatewayError.self) {
      _ = try self.parser.parse("{ account { name } }" + padding)
    }
  }

  @Test("A variable reference resolves against supplied values")
  func resolvesVariableReferences() throws {
    let document = try parser.parse("query Q($n: String!) { property(name: $n) { name } }")
    let argument = try #require(document.operation.selections.first?.arguments["name"])
    let resolved = try argument.resolved(
      variables: ["n": .string("properties/1")],
      path: "property.name"
    )
    #expect(resolved == .string("properties/1"))
  }

  @Test("An unsupplied variable reference is rejected when it is resolved")
  func rejectsUnsuppliedVariable() throws {
    let document = try parser.parse("query Q($n: String!) { property(name: $n) { name } }")
    let argument = try #require(document.operation.selections.first?.arguments["name"])
    #expect(throws: GatewayError.self) {
      _ = try argument.resolved(variables: [:], path: "property.name")
    }
  }

  @Test("Referenced variable names are collected from nested literals")
  func collectsReferencedVariables() throws {
    let document = try parser.parse(
      "query Q($a: String!, $b: Int!) { f(x: [{y: $a}], z: $b) { name } }"
    )
    let arguments = try #require(document.operation.selections.first?.arguments)
    let referenced = arguments.values.reduce(into: Set<String>()) {
      $0.formUnion($1.referencedVariables)
    }
    #expect(referenced == ["a", "b"])
  }
}
