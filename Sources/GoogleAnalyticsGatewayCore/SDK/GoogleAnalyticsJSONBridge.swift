import GatewaySDKKit

enum GoogleAnalyticsJSONBridge {
  static func gatewayValue(_ value: JSONValue) -> GatewayJSONValue {
    switch value {
    case .null: .null
    case .bool(let item): .bool(item)
    case .int(let item): .int(item)
    case .double(let item): .double(item)
    case .string(let item): .string(item)
    case .array(let items): .array(items.map(gatewayValue))
    case .object(let items): .object(items.mapValues(gatewayValue))
    }
  }

  static func coreValue(_ value: GatewayJSONValue) -> JSONValue {
    switch value {
    case .null: .null
    case .bool(let item): .bool(item)
    case .int(let item): .int(item)
    case .double(let item): .double(item)
    case .string(let item): .string(item)
    case .array(let items): .array(items.map(coreValue))
    case .object(let items): .object(items.mapValues(coreValue))
    }
  }

  static func envelope(_ response: GraphQLResponse) -> GatewayEnvelope {
    GatewayEnvelope(
      data: response.data.map(gatewayValue),
      errors: response.errors.map {
        GatewayEnvelopeError(message: $0.message, code: $0.code.rawValue)
      },
      requestId: response.requestID,
      exitCode: response.exitCode.rawValue,
      rawOutput: response.rendered(pretty: false)
    )
  }

  static func failure(_ error: Error) -> GatewayEnvelope {
    if let gatewayError = error as? GatewayError {
      return GatewayEnvelope(
        errors: [GatewayEnvelopeError(message: gatewayError.message, code: gatewayError.code.rawValue)],
        exitCode: gatewayError.exitCode.rawValue
      )
    }
    return GatewayEnvelope(
      errors: [GatewayEnvelopeError(
        message: "The gateway runtime could not be constructed.",
        code: GatewayErrorCode.internalError.rawValue
      )],
      exitCode: GatewayExitCode.internalFailure.rawValue
    )
  }
}
