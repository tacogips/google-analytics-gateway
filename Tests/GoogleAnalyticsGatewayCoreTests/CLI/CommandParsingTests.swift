import Foundation
import GoogleAnalyticsGatewayCore
import Testing

/// The command grammar is shared by all three executables, so a change here
/// changes every binary at once. The forbidden-flag list is the security-
/// relevant half: none of those options may become a way to point a binary at
/// another host, another credential, or a fixture transport.
@Suite("Command parsing")
struct CommandParsingTests {
  @Test("Every forbidden override is refused", arguments: CommandParser.forbiddenFlags)
  func rejectsForbiddenFlag(flag: String) throws {
    for arguments in [["graphql", "schema", flag, "value"], ["doctor", "\(flag)=value"]] {
      do {
        _ = try CommandParser.parse(arguments)
        Issue.record("Expected \(flag) to be refused")
      } catch let error as GatewayError {
        #expect(error.code == .validationError)
        #expect(error.message.contains(flag))
        #expect(error.exitCode == .usage)
      }
    }
  }

  @Test("A forbidden flag is refused even before the command it decorates")
  func rejectsForbiddenFlagBeforeCommand() throws {
    #expect(throws: GatewayError.self) {
      try CommandParser.parse(["--base-url", "https://analytics.example.com", "graphql", "schema"])
    }
  }

  @Test("No arguments and --help both print usage")
  func parsesHelp() throws {
    #expect(try CommandParser.parse([]) == .help)
    #expect(try CommandParser.parse(["--help"]) == .help)
    #expect(try CommandParser.parse(["-h"]) == .help)
    #expect(try CommandParser.parse(["--version"]) == .version)
  }

  @Test("graphql query takes exactly one inline document")
  func parsesGraphQLQuery() throws {
    let parsed = try CommandParser.parse([
      "graphql", "query", "{ sampleDataStreams(parent: \"properties/1\") { nodes { name } } }",
      "--variables", "{\"a\":1}", "--pretty", "--profile", "reader-one"
    ])
    guard case .graphQLQuery(let document, let variables, let selection, let pretty) = parsed else {
      Issue.record("Expected a graphql query command, got \(parsed)")
      return
    }
    #expect(document.hasPrefix("{ sampleDataStreams"))
    #expect(variables == Data("{\"a\":1}".utf8))
    #expect(selection.profileID == "reader-one")
    #expect(pretty)
  }

  @Test("graphql query-file takes a path and only the file variables option")
  func parsesGraphQLQueryFile() throws {
    let parsed = try CommandParser.parse([
      "graphql", "query-file", "/fixtures/query.graphql", "--variables-file", "/fixtures/vars.json"
    ])
    guard case .graphQLQueryFile(let path, let variablesPath, _, let pretty) = parsed else {
      Issue.record("Expected a graphql query-file command, got \(parsed)")
      return
    }
    #expect(path == "/fixtures/query.graphql")
    #expect(variablesPath == "/fixtures/vars.json")
    #expect(!pretty)
  }

  @Test("graphql schema ignores the global selection options and rejects the rest")
  func parsesGraphQLSchema() throws {
    #expect(try CommandParser.parse(["graphql", "schema"]) == .graphQLSchema)
    // The global --config/--profile options are tolerated (the schema renders
    // locally) so callers can keep a shared command prefix.
    #expect(
      try CommandParser.parse(["graphql", "schema", "--profile", "reader-one"]) == .graphQLSchema
    )
    #expect(
      try CommandParser.parse(["graphql", "schema", "--config", "/tmp/c.json"]) == .graphQLSchema
    )
    #expect(throws: GatewayError.self) {
      try CommandParser.parse(["graphql", "schema", "--variables", "{}"])
    }
    #expect(throws: GatewayError.self) {
      try CommandParser.parse(["graphql", "schema", "extra"])
    }
  }

  static let rejectedInvocations: [(String, [String])] = [
    ("two inline documents", ["graphql", "query", "{ a }", "{ b }"]),
    ("no document", ["graphql", "query"]),
    ("variables file on an inline query", ["graphql", "query", "{ a }", "--variables-file", "/v.json"]),
    ("inline variables on a query file", ["graphql", "query-file", "/q.graphql", "--variables", "{}"]),
    ("unknown graphql subcommand", ["graphql", "explain"]),
    ("no graphql subcommand", ["graphql"]),
    ("login options on a query", ["graphql", "query", "{ a }", "--no-browser"]),
    ("login timeout on a query", ["graphql", "query", "{ a }", "--timeout-seconds", "30"]),
    ("variables on auth", ["auth", "status", "--variables", "{}"]),
    ("two auth subcommands", ["auth", "status", "logout"]),
    ("unknown auth subcommand", ["auth", "refresh"]),
    ("login options on auth status", ["auth", "status", "--no-browser"]),
    ("login options on auth logout", ["auth", "logout", "--timeout-seconds", "30"]),
    ("timeout below the supported range", ["auth", "oauth2", "--timeout-seconds", "1"]),
    ("timeout above the supported range", ["auth", "oauth2", "--timeout-seconds", "6000"]),
    ("non-numeric timeout", ["auth", "oauth2", "--timeout-seconds", "soon"]),
    ("doctor with a positional", ["doctor", "everything"]),
    ("doctor with login options", ["doctor", "--no-browser"]),
    ("unknown command", ["explain"]),
    ("unknown option", ["doctor", "--verbose"]),
    ("option without a value", ["doctor", "--profile"]),
    ("repeated option", ["doctor", "--profile", "one", "--profile", "two"])
  ]

  @Test("Malformed invocations are usage errors", arguments: rejectedInvocations)
  func rejectsMalformedInvocation(label: String, arguments: [String]) throws {
    do {
      let parsed = try CommandParser.parse(arguments)
      Issue.record("Expected \(label) to be refused, got \(parsed)")
    } catch let error as GatewayError {
      #expect(error.code == .validationError, "\(label)")
      #expect(error.exitCode == .usage, "\(label)")
    }
  }

  @Test("The auth subcommands parse with their own options")
  func parsesAuthCommands() throws {
    let selection = CredentialSelection(configPath: "/fixtures/config.json", profileID: nil)
    #expect(try CommandParser.parse(["auth", "oauth2", "--config", "/fixtures/config.json"])
      == .authOAuth2(selection: selection, noBrowser: false, timeoutSeconds: nil))
    #expect(try CommandParser.parse([
      "auth", "oauth2", "--config", "/fixtures/config.json", "--no-browser", "--timeout-seconds", "30"
    ]) == .authOAuth2(selection: selection, noBrowser: true, timeoutSeconds: 30))
    #expect(try CommandParser.parse(["auth", "status", "--config", "/fixtures/config.json"])
      == .authStatus(selection: selection))
    #expect(try CommandParser.parse(["auth", "logout", "--config", "/fixtures/config.json"])
      == .authLogout(selection: selection))
    #expect(try CommandParser.parse(["doctor", "--config", "/fixtures/config.json"])
      == .doctor(selection: selection))
  }
}
