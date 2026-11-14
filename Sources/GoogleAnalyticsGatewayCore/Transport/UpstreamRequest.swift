import Foundation

public enum HTTPMethod: String, Sendable, Equatable, CaseIterable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"

  /// Only GET is automatically retried. Every other method requires a reviewed
  /// idempotency guarantee that the initial contract does not provide. Google's
  /// `PATCH` update methods are idempotent in principle, but a partial update
  /// applied twice is still a change an operator did not ask for, so they are
  /// excluded with the rest.
  public var isAutomaticallyRetryable: Bool { self == .get }
}

public struct UpstreamQueryItem: Sendable, Equatable {
  public let name: String
  public let value: String

  public init(name: String, value: String) {
    self.name = name
    self.value = value
  }
}

public enum UpstreamRequestBody: Sendable, Equatable {
  case none
  case json(JSONValue)
}

/// Where a transport must put the response body.
///
/// Almost every Google Analytics and Tag Manager method answers with JSON that
/// belongs in the response envelope. Selecting `.file` moves a success body
/// straight to disk instead, so its bytes exist only in the destination file
/// and never in an `UpstreamResponse`, an error description, or a log line.
public enum ResponseSink: Sendable, Equatable {
  case memory
  case file(path: String)

  /// Only a success body is content. A `4xx`/`5xx` body is the documented JSON
  /// error envelope, so it stays in memory for the error mapper and never
  /// reaches the caller's destination path.
  public static func isSuccess(status: Int) -> Bool { (200..<300).contains(status) }

  public var destinationPath: String? {
    if case .file(let path) = self { return path }
    return nil
  }
}

/// The result of writing a success body to the caller's destination path.
///
/// It describes the file rather than its contents: no field of this value can
/// hold a byte of the downloaded body.
public struct DownloadedFile: Sendable, Equatable {
  public let path: String
  public let byteCount: Int
  /// The upstream `Content-Type`, preserved verbatim when Google sent one.
  public let contentType: String?

  public init(path: String, byteCount: Int, contentType: String?) {
    self.path = path
    self.byteCount = byteCount
    self.contentType = contentType
  }
}

/// A capability-scoped request expressed in relative terms. Public SDK and
/// GraphQL callers never supply a raw URL, host, method, or query parameter;
/// the capability planner is the only producer of this value.
public struct UpstreamRequest: Sendable, Equatable {
  public let capabilityID: CapabilityID
  /// The Google service that owns the route. It selects the origin, so the
  /// request cannot be resolved against a host the capability did not declare.
  public let service: GoogleAPIService
  public let method: HTTPMethod
  /// Absolute path on the service origin, including the API version prefix and
  /// always leading-slashed, for example `/v1beta/properties/1/dataStreams`.
  public let path: String
  public let queryItems: [UpstreamQueryItem]
  public let headers: [String: String]
  public let body: UpstreamRequestBody
  public let timeout: TimeInterval
  /// Where the success body must go. Selected by the capability's declaration,
  /// never by a caller-supplied flag.
  public let responseSink: ResponseSink

  public init(
    capabilityID: CapabilityID,
    service: GoogleAPIService,
    method: HTTPMethod,
    path: String,
    queryItems: [UpstreamQueryItem] = [],
    headers: [String: String] = [:],
    body: UpstreamRequestBody = .none,
    timeout: TimeInterval = 60,
    responseSink: ResponseSink = .memory
  ) {
    self.capabilityID = capabilityID
    self.service = service
    self.method = method
    self.path = path
    self.queryItems = queryItems
    self.headers = headers
    self.body = body
    self.timeout = timeout
    self.responseSink = responseSink
  }

  /// The origin this request resolves against, fixed by its service.
  public var origin: URL { service.origin }
}

/// A request resolved against its service origin and decorated with
/// credentials, ready for a `GoogleTransport`.
///
/// The bearer token is carried as a `SecretValue` rather than a formatted
/// header so that a recording transport can assert that authorization was
/// applied without ever holding the header text.
public struct PreparedRequest: Sendable {
  public let url: URL
  public let method: HTTPMethod
  public let headers: [String: String]
  public let bearerToken: SecretValue?
  public let body: UpstreamRequestBody
  public let timeout: TimeInterval
  public let capabilityID: CapabilityID
  public let requestID: String
  public let responseSink: ResponseSink

  public init(
    url: URL,
    method: HTTPMethod,
    headers: [String: String],
    bearerToken: SecretValue?,
    body: UpstreamRequestBody,
    timeout: TimeInterval,
    capabilityID: CapabilityID,
    requestID: String,
    responseSink: ResponseSink = .memory
  ) {
    self.url = url
    self.method = method
    self.headers = headers
    self.bearerToken = bearerToken
    self.body = body
    self.timeout = timeout
    self.capabilityID = capabilityID
    self.requestID = requestID
    self.responseSink = responseSink
  }

  public var hasAuthorization: Bool { bearerToken != nil }
}

public struct UpstreamResponse: Sendable, Equatable {
  public let statusCode: Int
  /// Header names are lowercased so lookups do not depend on server casing.
  public let headers: [String: String]
  public let body: Data
  /// Set only when the request selected a file sink and the status was a
  /// success. `body` is then empty, which is what keeps downloaded bytes out of
  /// every diagnostic that can reach an operator.
  public let downloadedFile: DownloadedFile?

  public init(
    statusCode: Int,
    headers: [String: String] = [:],
    body: Data = Data(),
    downloadedFile: DownloadedFile? = nil
  ) {
    self.statusCode = statusCode
    self.headers = headers.reduce(into: [:]) { result, entry in
      result[entry.key.lowercased()] = entry.value
    }
    self.body = body
    self.downloadedFile = downloadedFile
  }

  public func header(_ name: String) -> String? { headers[name.lowercased()] }
}

/// Failures raised before an HTTP status is available.
public enum TransportFailure: Error, Sendable, Equatable {
  case cancelled
  case timedOut
  case connectivity(String)
  case tls(String)
  case malformedResponse(String)
  case localIO(String)

  /// Bounded automatic retry applies only to transient network conditions and
  /// only when the request method allows it.
  public var isTransient: Bool {
    switch self {
    case .timedOut, .connectivity:
      return true
    case .cancelled, .tls, .malformedResponse, .localIO:
      return false
    }
  }

  public var safeSummary: String {
    switch self {
    case .cancelled: return "The request was cancelled."
    case .timedOut: return "The request to the Google API timed out."
    case .connectivity(let detail): return "Could not reach the Google API: \(detail)."
    case .tls(let detail): return "TLS validation failed: \(detail)."
    case .malformedResponse(let detail):
      return "The Google API returned an unreadable response: \(detail)."
    case .localIO(let detail): return "A local file operation failed: \(detail)."
    }
  }
}

/// The injectable transport boundary. The executor depends on this protocol
/// rather than on `URLSession`, global state, or a singleton client.
public protocol GoogleTransport: Sendable {
  func send(_ request: PreparedRequest) async throws -> UpstreamResponse
}
