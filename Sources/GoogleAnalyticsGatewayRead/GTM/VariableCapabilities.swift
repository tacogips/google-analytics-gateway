import GoogleAnalyticsGatewayCore

/// Tag Manager variable reads, including the enabled built-in variables.
enum GTMVariableCapabilities {
  static let all: [CapabilityDefinition] = [get, list, builtInList]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.variables.get"),
    field: "gtmVariable",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.variable), .path("path"), required: true)
    ],
    result: .single(GTMModels.variable),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Variable."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.variables.list"),
    field: "gtmVariables",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/variables",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "variable", GTMModels.variable),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Variables of a Container."
  )

  static let builtInList = CapabilityDefinition(
    id: CapabilityID("gtm.builtInVariables.list"),
    field: "gtmBuiltInVariables",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/built_in_variables",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "builtInVariable", GTMModels.builtInVariable),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all the enabled Built-In Variables of a GTM Container."
  )
}
