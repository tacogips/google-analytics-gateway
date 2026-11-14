import Foundation

/// A coding key that accepts any name, used to enumerate the keys actually
/// present in a document so unknown fields can be rejected.
struct AuthAnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?
  init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
  init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

/// The persisted OAuth grant for one credential profile.
///
/// The stored document records which profile and product the grant belongs to
/// and the exact scope set that was granted, so a token file cannot be moved
/// between profiles or tiers and still be accepted.
public struct OAuthToken: Codable, Equatable, Sendable {
  public static let schemaVersion = 1
  public let storedSchemaVersion: Int
  public let profileId: String
  public let product: GatewayProduct
  public let accessToken: String
  public let refreshToken: String?
  public let tokenType: String
  public let expiry: Date
  public let updatedAt: Date
  public let scopes: [String]

  /// A token within `leeway` of expiry is treated as already unusable, so a
  /// request is never started with a grant that may expire mid-flight.
  public func isNearExpiry(now: Date, leeway: TimeInterval = 60) -> Bool {
    expiry <= now.addingTimeInterval(leeway)
  }

  enum CodingKeys: String, CodingKey, CaseIterable {
    case storedSchemaVersion = "schemaVersion", profileId, product, accessToken, refreshToken
    case tokenType, expiry = "expiresAt", updatedAt, scopes
  }

  public init(
    profile: CredentialProfile,
    accessToken: String,
    refreshToken: String?,
    tokenType: String,
    expiry: Date,
    updatedAt: Date = Date(),
    scopes: [String]
  ) throws {
    guard OAuthToken.isCredential(accessToken), refreshToken.map(OAuthToken.isCredential) ?? true,
      tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
      !scopes.isEmpty, Set(scopes) == Set(profile.oauthScopes), scopes.count == Set(scopes).count,
      scopes.allSatisfy({ $0.utf8.count <= 512 }) else {
      throw GatewayError(code: .validationError, message: "OAuth token store is invalid")
    }
    storedSchemaVersion = Self.schemaVersion
    profileId = profile.id
    product = profile.product
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.tokenType = tokenType
    self.expiry = expiry
    self.updatedAt = updatedAt
    self.scopes = scopes
  }

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.container(keyedBy: AuthAnyCodingKey.self)
    let allowed = Set(CodingKeys.allCases.map(\.stringValue))
    guard raw.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw GatewayError(code: .validationError, message: "OAuth token store contains unsupported fields")
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let schemaVersion = try container.decode(Int.self, forKey: .storedSchemaVersion)
    let profileId = try container.decode(String.self, forKey: .profileId)
    let product = try container.decode(GatewayProduct.self, forKey: .product)
    let scopes = try container.decode([String].self, forKey: .scopes)
    guard schemaVersion == Self.schemaVersion, !profileId.isEmpty,
      OAuthToken.isCredential(try container.decode(String.self, forKey: .accessToken)),
      (try container.decodeIfPresent(String.self, forKey: .refreshToken)).map(OAuthToken.isCredential) ?? true,
      (try container.decode(String.self, forKey: .tokenType)).caseInsensitiveCompare("Bearer") == .orderedSame,
      !scopes.isEmpty, scopes.count == Set(scopes).count else {
      throw GatewayError(code: .validationError, message: "OAuth token store is invalid")
    }
    storedSchemaVersion = schemaVersion
    self.profileId = profileId
    self.product = product
    accessToken = try container.decode(String.self, forKey: .accessToken)
    refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
    tokenType = try container.decode(String.self, forKey: .tokenType)
    expiry = try container.decode(Date.self, forKey: .expiry)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    self.scopes = scopes
  }

  /// A credential is a bounded run of printable non-space bytes: anything that
  /// could break a header or wrap onto a second line is not one. Internal so
  /// the credential resolver applies the same rule to environment-injected
  /// tokens.
  static func isCredential(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 8_192 && !value.utf8.contains(where: { $0 < 33 || $0 == 127 })
  }
}

public protocol OAuthTokenStoring: Sendable {
  func read(path: String, profile: CredentialProfile) throws -> OAuthToken
  func write(_ token: OAuthToken, path: String, profile: CredentialProfile) throws
  func delete(path: String, profile: CredentialProfile) throws -> Bool
}

/// Token persistence at the profile-named path only; there is no default
/// location, so a gateway never picks up credentials the operator did not name.
public struct OAuthTokenStore: OAuthTokenStoring, Sendable {
  public init() {}

  public func read(path: String, profile: CredentialProfile) throws -> OAuthToken {
    do {
      return try decode(
        SecureLocalFiles.readRegularFile(
          path: path,
          maximumBytes: 1_048_576,
          requireCurrentUser: true,
          requirePrivateMode: true,
          requirePrivateParent: true
        ),
        profile: profile
      )
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError(code: .validationError, message: "OAuth token store is invalid")
    }
  }

  public func write(_ token: OAuthToken, path: String, profile: CredentialProfile) throws {
    guard token.profileId == profile.id, token.product == profile.product,
      Set(token.scopes) == Set(profile.oauthScopes), token.scopes.count == profile.oauthScopes.count else {
      throw GatewayError(code: .validationError, message: "OAuth token store does not match selected profile")
    }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    try SecureLocalFiles.writePrivateFile(try encoder.encode(token), path: path)
  }

  public func delete(path: String, profile: CredentialProfile) throws -> Bool {
    try SecureLocalFiles.readAndDeletePrivateFile(path: path, maximumBytes: 1_048_576) { data in
      _ = try decode(data, profile: profile)
    }
  }

  private func decode(_ data: Data, profile: CredentialProfile) throws -> OAuthToken {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let token = try decoder.decode(OAuthToken.self, from: data)
    guard token.profileId == profile.id, token.product == profile.product,
      Set(token.scopes) == Set(profile.oauthScopes), token.scopes.count == profile.oauthScopes.count else {
      throw GatewayError(code: .validationError, message: "OAuth token store does not match selected profile")
    }
    return token
  }
}
