import Foundation

/// A capability request expressed before validation.
///
/// Typed SDK methods and GraphQL field execution both construct this value.
/// Neither path can reach the transport without passing through the planner.
public struct CapabilityInvocation: Sendable, Equatable {
  public let capabilityID: CapabilityID
  public let arguments: [String: JSONValue]

  public init(capabilityID: CapabilityID, arguments: [String: JSONValue] = [:]) {
    self.capabilityID = capabilityID
    self.arguments = arguments
  }
}

/// The validated, fully resolved outcome of planning an invocation.
public struct CapabilityPlan: Sendable, Equatable {
  public let definition: CapabilityDefinition
  public let request: UpstreamRequest
  public let validatedArguments: [String: ValidatedArgument]

  public var capabilityID: CapabilityID { definition.id }
}

/// The single capability-execution planner.
///
/// It resolves the capability, enforces the tier, validates arguments, checks
/// granted scopes, and produces the upstream request. Calling a Google API by
/// any other route is not possible from public API because `UpstreamRequest`
/// can only be built here.
public struct CapabilityPlanner: Sendable {
  public let registry: CapabilityRegistry
  private let coercer: ArgumentCoercer

  public init(registry: CapabilityRegistry, coercer: ArgumentCoercer = ArgumentCoercer()) {
    self.registry = registry
    self.coercer = coercer
  }

  /// Resolves a GraphQL field to a capability, applying the tier rule.
  public func definition(field: String, isMutation: Bool) throws -> CapabilityDefinition {
    if let definition = registry.definition(field: field, isMutation: isMutation) {
      return definition
    }
    if let higher = CapabilityCatalog.knownTier(field: field, isMutation: isMutation) {
      throw GatewayError(
        code: .capabilityDenied,
        message: "\(isMutation ? "Mutation" : "Query") \(field) requires the \(higher.rawValue) capability tier.",
        requiredTier: higher,
        recoveryGuidance: "Use the google-analytics-gateway-\(higher == .admin ? "admin" : "writer") executable."
      )
    }
    throw GatewayError.validation(
      "Unknown \(isMutation ? "mutation" : "query") field \(field).",
      recovery: "Run `graphql schema` to see the fields this binary exposes."
    )
  }

  /// Plans an invocation into an upstream request.
  ///
  /// Every check here is local, so a caller can plan before resolving a
  /// credential. `grantedScopes` is optional for exactly that reason: the
  /// executor plans first, then resolves the credential, then calls
  /// `validateScopes(for:grantedScopes:)`. That ordering is what makes an
  /// invalid argument report `VALIDATION_ERROR` rather than
  /// `AUTHENTICATION_FAILED` when no credential is configured.
  public func plan(
    _ invocation: CapabilityInvocation,
    grantedScopes: [String] = []
  ) throws -> CapabilityPlan {
    guard let definition = registry.definition(for: invocation.capabilityID) else {
      throw GatewayError(
        code: .capabilityDenied,
        message: "Capability \(invocation.capabilityID) is not linked into this binary.",
        capabilityID: invocation.capabilityID
      )
    }
    guard registry.tier.includes(definition.tier) else {
      throw GatewayError(
        code: .capabilityDenied,
        message: "Capability \(definition.id) requires the \(definition.tier.rawValue) tier.",
        capabilityID: definition.id,
        requiredTier: definition.tier
      )
    }
    guard definition.status.isExecutable else {
      throw GatewayError(
        code: .capabilityDenied,
        message: "Capability \(definition.id) is \(definition.status.rawValue) and cannot be executed.",
        capabilityID: definition.id
      )
    }
    try validateScopes(for: definition, grantedScopes: grantedScopes)

    let validated = try coercer.coerce(arguments: invocation.arguments, for: definition)
    let request = try RequestBuilder.build(definition: definition, arguments: validated)
    return CapabilityPlan(definition: definition, request: request, validatedArguments: validated)
  }

  /// Rejects a known scope mismatch before transport.
  ///
  /// An empty `grantedScopes` means the credential exposes no inspectable scope
  /// metadata; Google stays authoritative in that case.
  public func validateScopes(
    for definition: CapabilityDefinition,
    grantedScopes: [String]
  ) throws {
    guard definition.scopes.isSatisfied(byGranted: grantedScopes) else {
      throw GatewayError(
        code: .authorizationFailed,
        message: "The credential is missing a Google OAuth scope required by \(definition.id).",
        capabilityID: definition.id,
        recoveryGuidance: "Re-authorize with the \(definition.scopes.recommended) scope."
      )
    }
  }
}

/// Builds the upstream request from a capability definition and validated
/// arguments. This is the only place a path, query, or body is assembled.
enum RequestBuilder {
  static func build(
    definition: CapabilityDefinition,
    arguments: [String: ValidatedArgument]
  ) throws -> UpstreamRequest {
    try verifyConfirmations(definition: definition, arguments: arguments)

    var path = definition.pathTemplate
    var queryItems: [UpstreamQueryItem] = []
    var jsonBody: [String: JSONValue] = [:]
    var rootBody: JSONValue?
    var responseSink: ResponseSink = .memory

    for parameter in definition.arguments {
      guard let value = arguments[parameter.name] else { continue }
      switch parameter.binding {
      case .path(let placeholder):
        path = path.replacingOccurrences(
          of: "{\(placeholder)}",
          with: try pathSegments(for: value, argument: parameter.name)
        )
      case .query(let name):
        queryItems.append(contentsOf: try encodeQuery(named: name, value: value, joined: true))
      case .queryList(let name):
        queryItems.append(contentsOf: try encodeQuery(named: name, value: value, joined: false))
      case .bodyJSON(let name):
        jsonBody[name] = jsonValue(value, type: parameter.type)
      case .bodyRoot:
        rootBody = jsonValue(value, type: parameter.type)
      case .page:
        guard case .page(let page) = value else { break }
        if let size = page.pageSize {
          queryItems.append(UpstreamQueryItem(name: "pageSize", value: String(size)))
        }
        if let token = page.nextPageToken {
          // The public input field is `nextPageToken`, which is what a caller
          // reads back out of `pageInfo`; Google names the request parameter
          // `pageToken`. The rename lives here so the two never have to agree.
          queryItems.append(UpstreamQueryItem(name: "pageToken", value: token))
        }
      case .confirm:
        // Already checked above. A confirmation is a local guard on a
        // destructive request and never reaches Google.
        break
      case .destinationPath:
        // The destination never reaches Google; it only tells the transport
        // where the success body must land.
        guard case .destinationPath(let file) = value else { break }
        responseSink = .file(path: file)
      }
    }

    guard !path.contains("{") else {
      throw GatewayError.internalFailure(
        "Capability \(definition.id) produced an unresolved path placeholder."
      )
    }

    let body: UpstreamRequestBody
    if let rootBody {
      body = .json(rootBody)
    } else if !jsonBody.isEmpty {
      body = .json(.object(jsonBody))
    } else {
      body = .none
    }

    return UpstreamRequest(
      capabilityID: definition.id,
      service: definition.service,
      method: definition.method,
      path: path,
      queryItems: queryItems.sorted { $0.name < $1.name },
      body: body,
      responseSink: responseSink
    )
  }

  /// A destructive request must echo the resource name it removes.
  ///
  /// The echo is compared against the validated value the path is built from,
  /// so a confirmation can only ever agree with what is actually being deleted,
  /// and a mismatch fails locally before any credential or network access.
  private static func verifyConfirmations(
    definition: CapabilityDefinition,
    arguments: [String: ValidatedArgument]
  ) throws {
    for parameter in definition.arguments {
      guard let targetName = parameter.binding.confirmedArgumentName else { continue }
      guard case .string(let echoed)? = arguments[parameter.name] else {
        throw GatewayError.validation(
          "Argument \(parameter.name) is required for field \(definition.field).",
          recovery: "Repeat the \(targetName) value exactly to confirm the operation."
        )
      }
      guard case .resourceName(let target)? = arguments[targetName] else {
        throw GatewayError.internalFailure(
          "Capability \(definition.id) confirms against unresolved argument \(targetName)."
        )
      }
      guard echoed == target else {
        throw GatewayError.validation(
          "Argument \(parameter.name) does not match \(targetName).",
          recovery: "Repeat the \(targetName) value exactly to confirm the operation."
        )
      }
    }
  }

  /// Renders a Google resource name into a path template placeholder.
  ///
  /// A resource name is itself multi-segment, so the separators it already
  /// carries are preserved and each segment between them is escaped on its own.
  /// The coercer has already restricted segments to a character class that
  /// needs no escaping, so this is a no-op today; it keeps path construction
  /// correct if that class ever widens.
  private static func pathSegments(
    for value: ValidatedArgument,
    argument: String
  ) throws -> String {
    guard case .resourceName(let name) = value else {
      throw GatewayError.internalFailure("Path argument \(argument) is not a resource name.")
    }
    return name.split(separator: "/", omittingEmptySubsequences: false)
      .map { escapePathSegment(String($0)) }
      .joined(separator: "/")
  }

  private static func encodeQuery(
    named name: String,
    value: ValidatedArgument,
    joined: Bool
  ) throws -> [UpstreamQueryItem] {
    switch value {
    case .json:
      // Unreachable through a registered capability: `openJSONProblems` refuses
      // the registration at construction. Failing loudly rather than dropping
      // the value keeps that guarantee visible if the rule is ever weakened.
      throw GatewayError.internalFailure(
        "Argument \(name) carries open JSON and cannot be encoded into a query string."
      )
    case .resourceName(let text), .string(let text), .enumeration(let text):
      return [UpstreamQueryItem(name: name, value: text)]
    case .integer(let number):
      return [UpstreamQueryItem(name: name, value: String(number))]
    case .number(let number):
      return [UpstreamQueryItem(name: name, value: String(number))]
    case .boolean(let flag):
      return [UpstreamQueryItem(name: name, value: flag ? "true" : "false")]
    case .stringList(let items):
      // Google reads a repeated field either as repeated parameters or as one
      // comma-separated value; `updateMask` and `fields` are documented with
      // the comma form, which is what `.query` selects.
      return joined
        ? [UpstreamQueryItem(name: name, value: items.joined(separator: ","))]
        : items.map { UpstreamQueryItem(name: name, value: $0) }
    case .page, .destinationPath, .object, .objectList:
      return []
    }
  }

  /// Renders a validated value as JSON, using each input field's upstream key.
  ///
  /// The type travels with the value so a nested object is rendered against its
  /// declared shape rather than by guessing: an input field's public name and
  /// its upstream spelling can differ at any depth, and only the shape knows
  /// which is which.
  private static func jsonValue(_ value: ValidatedArgument, type: ArgumentValueType) -> JSONValue {
    switch value {
    case .resourceName(let text), .string(let text), .enumeration(let text):
      return .string(text)
    case .stringList(let items):
      return .array(items.map(JSONValue.string))
    case .integer(let number): return .int(number)
    case .number(let number): return .double(number)
    case .boolean(let flag): return .bool(flag)
    case .page, .destinationPath: return .null
    case .json(let document):
      // Verbatim: the whole point of the type is that the gateway does not
      // reshape what it does not model.
      return document
    case .object(let fields):
      guard let shape = type.nestedShape else { return .null }
      return jsonObject(fields, shape: shape)
    case .objectList(let entries):
      guard let shape = type.nestedShape else { return .null }
      return .array(entries.map { jsonObject($0, shape: shape) })
    }
  }

  private static func jsonObject(
    _ fields: [String: ValidatedArgument],
    shape: InputObjectShape
  ) -> JSONValue {
    var object: [String: JSONValue] = [:]
    for field in shape.fields {
      guard let value = fields[field.name] else { continue }
      let rendered = jsonValue(value, type: field.type)
      guard !rendered.isNull else { continue }
      object[field.upstreamJSONKey] = rendered
    }
    return .object(object)
  }

  private static func escapePathSegment(_ value: String) -> String {
    value.addingPercentEncoding(
      withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    ) ?? value
  }
}
