import Foundation
import Testing

import GoogleAnalyticsGatewayCore

/// `JSONValue` carries both the typed SDK path and the GraphQL path, so its
/// coding is the one place where a decoding mistake would reach every capability
/// at once.
@Suite("JSONValue coding")
struct JSONValueCodingTests {
  private func decode(_ text: String) throws -> JSONValue {
    try JSONValue.decodeJSON(Data(text.utf8))
  }

  // MARK: - Decoding

  @Test("An object decodes to its fields")
  func decodesObject() throws {
    #expect(
      try decode(#"{"name": "properties/1", "displayName": "Site"}"#)
        == .object(["name": .string("properties/1"), "displayName": .string("Site")])
    )
  }

  @Test("Booleans decode as booleans rather than as numbers")
  func decodesBooleansDistinctly() throws {
    // JSONSerialization returns NSNumber for both, so a naive conversion would
    // turn true into 1 and silently change a field's type.
    #expect(try decode(#"{"a": true, "b": false}"#) == .object(["a": .bool(true), "b": .bool(false)]))
    #expect(try decode(#"{"a": 1}"#) == .object(["a": .int(1)]))
  }

  @Test("Integers and fractional numbers decode to distinct cases")
  func decodesNumbersByKind() throws {
    #expect(try decode("7") == .int(7))
    #expect(try decode("-7") == .int(-7))
    #expect(try decode("1.5") == .double(1.5))
  }

  /// Google encodes 64-bit integers as JSON strings, so a quoted number has to
  /// stay a string. Coercing it to an int here would silently reshape a field
  /// the API deliberately widened, and would lose precision past 2^53.
  @Test("A quoted 64-bit integer stays a string")
  func preservesQuotedIntegers() throws {
    let value = try decode(#"{"userCount": "9007199254740993"}"#)
    #expect(value["userCount"] == .string("9007199254740993"))
    #expect(value["userCount"]?.intValue == nil)
  }

  @Test("Null, nested objects, and arrays decode structurally")
  func decodesNestedStructures() throws {
    #expect(
      try decode(#"{"a": null, "b": [1, {"c": "d"}]}"#)
        == .object(["a": .null, "b": .array([.int(1), .object(["c": .string("d")])])])
    )
  }

  @Test("A top-level fragment decodes, since Google answers some methods with one")
  func decodesFragments() throws {
    #expect(try decode(#""text""#) == .string("text"))
    #expect(try decode("null") == .null)
  }

  @Test("Malformed JSON is an upstream response failure, not a usage error")
  func rejectsMalformedJSON() throws {
    let error = #expect(throws: GatewayError.self) { _ = try self.decode("{not json") }
    #expect(error?.code == .upstreamResponseInvalid)
    #expect(error?.exitCode == .rejectedRequest)
  }

  // MARK: - Caller-supplied objects

  @Test("A caller-supplied object decodes to its fields")
  func decodesCallerObject() throws {
    let fields = try JSONValue.decodeJSONObject(
      Data(#"{"name": "properties/1"}"#.utf8),
      context: "Variables"
    )
    #expect(fields == ["name": .string("properties/1")])
  }

  /// A caller's malformed input is a local usage error, so it must exit as a
  /// usage failure rather than be reported as an upstream problem.
  @Test("Caller-supplied JSON that will not parse is a validation error")
  func rejectsCallerMalformedJSON() throws {
    let error = #expect(throws: GatewayError.self) {
      _ = try JSONValue.decodeJSONObject(Data("{nope".utf8), context: "Variables")
    }
    #expect(error?.code == .validationError)
    #expect(error?.exitCode == .usage)
    #expect(error?.message.contains("Variables") == true)
  }

  @Test("Caller-supplied JSON that is not an object is a validation error")
  func rejectsCallerNonObject() throws {
    let error = #expect(throws: GatewayError.self) {
      _ = try JSONValue.decodeJSONObject(Data("[1, 2]".utf8), context: "Variables")
    }
    #expect(error?.code == .validationError)
  }

  // MARK: - Encoding

  @Test("Object keys are sorted, so output is byte-for-byte reproducible")
  func encodesSortedKeys() throws {
    let value = JSONValue.object(["c": .int(3), "a": .int(1), "b": .int(2)])
    #expect(value.encodedJSON(pretty: false) == #"{"a":1,"b":2,"c":3}"#)
  }

  @Test("Pretty output changes whitespace only")
  func prettyPrintingChangesWhitespaceOnly() throws {
    let value = JSONValue.object(["a": .int(1), "b": .array([.int(2)])])
    let compact = value.encodedJSON(pretty: false)
    let pretty = value.encodedJSON(pretty: true)
    #expect(compact != pretty)
    #expect(pretty.contains("\n"))
    #expect(try JSONValue.decodeJSON(Data(pretty.utf8)) == value)
    #expect(try JSONValue.decodeJSON(Data(compact.utf8)) == value)
  }

  @Test("Empty objects and arrays encode without a body")
  func encodesEmptyContainers() throws {
    #expect(JSONValue.object([:]).encodedJSON(pretty: true) == "{}")
    #expect(JSONValue.array([]).encodedJSON(pretty: true) == "[]")
  }

  @Test("A whole-number double keeps a fractional part so it stays a Float")
  func encodesWholeDoublesWithFraction() throws {
    #expect(JSONValue.double(3).encodedJSON(pretty: false) == "3.0")
    #expect(JSONValue.int(3).encodedJSON(pretty: false) == "3")
  }

  @Test("Quotes, backslashes, and control characters are escaped")
  func escapesStrings() throws {
    let value = JSONValue.string("a\"b\\c\nd\te\rf\u{01}")
    // Written with conventional escapes rather than a raw literal so no control
    // character has to appear in this source file.
    let expected = "\"a\\\"b\\\\c\\nd\\te\\rf\\u0001\""
    #expect(value.encodedJSON(pretty: false) == expected)
  }

  @Test("Text outside the basic multilingual plane round-trips intact")
  func roundTripsAstralCharacters() throws {
    let value = JSONValue.object(["displayName": .string("Sitio 😀 Web")])
    let encoded = value.encodedJSON(pretty: false)
    #expect(try JSONValue.decodeJSON(Data(encoded.utf8)) == value)
  }

  @Test("A decoded escape sequence and its literal character are the same value")
  func decodesEscapedAstralCharacters() throws {
    #expect(try decode(#"{"a": "😀"}"#) == .object(["a": .string("\u{1F600}")]))
  }

  @Test("A nested structure round-trips through encoding and decoding")
  func roundTripsNestedStructures() throws {
    let value = JSONValue.object([
      "name": .string("properties/1"),
      "active": .bool(true),
      "missing": .null,
      "streams": .array([.object(["id": .int(1)]), .object(["id": .int(2)])]),
      "ratio": .double(0.25)
    ])
    let encoded = value.encodedJSON(pretty: false)
    #expect(try JSONValue.decodeJSON(Data(encoded.utf8)) == value)
  }

  // MARK: - Accessors

  @Test("Typed accessors read only their own case")
  func typedAccessorsAreNarrow() throws {
    #expect(JSONValue.string("a").stringValue == "a")
    #expect(JSONValue.int(1).stringValue == nil)
    #expect(JSONValue.bool(true).boolValue == true)
    #expect(JSONValue.int(1).boolValue == nil)
    #expect(JSONValue.array([.int(1)]).arrayValue == [.int(1)])
    #expect(JSONValue.object(["a": .int(1)]).objectValue == ["a": .int(1)])
    #expect(JSONValue.null.isNull)
  }

  /// An integer-valued float reads as an Int because Google returns whole
  /// numbers either way; a fractional one must not be silently truncated.
  @Test("Numeric accessors bridge only where no precision is lost")
  func numericAccessorsBridgeSafely() throws {
    #expect(JSONValue.double(4).intValue == 4)
    #expect(JSONValue.double(4.5).intValue == nil)
    #expect(JSONValue.int(4).doubleValue == 4.0)
  }

  @Test("Subscripting reads a field only from an object")
  func subscriptReadsObjectFields() throws {
    #expect(JSONValue.object(["a": .int(1)])["a"] == .int(1))
    #expect(JSONValue.object(["a": .int(1)])["b"] == nil)
    #expect(JSONValue.array([.int(1)])["a"] == nil)
  }

  @Test("Type descriptions use the names that appear in validation messages")
  func typeDescriptionsMatchGraphQLNames() throws {
    #expect(JSONValue.null.typeDescription == "null")
    #expect(JSONValue.bool(true).typeDescription == "Boolean")
    #expect(JSONValue.int(1).typeDescription == "Int")
    #expect(JSONValue.double(1.5).typeDescription == "Float")
    #expect(JSONValue.string("a").typeDescription == "String")
    #expect(JSONValue.array([]).typeDescription == "list")
    #expect(JSONValue.object([:]).typeDescription == "object")
  }
}
