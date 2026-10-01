import Foundation
import Testing
@testable import GoogleAnalyticsGatewayCore

@Test func everyAnalyticsRolePreservesExternalLogoutCredentials() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("external.json")
  let bytes = Data("external-fixture".utf8)
  try bytes.write(to: file)
  for role in [RoleDescriptor.reader, .writer, .admin] {
    for source in ["ACCESS_TOKEN": "external-fixture", "TOKEN_STORE_JSON": "external-fixture", "TOKEN_STORE_PATH": file.path] {
      let env = ["XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
                 "GOOGLE_ANALYTICS_GATEWAY_" + source.key: source.value]
      let commands = AuthCommands(role: role, auth: AuthService(), resolver: CredentialResolver(), environment: env)
      let result = commands.logout(selection: .init(configPath: nil, profileID: nil))
      #expect(result.exitCode == .success)
      #expect(result.standardOutput.contains("EXTERNAL_CREDENTIAL_PRESERVED"))
      #expect(try Data(contentsOf: file) == bytes)
    }
  }
}
