import Foundation

/// The stable output type of a capability.
///
/// A shape is the single source of truth for three derived artifacts: the
/// printed GraphQL type, the validator's field list, and the upstream-to-stable
/// projection. Deriving all three from one declaration is what makes the
/// bidirectional field-to-route coherence check mechanical.
public struct ModelShape: Sendable, Equatable {
  public let typeName: String
  public let fields: [ModelField]

  public init(typeName: String, fields: [ModelField]) {
    self.typeName = typeName
    self.fields = fields
  }

  public func field(named name: String) -> ModelField? {
    fields.first { $0.name == name }
  }

  /// Every object type reachable from this shape, including itself.
  public var reachableShapes: [ModelShape] {
    var collected: [String: ModelShape] = [:]
    collect(into: &collected)
    return collected.values.sorted { $0.typeName < $1.typeName }
  }

  private func collect(into collected: inout [String: ModelShape]) {
    guard collected[typeName] == nil else { return }
    collected[typeName] = self
    for field in fields {
      field.type.nestedShape?.collect(into: &collected)
    }
  }
}

public struct ModelField: Sendable, Equatable {
  /// Project-owned stable field name exposed by GraphQL and the SDK.
  public let name: String
  /// Upstream Google field name; an adapter detail that never reaches output.
  public let upstreamName: String
  public let type: ModelFieldType
  /// True when the projection must produce a value for the field.
  public let isRequired: Bool

  public init(_ name: String, upstream: String? = nil, _ type: ModelFieldType, required: Bool = false) {
    self.name = name
    self.upstreamName = upstream ?? name
    self.type = type
    self.isRequired = required
  }
}

public indirect enum ModelFieldType: Sendable, Equatable {
  /// A Google resource name, preserved verbatim as an opaque string.
  case resourceName
  case string
  case integer
  case number
  case boolean
  /// RFC 3339 instant, preserved verbatim as an opaque timestamp string.
  case dateTime
  /// Calendar date, preserved verbatim.
  case date
  case stringList
  /// An open-ended JSON subtree carried through verbatim.
  ///
  /// A few Google structures are recursive or open by design — a Tag Manager
  /// tag's `parameter` tree, a report request's filter expression, a report
  /// response's rows — and declaring a fixed `ModelShape` for them would either
  /// truncate values the API legitimately returns or need editing every time
  /// Google adds a key. The subtree is projected exactly as received.
  ///
  /// It is a leaf: it has no nested shape, so selecting sub-fields inside it is
  /// a validation error and selecting the field returns the whole subtree. That
  /// keeps the open-endedness out of the selection contract, where it could
  /// otherwise be mistaken for a shape the gateway validates.
  case json
  case object(ModelShape)
  case objectList(ModelShape)

  public var nestedShape: ModelShape? {
    switch self {
    case .object(let shape), .objectList(let shape): return shape
    default: return nil
    }
  }

  /// The printed GraphQL type name for this field.
  public var graphQLTypeName: String {
    switch self {
    case .resourceName: return "String"
    case .string, .dateTime, .date: return "String"
    case .integer: return "Int"
    case .number: return "Float"
    case .boolean: return "Boolean"
    case .stringList: return "[String!]"
    case .json: return "JSON"
    case .object(let shape): return shape.typeName
    case .objectList(let shape): return "[\(shape.typeName)!]"
    }
  }

  /// True when the field selects a nested selection set. An open JSON field is
  /// not composite: it is a leaf whose value happens to be a document.
  public var isComposite: Bool { nestedShape != nil }

  /// True when the field carries an open JSON subtree.
  public var isOpenJSON: Bool {
    if case .json = self { return true }
    return false
  }
}

/// How a capability's upstream payload becomes a public result.
///
/// Google has no shared response envelope: a `get` answers with the resource
/// itself, and a `list` answers with `{"<collection>": [...], "nextPageToken"}`
/// where the collection key differs per method and is omitted entirely when the
/// result is empty. Collection results therefore carry the upstream key rather
/// than assuming a fixed `data` field.
public enum ResultShape: Sendable, Equatable {
  /// The response body is the entity itself.
  case single(ModelShape)
  /// A `nodes` plus `pageInfo` connection read from the named upstream
  /// collection key, for example `dataStreams`.
  case connection(collection: String, ModelShape)
  /// A plain list with no pagination contract, read from the named upstream
  /// collection key.
  case list(collection: String, ModelShape)
  /// A mutation payload wrapping the returned entity under a named field.
  case payload(field: String, ModelShape)
  /// A destructive result carrying only the confirmed deleted resource name.
  case deletion
  /// A body written to the caller's destination path. The result describes the
  /// written file; the bytes themselves never enter the response value.
  case fileOutput(ModelShape)

  public var elementShape: ModelShape? {
    switch self {
    case .single(let shape), .fileOutput(let shape):
      return shape
    case .connection(_, let shape), .list(_, let shape), .payload(_, let shape):
      return shape
    case .deletion:
      return nil
    }
  }

  /// The upstream key a collection result reads its entities from.
  public var collectionKey: String? {
    switch self {
    case .connection(let key, _), .list(let key, _): return key
    default: return nil
    }
  }

  /// True when the capability answers with a body written to disk rather than
  /// with a JSON document.
  public var isFileOutput: Bool {
    if case .fileOutput = self { return true }
    return false
  }

  /// The GraphQL type name printed for the capability's field.
  public var graphQLTypeName: String {
    switch self {
    case .single(let shape): return shape.typeName
    case .connection(_, let shape): return "\(shape.typeName)Connection"
    case .list(_, let shape): return "[\(shape.typeName)!]!"
    case .payload(_, let shape): return "\(shape.typeName)Payload"
    case .deletion: return "DeletionPayload"
    case .fileOutput(let shape): return "\(shape.typeName)!"
    }
  }
}

/// The stable result of a capability that writes its body to a local file.
///
/// Declared in core rather than per resource so every file-output capability
/// answers with the same three facts and none can add a field that could hold
/// content.
public enum FileOutputShape {
  public static let shape = ModelShape(
    typeName: "DownloadedFile",
    fields: [
      ModelField("path", .string, required: true),
      ModelField("byteCount", .integer, required: true),
      ModelField("contentType", .string)
    ]
  )
}
