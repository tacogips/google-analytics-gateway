import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// The live transport's two structural refusals: it will not address a host the
/// policy has not approved, and it will not follow a redirect that would carry
/// the credential somewhere else.
@Suite("URLSession Google transport", .serialized)
struct GoogleTransportTests {
  static func request(
    url: String,
    method: HTTPMethod = .get,
    timeout: TimeInterval = 5
  ) throws -> PreparedRequest {
    PreparedRequest(
      url: try #require(URL(string: url)),
      method: method,
      headers: [:],
      bearerToken: SecretValue(fixtureAccessToken),
      body: .none,
      timeout: timeout,
      capabilityID: CapabilityID("sample.dataStreams.get"),
      requestID: fixtureRequestID
    )
  }

  @Test("A request to an unapproved host is refused before it is sent")
  func refusesUnapprovedHost() async throws {
    StubURLProtocol.install(byHost: [:], fallback: .http(status: 200, body: Data("{}".utf8)))
    defer { StubURLProtocol.reset() }
    let transport = URLSessionGoogleTransport(configuration: StubURLProtocol.sessionConfiguration())

    do {
      _ = try await transport.send(try Self.request(url: "https://analytics.example.com/v1beta/properties/1"))
      Issue.record("Expected the unapproved host to be refused")
    } catch let failure as TransportFailure {
      #expect(failure == .tls("request host is not an approved Google API host"))
    }

    #expect(StubURLProtocol.requestedURLs.isEmpty, "The refused request never reached the loading system")
  }

  @Test("The OAuth token host is not reachable by a capability request")
  func refusesTokenHostForCapabilityRequests() async throws {
    StubURLProtocol.install(byHost: [:], fallback: .http(status: 200, body: Data("{}".utf8)))
    defer { StubURLProtocol.reset() }
    let transport = URLSessionGoogleTransport(configuration: StubURLProtocol.sessionConfiguration())

    await #expect(throws: TransportFailure.self) {
      _ = try await transport.send(try Self.request(url: "https://oauth2.googleapis.com/token"))
    }
    #expect(StubURLProtocol.requestedURLs.isEmpty)
  }

  @Test("An approved host answers and the response is mapped verbatim")
  func deliversApprovedHostResponse() async throws {
    StubURLProtocol.install(byHost: [
      "analyticsadmin.googleapis.com": .http(
        status: 200,
        headers: ["Content-Type": "application/json"],
        body: Data(SampleFixtures.dataStream.utf8)
      )
    ])
    defer { StubURLProtocol.reset() }
    let transport = URLSessionGoogleTransport(configuration: StubURLProtocol.sessionConfiguration())

    let response = try await transport.send(
      try Self.request(url: "https://analyticsadmin.googleapis.com/v1beta/properties/1/dataStreams/2")
    )

    #expect(response.statusCode == 200)
    #expect(response.header("content-type") == "application/json")
    #expect(response.body == Data(SampleFixtures.dataStream.utf8))
    #expect(StubURLProtocol.requestedHosts == ["analyticsadmin.googleapis.com"])
  }

  /// One redirect the approved host offers, which the policy must refuse.
  struct RefusedRedirect: Sendable, CustomStringConvertible {
    let label: String
    let status: Int
    let location: String

    init(_ label: String, _ status: Int, _ location: String) {
      self.label = label
      self.status = status
      self.location = location
    }

    var description: String { label }
  }

  static let refusedRedirects: [RefusedRedirect] = [
    RefusedRedirect("cross-service redirect", 307, "https://analyticsdata.googleapis.com/v1beta/properties/1"),
    RefusedRedirect(
      "permanent cross-service redirect", 308, "https://analyticsdata.googleapis.com/v1beta/properties/1"
    ),
    RefusedRedirect("redirect off the approved list", 308, "https://analytics.example.com/v1beta/properties/1"),
    RefusedRedirect("downgrade to http", 307, "http://analyticsadmin.googleapis.com/v1beta/properties/1")
  ]

  @Test("A redirect away from the requested host is refused", arguments: refusedRedirects)
  func refusesRedirect(_ refused: RefusedRedirect) async throws {
    let label = refused.label
    let status = refused.status
    let target = try #require(URL(string: refused.location))
    StubURLProtocol.install(byHost: [
      "analyticsadmin.googleapis.com": .redirect(status: status, location: target),
      // Answering here at all is what makes a followed redirect visible: the
      // body could only be delivered if the credential had gone with it.
      "analyticsdata.googleapis.com": .http(status: 200, body: Data("{\"leaked\":true}".utf8)),
      "analytics.example.com": .http(status: 200, body: Data("{\"leaked\":true}".utf8))
    ])
    defer { StubURLProtocol.reset() }
    let transport = URLSessionGoogleTransport(configuration: StubURLProtocol.sessionConfiguration())

    let response = try await transport.send(
      try Self.request(url: "https://analyticsadmin.googleapis.com/v1beta/properties/1/dataStreams/2")
    )

    #expect(response.statusCode == status, "\(label) was followed instead of reported")
    let body = try #require(String(data: response.body, encoding: .utf8))
    #expect(!body.contains("leaked"), "\(label) delivered the redirect target's body")
    #expect(
      StubURLProtocol.requestedHosts == ["analyticsadmin.googleapis.com"],
      "\(label) reached \(StubURLProtocol.requestedHosts)"
    )
  }

  @Test("A same-host redirect is the only one the policy permits to carry the credential")
  func permitsSameHostRedirectOnly() throws {
    let origin = try #require(URL(string: "https://analyticsadmin.googleapis.com/v1beta/properties/1"))
    let policy = GoogleHostPolicy.production

    #expect(policy.permitsCredentialForwarding(
      to: try #require(URL(string: "https://analyticsadmin.googleapis.com/v1beta/properties/2")),
      from: origin
    ))
    #expect(!policy.permitsCredentialForwarding(
      to: try #require(URL(string: "https://analyticsdata.googleapis.com/v1beta/properties/1")),
      from: origin
    ))
    #expect(!policy.permitsCredentialForwarding(
      to: try #require(URL(string: "http://analyticsadmin.googleapis.com/v1beta/properties/1")),
      from: origin
    ))
    #expect(!policy.permitsCredentialForwarding(
      to: try #require(URL(string: "https://analytics.example.com/")),
      from: origin
    ))
  }

  @Test("A service origin must be a bare approved https host")
  func validatesServiceOrigins() throws {
    let policy = GoogleHostPolicy.production
    #expect(throws: Never.self) {
      try policy.validateBaseURL("https://analyticsadmin.googleapis.com", source: "fixture origin")
    }
    for rejected in [
      "http://analyticsadmin.googleapis.com",
      "https://analyticsadmin.googleapis.com/v1beta",
      "https://user:pass@analyticsadmin.googleapis.com",
      "https://analyticsadmin.googleapis.com?alt=json",
      "https://analytics.example.com",
      ""
    ] {
      #expect(throws: GatewayError.self) {
        try policy.validateBaseURL(rejected, source: "fixture origin")
      }
    }
  }
}
