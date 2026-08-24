import Foundation

/// A `URLProtocol` that answers from a table instead of the network, so the live
/// `URLSession` transport can be exercised without one.
///
/// It records every URL the loading system asks it for. That record is what
/// proves a refused redirect never reached the second host, rather than only
/// that the caller did not see its body.
public final class StubURLProtocol: URLProtocol {
  public enum Answer: Sendable {
    case http(status: Int, headers: [String: String] = [:], body: Data = Data())
    /// A redirect the loading system is asked to follow, which the transport's
    /// redirect policy then either permits or refuses.
    case redirect(status: Int, location: URL)
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var answers: [String: Answer] = [:]
  nonisolated(unsafe) private static var fallback: Answer = .http(status: 500)
  nonisolated(unsafe) private static var recorded: [URL] = []

  /// Installs the routing table, keyed by request host, and clears the record.
  public static func install(byHost answers: [String: Answer], fallback: Answer = .http(status: 500)) {
    lock.lock()
    self.answers = answers
    self.fallback = fallback
    recorded = []
    lock.unlock()
  }

  public static func reset() {
    install(byHost: [:])
  }

  public static var requestedURLs: [URL] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  public static var requestedHosts: [String] {
    requestedURLs.compactMap(\.host)
  }

  /// A session configuration whose only protocol is this stub.
  public static func sessionConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return configuration
  }

  private static func answer(for url: URL) -> Answer {
    lock.lock()
    defer { lock.unlock() }
    recorded.append(url)
    guard let host = url.host, let answer = answers[host] else { return fallback }
    return answer
  }

  public override static func canInit(with request: URLRequest) -> Bool { true }

  public override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  public override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    switch Self.answer(for: url) {
    case .http(let status, let headers, let body):
      guard let response = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
      ) else {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        return
      }
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      if !body.isEmpty { client?.urlProtocol(self, didLoad: body) }
      client?.urlProtocolDidFinishLoading(self)
    case .redirect(let status, let location):
      guard let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Location": location.absoluteString]
      ) else {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        return
      }
      // Offering the redirect is what invokes the session's redirect policy. A
      // refused redirect completes the task with this response, which is the
      // behavior under test.
      client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: location), redirectResponse: response)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  public override func stopLoading() {}
}
