import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// The executor joins a plan, a credential, and a transport. What is asserted
/// here is the part a caller cannot see: how many upstream attempts a failure
/// costs, which of them carry a refreshed credential, and what an operator is
/// told when Google refuses.
@Suite("Capability executor")
struct CapabilityExecutorTests {
  static func getInvocation() -> CapabilityInvocation {
    SampleCapabilities.invocation(
      SampleCapabilities.getDataStream,
      ["name": .string("properties/123456/dataStreams/789")]
    )
  }

  static func createInvocation() -> CapabilityInvocation {
    SampleCapabilities.invocation(
      SampleCapabilities.createDataStream,
      [
        "parent": .string("properties/123456"),
        "dataStream": .object([
          "displayName": .string("Web stream"),
          "streamKind": .string("WEB_DATA_STREAM")
        ])
      ]
    )
  }

  static func response(_ status: Int, headers: [String: String] = [:], json: String = "{}") -> RecordingTransport.Outcome {
    .response(UpstreamResponse(statusCode: status, headers: headers, body: Data(json.utf8)))
  }

  @Test("A 401 is retried exactly once with a refreshed credential and then reported")
  func refreshesOnceOnUnauthorized() async throws {
    let transport = RecordingTransport(outcomes: [
      Self.response(401, json: SampleFixtures.errorEnvelope),
      Self.response(401, json: SampleFixtures.errorEnvelope)
    ])
    let credentials = RecordingCredentialProvider.refreshable()
    let executor = try SampleCapabilities.executor(transport: transport, credentials: credentials)

    do {
      _ = try await executor.execute(Self.getInvocation())
      Issue.record("Expected the second 401 to be reported")
    } catch let error as GatewayError {
      #expect(error.code == .authenticationFailed)
      #expect(error.httpStatus == 401)
      #expect(error.recoveryGuidance?.contains("auth login") == true)
    }

    #expect(await transport.requestCount == 2, "One refused attempt and one refreshed attempt")
    #expect(credentials.refreshCount == 1, "A second refresh must never be attempted")
  }

  @Test("A refreshed credential resolves a 401 without spending a retry attempt")
  func refreshRecoversRequest() async throws {
    let transport = RecordingTransport(
      outcomes: [
        Self.response(401, json: SampleFixtures.errorEnvelope),
        Self.response(200, json: SampleFixtures.dataStream)
      ],
      repeatsFinalOutcome: false
    )
    let clock = TestClock()
    let credentials = RecordingCredentialProvider.refreshable()
    let executor = try SampleCapabilities.executor(
      transport: transport, clock: clock, credentials: credentials
    )

    let result = try await executor.execute(Self.getInvocation())

    #expect(result["name"]?.stringValue == "properties/123456/dataStreams/789")
    #expect(await transport.requestCount == 2)
    #expect(credentials.refreshCount == 1)
    #expect(clock.recordedSleeps.isEmpty, "A refresh is not a backed-off retry")
  }

  @Test("A 401 with no refresh state fails on the first attempt")
  func unauthorizedWithoutRefreshFailsImmediately() async throws {
    let transport = RecordingTransport(outcomes: [Self.response(401, json: SampleFixtures.errorEnvelope)])
    let credentials = RecordingCredentialProvider()
    let executor = try SampleCapabilities.executor(transport: transport, credentials: credentials)

    await #expect(throws: GatewayError.self) {
      _ = try await executor.execute(Self.getInvocation())
    }

    #expect(await transport.requestCount == 1)
    #expect(credentials.refreshCount == 1, "The refresh seam is consulted once and answers nil")
  }

  @Test("A 429 on a GET waits exactly as long as Retry-After asks")
  func honoursRetryAfter() async throws {
    let transport = RecordingTransport(
      outcomes: [
        Self.response(429, headers: ["Retry-After": "3"], json: SampleFixtures.errorEnvelope),
        Self.response(200, json: SampleFixtures.dataStream)
      ],
      repeatsFinalOutcome: false
    )
    let clock = TestClock()
    let executor = try SampleCapabilities.executor(transport: transport, clock: clock)

    _ = try await executor.execute(Self.getInvocation())

    #expect(clock.recordedSleeps == [3])
    #expect(await transport.requestCount == 2)
  }

  @Test("A GET is retried up to the policy limit and no further")
  func retriesGetToPolicyLimit() async throws {
    let transport = RecordingTransport(outcomes: [Self.response(500)])
    let clock = TestClock()
    let executor = try SampleCapabilities.executor(
      transport: transport,
      clock: clock,
      retryPolicy: RetryPolicy(maximumAttempts: 3, jitterFraction: 0)
    )

    do {
      _ = try await executor.execute(Self.getInvocation())
      Issue.record("Expected the retries to be exhausted")
    } catch let error as GatewayError {
      #expect(error.code == .upstreamUnavailable)
      #expect(!error.outcomeUnknown, "A GET that failed every attempt applied nothing")
    }

    #expect(await transport.requestCount == 3)
    #expect(clock.recordedSleeps.count == 2)
  }

  @Test("A POST is never retried and reports an unknown outcome")
  func doesNotRetryMutations() async throws {
    let transport = RecordingTransport(outcomes: [Self.response(500)])
    let clock = TestClock()
    let executor = try SampleCapabilities.executor(transport: transport, clock: clock)

    do {
      _ = try await executor.execute(Self.createInvocation())
      Issue.record("Expected the mutation to fail")
    } catch let error as GatewayError {
      #expect(error.code == .upstreamUnavailable)
      #expect(error.outcomeUnknown)
    }

    #expect(await transport.requestCount == 1)
    #expect(clock.recordedSleeps.isEmpty)
  }

  @Test("A transient transport failure on a POST is not retried either")
  func doesNotRetryMutationTransportFailure() async throws {
    let transport = RecordingTransport(outcomes: [.failure(.timedOut)])
    let executor = try SampleCapabilities.executor(transport: transport)

    do {
      _ = try await executor.execute(Self.createInvocation())
      Issue.record("Expected the mutation to fail")
    } catch let error as GatewayError {
      #expect(error.code == .transportFailed)
      #expect(error.outcomeUnknown)
      #expect(error.recoveryGuidance?.contains("not automatically retried") == true)
    }

    #expect(await transport.requestCount == 1)
  }

  static let statusCases: [(Int, GatewayErrorCode)] = [
    (400, .validationError),
    (409, .validationError),
    (422, .validationError),
    (401, .authenticationFailed),
    (403, .authorizationFailed),
    (404, .notFound),
    (429, .rateLimited),
    (500, .upstreamUnavailable),
    (503, .upstreamUnavailable)
  ]

  @Test("Each upstream status maps to its stable error code", arguments: statusCases)
  func mapsStatusToStableCode(status: Int, expected: GatewayErrorCode) async throws {
    let transport = RecordingTransport(outcomes: [
      Self.response(status, json: SampleFixtures.errorEnvelope)
    ])
    // Retry is disabled so a retryable status still surfaces its mapped code.
    let executor = try SampleCapabilities.executor(transport: transport, retryPolicy: .disabled)

    do {
      _ = try await executor.execute(Self.getInvocation())
      Issue.record("Expected status \(status) to fail")
    } catch let error as GatewayError {
      #expect(error.code == expected)
      #expect(error.httpStatus == status)
      #expect(error.requestID == fixtureRequestID)
      #expect(error.capabilityID == SampleCapabilities.getDataStream.id)
    }
  }

  @Test("A 409 conflict is a request the caller can fix, not an upstream outage")
  func conflictIsAValidationError() async throws {
    let transport = RecordingTransport(outcomes: [
      Self.response(409, json: """
        {"error":{"code":409,"message":"Data stream already exists","status":"ALREADY_EXISTS"}}
        """)
    ])
    let executor = try SampleCapabilities.executor(transport: transport)

    do {
      _ = try await executor.execute(Self.createInvocation())
      Issue.record("Expected the conflict to fail")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.exitCode == .usage)
      #expect(error.message.contains("ALREADY_EXISTS"))
      #expect(!error.message.contains("already exists"), "The free-text message must not be forwarded")
    }
  }

  @Test("Upstream free text never reaches an error a caller can see")
  func doesNotForwardUpstreamFreeText() async throws {
    let transport = RecordingTransport(outcomes: [
      Self.response(403, json: SampleFixtures.errorEnvelope)
    ])
    let executor = try SampleCapabilities.executor(transport: transport, retryPolicy: .disabled)

    do {
      _ = try await executor.execute(Self.getInvocation())
      Issue.record("Expected the refusal to fail")
    } catch let error as GatewayError {
      #expect(error.code == .authorizationFailed)
      // Only the documented status token is forwarded.
      #expect(error.message.contains("PERMISSION_DENIED"))
      let rendered = [error.message, error.description, error.recoveryGuidance ?? ""].joined(separator: " ")
        + error.extensions.encodedJSON(pretty: false)
      for marker in SampleFixtures.leakMarkers {
        #expect(!rendered.contains(marker), "Upstream text \(marker) leaked into \(rendered)")
      }
    }
  }

  @Test("An upstream status that is not a bare enum token is discarded whole")
  func discardsUnsafeUpstreamStatus() async throws {
    let transport = RecordingTransport(outcomes: [
      Self.response(404, json: """
        {"error":{"code":404,"message":"missing","status":"not found for properties/123456"}}
        """)
    ])
    let executor = try SampleCapabilities.executor(transport: transport)

    do {
      _ = try await executor.execute(Self.getInvocation())
      Issue.record("Expected the refusal to fail")
    } catch let error as GatewayError {
      #expect(error.code == .notFound)
      #expect(!error.message.contains("Upstream status"))
      #expect(!error.message.contains("properties/123456"))
    }
  }

  @Test("A delete confirms the resource name the planner validated")
  func deleteConfirmsValidatedName() async throws {
    let transport = RecordingTransport.succeeding(json: "{}")
    let executor = try SampleCapabilities.executor(transport: transport)

    let result = try await executor.execute(SampleCapabilities.invocation(
      SampleCapabilities.deleteDataStream,
      [
        "name": .string("properties/123456/dataStreams/789"),
        "confirmName": .string("properties/123456/dataStreams/789")
      ]
    ))

    #expect(result["deletedName"]?.stringValue == "properties/123456/dataStreams/789")
    #expect(await transport.requestCount == 1)
  }

  @Test("An empty upstream collection is an empty page, not a malformed response")
  func emptyCollectionIsAnEmptyPage() async throws {
    let transport = RecordingTransport.succeeding(json: "{}")
    let executor = try SampleCapabilities.executor(transport: transport)

    let result = try await executor.execute(SampleCapabilities.invocation(
      SampleCapabilities.listDataStreams,
      ["parent": .string("properties/123456")]
    ))

    #expect(result["nodes"]?.arrayValue?.isEmpty == true)
    #expect(result["pageInfo"]?["resultCount"]?.intValue == 0)
    #expect(result["pageInfo"]?["nextPageToken"]?.isNull == true)
  }

  @Test("A missing required upstream field fails rather than projecting a null")
  func missingRequiredFieldFails() async throws {
    let transport = RecordingTransport.succeeding(json: "{\"displayName\":\"Web stream\"}")
    let executor = try SampleCapabilities.executor(transport: transport)

    do {
      _ = try await executor.execute(Self.getInvocation())
      Issue.record("Expected the projection to fail")
    } catch let error as GatewayError {
      #expect(error.code == .upstreamResponseInvalid)
      #expect(error.requestID == fixtureRequestID)
    }
  }

  @Test("A validation failure costs no credential resolution and no request")
  func validationFailsBeforeCredentialResolution() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let credentials = RecordingCredentialProvider()
    let executor = try SampleCapabilities.executor(transport: transport, credentials: credentials)

    await #expect(throws: GatewayError.self) {
      _ = try await executor.execute(SampleCapabilities.invocation(
        SampleCapabilities.getDataStream,
        ["name": .string("properties/1/../2")]
      ))
    }

    #expect(await transport.requestCount == 0)
    #expect(credentials.resolutionCount == 0)
  }
}
