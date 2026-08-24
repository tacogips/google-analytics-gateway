import Foundation

/// The parsed command line, shared by all three executables so grammar cannot
/// drift between binaries.
public enum ParsedCommand: Sendable, Equatable {
  case help
  case version
  case graphQLQuery(document: String, variables: Data?, selection: CredentialSelection, pretty: Bool)
  case graphQLQueryFile(path: String, variablesPath: String?, selection: CredentialSelection, pretty: Bool)
  case graphQLSchema
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
    "--variables", "--variables-file", "--config", "--profile", "--timeout-seconds"
  ]

  public static func parse(_ arguments: [String]) throws -> ParsedCommand {
    guard !arguments.isEmpty else { return .help }

    var pretty = false
    var noBrowser = false
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
        pretty = true
      case "--no-browser":
        noBrowser = true
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
        pretty: pretty
      )
    case "auth":
      guard options["--variables"] == nil, options["--variables-file"] == nil else {
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
        !noBrowser, options["--timeout-seconds"] == nil
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
    pretty: Bool
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
      guard rest.count == 1, let document = rest.first else {
        throw GatewayError.validation("`graphql query` accepts exactly one document argument.")
      }
      guard options["--variables-file"] == nil else {
        throw GatewayError.validation("`graphql query` uses --variables, not --variables-file.")
      }
      let variables = options["--variables"].map { Data($0.utf8) }
      return .graphQLQuery(document: document, variables: variables, selection: selection, pretty: pretty)
    case "query-file":
      guard rest.count == 1, let path = rest.first else {
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
      guard rest.isEmpty, options["--variables"] == nil, options["--variables-file"] == nil else {
        throw GatewayError.validation("`graphql schema` accepts no additional arguments.")
      }
      return .graphQLSchema
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
        recovery: "Use `auth oauth2`, `auth status`, or `auth logout`."
      )
    }
    switch subcommand {
    case "oauth2":
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
        recovery: "Use `auth oauth2`, `auth status`, or `auth logout`."
      )
    }
  }
}
