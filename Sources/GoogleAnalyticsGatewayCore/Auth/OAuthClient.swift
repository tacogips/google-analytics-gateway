import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol OAuthHTTPHandling: Sendable {
  func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse)
}

/// The OAuth token endpoint is reached over its own session, separate from the
/// API transport: it talks to a different host, carries the client secret, and
/// must never follow a redirect away from the pinned endpoint.
public struct URLSessionOAuthHTTP: OAuthHTTPHandling, Sendable {
  private let session: URLSession
  private let waitTimeout: DispatchTimeInterval

  public init(configuration: URLSessionConfiguration = .ephemeral, timeoutSeconds: Int = 30) {
    configuration.timeoutIntervalForRequest = TimeInterval(timeoutSeconds)
    configuration.timeoutIntervalForResource = TimeInterval(timeoutSeconds)
    session = URLSession(
      configuration: configuration,
      delegate: OAuthRedirectRejectingDelegate.shared,
      delegateQueue: nil
    )
    waitTimeout = .seconds(timeoutSeconds + 1)
  }

  public func execute(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
    let semaphore = DispatchSemaphore(value: 0)
    let result = LockedOAuthResult()
    let task = session.dataTask(with: request) { data, response, error in
      result.set(data: data, response: response as? HTTPURLResponse, error: error)
      semaphore.signal()
    }
    task.resume()
    guard semaphore.wait(timeout: .now() + waitTimeout) == .success else {
      task.cancel()
      throw GatewayError(code: .transportFailed, message: "OAuth HTTP request timed out")
    }
    return try result.get()
  }
}

/// Refuses every redirect so a token exchange cannot be steered off the pinned
/// endpoint, taking the client secret and authorization code with it.
final class OAuthRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  static let shared = OAuthRedirectRejectingDelegate()

  func urlSession(
    _: URLSession,
    task _: URLSessionTask,
    willPerformHTTPRedirection _: HTTPURLResponse,
    newRequest _: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

private final class LockedOAuthResult: @unchecked Sendable {
  private let lock = NSLock()
  private var result: Result<(Data, HTTPURLResponse), Error>?

  func set(data: Data?, response: HTTPURLResponse?, error: Error?) {
    lock.lock()
    defer { lock.unlock() }
    if let error {
      result = .failure(error)
    } else if let data, let response {
      result = .success((data, response))
    } else {
      result = .failure(GatewayError(code: .transportFailed, message: "OAuth HTTP request failed"))
    }
  }

  func get() throws -> (Data, HTTPURLResponse) {
    lock.lock()
    defer { lock.unlock() }
    return try result?.get() ?? { throw GatewayError(code: .transportFailed, message: "OAuth HTTP request failed") }()
  }
}

/// Token exchange and refresh against the pinned Google token endpoint.
///
/// Every response must be a Bearer grant with a bounded lifetime and a scope
/// set exactly equal to what was requested; a grant that came back broader or
/// narrower than the profile declares is rejected rather than stored.
public struct OAuthClient: OAuthTokenRefreshing, Sendable {
  private let http: any OAuthHTTPHandling
  private let now: @Sendable () -> Date

  public init(http: any OAuthHTTPHandling = URLSessionOAuthHTTP(), now: @escaping @Sendable () -> Date = Date.init) {
    self.http = http
    self.now = now
  }

  public func refresh(clientPath: String, token: OAuthToken, requiredScopes: [String]) throws -> OAuthToken {
    guard let refreshToken = token.refreshToken, !refreshToken.isEmpty else {
      throw GatewayError(
        code: .authenticationFailed,
        message: "OAuth token cannot be refreshed",
        recoveryGuidance: "Run auth login for this profile"
      )
    }
    let client = try loadClient(path: clientPath)
    let response = try tokenRequest(
      client: client,
      values: ["grant_type": "refresh_token", "refresh_token": refreshToken]
    )
    return try makeToken(
      response: response,
      profile: token.profile,
      fallbackRefreshToken: refreshToken,
      requiredScopes: requiredScopes
    )
  }

  public func exchange(
    clientPath: String,
    code: String,
    verifier: String,
    redirectURI: String,
    profile: CredentialProfile
  ) throws -> OAuthToken {
    let client = try loadClient(path: clientPath)
    let response = try tokenRequest(
      client: client,
      values: [
        "grant_type": "authorization_code", "code": code,
        "code_verifier": verifier, "redirect_uri": redirectURI
      ]
    )
    let token = try makeToken(
      response: response,
      profile: profile,
      fallbackRefreshToken: nil,
      requiredScopes: profile.oauthScopes
    )
    // A login that yields no refresh token would leave the profile unusable
    // within the hour; fail now rather than persist a dead-end grant.
    guard let refreshToken = token.refreshToken, !refreshToken.isEmpty else {
      throw GatewayError(code: .upstreamResponseInvalid, message: "OAuth token response is invalid")
    }
    return token
  }

  public func loadClient(path: String) throws -> OAuthDesktopClient {
    do {
      return try JSONDecoder().decode(
        OAuthDesktopClient.self,
        from: SecureLocalFiles.readRegularFile(path: path, maximumBytes: 1_048_576, requireCurrentUser: true)
      )
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError(code: .validationError, message: "OAuth client file is invalid")
    }
  }

  private func tokenRequest(client: OAuthDesktopClient, values: [String: String]) throws -> OAuthResponse {
    var body = values
    body["client_id"] = client.clientId
    if let secret = client.clientSecret { body["client_secret"] = secret }
    guard let tokenURL = URL(string: OAuthDesktopClient.tokenEndpoint) else {
      throw GatewayError(code: .internalError, message: "OAuth token request failed")
    }
    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = body.sorted { $0.key < $1.key }
      .map { "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)" }
      .joined(separator: "&")
      .data(using: .utf8)
    let (data, response): (Data, HTTPURLResponse)
    do {
      (data, response) = try http.execute(request)
    } catch {
      throw GatewayError(code: .transportFailed, message: "OAuth token request failed")
    }
    // The provider body is never surfaced: it can echo the submitted grant.
    guard (200..<300).contains(response.statusCode) else {
      throw GatewayError(
        code: .authenticationFailed,
        message: "OAuth token request was rejected",
        httpStatus: response.statusCode,
        recoveryGuidance: "Run auth login for this profile"
      )
    }
    do {
      return try JSONDecoder().decode(OAuthResponse.self, from: data)
    } catch {
      throw GatewayError(code: .upstreamResponseInvalid, message: "OAuth token response is invalid")
    }
  }

  private func makeToken(
    response: OAuthResponse,
    profile: CredentialProfile,
    fallbackRefreshToken: String?,
    requiredScopes: [String]
  ) throws -> OAuthToken {
    guard let accessToken = response.accessToken, let expiresIn = response.expiresIn,
      (1...31_536_000).contains(expiresIn),
      response.tokenType?.caseInsensitiveCompare("Bearer") == .orderedSame else {
      throw GatewayError(code: .upstreamResponseInvalid, message: "OAuth token response is invalid")
    }
    // A refresh response may omit `scope`, which means "unchanged"; anything it
    // does return must match the requested bundle exactly, in both directions.
    let scopes = (response.scope ?? requiredScopes.joined(separator: " ")).split(separator: " ").map(String.init)
    guard Set(requiredScopes) == Set(scopes), scopes.count == Set(scopes).count else {
      throw GatewayError(code: .upstreamResponseInvalid, message: "OAuth token response scope is invalid")
    }
    let current = now()
    return try OAuthToken(
      profile: profile,
      accessToken: accessToken,
      refreshToken: response.refreshToken ?? fallbackRefreshToken,
      tokenType: "Bearer",
      expiry: current.addingTimeInterval(TimeInterval(expiresIn)),
      updatedAt: current,
      scopes: scopes
    )
  }
}

private extension OAuthToken {
  /// A refresh only knows the stored grant, not the profile config it came
  /// from. `OAuthToken.init` reads back the id, product, and scope set, so this
  /// stand-in reproduces those three fields; the capability tier and env-var
  /// name are never consulted on this path.
  var profile: CredentialProfile {
    CredentialProfile(
      id: profileId,
      product: product,
      capability: .reader,
      oauthScopes: scopes,
      accessTokenEnvironmentVariable: "OAUTH_TOKEN_STORE"
    )
  }
}

private struct OAuthResponse: Decodable {
  let accessToken: String?
  let refreshToken: String?
  let tokenType: String?
  let expiresIn: Int?
  let scope: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token", refreshToken = "refresh_token"
    case tokenType = "token_type", expiresIn = "expires_in", scope
  }
}

private extension String {
  var urlFormEncoded: String { addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
}
