import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The live `URLSession`-backed transport.
///
/// Redirects are inspected rather than followed blindly: a redirect to any host
/// other than the originating approved host is refused, and the authorization
/// header is never re-attached by `URLSession` because it is applied per request
/// by this type rather than stored on the session.
public final class URLSessionGoogleTransport: NSObject, GoogleTransport, @unchecked Sendable {
  private let session: URLSession
  private let hostPolicy: GoogleHostPolicy
  private let redirectGuard: RedirectGuard

  public init(
    hostPolicy: GoogleHostPolicy = .production,
    configuration: URLSessionConfiguration = .ephemeral
  ) {
    self.hostPolicy = hostPolicy
    let guardObject = RedirectGuard(hostPolicy: hostPolicy)
    self.redirectGuard = guardObject
    let sessionConfiguration = configuration
    sessionConfiguration.httpAdditionalHeaders = [:]
    sessionConfiguration.httpShouldSetCookies = false
    self.session = URLSession(
      configuration: sessionConfiguration,
      delegate: guardObject,
      delegateQueue: nil
    )
    super.init()
  }

  public func send(_ request: PreparedRequest) async throws -> UpstreamResponse {
    guard hostPolicy.allows(host: request.url.host) else {
      throw TransportFailure.tls("request host is not an approved Google API host")
    }
    redirectGuard.register(origin: request.url)
    defer { redirectGuard.unregister(origin: request.url) }

    var urlRequest = URLRequest(url: request.url)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.timeoutInterval = request.timeout
    for (name, value) in request.headers {
      urlRequest.setValue(value, forHTTPHeaderField: name)
    }
    // A file-sink route answers with content rather than the JSON envelope, so
    // demanding JSON would reject the very body the capability asked for.
    urlRequest.setValue(
      request.responseSink.destinationPath == nil ? "application/json" : "*/*",
      forHTTPHeaderField: "Accept"
    )
    if let token = request.bearerToken {
      urlRequest.setValue("Bearer \(token.reveal())", forHTTPHeaderField: "Authorization")
    }

    do {
      switch request.body {
      case .none:
        return try await perform(urlRequest, sink: request.responseSink)
      case .json(let value):
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = Data(value.encodedJSON(pretty: false).utf8)
        return try await perform(urlRequest, sink: request.responseSink)
      }
    } catch let failure as TransportFailure {
      throw failure
    } catch {
      throw Self.mapURLError(error)
    }
  }

  private func perform(_ request: URLRequest, sink: ResponseSink) async throws -> UpstreamResponse {
    do {
      if case .file(let path) = sink {
        // `download` streams to a temporary file, so a body of any size never
        // passes through this process's memory.
        let (temporaryURL, response) = try await session.download(for: request)
        let http = try Self.httpResponse(response)
        return try ResponseSinkDelivery.deliver(
          destinationPath: path,
          statusCode: http.statusCode,
          headers: Self.headers(of: http),
          temporaryURL: temporaryURL
        )
      }
      let (data, response) = try await session.data(for: request)
      return try Self.makeResponse(data: data, response: response)
    } catch let failure as TransportFailure {
      throw failure
    } catch {
      throw Self.mapURLError(error)
    }
  }

  private static func makeResponse(data: Data, response: URLResponse) throws -> UpstreamResponse {
    let http = try httpResponse(response)
    return UpstreamResponse(statusCode: http.statusCode, headers: headers(of: http), body: data)
  }

  private static func httpResponse(_ response: URLResponse) throws -> HTTPURLResponse {
    guard let http = response as? HTTPURLResponse else {
      throw TransportFailure.malformedResponse("response was not an HTTP response")
    }
    return http
  }

  private static func headers(of response: HTTPURLResponse) -> [String: String] {
    var headers: [String: String] = [:]
    for (key, value) in response.allHeaderFields {
      guard let name = key as? String, let text = value as? String else { continue }
      headers[name.lowercased()] = text
    }
    return headers
  }

  static func mapURLError(_ error: any Error) -> TransportFailure {
    let urlError = error as? URLError
    switch urlError?.code {
    case .some(.cancelled):
      return .cancelled
    case .some(.timedOut):
      return .timedOut
    case .some(.secureConnectionFailed), .some(.serverCertificateUntrusted),
         .some(.serverCertificateHasBadDate), .some(.serverCertificateNotYetValid),
         .some(.serverCertificateHasUnknownRoot), .some(.clientCertificateRejected),
         .some(.clientCertificateRequired):
      return .tls("secure connection could not be established")
    case .some(.cannotParseResponse), .some(.badServerResponse):
      return .malformedResponse("the response could not be parsed")
    case .some(.cannotOpenFile), .some(.cannotCreateFile), .some(.fileDoesNotExist):
      return .localIO("a local file could not be opened")
    case .some(let code):
      return .connectivity("network error \(code.rawValue)")
    case .none:
      return .connectivity("the request could not be completed")
    }
  }
}

/// Enforces the redirect policy for the live session.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let hostPolicy: GoogleHostPolicy
  private let lock = NSLock()
  private var origins: [URL] = []

  init(hostPolicy: GoogleHostPolicy) {
    self.hostPolicy = hostPolicy
  }

  func register(origin: URL) {
    lock.lock()
    origins.append(origin)
    lock.unlock()
  }

  func unregister(origin: URL) {
    lock.lock()
    if let index = origins.lastIndex(of: origin) {
      origins.remove(at: index)
    }
    lock.unlock()
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    guard let target = request.url, let origin = task.originalRequest?.url else {
      completionHandler(nil)
      return
    }
    guard hostPolicy.permitsCredentialForwarding(to: target, from: origin) else {
      // Refusing the redirect drops the authorization header with it; the task
      // completes with the redirect response, which maps to a stable error.
      completionHandler(nil)
      return
    }
    var forwarded = request
    // `URLSession` copies the original headers; re-set them explicitly so the
    // credential is only ever present on an approved same-host redirect.
    if let authorization = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
      forwarded.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
    completionHandler(forwarded)
  }
}
