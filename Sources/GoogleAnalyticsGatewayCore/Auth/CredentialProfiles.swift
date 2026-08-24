import Foundation

/// The Google product surface a credential profile authorizes.
///
/// `combined` exists because one operator frequently drives GA4 and Tag Manager
/// with a single consent screen; it carries the union of both product bundles
/// for its capability tier.
public enum GatewayProduct: String, Codable, CaseIterable, Equatable, Sendable {
  case analytics
  case tagManager = "tag-manager"
  case combined
}

/// A named credential binding: which product, at which capability tier, with
/// which exact OAuth scope bundle, and where the local OAuth material lives.
///
/// A profile never carries a secret value. It names the environment variable an
/// access token may arrive in, so a non-interactive caller can inject a token
/// without any file touching disk.
public struct CredentialProfile: Codable, Equatable, Sendable {
  public let id: String
  public let product: GatewayProduct
  public let capability: CapabilityTier
  public let oauthScopes: [String]
  public let accessTokenEnvironmentVariable: String
  public let oauthClientJSONPath: String?
  public let tokenStorePath: String?

  public init(
    id: String,
    product: GatewayProduct,
    capability: CapabilityTier,
    oauthScopes: [String],
    accessTokenEnvironmentVariable: String,
    oauthClientJSONPath: String? = nil,
    tokenStorePath: String? = nil
  ) {
    self.id = id
    self.product = product
    self.capability = capability
    self.oauthScopes = oauthScopes
    self.accessTokenEnvironmentVariable = accessTokenEnvironmentVariable
    self.oauthClientJSONPath = oauthClientJSONPath
    self.tokenStorePath = tokenStorePath
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id, product, capability, oauthScopes, accessTokenEnvironmentVariable
    case oauthClientJSONPath, tokenStorePath
  }

  /// Decoding rejects unknown fields outright: a misspelled security-relevant
  /// key must fail loudly instead of being silently ignored.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let raw = try decoder.container(keyedBy: AuthAnyCodingKey.self)
    let allowed = Set(CodingKeys.allCases.map(\.rawValue))
    guard raw.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
      throw GatewayError(code: .validationError, message: "Credential profile contains an unsupported field")
    }
    self.init(
      id: try container.decode(String.self, forKey: .id),
      product: try container.decode(GatewayProduct.self, forKey: .product),
      capability: try container.decode(CapabilityTier.self, forKey: .capability),
      oauthScopes: try container.decode([String].self, forKey: .oauthScopes),
      accessTokenEnvironmentVariable: try container.decode(String.self, forKey: .accessTokenEnvironmentVariable),
      oauthClientJSONPath: try container.decodeIfPresent(String.self, forKey: .oauthClientJSONPath),
      tokenStorePath: try container.decodeIfPresent(String.self, forKey: .tokenStorePath)
    )
  }
}

public struct CredentialProfileConfiguration: Codable, Equatable, Sendable {
  /// Environment fallback for the profile config path when `--config` is absent.
  public static let pathEnvironmentVariable = "GOOGLE_ANALYTICS_GATEWAY_CONFIG"

  public let profiles: [CredentialProfile]

  private enum CodingKeys: String, CodingKey, CaseIterable { case profiles }

  public init(profiles: [CredentialProfile]) throws { self.profiles = profiles; try validate() }

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.container(keyedBy: AuthAnyCodingKey.self)
    guard raw.allKeys.allSatisfy({ $0.stringValue == CodingKeys.profiles.rawValue }) else {
      throw GatewayError(code: .validationError, message: "Credential profile config contains an unsupported field")
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(profiles: container.decode([CredentialProfile].self, forKey: .profiles))
  }

  public static func decode(_ data: Data) throws -> CredentialProfileConfiguration {
    do {
      let configuration = try JSONDecoder().decode(CredentialProfileConfiguration.self, from: data)
      try configuration.validate()
      return configuration
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError(code: .validationError, message: "Credential profile config is not valid JSON")
    }
  }

  public static func load(path: String) throws -> CredentialProfileConfiguration {
    guard SecureLocalFiles.isSafePath(path) else {
      throw GatewayError(code: .validationError, message: "Credential profile config path is invalid")
    }
    let configURL = URL(fileURLWithPath: path).standardizedFileURL
    do {
      return try decode(Data(contentsOf: configURL)).resolvingPaths(
        relativeTo: configURL.deletingLastPathComponent(),
        configURL: configURL
      )
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError(code: .fileOperationFailed, message: "Unable to read credential profile config")
    }
  }

  /// Resolves the config path from an explicit `--config` value, falling back to
  /// `GOOGLE_ANALYTICS_GATEWAY_CONFIG`.
  public static func resolvePath(explicit: String?, environment: [String: String]) throws -> String {
    let candidate = explicit ?? environment[pathEnvironmentVariable]
    guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw GatewayError(
        code: .validationError,
        message: "No credential profile config path was provided",
        recoveryGuidance: "Pass --config <path> or set \(pathEnvironmentVariable)"
      )
    }
    guard SecureLocalFiles.isSafePath(candidate) else {
      throw GatewayError(code: .validationError, message: "Credential profile config path is invalid")
    }
    return candidate
  }

  public func profile(id: String) throws -> CredentialProfile {
    guard let profile = profiles.first(where: { $0.id == id }) else {
      throw GatewayError(
        code: .validationError,
        message: "Credential profile was not found",
        recoveryGuidance: "Known profile ids: \(profiles.map(\.id).sorted().joined(separator: ", "))"
      )
    }
    return profile
  }

  private func resolvingPaths(relativeTo directory: URL, configURL: URL) throws -> CredentialProfileConfiguration {
    let resolvedProfiles = try profiles.map { profile in
      CredentialProfile(
        id: profile.id,
        product: profile.product,
        capability: profile.capability,
        oauthScopes: profile.oauthScopes,
        accessTokenEnvironmentVariable: profile.accessTokenEnvironmentVariable,
        oauthClientJSONPath: try resolvedPath(profile.oauthClientJSONPath, relativeTo: directory),
        tokenStorePath: try resolvedPath(profile.tokenStorePath, relativeTo: directory)
      )
    }
    try validateResolvedPaths(profiles: resolvedProfiles, configURL: configURL)
    return try CredentialProfileConfiguration(profiles: resolvedProfiles)
  }

  private func resolvedPath(_ value: String?, relativeTo directory: URL) throws -> String? {
    guard let value else { return nil }
    guard SecureLocalFiles.isSafePath(value) else { throw configurationError("Configured path is unsafe") }
    let url = value.hasPrefix("/") ? URL(fileURLWithPath: value) : directory.appendingPathComponent(value)
    return url.standardizedFileURL.path
  }

  /// Two profiles sharing a token store would let a lower tier read a higher
  /// tier's token, and a store that aliases the config file would let a login
  /// overwrite the profile definitions. Both are rejected here.
  private func validateResolvedPaths(profiles: [CredentialProfile], configURL: URL) throws {
    let configPath = configURL.path
    var storePaths = Set<String>()
    var clientPaths = Set<String>()
    for profile in profiles {
      if let store = profile.tokenStorePath {
        guard store != configPath, storePaths.insert(store).inserted, !clientPaths.contains(store) else {
          throw configurationError("Token-store path collides with another configured path")
        }
      }
      if let client = profile.oauthClientJSONPath {
        guard client != configPath, !storePaths.contains(client) else {
          throw configurationError("OAuth client path collides with another configured path")
        }
        clientPaths.insert(client)
      }
    }
  }

  private func validate() throws {
    guard !profiles.isEmpty else { throw configurationError("At least one credential profile is required") }
    var ids = Set<String>()
    for profile in profiles {
      guard Self.isSafeProfileID(profile.id), ids.insert(profile.id).inserted else {
        throw configurationError("Credential profile id is invalid or duplicated")
      }
      let configuredScopes = Set(profile.oauthScopes)
      guard !configuredScopes.isEmpty, configuredScopes.count == profile.oauthScopes.count else {
        throw configurationError("Credential profile OAuth scopes are invalid")
      }
      // Exact bundle equality, not containment: a profile may neither request
      // more authority than its tier documents nor silently under-request and
      // fail later against a live capability.
      guard configuredScopes == Set(profile.product.oauthScopes(for: profile.capability)) else {
        throw configurationError(
          "Credential profile OAuth scopes are not the exact \(profile.capability.rawValue) bundle "
            + "for product \(profile.product.rawValue)"
        )
      }
      guard Self.isSafeEnvironmentVariable(profile.accessTokenEnvironmentVariable) else {
        throw configurationError("Access-token environment-variable name is unsafe")
      }
      let clientPath = profile.oauthClientJSONPath
      let storePath = profile.tokenStorePath
      guard (clientPath == nil) == (storePath == nil) else {
        throw configurationError("OAuth client and token-store paths must be configured together")
      }
      if let clientPath, !SecureLocalFiles.isSafePath(clientPath) {
        throw configurationError("OAuth client path is unsafe")
      }
      if let storePath, !SecureLocalFiles.isSafePath(storePath) {
        throw configurationError("Token-store path is unsafe")
      }
    }
  }

  private static func isSafeProfileID(_ value: String) -> Bool {
    guard (1...80).contains(value.count), let first = value.utf8.first, isASCIILetterOrNumber(first) else { return false }
    return value.utf8.allSatisfy { isASCIILetterOrNumber($0) || $0 == 45 || $0 == 95 }
  }

  /// Only a conventional POSIX environment-variable name is accepted, so a
  /// profile cannot name something a shell would refuse to export or that would
  /// be ambiguous to read back.
  static func isSafeEnvironmentVariable(_ value: String) -> Bool {
    guard (1...128).contains(value.count), let first = value.utf8.first,
      isASCIIUppercase(first) || first == 95 else { return false }
    return value.utf8.allSatisfy { isASCIIUppercase($0) || (48...57).contains($0) || $0 == 95 }
  }

  private static func isASCIILetterOrNumber(_ byte: UInt8) -> Bool {
    (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
  }

  private static func isASCIIUppercase(_ byte: UInt8) -> Bool { (65...90).contains(byte) }

  private func configurationError(_ message: String) -> GatewayError {
    GatewayError(code: .validationError, message: message)
  }
}

extension GatewayProduct {
  /// The exact OAuth scope bundle a profile of this product and tier must
  /// declare, from `design-docs/references/google-api-surfaces.md`
  /// ("Role-split executables map to scope sets").
  ///
  /// Tiers are cumulative, matching the capability tiers themselves: the admin
  /// bundle contains the reader and writer bundles so an admin binary can serve
  /// reader capabilities with the same consent.
  public func oauthScopes(for tier: CapabilityTier) -> [String] {
    switch tier {
    case .reader:
      return readerScopes
    case .writer:
      return writerScopes
    case .admin:
      return writerScopes + adminScopes
    }
  }

  private var readerScopes: [String] {
    switch self {
    case .analytics: [GoogleOAuthScope.analyticsReadonly]
    case .tagManager: [GoogleOAuthScope.tagManagerReadonly]
    case .combined: [GoogleOAuthScope.analyticsReadonly, GoogleOAuthScope.tagManagerReadonly]
    }
  }

  private var writerScopes: [String] {
    switch self {
    case .analytics:
      [GoogleOAuthScope.analyticsEdit, GoogleOAuthScope.analytics]
    case .tagManager:
      [
        GoogleOAuthScope.tagManagerEditContainers,
        GoogleOAuthScope.tagManagerEditContainerVersions,
        GoogleOAuthScope.tagManagerPublish
      ]
    case .combined:
      GatewayProduct.analytics.writerScopes + GatewayProduct.tagManager.writerScopes
    }
  }

  /// Scopes an admin bundle adds on top of the writer bundle, including the
  /// reader scopes so the admin consent covers every tier below it.
  private var adminScopes: [String] {
    switch self {
    case .analytics:
      [
        GoogleOAuthScope.analyticsReadonly,
        GoogleOAuthScope.analyticsManageUsers,
        GoogleOAuthScope.analyticsManageUsersReadonly
      ]
    case .tagManager:
      [
        GoogleOAuthScope.tagManagerReadonly,
        GoogleOAuthScope.tagManagerManageAccounts,
        GoogleOAuthScope.tagManagerManageUsers,
        GoogleOAuthScope.tagManagerDeleteContainers
      ]
    case .combined:
      GatewayProduct.analytics.adminScopes + GatewayProduct.tagManager.adminScopes
    }
  }
}

/// The Google OAuth scope URLs this gateway is allowed to request.
public enum GoogleOAuthScope {
  public static let analytics = "https://www.googleapis.com/auth/analytics"
  public static let analyticsReadonly = "https://www.googleapis.com/auth/analytics.readonly"
  public static let analyticsEdit = "https://www.googleapis.com/auth/analytics.edit"
  public static let analyticsManageUsers = "https://www.googleapis.com/auth/analytics.manage.users"
  public static let analyticsManageUsersReadonly = "https://www.googleapis.com/auth/analytics.manage.users.readonly"
  public static let tagManagerReadonly = "https://www.googleapis.com/auth/tagmanager.readonly"
  public static let tagManagerEditContainers = "https://www.googleapis.com/auth/tagmanager.edit.containers"
  public static let tagManagerEditContainerVersions = "https://www.googleapis.com/auth/tagmanager.edit.containerversions"
  public static let tagManagerPublish = "https://www.googleapis.com/auth/tagmanager.publish"
  public static let tagManagerDeleteContainers = "https://www.googleapis.com/auth/tagmanager.delete.containers"
  public static let tagManagerManageAccounts = "https://www.googleapis.com/auth/tagmanager.manage.accounts"
  public static let tagManagerManageUsers = "https://www.googleapis.com/auth/tagmanager.manage.users"
}
