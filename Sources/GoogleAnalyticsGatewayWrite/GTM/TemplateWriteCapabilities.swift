import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager custom template mutations, including the gallery import.
enum GTMTemplateWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert, importFromGallery]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.templates.create"),
    field: "gtmCreateTemplate",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/templates",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("template", .inputObject(GTMWriteInputs.template), .bodyRoot, required: true)
    ],
    result: .payload(field: "template", GTMModels.template),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Custom Template."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.templates.update"),
    field: "gtmUpdateTemplate",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.template), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("template", .inputObject(GTMWriteInputs.template), .bodyRoot, required: true)
    ],
    result: .payload(field: "template", GTMModels.template),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Template."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.templates.revert"),
    field: "gtmRevertTemplate",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.template), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedTemplate),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Template in a GTM Workspace."
  )

  /// The gallery template is named by owner, repository, and SHA rather than by
  /// a resource name, and Google refuses the import unless the caller
  /// acknowledges the permissions the template asks for.
  static let importFromGallery = CapabilityDefinition(
    id: CapabilityID("gtm.templates.importFromGallery"),
    field: "gtmImportFromGallery",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/templates:import_from_gallery",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("galleryOwner", .string, .query("galleryOwner")),
      ArgumentDefinition("galleryRepository", .string, .query("galleryRepository")),
      ArgumentDefinition("gallerySha", .string, .query("gallerySha")),
      ArgumentDefinition("acknowledgePermissions", .boolean, .query("acknowledgePermissions"))
    ],
    result: .payload(field: "template", GTMModels.template),
    scopes: .tagManagerEditContainers,
    summary: "Imports a GTM Custom Template from Gallery.",
    upstreamRejectionGuidance: "The import fails unless acknowledgePermissions is true, which is "
      + "how Google records that the template's requested permissions were reviewed."
  )
}
