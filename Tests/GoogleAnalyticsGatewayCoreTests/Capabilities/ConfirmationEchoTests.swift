import Foundation
import GoogleAnalyticsGatewayAdmin
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite
import Testing

/// Confirm arguments in the real registries are typed `.resourceName`, so the
/// echo arrives as `ValidatedArgument.resourceName`, not `.string`. These plans
/// run against the composed admin registry to pin that the echo comparison
/// accepts the production typing (a regression the sample-capability tests,
/// which type their confirms as `.string`, cannot catch).
@Suite("Confirmation echoes with production typing")
struct ConfirmationEchoTests {
  private static func planner() throws -> CapabilityPlanner {
    let registry = try CapabilityRegistry(
      tier: .admin,
      definitions: ReadCapabilities.all + WriteCapabilities.all + AdminCapabilities.all
    )
    return CapabilityPlanner(registry: registry)
  }

  @Test("A matching resource-name confirmation plans successfully")
  func matchingConfirmationPlans() throws {
    let planner = try Self.planner()
    let definition = try planner.definition(field: "gaDeleteProperty", isMutation: true)
    let plan = try planner.plan(
      CapabilityInvocation(
        capabilityID: definition.id,
        arguments: [
          "name": .string("properties/123"),
          "confirmName": .string("properties/123")
        ]
      )
    )
    #expect(plan.request.path == "/v1beta/properties/123")
    #expect(plan.request.method == .delete)
  }

  @Test("A mismatched confirmation is a validation error, not a missing argument")
  func mismatchedConfirmationRejected() throws {
    let planner = try Self.planner()
    let definition = try planner.definition(field: "gtmDeleteTag", isMutation: true)
    do {
      _ = try planner.plan(
        CapabilityInvocation(
          capabilityID: definition.id,
          arguments: [
            "path": .string("accounts/1/containers/2/workspaces/3/tags/4"),
            "confirmPath": .string("accounts/1/containers/2/workspaces/3/tags/5")
          ]
        )
      )
      Issue.record("A mismatched confirmation must not plan")
    } catch let error as GatewayError {
      #expect(error.code == .validationError)
      #expect(error.message.contains("does not match"))
    }
  }

  @Test("A batch-delete confirmation echoes the parent and plans")
  func batchDeleteConfirmationPlans() throws {
    let planner = try Self.planner()
    let definition = try planner.definition(
      field: "gaBatchDeleteAccountAccessBindings", isMutation: true
    )
    let plan = try planner.plan(
      CapabilityInvocation(
        capabilityID: definition.id,
        arguments: [
          "parent": .string("accounts/1"),
          "confirmParent": .string("accounts/1"),
          "requests": .array([
            .object(["name": .string("accounts/1/accessBindings/2")])
          ])
        ]
      )
    )
    #expect(plan.request.path.hasSuffix(":batchDelete"))
  }
}
