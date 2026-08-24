import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager writer capabilities (workspace entities, versions, publish, gtag config).
///
/// See design-docs/references/field-catalog.json: every `gtm*` field the
/// catalog places in the writer tier is registered here.
public enum GTMWriteCapabilities {
  public static let all: [CapabilityDefinition] =
    GTMAccountWriteCapabilities.all
    + GTMContainerWriteCapabilities.all
    + GTMWorkspaceWriteCapabilities.all
    + GTMTagWriteCapabilities.all
    + GTMTriggerWriteCapabilities.all
    + GTMVariableWriteCapabilities.all
    + GTMBuiltInVariableWriteCapabilities.all
    + GTMClientWriteCapabilities.all
    + GTMFolderWriteCapabilities.all
    + GTMTemplateWriteCapabilities.all
    + GTMTransformationWriteCapabilities.all
    + GTMZoneWriteCapabilities.all
    + GTMGtagConfigWriteCapabilities.all
    + GTMEnvironmentWriteCapabilities.all
    + GTMVersionWriteCapabilities.all
}
