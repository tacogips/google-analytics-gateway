import Foundation

/// How a validated argument value reaches the upstream request.
public enum ArgumentBinding: Sendable, Equatable {
  /// Substituted into a `{name}` placeholder in the path template. A Google
  /// resource name is a multi-segment value such as
  /// `properties/1/dataStreams/2`, so one placeholder covers the whole name
  /// rather than a single segment.
  case path(String)
  /// Sent as a single query parameter with the given upstream name.
  case query(String)
  /// Sent as a repeated query parameter, one entry per list element, which is
  /// how Google encodes repeated fields such as `fields` or `pageToken` lists.
  case queryList(String)
  /// Sent as a named JSON body field.
  case bodyJSON(String)
  /// Becomes the entire JSON request body.
  ///
  /// Google's create and update methods take the resource itself as the body,
  /// not a wrapper object, so `properties.dataStreams.create` posts a
  /// `DataStream` rather than `{"dataStream": {...}}`. A definition binds one
  /// argument this way instead of naming a key that does not exist upstream.
  case bodyRoot
  /// Expands to the `pageSize` and `pageToken` query parameters.
  case page
  /// A confirmation echo of another argument's resource name. It contributes
  /// nothing to the URL, query, or body; the planner refuses the request unless
  /// it matches the named `.path` argument exactly.
  case confirm(String)
  /// A validated local destination path. It selects the request's file response
  /// sink and contributes nothing to the upstream URL, query, or body.
  case destinationPath

  /// The `.path` argument a confirmation echoes, if this is one.
  var confirmedArgumentName: String? {
    if case .confirm(let name) = self { return name }
    return nil
  }
}

/// The set of resource-name patterns an argument accepts.
///
/// Google addresses every resource by a slash-separated name whose shape is
/// fixed per method, such as `properties/{property}/dataStreams/{dataStream}`.
/// Validating against the declared pattern locally means a malformed name is a
/// named validation error rather than an upstream 404, and it is what keeps a
/// caller-supplied segment from adding path structure of its own.
public struct ResourceNamePattern: Sendable, Equatable {
  /// Longest accepted resource name, well beyond any documented Google name.
  public static let maximumLength = 1024
  /// Longest accepted single identifier segment.
  public static let maximumSegmentLength = 128

  /// Alternative shapes, any one of which a value may match. A handful of
  /// methods, such as `runAccessReport`, accept either an account or a property
  /// name for the same argument.
  public let alternatives: [String]

  public init(_ alternatives: [String]) {
    self.alternatives = alternatives
  }

  public init(_ pattern: String) {
    self.alternatives = [pattern]
  }

  /// The shapes printed in the schema documentation for the argument.
  public var documentation: String { alternatives.joined(separator: " | ") }

  /// True when `value` matches at least one alternative.
  public func matches(_ value: String) -> Bool {
    guard !value.isEmpty, value.count <= Self.maximumLength else { return false }
    return alternatives.contains { Self.matches(value: value, pattern: $0) }
  }

  private static func matches(value: String, pattern: String) -> Bool {
    let valueSegments = value.split(separator: "/", omittingEmptySubsequences: false)
    let patternSegments = pattern.split(separator: "/", omittingEmptySubsequences: false)
    guard valueSegments.count == patternSegments.count else { return false }
    for (valueSegment, patternSegment) in zip(valueSegments, patternSegments) {
      if patternSegment.hasPrefix("{") && patternSegment.hasSuffix("}") {
        guard isSupportedSegment(valueSegment) else { return false }
      } else if valueSegment != patternSegment {
        return false
      }
    }
    return true
  }

  /// Identifier segments are treated as opaque: only length and character-class
  /// bounds are enforced, and the class excludes every character that could
  /// alter the structure of a path, a query string, or a header.
  private static func isSupportedSegment(_ segment: Substring) -> Bool {
    guard !segment.isEmpty, segment.count <= maximumSegmentLength else { return false }
    return segment.allSatisfy { character in
      character.isASCII
        && (character.isLetter || character.isNumber
          || character == "-" || character == "_" || character == "." || character == "~")
    }
  }
}

public enum ArgumentValueType: Sendable, Equatable {
  /// A Google resource name validated against its documented shape.
  case resourceName(ResourceNamePattern)
  case string
  case stringList
  case integer
  case number
  case boolean
  case page
  case enumeration(String, [String])
  /// A list restricted to a curated set of values, such as the metric
  /// aggregations the Data API accepts. Validating locally means an unaccepted
  /// value is a named validation error rather than an upstream 400.
  case enumerationList(String, [String])
  case inputObject(InputObjectShape)
  /// A repeated request-body object, such as the `dimensions` of a report.
  case inputObjectList(InputObjectShape)
  /// An open-ended JSON value passed to the request body verbatim.
  ///
  /// It exists for the Google structures that are recursive or open by design —
  /// a Tag Manager tag's `parameter` tree, a report request's filter
  /// expression — where an `InputObjectShape` would either reject a document
  /// the API accepts or need editing every time Google adds a key.
  ///
  /// It is deliberately the weakest type here: nothing about the value is
  /// checked, so a definition may only bind it into a request body. Registering
  /// one against a path or query binding is a coherence failure, because an
  /// unvalidated value must never reach a URL.
  case json

  /// Convenience for the common single-shape case.
  public static func resourceName(_ pattern: String) -> ArgumentValueType {
    .resourceName(ResourceNamePattern(pattern))
  }

  /// Convenience for an argument that accepts several documented shapes.
  public static func resourceName(_ alternatives: [String]) -> ArgumentValueType {
    .resourceName(ResourceNamePattern(alternatives))
  }

  public var graphQLTypeName: String {
    switch self {
    case .resourceName: return "String"
    case .string: return "String"
    case .stringList: return "[String!]"
    case .integer: return "Int"
    case .number: return "Float"
    case .boolean: return "Boolean"
    case .page: return "PageInput"
    case .enumeration(let name, _): return name
    case .enumerationList(let name, _): return "[\(name)!]"
    case .inputObject(let shape): return shape.typeName
    case .inputObjectList(let shape): return "[\(shape.typeName)!]"
    case .json: return "JSON"
    }
  }

  /// True when the type carries an unvalidated JSON document.
  public var isOpenJSON: Bool {
    if case .json = self { return true }
    return false
  }

  /// The input object this type carries, if any.
  public var nestedShape: InputObjectShape? {
    switch self {
    case .inputObject(let shape), .inputObjectList(let shape): return shape
    default: return nil
    }
  }
}

public struct ArgumentDefinition: Sendable, Equatable {
  public let name: String
  public let type: ArgumentValueType
  public let binding: ArgumentBinding
  public let isRequired: Bool
  /// Upstream limit on a list argument's length, when the reference documents
  /// one. Enforcing it locally keeps an over-long request from being assembled
  /// at all, rather than sending one Google will refuse.
  public let maximumCount: Int?

  public init(
    _ name: String,
    _ type: ArgumentValueType,
    _ binding: ArgumentBinding,
    required: Bool = false,
    maximumCount: Int? = nil
  ) {
    self.name = name
    self.type = type
    self.binding = binding
    self.isRequired = required
    self.maximumCount = maximumCount
  }

  /// The JSON key this value takes inside a request body.
  ///
  /// A body field binds `.bodyJSON` with the upstream name when the public
  /// argument name differs, so the upstream spelling stays an adapter detail
  /// exactly as it is for a top-level body field.
  public var upstreamJSONKey: String {
    if case .bodyJSON(let upstream) = binding { return upstream }
    return name
  }
}

/// A named GraphQL input object. Google request bodies are passed through to
/// the REST body after their keys are validated against this shape.
public struct InputObjectShape: Sendable, Equatable {
  public let typeName: String
  public let fields: [ArgumentDefinition]

  public init(typeName: String, fields: [ArgumentDefinition]) {
    self.typeName = typeName
    self.fields = fields
  }

  public func field(named name: String) -> ArgumentDefinition? {
    fields.first { $0.name == name }
  }

  /// Every input object reachable from this shape, including itself.
  public var reachableShapes: [InputObjectShape] {
    var collected: [String: InputObjectShape] = [:]
    collect(into: &collected)
    return collected.values.sorted { $0.typeName < $1.typeName }
  }

  private func collect(into collected: inout [String: InputObjectShape]) {
    guard collected[typeName] == nil else { return }
    collected[typeName] = self
    for field in fields {
      field.type.nestedShape?.collect(into: &collected)
    }
  }
}

/// How a successful DELETE response confirms the resource that was removed.
///
/// Google's delete methods answer `200` with an empty JSON object, so the
/// default confirms from the resource name the planner already validated. The
/// other case exists for a reviewed method that echoes the removed resource.
public enum DeletionConfirmation: Sendable, Equatable {
  case validatedRequestResourceNameOnEmptyBody
  case responseResourceName
}

/// The complete, declarative description of one capability.
///
/// Registration is a single value so the GraphQL field, the tier check, the
/// upstream service, the route, the scope metadata, the result projection, and
/// the implementation status cannot drift apart.
public struct CapabilityDefinition: Sendable, Equatable {
  public let id: CapabilityID
  /// Public GraphQL field name.
  public let field: String
  public let tier: CapabilityTier
  public let operationClass: OperationClass
  public let method: HTTPMethod
  /// The Google API this capability calls. It resolves the request origin, so a
  /// definition cannot address a host it does not name.
  public let service: GoogleAPIService
  /// Upstream path including the service's version prefix, for example
  /// `/v1beta/{parent}/dataStreams`. Placeholders are `{name}` tokens bound
  /// from `.path` arguments.
  public let pathTemplate: String
  public let arguments: [ArgumentDefinition]
  public let result: ResultShape
  public let deletionConfirmation: DeletionConfirmation
  public let scopes: ScopeRequirement
  public let maximumPageSize: Int?
  public let status: CapabilityStatus
  /// Documentation string printed in the role schema.
  public let summary: String
  /// Non-secret guidance for an upstream refusal a caller cannot diagnose from
  /// the stable error code alone.
  ///
  /// It exists for the case where Google's refusal is expected and structural
  /// rather than a caller mistake, such as asking for a report dimension the
  /// property has never collected: the code is correct, but on its own it reads
  /// as a missing resource. It never replaces guidance the mapped error already
  /// carries.
  public let upstreamRejectionGuidance: String?

  public init(
    id: CapabilityID,
    field: String,
    tier: CapabilityTier,
    operationClass: OperationClass,
    method: HTTPMethod,
    service: GoogleAPIService,
    pathTemplate: String,
    arguments: [ArgumentDefinition] = [],
    result: ResultShape,
    deletionConfirmation: DeletionConfirmation = .validatedRequestResourceNameOnEmptyBody,
    scopes: ScopeRequirement,
    maximumPageSize: Int? = nil,
    status: CapabilityStatus = .implemented,
    summary: String,
    upstreamRejectionGuidance: String? = nil
  ) {
    self.id = id
    self.field = field
    self.tier = tier
    self.operationClass = operationClass
    self.method = method
    self.service = service
    self.pathTemplate = pathTemplate
    self.arguments = arguments
    self.result = result
    self.deletionConfirmation = deletionConfirmation
    self.scopes = scopes
    self.maximumPageSize = maximumPageSize
    self.status = status
    self.summary = summary
    self.upstreamRejectionGuidance = upstreamRejectionGuidance
  }

  public var isDestructive: Bool { operationClass == .delete }

  /// The guidance to attach to a mapped upstream error, if any.
  ///
  /// It applies only to the codes that mean Google itself refused the request.
  /// A credential, quota, or availability failure has nothing to do with what
  /// the capability asked for, and already carries its own remedy.
  func rejectionGuidance(for code: GatewayErrorCode) -> String? {
    switch code {
    case .notFound, .validationError:
      return upstreamRejectionGuidance
    default:
      return nil
    }
  }

  public func argument(named name: String) -> ArgumentDefinition? {
    arguments.first { $0.name == name }
  }

  /// The single `.path`-bound argument, when the capability has exactly one.
  /// A delete confirms from it, so it is resolved once here rather than by
  /// re-parsing the produced URL.
  public var solePathArgument: ArgumentDefinition? {
    let bound = arguments.filter { if case .path = $0.binding { return true } else { return false } }
    return bound.count == 1 ? bound[0] : nil
  }

  /// Structural invariants that every registration must satisfy. Violations are
  /// internal errors surfaced by the registry's coherence test.
  public func coherenceProblems() -> [String] {
    var problems: [String] = []
    if operationClass == .delete && tier != .admin {
      problems.append("\(id) is a delete operation outside the admin tier.")
    }
    if method == .delete && tier != .admin {
      problems.append("\(id) uses HTTP DELETE outside the admin tier.")
    }
    if operationClass == .read && method != .get && method != .post {
      problems.append("\(id) is a read operation but does not use HTTP GET or POST.")
    }
    // Reads live in the reader tier, with one deliberate exception: principal
    // and permission reads (Tag Manager user_permissions) are administrative
    // even though they are HTTP GETs, so the admin tier may register reads.
    // The writer tier may not — no method in the covered surface is a
    // writer-only read.
    if operationClass == .read && tier == .writer {
      problems.append("\(id) is a read operation registered in the writer tier.")
    }
    if operationClass.isMutation && method == .get {
      problems.append("\(id) is a mutation bound to HTTP GET.")
    }
    if case .deletion = result, operationClass != .delete {
      problems.append("\(id) returns a deletion payload without being a delete operation.")
    }
    if deletionConfirmation == .responseResourceName {
      if case .deletion = result {} else {
        problems.append("\(id) declares deletion confirmation without returning a deletion payload.")
      }
    }
    if operationClass == .delete, case .deletion = result {} else if operationClass == .delete {
      problems.append("\(id) is a delete operation that does not return a deletion payload.")
    }
    if case .connection = result, maximumPageSize == nil {
      problems.append("\(id) returns a connection without a documented maximum page size.")
    }
    if maximumPageSize != nil, !arguments.contains(where: { $0.binding == .page }) {
      problems.append("\(id) declares a maximum page size without a page argument.")
    }
    problems.append(contentsOf: routeProblems())
    problems.append(contentsOf: bodyProblems())
    problems.append(contentsOf: confirmationProblems())
    problems.append(contentsOf: fileOutputProblems())
    problems.append(contentsOf: pathPlaceholderProblems())
    if !scopes.accepted.contains(scopes.recommended) {
      problems.append("\(id) recommends a scope that is not in its accepted list.")
    }
    if field.isEmpty || summary.isEmpty {
      problems.append("\(id) is missing a field name or summary.")
    }
    return problems
  }

  /// The route must belong to the service it names. Without this a v1alpha-only
  /// resource could be registered against the v1beta service and answer 404 for
  /// a reason no error message would explain.
  private func routeProblems() -> [String] {
    var problems: [String] = []
    if !pathTemplate.hasPrefix("/") {
      problems.append("\(id) path template does not start with a slash.")
    }
    if !service.owns(pathTemplate: pathTemplate) {
      problems.append(
        "\(id) path template does not start with the \(service.pathPrefix) prefix of \(service.rawValue)."
      )
    }
    return problems
  }

  /// A GET carries no body, and a body has exactly one root. Binding a root and
  /// a named field at once would produce a document whose shape depends on the
  /// order the arguments happen to be declared in.
  private func bodyProblems() -> [String] {
    var problems: [String] = []
    let roots = arguments.filter { $0.binding == .bodyRoot }
    let named = arguments.filter { if case .bodyJSON = $0.binding { return true } else { return false } }
    if roots.count > 1 {
      problems.append("\(id) binds more than one argument to the request body root.")
    }
    if !roots.isEmpty, !named.isEmpty {
      problems.append("\(id) mixes a request body root with named body fields.")
    }
    if method == .get, !roots.isEmpty || !named.isEmpty {
      problems.append("\(id) sends a request body on an HTTP GET.")
    }
    problems.append(contentsOf: openJSONProblems())
    return problems
  }

  /// An open JSON value is unvalidated by construction, so it may only travel
  /// in a request body. Binding one into a path or a query string would put a
  /// caller-supplied document into a URL, where no shape check stands between
  /// it and the route. Enforcing it at registration means no capability can be
  /// written that way in the first place.
  private func openJSONProblems() -> [String] {
    var problems: [String] = []
    for argument in arguments where argument.type.isOpenJSON {
      switch argument.binding {
      case .bodyJSON, .bodyRoot:
        continue
      default:
        problems.append(
          "\(id) binds open JSON argument \(argument.name) outside a request body."
        )
      }
    }
    for shape in arguments.compactMap({ $0.type.nestedShape }) {
      for nested in shape.reachableShapes {
        for field in nested.fields where field.type.isOpenJSON {
          switch field.binding {
          case .bodyJSON, .bodyRoot:
            continue
          default:
            problems.append(
              "\(id) binds open JSON input field \(nested.typeName).\(field.name) outside a request body."
            )
          }
        }
      }
    }
    return problems
  }

  /// A destructive operation must be confirmed by echoing the resource it
  /// removes. The echo is checked against the same validated value the path is
  /// built from, so a confirmation can only ever agree with what is actually
  /// being deleted.
  private func confirmationProblems() -> [String] {
    var problems: [String] = []
    let confirmations = arguments.filter { $0.binding.confirmedArgumentName != nil }
    if operationClass == .delete, confirmations.count != 1 {
      problems.append("\(id) is a delete operation without exactly one confirmation argument.")
    }
    if confirmations.count > 1 {
      problems.append("\(id) declares more than one confirmation argument.")
    }
    for confirmation in confirmations {
      if !confirmation.isRequired {
        problems.append("\(id) has an optional confirmation argument \(confirmation.name).")
      }
      guard let targetName = confirmation.binding.confirmedArgumentName else { continue }
      guard let target = argument(named: targetName) else {
        problems.append("\(id) confirmation \(confirmation.name) names unknown argument \(targetName).")
        continue
      }
      if case .path = target.binding {} else {
        problems.append("\(id) confirmation \(confirmation.name) names \(targetName), which is not a path argument.")
      }
    }
    return problems
  }

  /// A destination path and a file result are two halves of the same contract.
  /// Either alone would be a silent hazard: a sink with no file result would
  /// write bytes the caller never asked to receive, and a file result with no
  /// sink would leave the projection with nothing to describe. Only reads may
  /// write a destination, so no mutation can be made to produce a local file as
  /// a side effect.
  private func fileOutputProblems() -> [String] {
    var problems: [String] = []
    let destinations = arguments.filter { $0.binding == .destinationPath }
    if result.isFileOutput {
      if destinations.count != 1 {
        problems.append("\(id) returns a file output without exactly one destination argument.")
      }
      if !destinations.allSatisfy(\.isRequired) {
        problems.append("\(id) has an optional destination argument for a file output.")
      }
      if operationClass != .read {
        problems.append("\(id) writes a local file but is not a read operation.")
      }
    } else if !destinations.isEmpty {
      problems.append("\(id) accepts a destination argument without returning a file output.")
    }
    return problems
  }

  /// Placeholder names bound by an argument. Google mutations bind their path
  /// arguments at the top level, so nested body fields never carry a `.path`
  /// binding and are not consulted here.
  private static func boundPathNames(in arguments: [ArgumentDefinition]) -> Set<String> {
    var names: Set<String> = []
    for argument in arguments {
      if case .path(let name) = argument.binding {
        names.insert(name)
      }
    }
    return names
  }

  private func pathPlaceholderProblems() -> [String] {
    var problems: [String] = []
    let boundNames = Self.boundPathNames(in: arguments)
    for placeholder in Self.placeholders(in: pathTemplate) where !boundNames.contains(placeholder) {
      problems.append("\(id) path template references unbound placeholder {\(placeholder)}.")
    }
    for name in boundNames where !pathTemplate.contains("{\(name)}") {
      problems.append("\(id) binds argument to path placeholder {\(name)} that the template does not use.")
    }
    for argument in arguments {
      guard case .path = argument.binding else { continue }
      if case .resourceName = argument.type { continue }
      problems.append("\(id) binds \(argument.name) into the path without a resource-name shape.")
    }
    return problems
  }

  static func placeholders(in template: String) -> [String] {
    var names: [String] = []
    var current: String?
    for character in template {
      if character == "{" {
        current = ""
      } else if character == "}" {
        if let name = current { names.append(name) }
        current = nil
      } else if current != nil {
        current?.append(character)
      }
    }
    return names
  }
}
