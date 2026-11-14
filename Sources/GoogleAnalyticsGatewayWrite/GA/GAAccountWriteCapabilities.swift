import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1beta account mutations.
enum GAAccountWriteCapabilities {
  private static let account = "accounts/{account}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.accounts.update"),
      field: "gaUpdateAccount",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(account), .path("name"), required: true),
        ArgumentDefinition(
          "account",
          .inputObject(GAWriteInputs.accountUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "account", GAModels.account),
      scopes: .analyticsEdit,
      summary: "Updates an account."
    )
  ]
}
