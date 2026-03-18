import CloudKit
import Foundation

struct DeadlineCloudZoneProbeSnapshot: Hashable, Identifiable {
    var id: String { zoneIDDescription }

    let zoneName: String
    let ownerName: String
    let zoneIDDescription: String
    let currentRecordCount: Int
    let deletedRecordCount: Int
    let recordTypeCounts: [String: Int]
    let errorMessage: String?
}

struct DeadlineCloudProbeSnapshot: Hashable {
    let checkedAt: Date
    let containerIdentifier: String?
    let accountStatus: CKAccountStatus
    let customZoneNames: [String]
    let zoneSummaries: [DeadlineCloudZoneProbeSnapshot]
    let databaseErrorMessage: String?
}

struct DeadlineCloudWriteProbeSnapshot: Hashable {
    let checkedAt: Date
    let containerIdentifier: String?
    let accountStatus: CKAccountStatus
    let probeZoneName: String?
    let createSucceeded: Bool
    let deleteSucceeded: Bool
    let createErrorMessage: String?
    let deleteErrorMessage: String?
}

enum DeadlineCloudRecordProbe {
    static func fetchPrivateDatabaseSnapshot(containerIdentifier: String?) async -> DeadlineCloudProbeSnapshot {
        guard let containerIdentifier else {
            return DeadlineCloudProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: nil,
                accountStatus: .couldNotDetermine,
                customZoneNames: [],
                zoneSummaries: [],
                databaseErrorMessage: "Missing CloudKit container identifier."
            )
        }

        let container = CKContainer(identifier: containerIdentifier)
        let accountStatus = await accountStatus(for: container)
        guard accountStatus == .available else {
            return DeadlineCloudProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                customZoneNames: [],
                zoneSummaries: [],
                databaseErrorMessage: nil
            )
        }

        let database = container.privateCloudDatabase

        do {
            let zones = try await database.allRecordZones()
            let sortedZones = zones.sorted { lhs, rhs in
                if lhs.zoneID.zoneName == rhs.zoneID.zoneName {
                    return lhs.zoneID.ownerName < rhs.zoneID.ownerName
                }
                return lhs.zoneID.zoneName < rhs.zoneID.zoneName
            }

            var summaries: [DeadlineCloudZoneProbeSnapshot] = []
            for zone in sortedZones {
                let summary = await fetchZoneSummary(database: database, zoneID: zone.zoneID)
                summaries.append(summary)
            }

            return DeadlineCloudProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                customZoneNames: sortedZones.map(\.zoneID.zoneName),
                zoneSummaries: summaries,
                databaseErrorMessage: nil
            )
        } catch {
            return DeadlineCloudProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                customZoneNames: [],
                zoneSummaries: [],
                databaseErrorMessage: describe(error)
            )
        }
    }

    static func runPrivateDatabaseWriteProbe(containerIdentifier: String?) async -> DeadlineCloudWriteProbeSnapshot {
        guard let containerIdentifier else {
            return DeadlineCloudWriteProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: nil,
                accountStatus: .couldNotDetermine,
                probeZoneName: nil,
                createSucceeded: false,
                deleteSucceeded: false,
                createErrorMessage: "Missing CloudKit container identifier.",
                deleteErrorMessage: nil
            )
        }

        let container = CKContainer(identifier: containerIdentifier)
        let accountStatus = await accountStatus(for: container)
        guard accountStatus == .available else {
            return DeadlineCloudWriteProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                probeZoneName: nil,
                createSucceeded: false,
                deleteSucceeded: false,
                createErrorMessage: nil,
                deleteErrorMessage: nil
            )
        }

        let database = container.privateCloudDatabase
        let zoneName = "deadline-diagnostic-\(UUID().uuidString.lowercased())"
        let zone = CKRecordZone(zoneName: zoneName)

        do {
            _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        } catch {
            return DeadlineCloudWriteProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                probeZoneName: zoneName,
                createSucceeded: false,
                deleteSucceeded: false,
                createErrorMessage: describe(error),
                deleteErrorMessage: nil
            )
        }

        do {
            _ = try await database.modifyRecordZones(saving: [], deleting: [zone.zoneID])
            return DeadlineCloudWriteProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                probeZoneName: zoneName,
                createSucceeded: true,
                deleteSucceeded: true,
                createErrorMessage: nil,
                deleteErrorMessage: nil
            )
        } catch {
            return DeadlineCloudWriteProbeSnapshot(
                checkedAt: .now,
                containerIdentifier: containerIdentifier,
                accountStatus: accountStatus,
                probeZoneName: zoneName,
                createSucceeded: true,
                deleteSucceeded: false,
                createErrorMessage: nil,
                deleteErrorMessage: describe(error)
            )
        }
    }

    private static func fetchZoneSummary(
        database: CKDatabase,
        zoneID: CKRecordZone.ID
    ) async -> DeadlineCloudZoneProbeSnapshot {
        var changeToken: CKServerChangeToken?
        var recordTypeCounts: [String: Int] = [:]
        var currentRecordCount = 0
        var deletedRecordCount = 0

        do {
            while true {
                let response = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken,
                    desiredKeys: [],
                    resultsLimit: 200
                )

                for result in response.modificationResultsByID.values {
                    guard case .success(let modification) = result else { continue }
                    let recordType = modification.record.recordType
                    recordTypeCounts[recordType, default: 0] += 1
                    currentRecordCount += 1
                }

                deletedRecordCount += response.deletions.count
                changeToken = response.changeToken

                if response.moreComing == false {
                    break
                }
            }

            return DeadlineCloudZoneProbeSnapshot(
                zoneName: zoneID.zoneName,
                ownerName: zoneID.ownerName,
                zoneIDDescription: "\(zoneID.zoneName) @ \(zoneID.ownerName)",
                currentRecordCount: currentRecordCount,
                deletedRecordCount: deletedRecordCount,
                recordTypeCounts: recordTypeCounts,
                errorMessage: nil
            )
        } catch {
            return DeadlineCloudZoneProbeSnapshot(
                zoneName: zoneID.zoneName,
                ownerName: zoneID.ownerName,
                zoneIDDescription: "\(zoneID.zoneName) @ \(zoneID.ownerName)",
                currentRecordCount: currentRecordCount,
                deletedRecordCount: deletedRecordCount,
                recordTypeCounts: recordTypeCounts,
                errorMessage: describe(error)
            )
        }
    }

    private static func accountStatus(for container: CKContainer) async -> CKAccountStatus {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
        let recoverySuggestion = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
        let underlyingError = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription
        let partialErrorsDescription = describePartialErrors(from: nsError)

        return [
            describeNSError(nsError),
            failureReason,
            recoverySuggestion,
            underlyingError,
            partialErrorsDescription
        ]
        .compactMap { value in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }
        .joined(separator: "\n")
    }

    private static func describeNSError(_ error: NSError) -> String {
        if error.domain == CKErrorDomain {
            let codeName = describeCloudKitCode(error.code)
            if codeName.isEmpty == false {
                return "\(error.localizedDescription) [\(codeName)]"
            }
        }

        return error.localizedDescription
    }

    private static func describePartialErrors(from error: NSError) -> String? {
        guard
            error.domain == CKErrorDomain,
            let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError],
            partialErrors.isEmpty == false
        else {
            return nil
        }

        let lines = partialErrors.map { key, value in
            let item = String(describing: key)
            return "\(item): \(describe(value))"
        }
        .sorted()

        return lines.isEmpty ? nil : "Partial errors:\n" + lines.joined(separator: "\n")
    }

    private static func describeCloudKitCode(_ rawValue: Int) -> String {
        switch CKError.Code(rawValue: rawValue) {
        case .internalError:
            return "CKError.internalError"
        case .partialFailure:
            return "CKError.partialFailure"
        case .networkUnavailable:
            return "CKError.networkUnavailable"
        case .networkFailure:
            return "CKError.networkFailure"
        case .badContainer:
            return "CKError.badContainer"
        case .serviceUnavailable:
            return "CKError.serviceUnavailable"
        case .requestRateLimited:
            return "CKError.requestRateLimited"
        case .missingEntitlement:
            return "CKError.missingEntitlement"
        case .notAuthenticated:
            return "CKError.notAuthenticated"
        case .permissionFailure:
            return "CKError.permissionFailure"
        case .unknownItem:
            return "CKError.unknownItem"
        case .invalidArguments:
            return "CKError.invalidArguments"
        case .serverRecordChanged:
            return "CKError.serverRecordChanged"
        case .serverRejectedRequest:
            return "CKError.serverRejectedRequest"
        case .constraintViolation:
            return "CKError.constraintViolation"
        case .changeTokenExpired:
            return "CKError.changeTokenExpired"
        case .zoneBusy:
            return "CKError.zoneBusy"
        case .badDatabase:
            return "CKError.badDatabase"
        case .quotaExceeded:
            return "CKError.quotaExceeded"
        case .zoneNotFound:
            return "CKError.zoneNotFound"
        case .limitExceeded:
            return "CKError.limitExceeded"
        case .userDeletedZone:
            return "CKError.userDeletedZone"
        case .managedAccountRestricted:
            return "CKError.managedAccountRestricted"
        case .serverResponseLost:
            return "CKError.serverResponseLost"
        case .accountTemporarilyUnavailable:
            return "CKError.accountTemporarilyUnavailable"
        case .some(let code):
            return "CKError(\(code.rawValue))"
        case .none:
            return ""
        }
    }
}
