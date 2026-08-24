import Foundation

/// Implements `auth oauth2`, `auth status`, `auth logout`, and `doctor`.
///
/// These commands are available in all three executables because they manage
/// local credential state, not Google resources. `auth logout` removes the
/// local token store record only; it never calls a Google revocation endpoint.
public struct AuthCommands: Sendable {
  private let role: RoleDescriptor
  private let auth: any AuthManaging
  private let resolver: CredentialResolver
  private let environment: [String: String]

  public init(
    role: RoleDescriptor,
    auth: any AuthManaging,
    resolver: CredentialResolver,
    environment: [String: String]
  ) {
    self.role = role
    self.auth = auth
    self.resolver = resolver
    self.environment = environment
  }

  public func login(
    selection: CredentialSelection,
    noBrowser: Bool,
    timeoutSeconds: Int?
  ) -> CommandOutcome {
    do {
      let resolution = try ProfileSelector.resolve(
        selection: selection, tier: role.tier, environment: environment
      )
      guard !resolution.isSynthesized else {
        throw GatewayError.validation(
          "auth oauth2 requires a configuration document with an OAuth client.",
          recovery: "Pass --config naming a profile with oauthClientJSONPath and tokenStorePath."
        )
      }
      let output = try auth.login(
        profile: resolution.profile,
        noBrowser: noBrowser,
        redirectURI: nil,
        timeoutSeconds: Int32(timeoutSeconds ?? 180)
      )
      return CommandEnvelope.success(try Self.encoded(output))
    } catch let error as GatewayError {
      return CommandEnvelope.failure(error)
    } catch {
      return CommandEnvelope.failure(.internalFailure("The login flow failed unexpectedly."))
    }
  }

  public func status(selection: CredentialSelection) -> CommandOutcome {
    do {
      let resolution = try ProfileSelector.resolve(
        selection: selection, tier: role.tier, environment: environment
      )
      let report = auth.status(profile: resolution.profile, environment: environment)
      return CommandEnvelope.success(try Self.encoded(report))
    } catch let error as GatewayError {
      return CommandEnvelope.failure(error)
    } catch {
      return CommandEnvelope.failure(
        GatewayError(code: .fileOperationFailed, message: "The credential store could not be read.")
      )
    }
  }

  public func logout(selection: CredentialSelection) -> CommandOutcome {
    do {
      let resolution = try ProfileSelector.resolve(
        selection: selection, tier: role.tier, environment: environment
      )
      let removed = try auth.logout(profile: resolution.profile)
      return CommandEnvelope.success(.object(["removedLocalRecord": .bool(removed)]))
    } catch let error as GatewayError {
      return CommandEnvelope.failure(error)
    } catch {
      return CommandEnvelope.failure(
        GatewayError(code: .fileOperationFailed, message: "The token store could not be removed.")
      )
    }
  }

  /// Reports configuration and credential readiness without printing secret
  /// values: only presence flags and non-secret metadata appear.
  public func doctor(selection: CredentialSelection) -> CommandOutcome {
    do {
      let resolution = try ProfileSelector.resolve(
        selection: selection, tier: role.tier, environment: environment
      )
      let profile = resolution.profile
      let report = auth.status(profile: profile, environment: environment)
      // Trimmed to match the resolver's own predicate, so doctor never
      // reports a whitespace-only value as a usable token.
      let tokenVariableSet = !(environment[profile.accessTokenEnvironmentVariable] ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      var fields: [String: JSONValue] = [
        "executable": .string(role.executableName),
        "tier": .string(role.tier.rawValue),
        "configSource": .string(
          resolution.isSynthesized
            ? "SYNTHESIZED_DEFAULT"
            : (selection.configPath != nil ? "COMMAND_LINE" : "ENVIRONMENT")
        ),
        "profileId": .string(profile.id),
        "product": .string(profile.product.rawValue),
        "capability": .string(profile.capability.rawValue),
        "oauthScopes": .array(profile.oauthScopes.map(JSONValue.string)),
        "accessTokenEnvironmentVariable": .string(profile.accessTokenEnvironmentVariable),
        "accessTokenEnvironmentVariableSet": .bool(tokenVariableSet),
        "oauthClientConfigured": .bool(profile.oauthClientJSONPath != nil),
        "tokenStoreConfigured": .bool(profile.tokenStorePath != nil),
        "authStatus": try Self.encoded(report)
      ]
      if let path = resolution.configPath {
        fields["configPath"] = .string(path)
      }
      return CommandEnvelope.success(.object(fields))
    } catch let error as GatewayError {
      return CommandEnvelope.failure(error)
    } catch {
      return CommandEnvelope.failure(.internalFailure("The doctor report could not be produced."))
    }
  }

  static func encoded(_ value: some Encodable) throws -> JSONValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    return try JSONValue.decodeJSON(data)
  }
}
