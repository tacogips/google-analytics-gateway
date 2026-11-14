import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1beta account-scoped reads.
enum GAAccountCapabilities {
  private static let account = "accounts/{account}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.accounts.get"),
      field: "gaAccount",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(account), .path("name"), required: true)
      ],
      result: .single(GAModels.account),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single Account."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.accounts.list"),
      field: "gaAccounts",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/accounts",
      arguments: [
        ArgumentDefinition("showDeleted", .boolean, .query("showDeleted")),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "accounts", GAModels.account),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Returns all accounts accessible by the caller."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.accountSummaries.list"),
      field: "gaAccountSummaries",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/accountSummaries",
      arguments: [
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "accountSummaries", GAModels.accountSummary),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Returns summaries of all accounts accessible by the caller."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.accounts.getDataSharingSettings"),
      field: "gaDataSharingSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("accounts/{account}/dataSharingSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.dataSharingSettings),
      scopes: .analyticsReadonly,
      summary: "Get data sharing settings on an account."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.accounts.runAccessReport"),
      field: "gaRunAccountAccessReport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{entity}:runAccessReport",
      arguments: [
        ArgumentDefinition("entity", .resourceName(account), .path("entity"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.accessReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.accessReport),
      scopes: .analyticsReadonly,
      summary: "Returns a customized report of data access records to the account.",
      upstreamRejectionGuidance: "Access reports are retained for a limited window and are "
        + "available only to account administrators; confirm the date range is within "
        + "retention and that the credential administers this account."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.accounts.searchChangeHistoryEvents"),
      field: "gaSearchChangeHistoryEvents",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{account}:searchChangeHistoryEvents",
      arguments: [
        ArgumentDefinition("account", .resourceName(account), .path("account"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.changeHistorySearchRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.changeHistorySearchResult),
      // The only reader field whose scope is not `analyticsReadonly`: Google
      // documents `analytics.edit` as the sole sufficient scope for reading
      // change history. Declaring it means a readonly credential fails the
      // local scope check with the remedy attached, rather than reaching Google
      // and coming back as a bare 403.
      scopes: .analyticsEdit,
      summary: "Searches through all changes to an account or its children given the "
        + "specified set of filters.",
      upstreamRejectionGuidance: "Change history is retained for a limited window; a range "
        + "older than the retention period returns no events rather than an error."
    )
  ]
}
