import GoogleAnalyticsGatewayCore

/// Tag Manager account reads.
enum GTMAccountCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.accounts.get"),
    field: "gtmAccount",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.account), .path("path"), required: true)
    ],
    result: .single(GTMModels.account),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Account."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.accounts.list"),
    field: "gtmAccounts",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/accounts",
    arguments: [
      ArgumentDefinition("includeGoogleTags", .boolean, .query("includeGoogleTags")),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "account", GTMModels.account),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Accounts that a user has access to."
  )
}
