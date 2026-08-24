import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// The GA4 Admin API v1alpha user-deletion submission.
///
/// It removes the collected data of one visitor from a property rather than a
/// resource from the configuration, so it is destructive without being a
/// `delete`: there is no resource name to remove and no removed name to answer
/// with, only the instant before which that visitor's data is scheduled for
/// deletion. It is registered as an update for that reason, and carries the
/// house confirmation echo all the same — the act cannot be undone, and the
/// property it names is the only thing about it a caller can confirm.
enum GAUserDeletionCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.submitUserDeletion"),
      field: "gaSubmitUserDeletion",
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}:submitUserDeletion",
      arguments: [
        ArgumentDefinition("name", .resourceName(property), .path("name"), required: true),
        ArgumentDefinition(
          "confirmName",
          .resourceName(property),
          .confirm("name"),
          required: true
        ),
        // Google's request carries a union of four identifiers and accepts
        // exactly one of them. Which one is upstream's to enforce: each is
        // optional on its own, and requiring any here would forbid the other
        // three.
        ArgumentDefinition("userId", .string, .bodyJSON("userId")),
        ArgumentDefinition("clientId", .string, .bodyJSON("clientId")),
        ArgumentDefinition("appInstanceId", .string, .bodyJSON("appInstanceId")),
        ArgumentDefinition("userProvidedData", .string, .bodyJSON("userProvidedData"))
      ],
      result: .single(GAAlphaAdminInputs.userDeletionSubmission),
      scopes: .analyticsEdit,
      summary: "Submits a request for user deletion for a property.",
      upstreamRejectionGuidance: "Exactly one of userId, clientId, appInstanceId, or "
        + "userProvidedData identifies the visitor; Google refuses a request that names none or "
        + "more than one. User-provided data must be a single normalized email address or phone "
        + "number."
    )
  ]
}
