import GoogleAnalyticsGatewayCore

/// The GA4 Admin API v1alpha capabilities the admin tier owns: the deletes for
/// every alpha-only resource, the whole access-binding surface, and the
/// user-deletion submission.
///
/// They are grouped apart from the v1beta admin capabilities because the version
/// is a boundary worth seeing at the call site: Google reserves the right to
/// change an alpha method in a way it never would for a v1beta one.
public enum GAAlphaAdminCapabilities {
  public static let all: [CapabilityDefinition] =
    GAAlphaDeleteCapabilities.all
    + GAAccessBindingCapabilities.all
    + GAUserDeletionCapabilities.all
}
