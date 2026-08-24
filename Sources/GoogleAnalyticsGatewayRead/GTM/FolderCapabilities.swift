import GoogleAnalyticsGatewayCore

/// Tag Manager folder reads.
enum GTMFolderCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.folders.get"),
    field: "gtmFolder",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.folder), .path("path"), required: true)
    ],
    result: .single(GTMModels.folder),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Folder."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.folders.list"),
    field: "gtmFolders",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/folders",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "folder", GTMModels.folder),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Folders of a Container."
  )
}
