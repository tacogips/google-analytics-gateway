import Foundation

struct AnalyticsCredentialInput {
  let accessToken: String?
  let tokenStoreJSON: String?
  let tokenStorePath: String?

  init(profile: CredentialProfile, environment: [String: String]) throws {
    accessToken = try analyticsCredentialValue(profile: profile, suffix: "ACCESS_TOKEN",
                                               alias: profile.accessTokenEnvironmentVariable, environment: environment)
    tokenStoreJSON = try analyticsCredentialValue(profile: profile, suffix: "TOKEN_STORE_JSON", environment: environment)
    tokenStorePath = try analyticsCredentialValue(profile: profile, suffix: "TOKEN_STORE_PATH", environment: environment)
    let count = [accessToken, tokenStoreJSON, tokenStorePath].compactMap { $0 }.count
    guard count <= 1 else {
      throw GatewayError.validation("Select only one of ACCESS_TOKEN, TOKEN_STORE_JSON, or TOKEN_STORE_PATH")
    }
  }
}

func analyticsCredentialValue(
  profile: CredentialProfile, suffix: String, alias: String? = nil, environment: [String: String]
) throws -> String? {
  let prefix = "GOOGLE_ANALYTICS_GATEWAY_"
  let normalizedID = profile.id.uppercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }
  let specificPrefix = prefix + "CREDENTIAL_" + String(normalizedID) + "_"
  let tokenSources = ["ACCESS_TOKEN", "TOKEN_STORE_JSON", "TOKEN_STORE_PATH"]
  let clientSources = ["OAUTH_CLIENT_JSON", "OAUTH_CLIENT_PATH"]
  let group = tokenSources.contains(suffix) ? tokenSources : (clientSources.contains(suffix) ? clientSources : [suffix])
  let hasSpecific = group.contains { analyticsNonBlank(environment[specificPrefix + $0]) != nil }
  let global = prefix + suffix
  let selected = hasSpecific ? specificPrefix + suffix : global
  let effectiveAlias = alias == global && hasSpecific ? nil : alias
  let names = Set([selected, effectiveAlias].compactMap { $0 })
  let values = names.compactMap { name in analyticsNonBlank(environment[name]).map { (name, $0) } }
  guard let first = values.first else { return nil }
  guard values.allSatisfy({ $0.1 == first.1 }) else {
    throw GatewayError.validation("Conflicting credential environment variables: \(values.map { $0.0 }.sorted().joined(separator: ", "))")
  }
  return first.1
}

private func analyticsNonBlank(_ value: String?) -> String? {
  guard let value else { return nil }
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : trimmed
}

func analyticsProfilePaths(_ profile: CredentialProfile, environment: [String: String]) throws -> CredentialProfile {
  let client = try analyticsCredentialValue(profile: profile, suffix: "OAUTH_CLIENT_PATH", environment: environment)
  let json = try analyticsCredentialValue(profile: profile, suffix: "OAUTH_CLIENT_JSON", environment: environment)
  guard json == nil || client == nil else {
    throw GatewayError.validation("Select OAuth client JSON or path")
  }
  let token = try analyticsCredentialValue(profile: profile, suffix: "TOKEN_STORE_PATH", environment: environment)
  let clientPath = json != nil ? nil : (client ?? profile.oauthClientJSONPath)
  let tokenPath = token ?? profile.tokenStorePath
  if let clientPath, let tokenPath,
     URL(fileURLWithPath: clientPath).standardizedFileURL.path == URL(fileURLWithPath: tokenPath).standardizedFileURL.path {
    throw GatewayError.validation("OAuth client and token-store paths must differ")
  }
  return CredentialProfile(
    id: profile.id, product: profile.product, capability: profile.capability,
    oauthScopes: profile.oauthScopes, accessTokenEnvironmentVariable: profile.accessTokenEnvironmentVariable,
    oauthClientJSON: json ?? (client == nil ? profile.oauthClientJSON : nil),
    oauthClientJSONPath: clientPath, tokenStorePath: tokenPath
  )
}
