import Foundation

/// A validated argument value. Coercion happens once, in the planner, so the
/// typed SDK path and the GraphQL path cannot disagree about what a value means.
public indirect enum ValidatedArgument: Sendable, Equatable {
  /// A Google resource name that matched its declared shape.
  case resourceName(String)
  case string(String)
  case stringList([String])
  case integer(Int)
  case number(Double)
  case boolean(Bool)
  case enumeration(String)
  case page(PageInput)
  case destinationPath(String)
  case object([String: ValidatedArgument])
  case objectList([[String: ValidatedArgument]])
  /// An open JSON document accepted verbatim. The registry confines it to a
  /// request body, so an unchecked value can never reach a URL.
  case json(JSONValue)
}

/// Why a declared destination path cannot receive a downloaded body.
///
/// Each case is a distinct operator mistake with a distinct remedy, so they are
/// reported separately rather than collapsed into one "unusable path".
public enum DestinationProblem: String, Sendable, Equatable, CaseIterable {
  case alreadyExists
  case isDirectory
  case parentMissing
  case parentNotWritable

  public var summary: String {
    switch self {
    case .alreadyExists: return "already exists"
    case .isDirectory: return "names a directory"
    case .parentMissing: return "has no existing parent directory"
    case .parentNotWritable: return "has a parent directory that is not writable"
    }
  }

  public var recovery: String {
    switch self {
    case .alreadyExists:
      return "Choose a path that does not exist yet; a download never replaces a local file."
    case .isDirectory:
      return "Provide the full path of the file to create, including its name."
    case .parentMissing, .parentNotWritable:
      return "Create a writable parent directory first, then retry."
    }
  }
}

/// Checks that a declared destination path can be created.
public protocol FileAccess: Sendable {
  /// `nil` when the path can be created as a new file.
  func destinationProblem(atPath path: String) -> DestinationProblem?
}

public struct SystemFileAccess: FileAccess {
  public init() {}

  /// Checked before the request is sent so an unusable path costs no upstream
  /// call. The transport still refuses to overwrite, so a file that appears
  /// between this check and the write is caught there rather than clobbered.
  public func destinationProblem(atPath path: String) -> DestinationProblem? {
    let manager = FileManager.default
    var isDirectory: ObjCBool = false
    if manager.fileExists(atPath: path, isDirectory: &isDirectory) {
      return isDirectory.boolValue ? .isDirectory : .alreadyExists
    }
    let parent = (path as NSString).deletingLastPathComponent
    let resolved = parent.isEmpty ? FileManager.default.currentDirectoryPath : parent
    var parentIsDirectory: ObjCBool = false
    guard manager.fileExists(atPath: resolved, isDirectory: &parentIsDirectory),
          parentIsDirectory.boolValue
    else {
      return .parentMissing
    }
    return manager.isWritableFile(atPath: resolved) ? nil : .parentNotWritable
  }
}

/// Coerces raw request arguments into validated values.
public struct ArgumentCoercer: Sendable {
  private let fileAccess: any FileAccess

  public init(fileAccess: any FileAccess = SystemFileAccess()) {
    self.fileAccess = fileAccess
  }

  /// Validates all arguments of a capability invocation. Unknown arguments and
  /// missing required arguments both fail before authentication or transport.
  public func coerce(
    arguments: [String: JSONValue],
    for definition: CapabilityDefinition
  ) throws -> [String: ValidatedArgument] {
    for name in arguments.keys where definition.argument(named: name) == nil {
      throw GatewayError.validation(
        "Unknown argument \(name) for field \(definition.field).",
        recovery: "Run `graphql schema` to see the arguments this binary accepts."
      )
    }

    var validated: [String: ValidatedArgument] = [:]
    for parameter in definition.arguments {
      guard let raw = arguments[parameter.name], !raw.isNull else {
        if parameter.isRequired {
          throw GatewayError.validation(
            "Argument \(parameter.name) is required for field \(definition.field)."
          )
        }
        continue
      }
      if parameter.binding == .destinationPath {
        validated[parameter.name] = .destinationPath(
          try destinationPath(raw, path: parameter.name)
        )
        continue
      }
      validated[parameter.name] = try coerce(
        raw,
        type: parameter.type,
        path: parameter.name,
        capability: definition.id,
        maximumPageSize: definition.maximumPageSize,
        maximumCount: parameter.maximumCount
      )
    }
    return validated
  }

  private func coerce(
    _ value: JSONValue,
    type: ArgumentValueType,
    path: String,
    capability: CapabilityID,
    maximumPageSize: Int?,
    maximumCount: Int? = nil
  ) throws -> ValidatedArgument {
    switch type {
    case .resourceName(let pattern):
      return .resourceName(try resourceName(value, pattern: pattern, path: path))
    case .string:
      guard let text = value.stringValue else { throw typeError(path, "String", value) }
      return .string(text)
    case .stringList:
      let items = try list(value, path: path, maximumCount: maximumCount)
      return .stringList(try items.enumerated().map { entry in
        guard let text = entry.element.stringValue else {
          throw typeError("\(path)[\(entry.offset)]", "String", entry.element)
        }
        return text
      })
    case .integer:
      guard let number = value.intValue else { throw typeError(path, "Int", value) }
      return .integer(number)
    case .number:
      guard let number = value.doubleValue else { throw typeError(path, "Float", value) }
      return .number(number)
    case .boolean:
      guard let flag = value.boolValue else { throw typeError(path, "Boolean", value) }
      return .boolean(flag)
    case .enumeration(let name, let cases):
      guard let text = value.stringValue else { throw typeError(path, name, value) }
      guard cases.contains(text) else {
        throw GatewayError.validation(
          "Argument \(path) must be one of: \(cases.joined(separator: ", "))."
        )
      }
      return .enumeration(text)
    case .enumerationList(let name, let cases):
      let items = try list(value, path: path, maximumCount: maximumCount)
      return .stringList(try items.enumerated().map { entry in
        guard let text = entry.element.stringValue else {
          throw typeError("\(path)[\(entry.offset)]", name, entry.element)
        }
        guard cases.contains(text) else {
          throw GatewayError.validation(
            "Argument \(path)[\(entry.offset)] must be one of: \(cases.joined(separator: ", "))."
          )
        }
        return text
      })
    case .page:
      return .page(try page(value, path: path, capability: capability, maximum: maximumPageSize))
    case .inputObject(let shape):
      return .object(try inputObject(value, shape: shape, path: path, capability: capability))
    case .inputObjectList(let shape):
      let items = try list(value, path: path, maximumCount: maximumCount)
      return .objectList(try items.enumerated().map { entry in
        try inputObject(
          entry.element,
          shape: shape,
          path: "\(path)[\(entry.offset)]",
          capability: capability
        )
      })
    case .json:
      // Accepted verbatim, of any JSON kind. There is deliberately no check
      // here: the point of the type is to carry a document whose shape the
      // gateway does not model. What keeps that safe is the registration rule
      // confining it to a request body, not a validation step. A null only
      // reaches this point when the argument is optional, because the required
      // check above already rejected an omitted required argument.
      return .json(value)
    }
  }

  private func inputObject(
    _ value: JSONValue,
    shape: InputObjectShape,
    path: String,
    capability: CapabilityID
  ) throws -> [String: ValidatedArgument] {
    guard let fields = value.objectValue else {
      throw typeError(path, shape.typeName, value)
    }
    for name in fields.keys where shape.field(named: name) == nil {
      throw GatewayError.validation("Unknown input field \(path).\(name) for \(shape.typeName).")
    }
    var validated: [String: ValidatedArgument] = [:]
    for field in shape.fields {
      guard let raw = fields[field.name], !raw.isNull else {
        if field.isRequired {
          throw GatewayError.validation("Input field \(path).\(field.name) is required.")
        }
        continue
      }
      validated[field.name] = try coerce(
        raw,
        type: field.type,
        path: "\(path).\(field.name)",
        capability: capability,
        maximumPageSize: nil,
        maximumCount: field.maximumCount
      )
    }
    return validated
  }

  /// Validates a path the gateway will create. The check is local, so an
  /// unusable destination never costs an upstream request or a credential.
  private func destinationPath(_ value: JSONValue, path: String) throws -> String {
    guard let text = value.stringValue, !text.isEmpty else {
      throw typeError(path, "String", value)
    }
    guard !text.contains("\0") else {
      throw GatewayError(code: .fileOperationFailed, message: "\(path) is not a valid file path.")
    }
    if let problem = fileAccess.destinationProblem(atPath: text) {
      throw GatewayError(
        code: .fileOperationFailed,
        message: "\(path) \(problem.summary).",
        recoveryGuidance: problem.recovery
      )
    }
    return text
  }

  /// Resource names are treated as opaque: they are never decoded, normalized,
  /// or used to derive another value. Only the declared shape is enforced, so a
  /// malformed name fails before transport and no caller-supplied segment can
  /// add structure to the route.
  private func resourceName(
    _ value: JSONValue,
    pattern: ResourceNamePattern,
    path: String
  ) throws -> String {
    guard let text = value.stringValue else { throw typeError(path, "String", value) }
    guard pattern.matches(text) else {
      throw GatewayError.validation(
        "Argument \(path) is not a valid Google resource name.",
        recovery: "Use the form \(pattern.documentation)."
      )
    }
    return text
  }

  private func list(
    _ value: JSONValue,
    path: String,
    maximumCount: Int?
  ) throws -> [JSONValue] {
    // GraphQL list input coercion accepts a single value as a one-item list.
    let items = value.arrayValue ?? [value]
    if let maximumCount, items.count > maximumCount {
      throw GatewayError.validation(
        "Argument \(path) accepts at most \(maximumCount) values but received \(items.count).",
        recovery: "Split the request into batches of \(maximumCount) or fewer."
      )
    }
    return items
  }

  private func page(
    _ value: JSONValue,
    path: String,
    capability: CapabilityID,
    maximum: Int?
  ) throws -> PageInput {
    guard let fields = value.objectValue else { throw typeError(path, "PageInput", value) }
    for name in fields.keys where name != "pageSize" && name != "nextPageToken" {
      throw GatewayError.validation("Unknown page field \(path).\(name).")
    }
    var pageSize: Int?
    if let raw = fields["pageSize"], !raw.isNull {
      guard let number = raw.intValue else { throw typeError("\(path).pageSize", "Int", raw) }
      pageSize = number
    }
    var token: String?
    if let raw = fields["nextPageToken"], !raw.isNull {
      guard let text = raw.stringValue, !text.isEmpty else {
        throw typeError("\(path).nextPageToken", "String", raw)
      }
      guard text.count <= 4096 else {
        throw GatewayError.validation("\(path).nextPageToken is longer than the supported limit.")
      }
      token = text
    }
    return try PageInput(pageSize: pageSize, nextPageToken: token)
      .validated(maximumPageSize: maximum, capability: capability)
  }

  private func typeError(_ path: String, _ expected: String, _ value: JSONValue) -> GatewayError {
    GatewayError.validation("Argument \(path) must be of type \(expected), not \(value.typeDescription).")
  }
}
