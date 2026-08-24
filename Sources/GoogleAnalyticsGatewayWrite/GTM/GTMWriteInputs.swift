import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Request bodies for the Tag Manager v2 mutations.
///
/// Tag Manager's create and update methods take the resource itself as the
/// request body, so each shape here names every property the v2 discovery
/// document documents for that resource — including the server-assigned ones
/// (`path`, `fingerprint`, `tagManagerUrl`, the `*Id` fields). Google ignores
/// what it owns, and the round trip a caller actually performs is to read an
/// entity, edit one field, and PUT it back: rejecting the keys the read
/// returned would make that the one workflow the gateway cannot express.
///
/// The `Parameter` and `Condition` trees stay `.json`. `Parameter` contains
/// lists and maps of `Parameter` and `Condition` contains `Parameter`, so an
/// `InputObjectShape` could only describe them to some fixed depth and would
/// reject documents the API accepts. Everything else is typed, so a misspelled
/// key is a local validation error rather than an upstream 400.
///
/// Every field binds `.bodyJSON` with its upstream spelling: that is what the
/// request builder reads for the JSON key, and it is what the registry requires
/// of a `.json` value, which may travel in a request body and nowhere else.
public enum GTMWriteInputs {

  // MARK: - Enumerations

  /// `Entity.changeStatus`, used by the bulk update and conflict resolution
  /// bodies.
  public static let changeStatus = ArgumentValueType.enumeration(
    "GtmChangeStatus",
    ["changeStatusUnspecified", "none", "added", "deleted", "updated"]
  )

  /// `Environment.type`. Only `user` environments can be created, but a caller
  /// editing an environment it read back may carry any of the four values.
  public static let environmentType = ArgumentValueType.enumeration(
    "GtmEnvironmentType",
    ["user", "live", "latest", "workspace"]
  )

  // MARK: - Workspace entities

  public static let tagConsentSetting = InputObjectShape(
    typeName: "GtmTagConsentSettingInput",
    fields: [
      ArgumentDefinition("consentStatus", .string, .bodyJSON("consentStatus")),
      ArgumentDefinition("consentType", .json, .bodyJSON("consentType"))
    ]
  )

  public static let setupTag = InputObjectShape(
    typeName: "GtmSetupTagInput",
    fields: [
      ArgumentDefinition("tagName", .string, .bodyJSON("tagName")),
      ArgumentDefinition("stopOnSetupFailure", .boolean, .bodyJSON("stopOnSetupFailure"))
    ]
  )

  public static let teardownTag = InputObjectShape(
    typeName: "GtmTeardownTagInput",
    fields: [
      ArgumentDefinition("tagName", .string, .bodyJSON("tagName")),
      ArgumentDefinition("stopTeardownOnFailure", .boolean, .bodyJSON("stopTeardownOnFailure"))
    ]
  )

  public static let tag = InputObjectShape(
    typeName: "GtmTagInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.tag), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("tagId", .string, .bodyJSON("tagId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("type", .string, .bodyJSON("type")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("paused", .boolean, .bodyJSON("paused")),
      ArgumentDefinition("liveOnly", .boolean, .bodyJSON("liveOnly")),
      ArgumentDefinition("parentFolderId", .string, .bodyJSON("parentFolderId")),
      ArgumentDefinition("tagFiringOption", .string, .bodyJSON("tagFiringOption")),
      ArgumentDefinition("firingTriggerId", .stringList, .bodyJSON("firingTriggerId")),
      ArgumentDefinition("blockingTriggerId", .stringList, .bodyJSON("blockingTriggerId")),
      ArgumentDefinition("scheduleStartMs", .integer, .bodyJSON("scheduleStartMs")),
      ArgumentDefinition("scheduleEndMs", .integer, .bodyJSON("scheduleEndMs")),
      ArgumentDefinition(
        "monitoringMetadataTagNameKey",
        .string,
        .bodyJSON("monitoringMetadataTagNameKey")
      ),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("consentSettings", .inputObject(tagConsentSetting), .bodyJSON("consentSettings")),
      ArgumentDefinition("setupTag", .inputObjectList(setupTag), .bodyJSON("setupTag")),
      ArgumentDefinition("teardownTag", .inputObjectList(teardownTag), .bodyJSON("teardownTag")),
      ArgumentDefinition("parameter", .json, .bodyJSON("parameter")),
      ArgumentDefinition("priority", .json, .bodyJSON("priority")),
      ArgumentDefinition("monitoringMetadata", .json, .bodyJSON("monitoringMetadata"))
    ]
  )

  public static let trigger = InputObjectShape(
    typeName: "GtmTriggerInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.trigger), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("triggerId", .string, .bodyJSON("triggerId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("type", .string, .bodyJSON("type")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("parentFolderId", .string, .bodyJSON("parentFolderId")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      // `Condition` lists, each carrying `Parameter` values.
      ArgumentDefinition("filter", .json, .bodyJSON("filter")),
      ArgumentDefinition("autoEventFilter", .json, .bodyJSON("autoEventFilter")),
      ArgumentDefinition("customEventFilter", .json, .bodyJSON("customEventFilter")),
      // The remaining trigger settings are `Parameter` values.
      ArgumentDefinition("parameter", .json, .bodyJSON("parameter")),
      ArgumentDefinition("checkValidation", .json, .bodyJSON("checkValidation")),
      ArgumentDefinition(
        "continuousTimeMinMilliseconds",
        .json,
        .bodyJSON("continuousTimeMinMilliseconds")
      ),
      ArgumentDefinition("eventName", .json, .bodyJSON("eventName")),
      ArgumentDefinition(
        "horizontalScrollPercentageList",
        .json,
        .bodyJSON("horizontalScrollPercentageList")
      ),
      ArgumentDefinition("interval", .json, .bodyJSON("interval")),
      ArgumentDefinition("intervalSeconds", .json, .bodyJSON("intervalSeconds")),
      ArgumentDefinition("limit", .json, .bodyJSON("limit")),
      ArgumentDefinition("maxTimerLengthSeconds", .json, .bodyJSON("maxTimerLengthSeconds")),
      ArgumentDefinition("selector", .json, .bodyJSON("selector")),
      ArgumentDefinition("totalTimeMinMilliseconds", .json, .bodyJSON("totalTimeMinMilliseconds")),
      ArgumentDefinition("uniqueTriggerId", .json, .bodyJSON("uniqueTriggerId")),
      ArgumentDefinition(
        "verticalScrollPercentageList",
        .json,
        .bodyJSON("verticalScrollPercentageList")
      ),
      ArgumentDefinition("visibilitySelector", .json, .bodyJSON("visibilitySelector")),
      ArgumentDefinition("visiblePercentageMax", .json, .bodyJSON("visiblePercentageMax")),
      ArgumentDefinition("visiblePercentageMin", .json, .bodyJSON("visiblePercentageMin")),
      ArgumentDefinition("waitForTags", .json, .bodyJSON("waitForTags")),
      ArgumentDefinition("waitForTagsTimeout", .json, .bodyJSON("waitForTagsTimeout"))
    ]
  )

  public static let variableFormatValue = InputObjectShape(
    typeName: "GtmVariableFormatValueInput",
    fields: [
      ArgumentDefinition("caseConversionType", .string, .bodyJSON("caseConversionType")),
      ArgumentDefinition("convertToNumber", .string, .bodyJSON("convertToNumber")),
      ArgumentDefinition("convertToBoolean", .boolean, .bodyJSON("convertToBoolean")),
      ArgumentDefinition("convertNullToValue", .json, .bodyJSON("convertNullToValue")),
      ArgumentDefinition("convertUndefinedToValue", .json, .bodyJSON("convertUndefinedToValue")),
      ArgumentDefinition("convertTrueToValue", .json, .bodyJSON("convertTrueToValue")),
      ArgumentDefinition("convertFalseToValue", .json, .bodyJSON("convertFalseToValue"))
    ]
  )

  public static let variable = InputObjectShape(
    typeName: "GtmVariableInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.variable), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("variableId", .string, .bodyJSON("variableId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("type", .string, .bodyJSON("type")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("parentFolderId", .string, .bodyJSON("parentFolderId")),
      ArgumentDefinition("enablingTriggerId", .stringList, .bodyJSON("enablingTriggerId")),
      ArgumentDefinition("disablingTriggerId", .stringList, .bodyJSON("disablingTriggerId")),
      ArgumentDefinition("scheduleStartMs", .integer, .bodyJSON("scheduleStartMs")),
      ArgumentDefinition("scheduleEndMs", .integer, .bodyJSON("scheduleEndMs")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("formatValue", .inputObject(variableFormatValue), .bodyJSON("formatValue")),
      ArgumentDefinition("parameter", .json, .bodyJSON("parameter"))
    ]
  )

  /// Built-in variables are created and reverted by type rather than by body,
  /// so this shape exists only for the entity bodies that carry one.
  public static let builtInVariable = InputObjectShape(
    typeName: "GtmBuiltInVariableInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.builtInVariable), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("type", .string, .bodyJSON("type"))
    ]
  )

  public static let client = InputObjectShape(
    typeName: "GtmClientInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.client), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("clientId", .string, .bodyJSON("clientId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("type", .string, .bodyJSON("type")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("priority", .integer, .bodyJSON("priority")),
      ArgumentDefinition("parentFolderId", .string, .bodyJSON("parentFolderId")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("parameter", .json, .bodyJSON("parameter"))
    ]
  )

  public static let folder = InputObjectShape(
    typeName: "GtmFolderInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.folder), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("folderId", .string, .bodyJSON("folderId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl"))
    ]
  )

  public static let galleryReference = InputObjectShape(
    typeName: "GtmGalleryReferenceInput",
    fields: [
      ArgumentDefinition("host", .string, .bodyJSON("host")),
      ArgumentDefinition("owner", .string, .bodyJSON("owner")),
      ArgumentDefinition("repository", .string, .bodyJSON("repository")),
      ArgumentDefinition("version", .string, .bodyJSON("version")),
      ArgumentDefinition("signature", .string, .bodyJSON("signature")),
      ArgumentDefinition("galleryTemplateId", .string, .bodyJSON("galleryTemplateId")),
      ArgumentDefinition("templateDeveloperId", .string, .bodyJSON("templateDeveloperId")),
      ArgumentDefinition("isModified", .boolean, .bodyJSON("isModified"))
    ]
  )

  /// Google's `CustomTemplate`.
  public static let template = InputObjectShape(
    typeName: "GtmTemplateInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.template), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("templateId", .string, .bodyJSON("templateId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("templateData", .string, .bodyJSON("templateData")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("galleryReference", .inputObject(galleryReference), .bodyJSON("galleryReference"))
    ]
  )

  public static let transformation = InputObjectShape(
    typeName: "GtmTransformationInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.transformation), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("transformationId", .string, .bodyJSON("transformationId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("type", .string, .bodyJSON("type")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("parentFolderId", .string, .bodyJSON("parentFolderId")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("parameter", .json, .bodyJSON("parameter"))
    ]
  )

  public static let zoneTypeRestriction = InputObjectShape(
    typeName: "GtmZoneTypeRestrictionInput",
    fields: [
      ArgumentDefinition("enable", .boolean, .bodyJSON("enable")),
      ArgumentDefinition("whitelistedTypeId", .stringList, .bodyJSON("whitelistedTypeId"))
    ]
  )

  public static let zoneBoundary = InputObjectShape(
    typeName: "GtmZoneBoundaryInput",
    fields: [
      ArgumentDefinition(
        "customEvaluationTriggerId",
        .stringList,
        .bodyJSON("customEvaluationTriggerId")
      ),
      // A `Condition` list, which carries `Parameter` values.
      ArgumentDefinition("condition", .json, .bodyJSON("condition"))
    ]
  )

  public static let zoneChildContainer = InputObjectShape(
    typeName: "GtmZoneChildContainerInput",
    fields: [
      ArgumentDefinition("publicId", .string, .bodyJSON("publicId")),
      ArgumentDefinition("nickname", .string, .bodyJSON("nickname"))
    ]
  )

  public static let zone = InputObjectShape(
    typeName: "GtmZoneInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.zone), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("zoneId", .string, .bodyJSON("zoneId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("boundary", .inputObject(zoneBoundary), .bodyJSON("boundary")),
      ArgumentDefinition("typeRestriction", .inputObject(zoneTypeRestriction), .bodyJSON("typeRestriction")),
      ArgumentDefinition("childContainer", .inputObjectList(zoneChildContainer), .bodyJSON("childContainer"))
    ]
  )

  public static let gtagConfig = InputObjectShape(
    typeName: "GtmGtagConfigInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.gtagConfig), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("gtagConfigId", .string, .bodyJSON("gtagConfigId")),
      ArgumentDefinition("type", .string, .bodyJSON("type")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("parameter", .json, .bodyJSON("parameter"))
    ]
  )

  // MARK: - Workspace, container, account

  public static let workspace = InputObjectShape(
    typeName: "GtmWorkspaceInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl"))
    ]
  )

  public static let containerFeatures = InputObjectShape(
    typeName: "GtmContainerFeaturesInput",
    fields: [
      ArgumentDefinition("supportUserPermissions", .boolean, .bodyJSON("supportUserPermissions")),
      ArgumentDefinition("supportEnvironments", .boolean, .bodyJSON("supportEnvironments")),
      ArgumentDefinition("supportWorkspaces", .boolean, .bodyJSON("supportWorkspaces")),
      ArgumentDefinition("supportGtagConfigs", .boolean, .bodyJSON("supportGtagConfigs")),
      ArgumentDefinition("supportBuiltInVariables", .boolean, .bodyJSON("supportBuiltInVariables")),
      ArgumentDefinition("supportClients", .boolean, .bodyJSON("supportClients")),
      ArgumentDefinition("supportFolders", .boolean, .bodyJSON("supportFolders")),
      ArgumentDefinition("supportTags", .boolean, .bodyJSON("supportTags")),
      ArgumentDefinition("supportTemplates", .boolean, .bodyJSON("supportTemplates")),
      ArgumentDefinition("supportTriggers", .boolean, .bodyJSON("supportTriggers")),
      ArgumentDefinition("supportVariables", .boolean, .bodyJSON("supportVariables")),
      ArgumentDefinition("supportVersions", .boolean, .bodyJSON("supportVersions")),
      ArgumentDefinition("supportZones", .boolean, .bodyJSON("supportZones")),
      ArgumentDefinition("supportTransformations", .boolean, .bodyJSON("supportTransformations"))
    ]
  )

  public static let container = InputObjectShape(
    typeName: "GtmContainerInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.container), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("publicId", .string, .bodyJSON("publicId")),
      ArgumentDefinition("domainName", .stringList, .bodyJSON("domainName")),
      ArgumentDefinition("tagIds", .stringList, .bodyJSON("tagIds")),
      ArgumentDefinition("taggingServerUrls", .stringList, .bodyJSON("taggingServerUrls")),
      ArgumentDefinition("usageContext", .stringList, .bodyJSON("usageContext")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("features", .inputObject(containerFeatures), .bodyJSON("features"))
    ]
  )

  public static let accountFeatures = InputObjectShape(
    typeName: "GtmAccountFeaturesInput",
    fields: [
      ArgumentDefinition("supportUserPermissions", .boolean, .bodyJSON("supportUserPermissions")),
      ArgumentDefinition("supportMultipleContainers", .boolean, .bodyJSON("supportMultipleContainers"))
    ]
  )

  public static let account = InputObjectShape(
    typeName: "GtmAccountInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.account), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("shareData", .boolean, .bodyJSON("shareData")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("features", .inputObject(accountFeatures), .bodyJSON("features"))
    ]
  )

  public static let environment = InputObjectShape(
    typeName: "GtmEnvironmentInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.environment), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("workspaceId", .string, .bodyJSON("workspaceId")),
      ArgumentDefinition("environmentId", .string, .bodyJSON("environmentId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("type", environmentType, .bodyJSON("type")),
      ArgumentDefinition("url", .string, .bodyJSON("url")),
      ArgumentDefinition("enableDebug", .boolean, .bodyJSON("enableDebug")),
      ArgumentDefinition("containerVersionId", .string, .bodyJSON("containerVersionId")),
      ArgumentDefinition("authorizationCode", .string, .bodyJSON("authorizationCode")),
      ArgumentDefinition("authorizationTimestamp", .string, .bodyJSON("authorizationTimestamp")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl"))
    ]
  )

  // MARK: - Container version

  /// A container version carries the full snapshot of every workspace entity,
  /// so it reuses the entity shapes above rather than restating them.
  public static let containerVersion = InputObjectShape(
    typeName: "GtmContainerVersionInput",
    fields: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.containerVersion), .bodyJSON("path")),
      ArgumentDefinition("accountId", .string, .bodyJSON("accountId")),
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("containerVersionId", .string, .bodyJSON("containerVersionId")),
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("deleted", .boolean, .bodyJSON("deleted")),
      ArgumentDefinition("fingerprint", .string, .bodyJSON("fingerprint")),
      ArgumentDefinition("tagManagerUrl", .string, .bodyJSON("tagManagerUrl")),
      ArgumentDefinition("container", .inputObject(container), .bodyJSON("container")),
      ArgumentDefinition("tag", .inputObjectList(tag), .bodyJSON("tag")),
      ArgumentDefinition("trigger", .inputObjectList(trigger), .bodyJSON("trigger")),
      ArgumentDefinition("variable", .inputObjectList(variable), .bodyJSON("variable")),
      ArgumentDefinition("builtInVariable", .inputObjectList(builtInVariable), .bodyJSON("builtInVariable")),
      ArgumentDefinition("folder", .inputObjectList(folder), .bodyJSON("folder")),
      ArgumentDefinition("client", .inputObjectList(client), .bodyJSON("client")),
      ArgumentDefinition("zone", .inputObjectList(zone), .bodyJSON("zone")),
      ArgumentDefinition("customTemplate", .inputObjectList(template), .bodyJSON("customTemplate")),
      ArgumentDefinition("transformation", .inputObjectList(transformation), .bodyJSON("transformation")),
      ArgumentDefinition("gtagConfig", .inputObjectList(gtagConfig), .bodyJSON("gtagConfig"))
    ]
  )

  /// `CreateContainerVersionRequestVersionOptions`.
  public static let versionOptions = InputObjectShape(
    typeName: "GtmVersionOptionsInput",
    fields: [
      ArgumentDefinition("name", .string, .bodyJSON("name")),
      ArgumentDefinition("notes", .string, .bodyJSON("notes"))
    ]
  )

  // MARK: - Workspace change bodies

  /// One changed or conflicting entity: exactly one resource field alongside
  /// the change status.
  public static let entity = InputObjectShape(
    typeName: "GtmEntityInput",
    fields: [
      ArgumentDefinition("changeStatus", changeStatus, .bodyJSON("changeStatus")),
      ArgumentDefinition("tag", .inputObject(tag), .bodyJSON("tag")),
      ArgumentDefinition("trigger", .inputObject(trigger), .bodyJSON("trigger")),
      ArgumentDefinition("variable", .inputObject(variable), .bodyJSON("variable")),
      ArgumentDefinition("builtInVariable", .inputObject(builtInVariable), .bodyJSON("builtInVariable")),
      ArgumentDefinition("folder", .inputObject(folder), .bodyJSON("folder")),
      ArgumentDefinition("client", .inputObject(client), .bodyJSON("client")),
      ArgumentDefinition("zone", .inputObject(zone), .bodyJSON("zone")),
      ArgumentDefinition("customTemplate", .inputObject(template), .bodyJSON("customTemplate")),
      ArgumentDefinition("transformation", .inputObject(transformation), .bodyJSON("transformation")),
      ArgumentDefinition("gtagConfig", .inputObject(gtagConfig), .bodyJSON("gtagConfig"))
    ]
  )

  /// `ProposedChange`, the bulk update request body.
  public static let proposedChange = InputObjectShape(
    typeName: "GtmProposedChangeInput",
    fields: [
      ArgumentDefinition("changes", .inputObjectList(entity), .bodyJSON("changes"))
    ]
  )
}
