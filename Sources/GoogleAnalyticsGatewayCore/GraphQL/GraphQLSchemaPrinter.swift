import Foundation

/// Renders the role-specific schema from the linked capability registry.
///
/// The printed document is derived from the same declarations the validator and
/// the projection use, so the schema a binary prints cannot describe a field it
/// cannot execute. It is always rendered locally and never fetched from a Google
/// API.
public struct GraphQLSchemaPrinter: Sendable {
  private let registry: CapabilityRegistry

  public init(registry: CapabilityRegistry) {
    self.registry = registry
  }

  public func print() -> String {
    var sections: [String] = []
    sections.append(header())
    sections.append(scalarsAndSharedTypes())
    sections.append(inputTypes())
    sections.append(objectTypes())
    sections.append(rootTypes())
    return sections.filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
  }

  private func header() -> String {
    """
    # google-analytics-gateway \(registry.tier.rawValue) schema
    # Owned and versioned by google-analytics-gateway. Rendered locally from the
    # linked capability registry; it is never fetched from a Google API.
    """
  }

  private func scalarsAndSharedTypes() -> String {
    var blocks: [String] = []
    if usesJSONScalar {
      blocks.append(
        """
        \"\"\"An open JSON value carried through verbatim. It has no sub-fields to
        select: reading it yields the whole subtree exactly as the Google API
        returned it.\"\"\"
        scalar JSON
        """
      )
    }
    blocks.append(
      """
      type PageInfo {
        resultCount: Int!
        nextPageToken: String
      }
      """
    )
    if !registry.definitions.filter({ $0.operationClass == .delete }).isEmpty {
      blocks.append(
        """
        \"\"\"Result of a destructive operation. Contains the confirmed deleted resource name.\"\"\"
        type DeletionPayload {
          deletedName: String!
        }
        """
      )
    }
    return blocks.joined(separator: "\n\n")
  }

  /// True when any linked capability accepts or returns an open JSON value.
  ///
  /// The scalar is declared only when it is used, so a schema that models every
  /// one of its types does not advertise an escape hatch it never takes.
  private var usesJSONScalar: Bool {
    registry.definitions.contains { definition in
      if definition.arguments.contains(where: { $0.type.isOpenJSON }) { return true }
      let inputShapes = definition.arguments.compactMap { $0.type.nestedShape }
      let inInput = inputShapes.contains { shape in
        shape.reachableShapes.contains { $0.fields.contains { $0.type.isOpenJSON } }
      }
      if inInput { return true }
      guard let element = definition.result.elementShape else { return false }
      return element.reachableShapes.contains { $0.fields.contains { $0.type.isOpenJSON } }
    }
  }

  private func inputTypes() -> String {
    var rendered: [String: String] = [:]
    var usesPage = false
    var enumerations: [String: [String]] = [:]

    for definition in registry.definitions {
      for argument in definition.arguments {
        collectInput(argument, into: &rendered, enumerations: &enumerations)
        if case .page = argument.type { usesPage = true }
      }
    }

    var blocks: [String] = []
    if usesPage {
      blocks.append(
        """
        input PageInput {
          pageSize: Int
          nextPageToken: String
        }
        """
      )
    }
    blocks.append(contentsOf: enumerations.keys.sorted().map { name in
      let values = (enumerations[name] ?? []).map { "  \($0)" }.joined(separator: "\n")
      return "enum \(name) {\n\(values)\n}"
    })
    blocks.append(contentsOf: rendered.keys.sorted().compactMap { rendered[$0] })
    return blocks.joined(separator: "\n\n")
  }

  private func collectInput(
    _ argument: ArgumentDefinition,
    into rendered: inout [String: String],
    enumerations: inout [String: [String]]
  ) {
    switch argument.type {
    case .enumeration(let name, let cases), .enumerationList(let name, let cases):
      enumerations[name] = cases
    case .inputObject(let shape), .inputObjectList(let shape):
      guard rendered[shape.typeName] == nil else { return }
      // Reserve the name first so a self-referencing shape cannot recurse.
      rendered[shape.typeName] = ""
      let fields = shape.fields
        .sorted { $0.name < $1.name }
        .map { "  \($0.name): \($0.type.graphQLTypeName)\($0.isRequired ? "!" : "")" }
        .joined(separator: "\n")
      rendered[shape.typeName] = "input \(shape.typeName) {\n\(fields)\n}"
      for field in shape.fields {
        collectInput(field, into: &rendered, enumerations: &enumerations)
      }
    default:
      return
    }
  }

  private func objectTypes() -> String {
    var shapes: [String: ModelShape] = [:]
    var connections: Set<String> = []
    var payloads: [String: String] = [:]

    for definition in registry.definitions {
      guard let element = definition.result.elementShape else { continue }
      for shape in element.reachableShapes {
        shapes[shape.typeName] = shape
      }
      if case .connection = definition.result {
        connections.insert(element.typeName)
      }
      if case .payload(let field, _) = definition.result {
        payloads[element.typeName] = field
      }
    }

    var blocks: [String] = []
    for name in shapes.keys.sorted() {
      guard let shape = shapes[name] else { continue }
      let fields = shape.fields
        .map { "  \($0.name): \($0.type.graphQLTypeName)\($0.isRequired ? "!" : "")" }
        .joined(separator: "\n")
      blocks.append("type \(shape.typeName) {\n\(fields)\n}")
    }
    for name in connections.sorted() {
      blocks.append(
        """
        type \(name)Connection {
          nodes: [\(name)!]!
          pageInfo: PageInfo!
        }
        """
      )
    }
    for name in payloads.keys.sorted() {
      guard let field = payloads[name] else { continue }
      blocks.append("type \(name)Payload {\n  \(field): \(name)!\n}")
    }
    return blocks.joined(separator: "\n\n")
  }

  private func rootTypes() -> String {
    var blocks: [String] = []
    let queries = registry.queryDefinitions
    if !queries.isEmpty {
      blocks.append("type Query {\n\(queries.map(fieldLine).joined(separator: "\n"))\n}")
    }
    let mutations = registry.mutationDefinitions
    if !mutations.isEmpty {
      blocks.append("type Mutation {\n\(mutations.map(fieldLine).joined(separator: "\n"))\n}")
    }
    return blocks.joined(separator: "\n\n")
  }

  private func fieldLine(_ definition: CapabilityDefinition) -> String {
    let prefix = definition.isDestructive ? "DESTRUCTIVE. " : ""
    let summary =
      "  \"\"\"\(prefix)\(definition.summary) Capability: \(definition.id)."
      + "\(resourceNameShapes(definition))\"\"\""
    let arguments = definition.arguments
      .sorted { $0.name < $1.name }
      .map { "\($0.name): \($0.type.graphQLTypeName)\($0.isRequired ? "!" : "")" }
      .joined(separator: ", ")
    let signature = arguments.isEmpty
      ? "  \(definition.field): \(definition.result.graphQLTypeName)"
      : "  \(definition.field)(\(arguments)): \(definition.result.graphQLTypeName)"
    return "\(summary)\n\(signature)"
  }

  /// The documented shape of each resource-name argument, appended to the
  /// field's docstring.
  ///
  /// A resource name prints as a bare `String`, so without this a caller learns
  /// that `parent` must look like `properties/{property}` only by sending a
  /// request that fails validation. The shapes are read from the same
  /// `ResourceNamePattern` the planner enforces, so the documented form and the
  /// accepted form cannot drift apart.
  private func resourceNameShapes(_ definition: CapabilityDefinition) -> String {
    let shapes = definition.arguments
      .sorted { $0.name < $1.name }
      .compactMap { argument -> String? in
        guard case .resourceName(let pattern) = argument.type else { return nil }
        return "\(argument.name): \(pattern.documentation)"
      }
    guard !shapes.isEmpty else { return "" }
    return " Resource names: \(shapes.joined(separator: ", "))."
  }
}
