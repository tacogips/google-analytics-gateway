import Foundation
import GoogleAnalyticsGatewayAdmin
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite
import Testing

/// `CapabilityCatalog` is a name-only table that links no write or admin code,
/// which is what lets a reader binary answer `CAPABILITY_DENIED` with the
/// required tier instead of "unknown field". Its value depends entirely on
/// agreeing with the modules in both directions: a field missing from the table
/// reports itself as unknown to reader callers, and a field in the table that no
/// module registers promises a capability no binary can serve.
///
/// The comparison is made against the tier aggregators rather than the
/// composed per-binary registries, because each aggregator is exactly the set of
/// definitions its tier contributes.
@Suite("Capability catalog coherence")
struct CapabilityCatalogTests {
  /// A field a lower-tier binary must be told the tier of, rather than told it
  /// does not exist.
  struct DeniedField {
    let field: String
    let isMutation: Bool
    let tier: CapabilityTier
  }

  static func fields(_ definitions: [CapabilityDefinition], mutations: Bool) -> Set<String> {
    Set(definitions.filter { $0.operationClass.isMutation == mutations }.map(\.field))
  }

  /// Names both directions of a disagreement, so a failure says which field is
  /// missing from which side rather than printing two large sets.
  static func difference(registered: Set<String>, catalogued: Set<String>) -> String {
    let missingFromTable = registered.subtracting(catalogued).sorted()
    let missingFromModule = catalogued.subtracting(registered).sorted()
    return "registered but not catalogued: \(missingFromTable); "
      + "catalogued but not registered: \(missingFromModule)"
  }

  /// True while the tier modules are still being authored. The catalog is
  /// populated first, so until the registrations land the two cannot agree and
  /// the coherence assertions would report a failure that is really a
  /// not-yet-written module.
  static var registriesArePending: Bool {
    WriteCapabilities.all.isEmpty && AdminCapabilities.all.isEmpty
  }

  @Test("Every writer mutation the catalog names is registered by the writer module")
  func writerCatalogMatchesWriterModule() throws {
    guard !Self.registriesArePending else {
      #expect(
        CapabilityCatalog.writerMutationFields.isEmpty
          && CapabilityCatalog.adminMutationFields.isEmpty,
        "The writer and admin registries are not populated yet, so the catalog must still be empty"
      )
      return
    }

    let registered = Self.fields(WriteCapabilities.all, mutations: true)
    let catalogued = Set(CapabilityCatalog.writerMutationFields)

    #expect(
      registered == catalogued,
      "\(Self.difference(registered: registered, catalogued: catalogued))"
    )
    #expect(CapabilityCatalog.writerMutationFields.count == catalogued.count, "The table repeats a name")
    #expect(Self.fields(WriteCapabilities.all, mutations: false).isEmpty,
      "The writer module registered a read; reads belong to the reader tier")
  }

  @Test("Every admin mutation the catalog names is registered by the admin module")
  func adminCatalogMatchesAdminModule() throws {
    guard !Self.registriesArePending else { return }

    let registered = Self.fields(AdminCapabilities.all, mutations: true)
    let catalogued = Set(CapabilityCatalog.adminMutationFields)

    #expect(
      registered == catalogued,
      "\(Self.difference(registered: registered, catalogued: catalogued))"
    )
    #expect(CapabilityCatalog.adminMutationFields.count == catalogued.count, "The table repeats a name")
  }

  @Test("The admin query table names exactly the admin module's reads")
  func adminQueryCatalogMatchesAdminModule() throws {
    guard !Self.registriesArePending else { return }

    let registered = Self.fields(AdminCapabilities.all, mutations: false)
    let catalogued = Set(CapabilityCatalog.adminQueryFields)

    #expect(
      registered == catalogued,
      "\(Self.difference(registered: registered, catalogued: catalogued))"
    )
    // An admin-tier read is unusual enough to name: these are HTTP GETs that
    // are administrative all the same, so a reader binary must be told the tier
    // rather than told the field does not exist.
    #expect(registered.allSatisfy { $0.hasPrefix("gtmUserPermission") })
  }

  @Test("No reader field appears in any tier table")
  func readerFieldsAreNotCatalogued() throws {
    guard !Self.registriesArePending else { return }

    let readerFields = Set(ReadCapabilities.all.map(\.field))
    #expect(!readerFields.isEmpty)

    let writerTable = Set(CapabilityCatalog.writerMutationFields)
    let adminTable = Set(CapabilityCatalog.adminMutationFields)
    let adminQueryTable = Set(CapabilityCatalog.adminQueryFields)

    #expect(readerFields.isDisjoint(with: writerTable),
      "\(readerFields.intersection(writerTable).sorted()) are reader fields listed as writer mutations")
    #expect(readerFields.isDisjoint(with: adminTable),
      "\(readerFields.intersection(adminTable).sorted()) are reader fields listed as admin mutations")
    #expect(readerFields.isDisjoint(with: adminQueryTable),
      "\(readerFields.intersection(adminQueryTable).sorted()) are reader fields listed as admin queries")
    #expect(ReadCapabilities.all.allSatisfy { !$0.operationClass.isMutation },
      "The reader module registered a mutation")
  }

  @Test("The writer and admin tables are disjoint")
  func tierTablesAreDisjoint() {
    let writerTable = Set(CapabilityCatalog.writerMutationFields)
    let adminTable = Set(CapabilityCatalog.adminMutationFields)
    #expect(writerTable.isDisjoint(with: adminTable),
      "\(writerTable.intersection(adminTable).sorted()) are claimed by two tiers")
  }

  @Test("knownTier answers the owning tier for a catalogued field")
  func knownTierAnswersOwningTier() throws {
    guard !Self.registriesArePending else { return }

    for field in CapabilityCatalog.writerMutationFields {
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: true) == .writer, "\(field)")
      // The same name is not a query, so asking as one must not answer a tier.
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: false) == nil, "\(field)")
    }
    for field in CapabilityCatalog.adminMutationFields {
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: true) == .admin, "\(field)")
    }
    for field in CapabilityCatalog.adminQueryFields {
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: false) == .admin, "\(field)")
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: true) == nil, "\(field)")
    }
  }

  @Test("knownTier answers nothing for reader fields and for names off the contract")
  func knownTierIsSilentForReaderAndUnknownFields() throws {
    for field in ReadCapabilities.all.map(\.field) {
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: false) == nil, "\(field)")
      #expect(CapabilityCatalog.knownTier(field: field, isMutation: true) == nil, "\(field)")
    }
    for name in ["sampleCreateDataStream", "gaDeleteEverything", "", "__schema"] {
      #expect(CapabilityCatalog.knownTier(field: name, isMutation: true) == nil, "\(name)")
      #expect(CapabilityCatalog.knownTier(field: name, isMutation: false) == nil, "\(name)")
    }
  }

  @Test("A reader registry denies a catalogued mutation with the tier it needs")
  func readerPlannerDeniesCataloguedMutation() throws {
    guard !Self.registriesArePending else { return }
    let planner = CapabilityPlanner(registry: try CapabilityRegistry(
      tier: .reader, definitions: ReadCapabilities.all
    ))

    let cases: [DeniedField] =
      CapabilityCatalog.writerMutationFields.prefix(1)
        .map { DeniedField(field: $0, isMutation: true, tier: .writer) }
      + CapabilityCatalog.adminMutationFields.prefix(1)
        .map { DeniedField(field: $0, isMutation: true, tier: .admin) }
      + CapabilityCatalog.adminQueryFields.prefix(1)
        .map { DeniedField(field: $0, isMutation: false, tier: .admin) }

    for denied in cases {
      do {
        _ = try planner.definition(field: denied.field, isMutation: denied.isMutation)
        Issue.record("Expected \(denied.field) to be denied in a reader binary")
      } catch let error as GatewayError {
        #expect(error.code == .capabilityDenied, "\(denied.field)")
        #expect(error.requiredTier == denied.tier, "\(denied.field)")
        #expect(
          error.recoveryGuidance?.contains(denied.tier == .admin ? "admin" : "writer") == true,
          "\(denied.field)"
        )
      }
    }
  }

  @Test("A writer registry serves writer mutations and still denies admin ones")
  func writerRegistryStopsAtItsOwnTier() throws {
    guard !Self.registriesArePending else { return }
    let planner = CapabilityPlanner(registry: try CapabilityRegistry(
      tier: .writer, definitions: ReadCapabilities.all + WriteCapabilities.all
    ))

    for field in CapabilityCatalog.writerMutationFields {
      #expect(throws: Never.self) { try planner.definition(field: field, isMutation: true) }
    }
    for field in CapabilityCatalog.adminMutationFields.prefix(3) {
      do {
        _ = try planner.definition(field: field, isMutation: true)
        Issue.record("Expected \(field) to be denied in a writer binary")
      } catch let error as GatewayError {
        #expect(error.code == .capabilityDenied)
        #expect(error.requiredTier == .admin)
      }
    }
  }

  @Test("Each tier's composed registry builds and is internally coherent")
  func composedRegistriesAreCoherent() throws {
    guard !Self.registriesArePending else { return }

    let reader = try CapabilityRegistry(tier: .reader, definitions: ReadCapabilities.all)
    let writer = try CapabilityRegistry(
      tier: .writer, definitions: ReadCapabilities.all + WriteCapabilities.all
    )
    let admin = try CapabilityRegistry(
      tier: .admin, definitions: ReadCapabilities.all + WriteCapabilities.all + AdminCapabilities.all
    )

    for registry in [reader, writer, admin] {
      #expect(registry.coherenceProblems().isEmpty, "\(registry.coherenceProblems())")
    }
    #expect(reader.mutationDefinitions.isEmpty, "The reader binary must expose no mutation")
    #expect(writer.definitions.count == reader.definitions.count + WriteCapabilities.all.count)
    #expect(admin.definitions.count == writer.definitions.count + AdminCapabilities.all.count)
  }
}
