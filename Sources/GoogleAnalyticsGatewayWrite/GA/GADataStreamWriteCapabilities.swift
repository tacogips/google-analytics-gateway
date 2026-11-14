import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1beta data stream and Measurement Protocol secret mutations.
enum GADataStreamWriteCapabilities {
  private static let property = "properties/{property}"
  private static let dataStream = "properties/{property}/dataStreams/{dataStream}"
  private static let secret =
    "properties/{property}/dataStreams/{dataStream}/measurementProtocolSecrets/{secret}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.create"),
      field: "gaCreateDataStream",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/dataStreams",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "dataStream",
          .inputObject(GAWriteInputs.dataStreamCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "dataStream", GAModels.dataStream),
      scopes: .analyticsEdit,
      summary: "Creates a DataStream.",
      upstreamRejectionGuidance: "The stream body must match the declared type: a web stream "
        + "needs webStreamData and a display name, an Android stream needs "
        + "androidAppStreamData, and an iOS stream needs iosAppStreamData."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.update"),
      field: "gaUpdateDataStream",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(dataStream), .path("name"), required: true),
        ArgumentDefinition(
          "dataStream",
          .inputObject(GAWriteInputs.dataStreamUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "dataStream", GAModels.dataStream),
      scopes: .analyticsEdit,
      summary: "Updates a DataStream on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.measurementProtocolSecrets.create"),
      field: "gaCreateMeasurementProtocolSecret",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/measurementProtocolSecrets",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition(
          "measurementProtocolSecret",
          .inputObject(GAWriteInputs.measurementProtocolSecret),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(
        field: "measurementProtocolSecret",
        GAModels.measurementProtocolSecret
      ),
      scopes: .analyticsEdit,
      summary: "Creates a measurement protocol secret."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.measurementProtocolSecrets.update"),
      field: "gaUpdateMeasurementProtocolSecret",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(secret), .path("name"), required: true),
        ArgumentDefinition(
          "measurementProtocolSecret",
          .inputObject(GAWriteInputs.measurementProtocolSecret),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(
        field: "measurementProtocolSecret",
        GAModels.measurementProtocolSecret
      ),
      scopes: .analyticsEdit,
      summary: "Updates a measurement protocol secret."
    )
  ]
}
