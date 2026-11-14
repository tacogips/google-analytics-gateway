import Foundation

/// Maps Google API HTTP responses to the stable public error contract.
///
/// Google answers a failure with `{"error": {"code", "message", "status",
/// "details"}}`. Only `status` is read, and only when it is a bare enum token:
/// `message` is free text that routinely echoes the resource name, the field
/// path, or the value the caller sent, so forwarding it would leak request
/// content into a log line an operator shares. This is the same structural rule
/// `GoogleRESTClient.sanitizedProviderMessage` applies in google-marketing-gateway.
public enum UpstreamErrorMapper {
  /// The character class a forwarded upstream status must match in full:
  /// an uppercase enum token such as `PERMISSION_DENIED` or `NOT_FOUND`.
  /// Anything else is discarded rather than trimmed, because a value that is
  /// not a token is not a status.
  static let safeStatusPattern = #"^[A-Z][A-Z0-9_]{0,79}$"#

  public struct Outcome: Sendable, Equatable {
    public let code: GatewayErrorCode
    public let upstreamErrorCode: String?
    public let retryAfterSeconds: Int?

    public init(code: GatewayErrorCode, upstreamErrorCode: String?, retryAfterSeconds: Int?) {
      self.code = code
      self.upstreamErrorCode = upstreamErrorCode
      self.retryAfterSeconds = retryAfterSeconds
    }
  }

  public static func classify(_ response: UpstreamResponse) -> Outcome? {
    guard !(200..<300).contains(response.statusCode) else { return nil }
    let upstream = upstreamErrorCode(in: response.body)
    let retryAfter = retryAfterSeconds(in: response)

    let code: GatewayErrorCode
    switch response.statusCode {
    // 409 is Google's ALREADY_EXISTS / conflict answer to a create or update;
    // the caller can fix the request, so it maps with the other usage errors.
    case 400, 409, 422:
      code = .validationError
    case 401:
      code = .authenticationFailed
    case 403:
      code = .authorizationFailed
    case 404:
      code = .notFound
    case 429:
      code = .rateLimited
    case 500...599:
      code = .upstreamUnavailable
    default:
      code = .upstreamResponseInvalid
    }
    return Outcome(code: code, upstreamErrorCode: upstream, retryAfterSeconds: retryAfter)
  }

  /// Builds the public error. The message names the stable condition and the
  /// documented upstream status token only; no upstream message text is
  /// forwarded.
  public static func error(
    from outcome: Outcome,
    status: Int,
    capability: CapabilityID,
    requestID: String,
    method: HTTPMethod
  ) -> GatewayError {
    let summary: String
    switch outcome.code {
    case .validationError:
      summary = "The Google API rejected the request parameters."
    case .authenticationFailed:
      summary = "The Google API rejected the credential."
    case .authorizationFailed:
      summary = "The Google API denied access to this operation."
    case .notFound:
      summary = "The requested Google resource was not found."
    case .rateLimited:
      summary = "Google API quota exhausted."
    case .upstreamUnavailable:
      summary = "The Google API is temporarily unavailable."
    default:
      summary = "The Google API returned an unexpected response."
    }

    var recovery: String?
    switch outcome.code {
    case .authenticationFailed:
      recovery = "Run `auth login` again to refresh the stored Google credential."
    case .authorizationFailed:
      recovery = "Confirm the credential's OAuth scopes and the Google account's role on the "
        + "property or container permit this operation."
    case .rateLimited:
      recovery = "Google enforces per-project and per-property quotas; retry after the "
        + "quota window, or request a quota increase in the Cloud console."
    default:
      recovery = nil
    }

    let unknownOutcome = !method.isAutomaticallyRetryable
      && (outcome.code == .upstreamUnavailable || outcome.code == .rateLimited)

    let message = outcome.upstreamErrorCode.map { "\(summary) Upstream status: \($0)." } ?? summary
    return GatewayError(
      code: outcome.code,
      message: message,
      requestID: requestID,
      httpStatus: status,
      capabilityID: capability,
      outcomeUnknown: unknownOutcome,
      retryAfterSeconds: outcome.retryAfterSeconds,
      recoveryGuidance: recovery
    )
  }

  /// Extracts only the `error.status` enum token from a Google error body.
  ///
  /// `error.code` duplicates the HTTP status, `error.message` is free text, and
  /// `error.details` carries request-derived field paths, so none of them is
  /// read. A body that is not the documented envelope yields `nil` rather than
  /// a partial description.
  static func upstreamErrorCode(in body: Data) -> String? {
    guard let value = try? JSONValue.decodeJSON(body),
          let status = value["error"]?["status"]?.stringValue,
          isSafeStatusToken(status)
    else {
      return nil
    }
    return status
  }

  /// A structural check, not a filter: the value is forwarded whole or not at
  /// all, so no fragment of an unexpected message can be assembled into one.
  static func isSafeStatusToken(_ value: String) -> Bool {
    value.range(of: safeStatusPattern, options: .regularExpression) != nil
  }

  static func retryAfterSeconds(in response: UpstreamResponse) -> Int? {
    guard let raw = response.header("retry-after") else { return nil }
    guard let seconds = Int(raw.trimmingCharacters(in: .whitespaces)), seconds >= 0 else {
      return nil
    }
    return min(seconds, 300)
  }
}
