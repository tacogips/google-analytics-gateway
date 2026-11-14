import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager account mutations. Google gates the account update behind the
/// account-management scope rather than the container edit scope.
enum GTMAccountWriteCapabilities {
  static let all: [CapabilityDefinition] = [update]

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.accounts.update"),
    field: "gtmUpdateAccount",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.account), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("account", .inputObject(GTMWriteInputs.account), .bodyRoot, required: true)
    ],
    result: .payload(field: "account", GTMModels.account),
    scopes: .tagManagerManageAccounts,
    summary: "Updates a GTM Account."
  )
}
