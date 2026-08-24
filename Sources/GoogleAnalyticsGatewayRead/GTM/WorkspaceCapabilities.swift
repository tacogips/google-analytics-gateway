import GoogleAnalyticsGatewayCore

/// Tag Manager workspace reads, including the workspace change and conflict
/// status.
enum GTMWorkspaceCapabilities {
  static let all: [CapabilityDefinition] = [get, list, status]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.get"),
    field: "gtmWorkspace",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true)
    ],
    result: .single(GTMModels.workspace),
    scopes: .tagManagerReadonly,
    summary: "Gets a Workspace."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.list"),
    field: "gtmWorkspaces",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/workspaces",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "workspace", GTMModels.workspace),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all Workspaces that belong to a GTM Container."
  )

  static let status = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.getStatus"),
    field: "gtmWorkspaceStatus",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}/status",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true)
    ],
    result: .single(GTMModels.workspaceStatus),
    scopes: .tagManagerReadonly,
    summary: "Finds conflicting and modified entities in the workspace."
  )
}
