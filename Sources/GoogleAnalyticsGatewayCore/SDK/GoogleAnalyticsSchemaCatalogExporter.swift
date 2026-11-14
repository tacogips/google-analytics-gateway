import GatewaySDKKit

/// Derives the neutral kit catalog from the registry source of truth.
public enum GoogleAnalyticsSchemaCatalogExporter {
  public static func export(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition]
  ) throws -> GatewaySchemaCatalog {
    let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
    var types: [String: GatewayNamedType] = [:]

    func add(_ type: GatewayNamedType) throws {
      if let existing = types[type.name], existing != type {
        throw GatewayError.internalFailure("Catalog type \(type.name) has incompatible shapes.")
      }
      types[type.name] = type
    }

    try add(GatewayNamedType(name: "PageInfo", kind: .object([
      GatewayField(name: "nextPageToken", type: .named("String")),
      GatewayField(name: "resultCount", type: .nonNull(.named("Int")))
    ])))

    func inputType(_ argument: ArgumentValueType) -> GatewayTypeRef {
      switch argument {
      case .resourceName: .named("ID")
      case .string: .named("String")
      case .stringList: .list(.nonNull(.named("String")))
      case .integer: .named("Int")
      case .number: .named("Float")
      case .boolean: .named("Boolean")
      case .page: .named("PageInput")
      case .enumeration(let name, _): .named(name)
      case .enumerationList(let name, _): .list(.nonNull(.named(name)))
      case .inputObject(let shape): .named(shape.typeName)
      case .inputObjectList(let shape): .list(.nonNull(.named(shape.typeName)))
      case .json: .named("JSON")
      }
    }

    /// Catalog resource-name arguments intentionally use ID, while nested input
    /// fields retain the executable schema's String representation.
    func inputObjectFieldType(_ argument: ArgumentValueType) -> GatewayTypeRef {
      if case .resourceName = argument { return .named("String") }
      return inputType(argument)
    }

    func addInput(_ argument: ArgumentValueType) throws {
      switch argument {
      case .enumeration(let name, let values), .enumerationList(let name, let values):
        try add(GatewayNamedType(name: name, kind: .enumeration(values.sorted())))
      case .inputObject(let shape), .inputObjectList(let shape):
        for nested in shape.reachableShapes {
          try add(GatewayNamedType(
            name: nested.typeName,
            kind: .inputObject(nested.fields.map { field in
              GatewayArgument(
                name: field.name,
                type: field.isRequired
                  ? .nonNull(inputObjectFieldType(field.type))
                  : inputObjectFieldType(field.type),
                isRequired: field.isRequired
              )
            }.sorted { $0.name < $1.name })
          ))
          for field in nested.fields { try addInput(field.type) }
        }
      case .page:
        try add(GatewayNamedType(name: "PageInput", kind: .inputObject([
          GatewayArgument(name: "nextPageToken", type: .named("String")),
          GatewayArgument(name: "pageSize", type: .named("Int"))
        ])))
      default: break
      }
    }

    func outputType(_ type: ModelFieldType) -> GatewayTypeRef {
      switch type {
      // Resource-name arguments use ID as a catalog convenience, but returned
      // model fields retain the runtime schema's String representation.
      case .resourceName: .named("String")
      case .string, .dateTime, .date: .named("String")
      case .integer: .named("Int")
      case .number: .named("Float")
      case .boolean: .named("Boolean")
      case .stringList: .list(.nonNull(.named("String")))
      case .json: .named("JSON")
      case .object(let shape): .named(shape.typeName)
      case .objectList(let shape): .list(.nonNull(.named(shape.typeName)))
      }
    }

    func addOutput(_ shape: ModelShape) throws {
      for nested in shape.reachableShapes {
        try add(GatewayNamedType(name: nested.typeName, kind: .object(
          nested.fields.map { field in
            GatewayField(name: field.name, type: field.isRequired ? .nonNull(outputType(field.type)) : outputType(field.type))
          }.sorted { $0.name < $1.name }
        )))
      }
    }

    func resultType(_ result: ResultShape) throws -> GatewayTypeRef {
      switch result {
      case .single(let shape):
        try addOutput(shape); return .named(shape.typeName)
      case .fileOutput(let shape):
        try addOutput(shape); return .nonNull(.named(shape.typeName))
      case .connection(_, let shape):
        try addOutput(shape)
        try add(GatewayNamedType(name: "\(shape.typeName)Connection", kind: .object([
          GatewayField(name: "nodes", type: .nonNull(.list(.nonNull(.named(shape.typeName))))),
          GatewayField(name: "pageInfo", type: .nonNull(.named("PageInfo")))
        ])))
        return .named("\(shape.typeName)Connection")
      case .list(_, let shape):
        try addOutput(shape); return .nonNull(.list(.nonNull(.named(shape.typeName))))
      case .payload(let field, let shape):
        try addOutput(shape)
        try add(GatewayNamedType(name: "\(shape.typeName)Payload", kind: .object([
          GatewayField(name: field, type: .nonNull(.named(shape.typeName)))
        ])))
        return .named("\(shape.typeName)Payload")
      case .deletion:
        try add(GatewayNamedType(name: "DeletionPayload", kind: .object([
          GatewayField(name: "deletedName", type: .nonNull(.named("String")))
        ])))
        return .named("DeletionPayload")
      }
    }

    let operations = try registry.definitions.map { definition -> GatewayOperation in
      for argument in definition.arguments { try addInput(argument.type) }
      let kind: GatewayOperation.Kind = definition.operationClass.isMutation ? .mutation : .query
      return GatewayOperation(
        name: definition.field, kind: kind, tier: definition.tier.rawValue,
        arguments: definition.arguments.map { argument in
          GatewayArgument(
            name: argument.name,
            type: argument.isRequired ? .nonNull(inputType(argument.type)) : inputType(argument.type),
            isRequired: argument.isRequired,
            description: argumentDescription(argument)
          )
        }.sorted { $0.name < $1.name },
        result: try resultType(definition.result), summary: definition.summary,
        isDestructive: definition.isDestructive,
        domain: try domain(for: definition.field)
      )
    }.sorted { lhs, rhs in
      if lhs.kind != rhs.kind { return operationOrder(lhs.kind) < operationOrder(rhs.kind) }
      return lhs.name < rhs.name
    }
    let catalog = GatewaySchemaCatalog(
      provider: "google-analytics-gateway", tier: role.tier.rawValue,
      operations: operations, types: types.values.sorted { $0.name < $1.name }
    )
    guard catalog.validate().isEmpty else {
      throw GatewayError.internalFailure("Generated SDK schema catalog is invalid.")
    }
    return catalog
  }

  private static func argumentDescription(_ argument: ArgumentDefinition) -> String? {
    if case .resourceName(let pattern) = argument.type {
      return "Resource name pattern: \(pattern.documentation)"
    }
    return argument.type.nestedShape?.typeName
  }

  private static func domain(for field: String) throws -> String {
    if field.hasPrefix("ga") { return "ga" }
    if field.hasPrefix("gtm") { return "gtm" }
    throw GatewayError.internalFailure("Catalog operation \(field) has no ga or gtm prefix.")
  }

  private static func operationOrder(_ kind: GatewayOperation.Kind) -> Int {
    switch kind {
    case .query: 0
    case .mutation: 1
    case .command: 2
    }
  }
}
