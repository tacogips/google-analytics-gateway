import Foundation

/// Decodes a Google API JSON response and maps it onto the capability's stable
/// model shape.
///
/// Google has no shared response envelope: a `get` answers with the resource
/// itself and a `list` answers with a named collection alongside an optional
/// `nextPageToken`. Unknown upstream fields are ignored, but the public
/// projection exposes only registered stable fields. A body that is not an
/// object, missing required data, or an incompatible field type is a decoding
/// error rather than a silently empty result.
public enum ResponseProjection {
  /// Decodes the top-level JSON object every documented method answers with.
  public static func documentObject(
    _ body: Data,
    capability: CapabilityID
  ) throws -> [String: JSONValue] {
    // A handful of documented methods (Tag Manager `resolve_conflict`,
    // `move_entities_to_folder`) answer success with an empty body rather than
    // `{}`. An empty body is the empty object; a non-empty body must still be
    // valid JSON.
    guard !body.isEmpty else { return [:] }
    let value: JSONValue
    do {
      value = try JSONValue.decodeJSON(body)
    } catch {
      throw GatewayError(
        code: .upstreamResponseInvalid,
        message: "The Google API returned a response that is not valid JSON.",
        capabilityID: capability
      )
    }
    guard let fields = value.objectValue else {
      throw GatewayError(
        code: .upstreamResponseInvalid,
        message: "The Google API returned a response that is not an object.",
        capabilityID: capability
      )
    }
    return fields
  }

  /// Reads the entities of a collection response.
  ///
  /// Google omits the collection key entirely when a list is empty, so a
  /// missing key is an empty page rather than a malformed response. A key that
  /// is present but is not a list is still an error.
  public static func collectionItems(
    _ body: Data,
    key: String,
    capability: CapabilityID
  ) throws -> [JSONValue] {
    let fields = try documentObject(body, capability: capability)
    guard let collection = fields[key], !collection.isNull else { return [] }
    guard let items = collection.arrayValue else {
      throw GatewayError(
        code: .upstreamResponseInvalid,
        message: "The Google API returned \(key) as something other than a collection.",
        capabilityID: capability
      )
    }
    return items
  }

  static func nextPageToken(_ body: Data) -> String? {
    guard let value = try? JSONValue.decodeJSON(body),
          let token = value["nextPageToken"]?.stringValue,
          !token.isEmpty
    else {
      return nil
    }
    return token
  }

  /// Builds the full stable result for a capability from a transport response.
  ///
  /// A file-output capability is projected from the transport's write outcome
  /// rather than from a body, because its success body was streamed to the
  /// caller's destination path and is deliberately not in memory.
  public static func result(
    for definition: CapabilityDefinition,
    response: UpstreamResponse,
    validatedDeletionResourceName: String? = nil
  ) throws -> JSONValue {
    guard case .fileOutput(let shape) = definition.result else {
      return try result(
        for: definition,
        body: response.body,
        validatedDeletionResourceName: validatedDeletionResourceName
      )
    }
    guard let file = response.downloadedFile else {
      // Reached when Google answered a content route with a body-less success,
      // which the delivery refuses to turn into a zero-byte file. Naming that
      // nothing was written is the part an operator cannot see for themselves.
      throw GatewayError(
        code: .upstreamResponseInvalid,
        message: "The Google API returned no content for \(definition.field).",
        capabilityID: definition.id,
        recoveryGuidance: "No file was written. Confirm the resource still holds content, "
          + "then retry."
      )
    }
    return try project(
      .object([
        "path": .string(file.path),
        "byteCount": .int(file.byteCount),
        "contentType": file.contentType.map(JSONValue.string) ?? .null
      ]),
      shape: shape,
      capability: definition.id
    )
  }

  /// Builds the full stable result for a capability from a response body.
  public static func result(
    for definition: CapabilityDefinition,
    body: Data,
    validatedDeletionResourceName: String? = nil
  ) throws -> JSONValue {
    switch definition.result {
    case .fileOutput:
      throw GatewayError.internalFailure(
        "\(definition.id) writes its body to a file and cannot be projected from memory."
      )
    case .single(let shape):
      let fields = try documentObject(body, capability: definition.id)
      return try project(.object(fields), shape: shape, capability: definition.id)

    case .list(let key, let shape):
      let items = try collectionItems(body, key: key, capability: definition.id)
      return .array(try items.map { try project($0, shape: shape, capability: definition.id) })

    case .connection(let key, let shape):
      let items = try collectionItems(body, key: key, capability: definition.id)
      let nodes = try items.map { try project($0, shape: shape, capability: definition.id) }
      let pageInfo = PageInfo(resultCount: nodes.count, nextPageToken: nextPageToken(body))
      return .object(["nodes": .array(nodes), "pageInfo": pageInfo.stableValue])

    case .payload(let field, let shape):
      // Google's create, update, and custom-verb mutations answer with the
      // affected resource itself, so the payload wraps the whole body.
      let fields = try documentObject(body, capability: definition.id)
      guard !fields.isEmpty else {
        throw GatewayError(
          code: .upstreamResponseInvalid,
          message: "The Google API accepted the \(definition.field) mutation but returned no \(shape.typeName).",
          capabilityID: definition.id
        )
      }
      return .object([field: try project(.object(fields), shape: shape, capability: definition.id)])

    case .deletion:
      // A Google delete answers `200` with an empty JSON object, so the
      // resource name comes from the request the planner already validated.
      // Only a capability carrying the reviewed echo policy reads it back out
      // of the body instead.
      let confirmed = try confirmedDeletedResourceName(
        body: body,
        policy: definition.deletionConfirmation,
        validatedResourceName: validatedDeletionResourceName,
        capability: definition.id
      )
      guard let confirmed else {
        throw GatewayError(
          code: .upstreamResponseInvalid,
          message: "The Google API did not confirm which resource was deleted.",
          capabilityID: definition.id,
          outcomeUnknown: true
        )
      }
      return .object(["deletedName": .string(confirmed)])
    }
  }

  private static func confirmedDeletedResourceName(
    body: Data,
    policy: DeletionConfirmation,
    validatedResourceName: String?,
    capability: CapabilityID
  ) throws -> String? {
    switch policy {
    case .responseResourceName:
      let fields = try documentObject(body, capability: capability)
      guard let name = fields["name"]?.stringValue, !name.isEmpty else { return nil }
      return name
    case .validatedRequestResourceNameOnEmptyBody:
      // An empty body is what a Google delete returns; `{}` decodes to the same
      // thing. Either way the request's own validated name is the confirmation.
      if !body.isEmpty {
        _ = try documentObject(body, capability: capability)
      }
      guard let validatedResourceName, !validatedResourceName.isEmpty else { return nil }
      return validatedResourceName
    }
  }

  /// Maps one upstream entity onto its stable shape.
  public static func project(
    _ value: JSONValue,
    shape: ModelShape,
    capability: CapabilityID
  ) throws -> JSONValue {
    guard let upstream = value.objectValue else {
      throw GatewayError(
        code: .upstreamResponseInvalid,
        message: "The Google API returned a \(shape.typeName) entry that is not an object.",
        capabilityID: capability
      )
    }
    var projected: [String: JSONValue] = [:]
    projected.reserveCapacity(shape.fields.count)
    for field in shape.fields {
      let raw = upstream[field.upstreamName] ?? .null
      if raw.isNull {
        if field.isRequired {
          throw GatewayError(
            code: .upstreamResponseInvalid,
            message: "The Google \(shape.typeName) is missing the required field \(field.name).",
            capabilityID: capability
          )
        }
        projected[field.name] = .null
        continue
      }
      projected[field.name] = try convert(
        raw,
        to: field.type,
        fieldName: "\(shape.typeName).\(field.name)",
        capability: capability
      )
    }
    return .object(projected)
  }

  private static func convert(
    _ value: JSONValue,
    to type: ModelFieldType,
    fieldName: String,
    capability: CapabilityID
  ) throws -> JSONValue {
    switch type {
    case .resourceName, .string, .dateTime, .date:
      guard let text = value.stringValue else {
        throw mismatch(fieldName, "a string", value, capability)
      }
      return .string(text)
    case .integer:
      // Google serializes int64 fields as JSON strings, so a numeric string is
      // the documented representation rather than a type mismatch.
      if let number = value.intValue { return .int(number) }
      if let text = value.stringValue, let number = Int(text) { return .int(number) }
      throw mismatch(fieldName, "an integer", value, capability)
    case .number:
      if let number = value.doubleValue { return .double(number) }
      if let text = value.stringValue, let number = Double(text) { return .double(number) }
      throw mismatch(fieldName, "a number", value, capability)
    case .boolean:
      guard let flag = value.boolValue else {
        throw mismatch(fieldName, "a boolean", value, capability)
      }
      return .bool(flag)
    case .stringList:
      guard let items = value.arrayValue else {
        throw mismatch(fieldName, "a list", value, capability)
      }
      return .array(try items.map { item in
        guard let text = item.stringValue else {
          throw mismatch(fieldName, "a list of strings", item, capability)
        }
        return .string(text)
      })
    case .json:
      // Passed through exactly as Google sent it, of any JSON kind. No shape is
      // asserted, so there is nothing here that could reject a document the API
      // legitimately returns.
      return value
    case .object(let nested):
      return try project(value, shape: nested, capability: capability)
    case .objectList(let nested):
      guard let items = value.arrayValue else {
        throw mismatch(fieldName, "a list", value, capability)
      }
      return .array(try items.map { try project($0, shape: nested, capability: capability) })
    }
  }

  private static func mismatch(
    _ fieldName: String,
    _ expected: String,
    _ value: JSONValue,
    _ capability: CapabilityID
  ) -> GatewayError {
    GatewayError(
      code: .upstreamResponseInvalid,
      message: "The Google field \(fieldName) was expected to be \(expected) but was \(value.typeDescription).",
      capabilityID: capability
    )
  }
}
