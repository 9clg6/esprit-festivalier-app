import EFDomain
import Foundation

/// No sync until `/v1/me/sync` exists (STORY-023): nothing leaves the device.
public struct NoopSyncService: SyncService {
    public init() {}

    public var lastSyncedAt: Date? { nil }

    public func sync() async throws -> SyncStatus { .unavailable }
}
