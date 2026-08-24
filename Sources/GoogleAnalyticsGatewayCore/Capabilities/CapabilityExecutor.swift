import Foundation

/// Executes planned capabilities against the Google APIs.
///
/// It is the only component that joins a plan, a credential, and a transport.
/// Because both the typed SDK and the GraphQL runtime call `execute(_:)` with a
/// `CapabilityPlan` produced by `CapabilityPlanner`, neither can select a
/// different capability, route, validation outcome, or error mapping.
public struct CapabilityExecutor: Sendable {
  public let planner: CapabilityPlanner
  private let transport: any GoogleTransport
  private let credentials: any CredentialProvider
  private let clock: any GatewayClock
  private let retryPolicy: RetryPolicy
  private let requestIDFactory: @Sendable () -> String

  public init(
    planner: CapabilityPlanner,
    transport: any GoogleTransport,
    credentials: any CredentialProvider,
    clock: any GatewayClock = SystemClock(),
    retryPolicy: RetryPolicy = RetryPolicy(),
    requestIDFactory: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    self.planner = planner
    self.transport = transport
    self.credentials = credentials
    self.clock = clock
    self.retryPolicy = retryPolicy
    self.requestIDFactory = requestIDFactory
  }

  /// Plans and executes an invocation, returning the full stable result.
  ///
  /// Planning runs first and is entirely local, so unsupported fields, unknown
  /// arguments, malformed resource names, unconfirmed deletes, and oversized
  /// page sizes all fail before any credential is resolved. The scope check
  /// needs the credential, so it runs immediately after resolution and still
  /// before transport.
  public func execute(
    _ invocation: CapabilityInvocation
  ) async throws -> JSONValue {
    let plan = try planner.plan(invocation)
    let credential = try await credentials.credential()
    try planner.validateScopes(
      for: plan.definition,
      grantedScopes: credential.grantedScopes
    )
    return try await execute(plan, credential: credential)
  }

  /// Executes an already-planned capability.
  public func execute(
    _ plan: CapabilityPlan,
    credential: ResolvedCredential? = nil
  ) async throws -> JSONValue {
    let resolved: ResolvedCredential
    if let credential {
      resolved = credential
    } else {
      resolved = try await credentials.credential()
    }
    let requestID = requestIDFactory()
    let response = try await send(plan: plan, credential: resolved, requestID: requestID)
    do {
      return try ResponseProjection.result(
        for: plan.definition,
        response: response,
        validatedDeletionResourceName: plan.validatedDeletionResourceName
      )
    } catch let error as GatewayError {
      throw error.withContext(requestID: requestID, capabilityID: plan.capabilityID)
    }
  }

  private func send(
    plan: CapabilityPlan,
    credential: ResolvedCredential,
    requestID: String
  ) async throws -> UpstreamResponse {
    var currentCredential = credential
    var didRefresh = false
    var attempt = 0
    let started = clock.now

    while true {
      attempt += 1
      let prepared = try Self.prepare(
        plan.request,
        credential: currentCredential,
        requestID: requestID
      )

      let response: UpstreamResponse
      do {
        response = try await transport.send(prepared)
      } catch let failure as TransportFailure {
        let elapsed = clock.now.timeIntervalSince(started)
        if failure.isTransient,
           let delay = retryPolicy.delayBeforeRetry(
             attempt: attempt,
             method: plan.request.method,
             retryAfterSeconds: nil,
             elapsedSeconds: elapsed
           ) {
          try await clock.sleep(seconds: delay)
          continue
        }
        throw Self.transportError(
          failure,
          plan: plan,
          requestID: requestID
        )
      }

      if let outcome = UpstreamErrorMapper.classify(response) {
        // A 401 permits exactly one refresh attempt; a second 401 is returned.
        if outcome.code == .authenticationFailed, !didRefresh,
           let refreshed = try await credentials.refreshedCredential(after: currentCredential) {
          didRefresh = true
          currentCredential = refreshed
          // The re-send carries a new credential for a request that was refused
          // for the old one, so it is not one of the attempts the retry policy
          // budgets for transient upstream conditions. Without this, a request
          // that refreshes and then meets a 429 gets fewer retries than the
          // policy specifies, and `didRefresh` already bounds this branch to
          // one pass.
          attempt -= 1
          continue
        }

        let elapsed = clock.now.timeIntervalSince(started)
        if RetryPolicy.isRetryable(status: response.statusCode),
           let delay = retryPolicy.delayBeforeRetry(
             attempt: attempt,
             method: plan.request.method,
             retryAfterSeconds: outcome.retryAfterSeconds,
             elapsedSeconds: elapsed
           ) {
          try await clock.sleep(seconds: delay)
          continue
        }

        throw UpstreamErrorMapper.error(
          from: outcome,
          status: response.statusCode,
          capability: plan.capabilityID,
          requestID: requestID,
          method: plan.request.method
        ).withRecoveryGuidance(plan.definition.rejectionGuidance(for: outcome.code))
      }

      return response
    }
  }

  /// Maps a transport failure. Non-idempotent methods report an unknown
  /// outcome because the transport cannot prove Google did not apply the change.
  static func transportError(
    _ failure: TransportFailure,
    plan: CapabilityPlan,
    requestID: String
  ) -> GatewayError {
    if case .localIO(let detail) = failure {
      return GatewayError(
        code: .fileOperationFailed,
        message: "A local file operation failed: \(detail).",
        requestID: requestID,
        capabilityID: plan.capabilityID
      )
    }
    let outcomeUnknown = !plan.request.method.isAutomaticallyRetryable && failure != .cancelled
    return GatewayError(
      code: .transportFailed,
      message: failure.safeSummary,
      requestID: requestID,
      capabilityID: plan.capabilityID,
      outcomeUnknown: outcomeUnknown,
      recoveryGuidance: outcomeUnknown
        ? "The request was not automatically retried. Confirm the current state in the "
          + "Google Analytics or Tag Manager console before retrying."
        : nil
    )
  }

  /// Resolves the relative request against the origin of the service its
  /// capability declared.
  ///
  /// The origin comes from the capability, not from the credential and not from
  /// any caller-supplied value, so one credential can address several Google
  /// services without any of them being reachable by a request that did not
  /// name it.
  public static func prepare(
    _ request: UpstreamRequest,
    credential: ResolvedCredential,
    requestID: String
  ) throws -> PreparedRequest {
    var components = URLComponents(url: request.origin, resolvingAgainstBaseURL: false)
    components?.path = request.path
    if !request.queryItems.isEmpty {
      components?.queryItems = request.queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
    }
    guard let url = components?.url else {
      throw GatewayError.internalFailure("The capability request could not be resolved to a URL.")
    }
    return PreparedRequest(
      url: url,
      method: request.method,
      headers: request.headers,
      bearerToken: credential.token,
      body: request.body,
      timeout: request.timeout,
      capabilityID: request.capabilityID,
      requestID: requestID,
      responseSink: request.responseSink
    )
  }
}

private extension CapabilityPlan {
  /// Delete capabilities are registry-validated to bind exactly one resource
  /// name into their path and to require a confirmation echo of it. Reading
  /// that already-coerced value back is what lets an empty Google delete
  /// response still name what was removed, without parsing a URL or trusting an
  /// unvalidated caller value.
  var validatedDeletionResourceName: String? {
    guard case .deletion = definition.result,
          let argument = definition.solePathArgument,
          case .resourceName(let name)? = validatedArguments[argument.name]
    else {
      return nil
    }
    return name
  }
}
