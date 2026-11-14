import Foundation
import GatewaySDKKit

/// The parsed command line, shared by all three executables so grammar cannot
/// drift between binaries.
public enum ParsedCommand: Sendable, Equatable {
  case help
  case version
  case graphQLQuery(document: String, variables: Data?, selection: CredentialSelection, pretty: Bool)
  case graphQLQueryFile(path: String, variablesPath: String?, selection: CredentialSelection, pretty: Bool)
  case graphQLSchema
  case graphQLSearch(pattern: String, kinds: Set<GatewayDefinitionKind>, includeReferencedTypes: Bool, limit: Int?, pretty: Bool)
  case graphQLOperation(name: String, variables: Data?, variablesPath: String?, selectionPaths: [String]?, selection: CredentialSelection, pretty: Bool)
  case authOAuth2(selection: CredentialSelection, noBrowser: Bool, timeoutSeconds: Int?)
  case authStatus(selection: CredentialSelection)
  case authLogout(selection: CredentialSelection)
  case doctor(selection: CredentialSelection)
}

/// The credential profile a command should use.
///
/// The config path and profile id travel together because a profile id is
/// meaningless outside the configuration document that defines it. Both are
/// optional at parse time; resolution (explicit path, environment fallback,
/// synthesized env-token profile) happens later so `--help` and parsing errors
/// never read the filesystem.
public struct CredentialSelection: Sendable, Equatable {
  public let configPath: String?
  public let profileID: String?

  public init(configPath: String?, profileID: String?) {
    self.configPath = configPath
    self.profileID = profileID
  }
}

public enum CommandParser {
  /// Rejected flags include every override the contract forbids: redirect URI,
  /// certificate, trust bypass, mock transport, fixture path, arbitrary host,
  /// and inline credentials.
  public static let forbiddenFlags: [String] = [
    "--redirect-uri",
    "--callback-url",
    "--identity-label",
    "--keychain-label",
    "--certificate",
    "--private-key",
    "--insecure",
    "--allow-insecure",
    "--trust-bypass",
    "--no-verify",
    "--mock-transport",
    "--fixture",
    "--fixtures",
    "--test-mode",
    "--base-url",
    "--api-host",
    "--token",
    "--access-token",
    "--client-secret"
  ]

  private static let valueOptions: Set<String> = [
    "--variables", "--variables-file", "--config", "--profile", "--timeout-seconds", "--kinds", "--limit", "--select"
  ]

  public static func parse(_ arguments: [String]) throws -> ParsedCommand {
    guard !arguments.isEmpty, arguments != ["auth"] else { return .help }

    var pretty = false
    var noBrowser = false
    var includeReferencedTypes = false
    var flags: Set<String> = []
    var positional: [String] = []
    var options: [String: String] = [:]
    var index = 0

    while index < arguments.count {
      let argument = arguments[index]
      if let forbidden = forbiddenFlags.first(where: { argument == $0 || argument.hasPrefix("\($0)=") }) {
        throw GatewayError.validation(
          "The \(forbidden) option is not supported.",
          recovery: "This binary accepts no credential, host, certificate, or test-mode override."
        )
      }
      switch argument {
      case "--help", "-h":
        return .help
      case "--version":
        return .version
      case "--pretty":
        guard flags.insert(argument).inserted else {
          throw GatewayError.validation("Option \(argument) is supplied more than once.")
        }
        pretty = true
      case "--no-browser":
        guard flags.insert(argument).inserted else {
          throw GatewayError.validation("Option \(argument) is supplied more than once.")
        }
        noBrowser = true
      case "--include-referenced-types":
        guard flags.insert(argument).inserted else {
          throw GatewayError.validation("Option \(argument) is supplied more than once.")
        }
        includeReferencedTypes = true
      case _ where valueOptions.contains(argument):
        guard index + 1 < arguments.count else {
          throw GatewayError.validation("Option \(argument) requires a value.")
        }
        guard options[argument] == nil else {
          throw GatewayError.validation("Option \(argument) is supplied more than once.")
        }
        options[argument] = arguments[index + 1]
        index += 1
      default:
        if argument.hasPrefix("-") && argument != "-" {
          throw GatewayError.validation(
            "Unknown option \(argument).",
            recovery: "Run --help to see the supported commands."
          )
        }
        positional.append(argument)
      }
      index += 1
    }

    let selection = CredentialSelection(
      configPath: options["--config"],
      profileID: options["--profile"]
    )

    guard let command = positional.first else { return .help }
    switch command {
    case "graphql":
      guard !noBrowser, options["--timeout-seconds"] == nil else {
        throw GatewayError.validation("The graphql command does not accept login options.")
      }
      return try parseGraphQL(
        Array(positional.dropFirst()),
        options: options,
        selection: selection,
        pretty: pretty,
        includeReferencedTypes: includeReferencedTypes,
        noBrowser: noBrowser
      )
    case "auth":
      guard options["--variables"] == nil, options["--variables-file"] == nil,
        options["--kinds"] == nil, options["--limit"] == nil, options["--select"] == nil,
        !includeReferencedTypes
      else {
        throw GatewayError.validation("The auth commands do not accept variable options.")
      }
      return try parseAuth(
        Array(positional.dropFirst()),
        selection: selection,
        noBrowser: noBrowser,
        timeoutSeconds: try timeoutSeconds(options)
      )
    case "doctor":
      guard positional.count == 1, options["--variables"] == nil, options["--variables-file"] == nil,
        options["--kinds"] == nil, options["--limit"] == nil, options["--select"] == nil,
        !noBrowser, !includeReferencedTypes, options["--timeout-seconds"] == nil
      else {
        throw GatewayError.validation("`doctor` accepts only --config and --profile.")
      }
      return .doctor(selection: selection)
    default:
      throw GatewayError.validation(
        "Unknown command \(command).",
        recovery: "Supported commands are `graphql`, `auth`, and `doctor`."
      )
    }
  }

  private static func timeoutSeconds(_ options: [String: String]) throws -> Int? {
    guard let raw = options["--timeout-seconds"] else { return nil }
    guard let value = Int(raw), (5...600).contains(value) else {
      throw GatewayError.validation("Option --timeout-seconds must be an integer between 5 and 600.")
    }
    return value
  }

  private static func parseGraphQL(
    _ positional: [String],
    options: [String: String],
    selection: CredentialSelection,
    pretty: Bool,
    includeReferencedTypes: Bool,
    noBrowser: Bool
  ) throws -> ParsedCommand {
    guard let subcommand = positional.first else {
      throw GatewayError.validation(
        "The graphql command requires a subcommand.",
        recovery: "Use `graphql query`, `graphql query-file`, or `graphql schema`."
      )
    }
    let rest = Array(positional.dropFirst())
    switch subcommand {
    case "query":
      guard !includeReferencedTypes, options["--kinds"] == nil, options["--limit"] == nil,
        options["--select"] == nil, rest.count == 1, let document = rest.first
      else {
        throw GatewayError.validation("`graphql query` accepts exactly one document argument.")
      }
      guard options["--variables-file"] == nil else {
        throw GatewayError.validation("`graphql query` uses --variables, not --variables-file.")
      }
      let variables = options["--variables"].map { Data($0.utf8) }
      return .graphQLQuery(document: document, variables: variables, selection: selection, pretty: pretty)
    case "query-file":
      guard !includeReferencedTypes, options["--kinds"] == nil, options["--limit"] == nil,
        options["--select"] == nil, rest.count == 1, let path = rest.first
      else {
        throw GatewayError.validation("`graphql query-file` accepts exactly one path argument.")
      }
      guard options["--variables"] == nil else {
        throw GatewayError.validation("`graphql query-file` uses --variables-file, not --variables.")
      }
      return .graphQLQueryFile(
        path: path,
        variablesPath: options["--variables-file"],
        selection: selection,
        pretty: pretty
      )
    case "schema":
      // The global --config/--profile options are accepted (and ignored —
      // the schema renders locally) so a caller can keep them in a shared
      // command prefix; only the variables options are meaningless here.
      guard !includeReferencedTypes, rest.isEmpty, options["--variables"] == nil,
        options["--variables-file"] == nil, options["--kinds"] == nil,
        options["--limit"] == nil, options["--select"] == nil
      else {
        throw GatewayError.validation("`graphql schema` accepts no additional arguments.")
      }
      return .graphQLSchema
    case "search":
      guard rest.count == 1, let pattern = rest.first,
        options["--variables"] == nil, options["--variables-file"] == nil,
        options["--select"] == nil, options["--timeout-seconds"] == nil, !noBrowser
      else { throw GatewayError.validation("`graphql search` accepts one pattern and search options only.") }
      let kinds: Set<GatewayDefinitionKind>
      if let raw = options["--kinds"] {
        let names = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let parsed = names.compactMap(GatewayDefinitionKind.init(rawValue:))
        guard !names.isEmpty, parsed.count == names.count else {
          throw GatewayError.validation("Option --kinds contains an unknown kind.")
        }
        kinds = Set(parsed)
      } else {
        kinds = Set(GatewayDefinitionKind.allCases)
      }
      let limit: Int?
      if let raw = options["--limit"] {
        guard let value = Int(raw), value > 0 else {
          throw GatewayError.validation("Option --limit must be a positive integer.")
        }
        limit = value
      } else { limit = nil }
      return .graphQLSearch(
        pattern: pattern, kinds: kinds,
        includeReferencedTypes: includeReferencedTypes, limit: limit, pretty: pretty
      )
    case "operation":
      guard !includeReferencedTypes, options["--kinds"] == nil, options["--limit"] == nil,
        options["--timeout-seconds"] == nil, !noBrowser, rest.count == 1, let name = rest.first
      else {
        throw GatewayError.validation("`graphql operation` accepts exactly one operation name.")
      }
      guard !(options["--variables"] != nil && options["--variables-file"] != nil) else {
        throw GatewayError.validation("`graphql operation` accepts either --variables or --variables-file.")
      }
      let paths = options["--select"].map { raw in
        raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
      }
      if let paths, paths.isEmpty || paths.contains(where: { $0.isEmpty }) {
        throw GatewayError.validation("Option --select requires comma-separated field paths.")
      }
      return .graphQLOperation(
        name: name, variables: options["--variables"].map { Data($0.utf8) },
        variablesPath: options["--variables-file"], selectionPaths: paths,
        selection: selection, pretty: pretty
      )
    default:
      throw GatewayError.validation(
        "Unknown graphql subcommand \(subcommand).",
        recovery: "Use `graphql query`, `graphql query-file`, or `graphql schema`."
      )
    }
  }

  private static func parseAuth(
    _ positional: [String],
    selection: CredentialSelection,
    noBrowser: Bool,
    timeoutSeconds: Int?
  ) throws -> ParsedCommand {
    guard let subcommand = positional.first, positional.count == 1 else {
      throw GatewayError.validation(
        "The auth command requires exactly one subcommand.",
        recovery: "Use `auth login` (or `auth oauth2`), `auth status`, or `auth logout`."
      )
    }
    switch subcommand {
    case "login", "oauth2":
      return .authOAuth2(selection: selection, noBrowser: noBrowser, timeoutSeconds: timeoutSeconds)
    case "status":
      guard !noBrowser, timeoutSeconds == nil else {
        throw GatewayError.validation("`auth status` does not accept login options.")
      }
      return .authStatus(selection: selection)
    case "logout":
      guard !noBrowser, timeoutSeconds == nil else {
        throw GatewayError.validation("`auth logout` does not accept login options.")
      }
      return .authLogout(selection: selection)
    default:
      throw GatewayError.validation(
        "Unknown auth subcommand \(subcommand).",
        recovery: "Use `auth login` (or `auth oauth2`), `auth status`, or `auth logout`."
      )
    }
  }
}
