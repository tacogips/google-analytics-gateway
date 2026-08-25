import Foundation

/// The Google API surfaces this gateway addresses.
///
/// Wrike exposes one API origin, so its transport could resolve a single base
/// URL from the credential. Google splits the same product across independent
/// service hosts, so the origin is a property of the capability rather than of
/// the credential: a definition names its service, and the planner resolves the
/// origin and version prefix from that name alone. No caller-supplied value
/// participates, which is what keeps a capability from being pointed at a host
/// the host policy has not approved.
public enum GoogleAPIService: String, Sendable, Equatable, Hashable, CaseIterable, Comparable {
  /// GA4 Admin API v1beta: accounts, properties, data streams, custom
  /// dimensions and metrics, key events, linked-product links.
  case analyticsAdminV1Beta = "analyticsadmin.v1beta"
  /// GA4 Admin API v1alpha: audiences, access bindings, channel groups, and the
  /// other resources that have not reached v1beta.
  case analyticsAdminV1Alpha = "analyticsadmin.v1alpha"
  /// GA4 Data API v1beta: the report, realtime, metadata, and compatibility
  /// methods, plus audience exports.
  case analyticsDataV1Beta = "analyticsdata.v1beta"
  /// GA4 Data API v1alpha: funnel reports, report tasks, audience lists, and the
  /// property quota snapshot, none of which have reached v1beta.
  case analyticsDataV1Alpha = "analyticsdata.v1alpha"
  /// Tag Manager API v2, including the Google tag configuration and destination
  /// resources that stand in for a standalone gtag API.
  case tagManagerV2 = "tagmanager.v2"

  /// The API host. Every value here must also appear in
  /// `GoogleHostPolicy.approvedAPIHosts`; `GoogleHostPolicy` asserts the two
  /// agree so a new service cannot reach the network without being approved.
  public var host: String {
    switch self {
    case .analyticsAdminV1Beta, .analyticsAdminV1Alpha:
      return "analyticsadmin.googleapis.com"
    case .analyticsDataV1Beta, .analyticsDataV1Alpha:
      return "analyticsdata.googleapis.com"
    case .tagManagerV2:
      return "tagmanager.googleapis.com"
    }
  }

  /// The leading path segments every method of the service shares.
  ///
  /// Capability path templates carry this prefix themselves, because a Google
  /// method path is documented with its version and reads wrongly without it.
  /// Keeping the prefix here as well lets the registry check that a template
  /// and the service it names agree, so a v1alpha-only resource cannot be
  /// registered against the v1beta service and quietly 404.
  public var pathPrefix: String {
    switch self {
    case .analyticsAdminV1Beta, .analyticsDataV1Beta:
      return "/v1beta"
    case .analyticsAdminV1Alpha, .analyticsDataV1Alpha:
      return "/v1alpha"
    case .tagManagerV2:
      return "/tagmanager/v2"
    }
  }

  /// The bare origin a capability request is resolved against. It carries no
  /// path: the version prefix belongs to the capability's path template, so a
  /// request URL is exactly `origin + pathTemplate`.
  public var origin: URL {
    // The host is a compile-time constant from the closed set above, so this
    // string is always a valid absolute URL.
    guard let url = URL(string: "https://\(host)") else {
      preconditionFailure("GoogleAPIService \(rawValue) has an unconstructable origin.")
    }
    return url
  }

  /// The human-readable service name used in schema documentation.
  public var displayName: String {
    switch self {
    case .analyticsAdminV1Beta: return "GA4 Admin API v1beta"
    case .analyticsAdminV1Alpha: return "GA4 Admin API v1alpha"
    case .analyticsDataV1Beta: return "GA4 Data API v1beta"
    case .analyticsDataV1Alpha: return "GA4 Data API v1alpha"
    case .tagManagerV2: return "Tag Manager API v2"
    }
  }

  /// True when a capability path template belongs to this service.
  public func owns(pathTemplate: String) -> Bool {
    pathTemplate == pathPrefix || pathTemplate.hasPrefix("\(pathPrefix)/")
  }

  public static func < (lhs: GoogleAPIService, rhs: GoogleAPIService) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
