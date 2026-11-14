import Foundation

/// Explicit pagination input. The client never fetches every page implicitly.
public struct PageInput: Sendable, Equatable {
  public let pageSize: Int?
  public let nextPageToken: String?

  public init(pageSize: Int? = nil, nextPageToken: String? = nil) {
    self.pageSize = pageSize
    self.nextPageToken = nextPageToken
  }

  /// Validates the request against the capability's documented upstream maximum.
  /// Oversized values are rejected rather than silently clamped.
  public func validated(maximumPageSize: Int?, capability: CapabilityID) throws -> PageInput {
    guard let pageSize else { return self }
    guard pageSize > 0 else {
      throw GatewayError.validation("page.pageSize must be greater than zero.")
    }
    guard let maximumPageSize else {
      throw GatewayError.validation(
        "Capability \(capability.rawValue) does not support a page size argument."
      )
    }
    guard pageSize <= maximumPageSize else {
      throw GatewayError.validation(
        "page.pageSize exceeds the maximum of \(maximumPageSize) for \(capability.rawValue)."
      )
    }
    return self
  }
}

/// Stable pagination metadata returned by collection capabilities.
public struct PageInfo: Sendable, Equatable {
  public let resultCount: Int
  public let nextPageToken: String?

  public init(resultCount: Int, nextPageToken: String?) {
    self.resultCount = resultCount
    self.nextPageToken = nextPageToken
  }

  public var stableValue: JSONValue {
    .object([
      "resultCount": .int(resultCount),
      "nextPageToken": nextPageToken.map(JSONValue.string) ?? .null
    ])
  }
}
