import GoogleAnalyticsGatewayCore

/// Tag Manager destination reads.
enum GTMDestinationCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.destinations.get"),
    field: "gtmDestination",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.destination), .path("path"), required: true)
    ],
    result: .single(GTMModels.destination),
    scopes: .tagManagerReadonly,
    summary: "Gets a Destination."
  )

  /// The only Tag Manager list method that documents no `pageToken`, so it is a
  /// plain list rather than a connection: offering a page argument Google does
  /// not read would advertise pagination this route cannot perform.
  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.destinations.list"),
    field: "gtmDestinations",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/destinations",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true)
    ],
    result: .list(collection: "destination", GTMModels.destination),
    scopes: .tagManagerReadonly,
    summary: "Lists all Destinations linked to a GTM Container."
  )
}
