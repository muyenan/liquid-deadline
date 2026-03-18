# iCloud Sync Migration Plan

## Goals
- Keep legacy local data readable, even if early payloads omitted `id`.
- Prevent legacy expanded recurring items from being uploaded to CloudKit as 180 independent records.
- Move to a sync-safe model built on `Core Data + NSPersistentCloudKitContainer`.

## Current Legacy Risks
- `DeadlineItem` payloads may exist without `id`. These must be assigned a fresh `UUID` during decode and then re-saved locally.
- Recurring items are currently materialized as many future instances. In the current store, a daily recurring item can expand into 180 local rows.
- Subscription feeds already store per-event items locally. These items should stay local-only in the sync migration; only subscription definitions should sync.

## Target Sync Model
- `TaskItem`
  - One-time manual/file-import task.
- `RecurringSeries`
  - The seed task and repeat rule.
- `RecurringOccurrenceOverride`
  - Sparse overrides for one generated occurrence: completion, deletion, or field edits.
- `TaskGroup`
  - Tag list entry.
- `TaskSubscription`
  - Subscription URL plus tag/category assignment.

## Migration Rules
1. Read legacy items from `UserDefaults`.
2. Assign missing `UUID`s and repair duplicate IDs before any sync import.
3. Import non-recurring manual/file-import items 1:1 into the new sync store.
4. Ignore subscription-generated items for cloud import. Only migrate subscription definitions.
5. Collapse recurring legacy items by `repeatSeriesID`.
6. For each recurring group, require exactly one seed item:
   - `repeatRule != nil`
   - `repeatOccurrenceIndex == 0`
7. Reconstruct expected generated occurrences from the seed rule.
8. Store only:
   - the seed as `RecurringSeries`
   - sparse occurrence overrides when a generated occurrence differs from the expected default
   - deleted/missing generated occurrences as deletion overrides
9. If a recurring group is inconsistent, do not auto-upload it. Keep it local and surface it in a migration report.

## Smart Deduplication
- Run only when sync is enabled for the first time, re-enabled, or after an account switch merge.
- First match by record `UUID`.
- If there is no `UUID` match, allow deduplication only when all normalized fields are identical:
  - title
  - detail
  - category
  - startDate
  - endDate
  - completedAt
  - isAllDay
  - repeat rule fields when applicable
- If any key field differs, keep both records.

## Account Switch Behavior
- Pause automatic sync when the iCloud account fingerprint changes.
- Present:
  - Merge local data with cloud data
  - Delete local syncable data and resync
  - Turn off automatic sync
- The merge path uses the same UUID-first, strict-content-second logic as first-time sync.

## Implementation Order
1. Legacy decode compatibility
2. Recurring-series migration report
3. New Core Data schema
4. Local migration from `UserDefaults` into Core Data
5. CloudKit mirroring enablement
6. Conflict UI and account-switch flow
