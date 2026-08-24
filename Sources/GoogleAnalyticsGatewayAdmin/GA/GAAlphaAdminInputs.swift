import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Request bodies and the two response shapes the v1alpha admin surface owns.
///
/// The access-binding shapes are the discovery schema minus `name` wherever
/// Google marks it `Output only`, which is everywhere except the batch update
/// and batch delete requests: those identify the binding to act on by the `name`
/// carried inside each element, because a batch has no path of its own to name
/// it with.
///
/// Both batch-request elements accept an account-scoped or a property-scoped
/// binding name. Google requires every element's parent to match the `parent`
/// the request is addressed to and refuses the batch otherwise, so the local
/// check is the name's shape and the agreement between the two stays upstream's
/// to enforce — the alternative, a separate input type per parent, would double
/// the published schema to restate a rule the API applies anyway.
enum GAAlphaAdminInputs {
  private static let bindingName = ResourceNamePattern([
    GAAlphaDeleteCapabilities.accountAccessBinding,
    GAAlphaDeleteCapabilities.propertyAccessBinding
  ])

  /// The writable half of an `AccessBinding`. `roles` is the whole grant rather
  /// than an addition to it: Google replaces the list, and an empty list on an
  /// existing binding removes the person's access altogether.
  static let accessBinding = InputObjectShape(
    typeName: "GAAccessBindingInput",
    fields: [
      ArgumentDefinition("user", .string, .bodyJSON("user")),
      ArgumentDefinition("roles", .stringList, .bodyJSON("roles"))
    ]
  )

  /// The same shape with the binding's own name, which a batch update needs to
  /// say which binding each element is about.
  static let identifiedAccessBinding = InputObjectShape(
    typeName: "GAIdentifiedAccessBindingInput",
    fields: [
      ArgumentDefinition("name", .resourceName(bindingName), .bodyJSON("name"), required: true),
      ArgumentDefinition("user", .string, .bodyJSON("user")),
      ArgumentDefinition("roles", .stringList, .bodyJSON("roles"))
    ]
  )

  /// `CreateAccessBindingRequest`. The wrapper exists upstream, so it exists
  /// here: the batch body is `{"requests": [{"accessBinding": {...}}]}`, not a
  /// bare list of bindings. Its `parent` field is deliberately absent — Google
  /// accepts it only when it repeats the parent the request is already
  /// addressed to, so offering it could only ever produce a refused request.
  static let accessBindingCreateRequest = InputObjectShape(
    typeName: "GACreateAccessBindingRequestInput",
    fields: [
      ArgumentDefinition(
        "accessBinding",
        .inputObject(accessBinding),
        .bodyJSON("accessBinding"),
        required: true
      )
    ]
  )

  /// `UpdateAccessBindingRequest`.
  static let accessBindingUpdateRequest = InputObjectShape(
    typeName: "GAUpdateAccessBindingRequestInput",
    fields: [
      ArgumentDefinition(
        "accessBinding",
        .inputObject(identifiedAccessBinding),
        .bodyJSON("accessBinding"),
        required: true
      )
    ]
  )

  /// `DeleteAccessBindingRequest`, which carries only the name to remove.
  static let accessBindingDeleteRequest = InputObjectShape(
    typeName: "GADeleteAccessBindingRequestInput",
    fields: [
      ArgumentDefinition("name", .resourceName(bindingName), .bodyJSON("name"), required: true)
    ]
  )

  /// The most elements Google accepts in one access-binding batch.
  static let maximumBatchSize = 1000

  /// `BatchDeleteAccessBindings` answers `200` with `{}`: there is no removed
  /// resource to describe, because the request removed a set of them and the
  /// parent it was addressed to still exists.
  ///
  /// A GraphQL type still needs a field, so the shape carries the parent the
  /// batch was addressed to. Google does not return it, so it projects as null
  /// and the successful response itself is the confirmation — the same contract
  /// `GAUserDataCollectionAcknowledgement` uses for the other method Google
  /// answers with an empty body.
  static let accessBindingBatchDeletion = ModelShape(
    typeName: "GAAccessBindingBatchDeletion",
    fields: [
      ModelField("parent", .resourceName)
    ]
  )

  /// `SubmitUserDeletionResponse`. The instant is the whole answer: every hit
  /// from the named visitor recorded before it is scheduled for deletion.
  static let userDeletionSubmission = ModelShape(
    typeName: "GAUserDeletionSubmission",
    fields: [
      ModelField("deletionRequestTime", .dateTime)
    ]
  )
}
