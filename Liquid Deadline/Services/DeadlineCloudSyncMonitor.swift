import CloudKit
import Foundation

struct DeadlineCloudAccountSnapshot: Hashable {
    var status: CKAccountStatus
    var fingerprint: String?
}

struct DeadlineCloudAccountPrompt: Identifiable, Hashable {
    let id = UUID()
    let fingerprint: String?
}

enum DeadlineCloudSyncMonitor {
    static func fetchCurrentAccountSnapshot() async -> DeadlineCloudAccountSnapshot {
        guard let containerIdentifier = DeadlineStorage.cloudKitContainerIdentifier else {
            return DeadlineCloudAccountSnapshot(status: .couldNotDetermine, fingerprint: nil)
        }

        let container = CKContainer(identifier: containerIdentifier)
        let status = await accountStatus(for: container)
        guard status == .available else {
            return DeadlineCloudAccountSnapshot(status: status, fingerprint: nil)
        }

        let fingerprint = await fetchUserFingerprint(for: container)
        return DeadlineCloudAccountSnapshot(status: status, fingerprint: fingerprint)
    }

    private static func accountStatus(for container: CKContainer) async -> CKAccountStatus {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    private static func fetchUserFingerprint(for container: CKContainer) async -> String? {
        await withCheckedContinuation { continuation in
            container.fetchUserRecordID { recordID, _ in
                continuation.resume(returning: recordID?.recordName)
            }
        }
    }
}
