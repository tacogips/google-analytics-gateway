import Foundation
import Testing

@testable import GoogleAnalyticsGatewayCore

/// The lexer is internal, so these reach it directly rather than through the
/// parser. A tokenizer bug that the parser happens to mask today would surface
/// the moment the grammar widened, so it is pinned on its own.
@Suite("GraphQL lexer")
struct GraphQLLexerTests {
  /// Drains the lexer, dropping the terminator. The cap only bounds a runaway
  /// loop if a future edit ever stops advancing the index; a correct lexer never
  /// reaches it.
  private func tokens(of source: String) throws -> [GraphQLToken] {
    var lexer = GraphQLLexer(source)
    var collected: [GraphQLToken] = []
    while collected.count < 4096 {
      let token = try lexer.nextToken()
      if token == .endOfDocument { return collected }
      collected.append(token)
    }
    return collected
  }

  @Test("Names, punctuators, and a selection set tokenize in order")
  func tokenizesSelectionSet() throws {
    #expect(
      try tokens(of: "{ property { name } }") == [
        .punctuator("{"), .name("property"), .punctuator("{"), .name("name"),
        .punctuator("}"), .punctuator("}")
      ]
    )
  }

  @Test("A name may carry digits and underscores after its first character")
  func tokenizesComplexNames() throws {
    #expect(try tokens(of: "_a1 b_2") == [.name("_a1"), .name("b_2")])
  }

  @Test("Integers and floats are distinguished")
  func distinguishesNumbers() throws {
    #expect(try tokens(of: "1") == [.int(1)])
    #expect(try tokens(of: "-42") == [.int(-42)])
    #expect(try tokens(of: "1.5") == [.double(1.5)])
    #expect(try tokens(of: "-2.5e3") == [.double(-2500.0)])
  }

  @Test("Whitespace, commas, and comments are ignored")
  func skipsIgnoredTokens() throws {
    #expect(try tokens(of: "  a ,\n b # trailing comment\n c") == [.name("a"), .name("b"), .name("c")])
  }

  @Test("A comment runs only to the end of its line")
  func commentEndsAtNewline() throws {
    #expect(try tokens(of: "# hidden\nvisible") == [.name("visible")])
  }

  @Test("The spread punctuation lexes as one token so the parser can name it")
  func lexesSpread() throws {
    #expect(try tokens(of: "...Fields") == [.spread, .name("Fields")])
  }

  @Test("String escapes decode, including a surrogate pair")
  func decodesStringEscapes() throws {
    // A raw Swift literal, so each backslash reaches the lexer as the escape the
    // document actually contains rather than one Swift already decoded.
    #expect(
      try tokens(of: #""a\tb\"c\\d\/eAé😀z""#)
        == [.string("a\tb\"c\\d/eA\u{E9}\u{1F600}z")]
    )
  }

  @Test("Backspace and form feed escapes decode")
  func decodesControlEscapes() throws {
    #expect(try tokens(of: #""a\bb\fc""#) == [.string("a\u{08}b\u{0C}c")])
  }

  @Test("An empty string literal is a valid token")
  func lexesEmptyString() throws {
    #expect(try tokens(of: #""""#) == [.string("")])
  }

  struct MalformedSource: Sendable, CustomTestStringConvertible {
    let name: String
    let source: String
    var testDescription: String { name }
  }

  /// A half-formed surrogate is still malformed. Accepting one would put an
  /// unpaired scalar into an upstream request.
  @Test(
    "A malformed unicode escape is rejected",
    arguments: [
      MalformedSource(name: "lone high surrogate", source: #""\uD83D""#),
      MalformedSource(name: "lone low surrogate", source: #""\uDE00""#),
      MalformedSource(name: "high surrogate then a plain escape", source: #""\uD83D\n""#),
      MalformedSource(name: "high surrogate then a non-surrogate", source: #""\uD83DA""#),
      MalformedSource(name: "truncated escape", source: #""\u12""#),
      MalformedSource(name: "non-hex escape", source: #""\uZZZZ""#)
    ]
  )
  func rejectsMalformedUnicodeEscape(testCase: MalformedSource) throws {
    #expect(throws: GatewayError.self, "\(testCase.name) must be rejected") {
      _ = try self.tokens(of: testCase.source)
    }
  }

  @Test(
    "Malformed source is rejected",
    arguments: [
      MalformedSource(name: "block string", source: #""""x""""#),
      MalformedSource(name: "unterminated string", source: "\"abc"),
      MalformedSource(name: "newline inside a string", source: "\"a\nb\""),
      MalformedSource(name: "invalid escape", source: #""a\qb""#),
      MalformedSource(name: "lone dot", source: "."),
      MalformedSource(name: "two dots", source: ".."),
      MalformedSource(name: "unsupported character", source: "%")
    ]
  )
  func rejectsMalformedSource(testCase: MalformedSource) throws {
    #expect(throws: GatewayError.self, "\(testCase.name) must be rejected") {
      _ = try self.tokens(of: testCase.source)
    }
  }

  @Test("Every lexer rejection is a validation error, never an upstream failure")
  func rejectionsAreValidationErrors() throws {
    let error = #expect(throws: GatewayError.self) {
      _ = try self.tokens(of: "%")
    }
    #expect(error?.code == .validationError)
  }
}
