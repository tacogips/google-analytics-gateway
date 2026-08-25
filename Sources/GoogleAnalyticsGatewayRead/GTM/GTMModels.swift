import GoogleAnalyticsGatewayCore

/// Resource-name shapes for the Tag Manager API v2.
///
/// Tag Manager addresses every resource by its `path`, an
/// `accounts/{a}/containers/{c}/...` name rather than a bare id, and the writer
/// and admin registries address the same resources. The patterns live here once
/// so a container path validated by `gtmContainer` and one validated by
/// `gtmUpdateContainer` cannot drift apart.
public enum GTMResourceNames {
  public static let account = "accounts/{account}"
  public static let container = "accounts/{account}/containers/{container}"
  public static let workspace = "accounts/{account}/containers/{container}/workspaces/{workspace}"

  public static let tag = "\(workspace)/tags/{tag}"
  public static let trigger = "\(workspace)/triggers/{trigger}"
  public static let variable = "\(workspace)/variables/{variable}"
  public static let builtInVariable = "\(workspace)/built_in_variables"
  public static let client = "\(workspace)/clients/{client}"
  public static let folder = "\(workspace)/folders/{folder}"
  public static let template = "\(workspace)/templates/{template}"
  public static let transformation = "\(workspace)/transformations/{transformation}"
  public static let zone = "\(workspace)/zones/{zone}"
  public static let gtagConfig = "\(workspace)/gtag_config/{gtagConfig}"

  public static let environment = "\(container)/environments/{environment}"
  public static let containerVersion = "\(container)/versions/{version}"
  public static let destination = "\(container)/destinations/{destination}"
  public static let userPermission = "\(account)/user_permissions/{userPermission}"
}

/// Stable Tag Manager model shapes, shared by the read, write, and admin
/// registries.
///
/// Every shape types each field the v2 discovery document documents for the
/// resource. The exceptions are the structures Google defines recursively — a
/// `Parameter` contains lists and maps of `Parameter`, and a `Condition`
/// contains `Parameter` — which are carried through as open JSON. A fixed
/// `ModelShape` for them could only be built to a finite depth, so it would
/// truncate documents the API legitimately returns.
public enum GTMModels {

  // MARK: - Account

  public static let accountFeatures = ModelShape(
    typeName: "GtmAccountFeatures",
    fields: [
      ModelField("supportUserPermissions", .boolean),
      ModelField("supportMultipleContainers", .boolean)
    ]
  )

  public static let account = ModelShape(
    typeName: "GtmAccount",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("name", .string),
      ModelField("shareData", .boolean),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("features", .object(accountFeatures))
    ]
  )

  // MARK: - Container

  public static let containerFeatures = ModelShape(
    typeName: "GtmContainerFeatures",
    fields: [
      ModelField("supportUserPermissions", .boolean),
      ModelField("supportEnvironments", .boolean),
      ModelField("supportWorkspaces", .boolean),
      ModelField("supportGtagConfigs", .boolean),
      ModelField("supportBuiltInVariables", .boolean),
      ModelField("supportClients", .boolean),
      ModelField("supportFolders", .boolean),
      ModelField("supportTags", .boolean),
      ModelField("supportTemplates", .boolean),
      ModelField("supportTriggers", .boolean),
      ModelField("supportVariables", .boolean),
      ModelField("supportVersions", .boolean),
      ModelField("supportZones", .boolean),
      ModelField("supportTransformations", .boolean)
    ]
  )

  public static let container = ModelShape(
    typeName: "GtmContainer",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("name", .string),
      ModelField("publicId", .string),
      ModelField("domainName", .stringList),
      ModelField("tagIds", .stringList),
      ModelField("taggingServerUrls", .stringList),
      ModelField("usageContext", .stringList),
      ModelField("notes", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("features", .object(containerFeatures))
    ]
  )

  /// `GetContainerSnippetResponse`: the tagging snippet for a container.
  public static let containerSnippet = ModelShape(
    typeName: "GtmContainerSnippet",
    fields: [
      ModelField("snippet", .string),
      ModelField("containerConfig", .string)
    ]
  )

  // MARK: - Workspace

  public static let workspace = ModelShape(
    typeName: "GtmWorkspace",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("name", .string),
      ModelField("description", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string)
    ]
  )

  // MARK: - Workspace entities

  public static let tagConsentSetting = ModelShape(
    typeName: "GtmTagConsentSetting",
    fields: [
      ModelField("consentStatus", .string),
      // A `Parameter`, which is recursive.
      ModelField("consentType", .json)
    ]
  )

  public static let setupTag = ModelShape(
    typeName: "GtmSetupTag",
    fields: [
      ModelField("tagName", .string),
      ModelField("stopOnSetupFailure", .boolean)
    ]
  )

  public static let teardownTag = ModelShape(
    typeName: "GtmTeardownTag",
    fields: [
      ModelField("tagName", .string),
      ModelField("stopTeardownOnFailure", .boolean)
    ]
  )

  public static let tag = ModelShape(
    typeName: "GtmTag",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("tagId", .string),
      ModelField("name", .string),
      ModelField("type", .string),
      ModelField("notes", .string),
      ModelField("paused", .boolean),
      ModelField("liveOnly", .boolean),
      ModelField("parentFolderId", .string),
      ModelField("tagFiringOption", .string),
      ModelField("firingTriggerId", .stringList),
      ModelField("blockingTriggerId", .stringList),
      // int64 fields Google serializes as decimal strings.
      ModelField("scheduleStartMs", .integer),
      ModelField("scheduleEndMs", .integer),
      ModelField("monitoringMetadataTagNameKey", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("consentSettings", .object(tagConsentSetting)),
      ModelField("setupTag", .objectList(setupTag)),
      ModelField("teardownTag", .objectList(teardownTag)),
      // Recursive `Parameter` trees.
      ModelField("parameter", .json),
      ModelField("priority", .json),
      ModelField("monitoringMetadata", .json)
    ]
  )

  public static let trigger = ModelShape(
    typeName: "GtmTrigger",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("triggerId", .string),
      ModelField("name", .string),
      ModelField("type", .string),
      ModelField("notes", .string),
      ModelField("parentFolderId", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      // `Condition` lists: each condition carries a `Parameter` list.
      ModelField("filter", .json),
      ModelField("autoEventFilter", .json),
      ModelField("customEventFilter", .json),
      // The remaining trigger settings are all single `Parameter` values.
      ModelField("parameter", .json),
      ModelField("checkValidation", .json),
      ModelField("continuousTimeMinMilliseconds", .json),
      ModelField("eventName", .json),
      ModelField("horizontalScrollPercentageList", .json),
      ModelField("interval", .json),
      ModelField("intervalSeconds", .json),
      ModelField("limit", .json),
      ModelField("maxTimerLengthSeconds", .json),
      ModelField("selector", .json),
      ModelField("totalTimeMinMilliseconds", .json),
      ModelField("uniqueTriggerId", .json),
      ModelField("verticalScrollPercentageList", .json),
      ModelField("visibilitySelector", .json),
      ModelField("visiblePercentageMax", .json),
      ModelField("visiblePercentageMin", .json),
      ModelField("waitForTags", .json),
      ModelField("waitForTagsTimeout", .json)
    ]
  )

  public static let variableFormatValue = ModelShape(
    typeName: "GtmVariableFormatValue",
    fields: [
      ModelField("caseConversionType", .string),
      ModelField("convertToNumber", .string),
      ModelField("convertToBoolean", .boolean),
      // `Parameter` values.
      ModelField("convertNullToValue", .json),
      ModelField("convertUndefinedToValue", .json),
      ModelField("convertTrueToValue", .json),
      ModelField("convertFalseToValue", .json)
    ]
  )

  public static let variable = ModelShape(
    typeName: "GtmVariable",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("variableId", .string),
      ModelField("name", .string),
      ModelField("type", .string),
      ModelField("notes", .string),
      ModelField("parentFolderId", .string),
      ModelField("enablingTriggerId", .stringList),
      ModelField("disablingTriggerId", .stringList),
      ModelField("scheduleStartMs", .integer),
      ModelField("scheduleEndMs", .integer),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("formatValue", .object(variableFormatValue)),
      ModelField("parameter", .json)
    ]
  )

  public static let builtInVariable = ModelShape(
    typeName: "GtmBuiltInVariable",
    fields: [
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("name", .string),
      ModelField("type", .string)
    ]
  )

  public static let client = ModelShape(
    typeName: "GtmClient",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("clientId", .string),
      ModelField("name", .string),
      ModelField("type", .string),
      ModelField("notes", .string),
      ModelField("priority", .integer),
      ModelField("parentFolderId", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("parameter", .json)
    ]
  )

  public static let folder = ModelShape(
    typeName: "GtmFolder",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("folderId", .string),
      ModelField("name", .string),
      ModelField("notes", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string)
    ]
  )

  public static let galleryReference = ModelShape(
    typeName: "GtmGalleryReference",
    fields: [
      ModelField("host", .string),
      ModelField("owner", .string),
      ModelField("repository", .string),
      ModelField("version", .string),
      ModelField("signature", .string),
      ModelField("galleryTemplateId", .string),
      ModelField("templateDeveloperId", .string),
      ModelField("isModified", .boolean)
    ]
  )

  /// Google's `CustomTemplate`.
  public static let template = ModelShape(
    typeName: "GtmTemplate",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("templateId", .string),
      ModelField("name", .string),
      ModelField("templateData", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("galleryReference", .object(galleryReference))
    ]
  )

  public static let transformation = ModelShape(
    typeName: "GtmTransformation",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("transformationId", .string),
      ModelField("name", .string),
      ModelField("type", .string),
      ModelField("notes", .string),
      ModelField("parentFolderId", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("parameter", .json)
    ]
  )

  public static let zoneTypeRestriction = ModelShape(
    typeName: "GtmZoneTypeRestriction",
    fields: [
      ModelField("enable", .boolean),
      ModelField("whitelistedTypeId", .stringList)
    ]
  )

  public static let zoneBoundary = ModelShape(
    typeName: "GtmZoneBoundary",
    fields: [
      ModelField("customEvaluationTriggerId", .stringList),
      // A `Condition` list, which carries `Parameter` values.
      ModelField("condition", .json)
    ]
  )

  public static let zoneChildContainer = ModelShape(
    typeName: "GtmZoneChildContainer",
    fields: [
      ModelField("publicId", .string),
      ModelField("nickname", .string)
    ]
  )

  public static let zone = ModelShape(
    typeName: "GtmZone",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("zoneId", .string),
      ModelField("name", .string),
      ModelField("notes", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("boundary", .object(zoneBoundary)),
      ModelField("typeRestriction", .object(zoneTypeRestriction)),
      ModelField("childContainer", .objectList(zoneChildContainer))
    ]
  )

  public static let gtagConfig = ModelShape(
    typeName: "GtmGtagConfig",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("gtagConfigId", .string),
      ModelField("type", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("parameter", .json)
    ]
  )

  // MARK: - Container-level resources

  public static let environment = ModelShape(
    typeName: "GtmEnvironment",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("workspaceId", .string),
      ModelField("environmentId", .string),
      ModelField("name", .string),
      ModelField("description", .string),
      ModelField("type", .string),
      ModelField("url", .string),
      ModelField("enableDebug", .boolean),
      ModelField("containerVersionId", .string),
      ModelField("authorizationCode", .string),
      ModelField("authorizationTimestamp", .dateTime),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string)
    ]
  )

  public static let destination = ModelShape(
    typeName: "GtmDestination",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("destinationId", .string),
      ModelField("destinationLinkId", .string),
      ModelField("name", .string),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string)
    ]
  )

  public static let containerVersionHeader = ModelShape(
    typeName: "GtmContainerVersionHeader",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("containerVersionId", .string),
      ModelField("name", .string),
      ModelField("deleted", .boolean),
      // Google documents the entity counts as decimal strings.
      ModelField("numTags", .integer),
      ModelField("numTriggers", .integer),
      ModelField("numVariables", .integer),
      ModelField("numClients", .integer),
      ModelField("numGtagConfigs", .integer),
      ModelField("numTransformations", .integer),
      ModelField("numZones", .integer),
      ModelField("numCustomTemplates", .integer)
    ]
  )

  /// A container version carries the full snapshot of every workspace entity,
  /// so it reuses the same shapes the workspace reads project.
  public static let containerVersion = ModelShape(
    typeName: "GtmContainerVersion",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("containerId", .string),
      ModelField("containerVersionId", .string),
      ModelField("name", .string),
      ModelField("description", .string),
      ModelField("deleted", .boolean),
      ModelField("fingerprint", .string),
      ModelField("tagManagerUrl", .string),
      ModelField("container", .object(container)),
      ModelField("tag", .objectList(tag)),
      ModelField("trigger", .objectList(trigger)),
      ModelField("variable", .objectList(variable)),
      ModelField("builtInVariable", .objectList(builtInVariable)),
      ModelField("folder", .objectList(folder)),
      ModelField("client", .objectList(client)),
      ModelField("zone", .objectList(zone)),
      ModelField("customTemplate", .objectList(template)),
      ModelField("transformation", .objectList(transformation)),
      ModelField("gtagConfig", .objectList(gtagConfig))
    ]
  )

  // MARK: - Workspace status

  /// One changed or conflicting entity. Google returns exactly one of the
  /// resource fields populated, alongside the change status.
  public static let entity = ModelShape(
    typeName: "GtmEntity",
    fields: [
      ModelField("changeStatus", .string),
      ModelField("tag", .object(tag)),
      ModelField("trigger", .object(trigger)),
      ModelField("variable", .object(variable)),
      ModelField("builtInVariable", .object(builtInVariable)),
      ModelField("folder", .object(folder)),
      ModelField("client", .object(client)),
      ModelField("zone", .object(zone)),
      ModelField("customTemplate", .object(template)),
      ModelField("transformation", .object(transformation)),
      ModelField("gtagConfig", .object(gtagConfig))
    ]
  )

  public static let mergeConflict = ModelShape(
    typeName: "GtmMergeConflict",
    fields: [
      ModelField("entityInBaseVersion", .object(entity)),
      ModelField("entityInWorkspace", .object(entity))
    ]
  )

  /// `GetWorkspaceStatusResponse`.
  public static let workspaceStatus = ModelShape(
    typeName: "GtmWorkspaceStatus",
    fields: [
      ModelField("workspaceChange", .objectList(entity)),
      ModelField("mergeConflict", .objectList(mergeConflict))
    ]
  )

  /// `SyncStatus`, reported by the workspace sync and resolve mutations.
  public static let syncStatus = ModelShape(
    typeName: "GtmSyncStatus",
    fields: [
      ModelField("mergeConflict", .boolean),
      ModelField("syncError", .boolean)
    ]
  )

  // MARK: - User permissions

  public static let accountAccess = ModelShape(
    typeName: "GtmAccountAccess",
    fields: [
      ModelField("permission", .string)
    ]
  )

  public static let containerAccess = ModelShape(
    typeName: "GtmContainerAccess",
    fields: [
      ModelField("containerId", .string),
      ModelField("permission", .string)
    ]
  )

  public static let userPermission = ModelShape(
    typeName: "GtmUserPermission",
    fields: [
      // Optional rather than required: entities embedded in a ContainerVersion
      // (and workspace-status entities) are returned without their API path.
      ModelField("path", .resourceName),
      ModelField("accountId", .string),
      ModelField("emailAddress", .string),
      ModelField("accountAccess", .object(accountAccess)),
      ModelField("containerAccess", .objectList(containerAccess))
    ]
  )
}
