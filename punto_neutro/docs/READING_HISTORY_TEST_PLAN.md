# Reading History - Test Plan (Milestone D.5)

## Overview

This document provides QA test scenarios for the Reading History feature.

**Feature Scope:**
- **Default behavior:** 100% local-only (privacy-first)
- **Optional:** Server sync for analytics (opt-in)
- **Focus:** Offline-repeat reading tracking + batch upload testing

---

## Test Environment Setup

### Prerequisites
- Flutter app with Reading History feature enabled
- Device/emulator with SQLite support
- (Optional) Supabase project with `news_read_history` table
- (Optional) Multiple test articles with different categories

### Test Data Requirements
- At least 5-10 different news articles
- Articles from different categories (Politics, Sports, Tech, etc.)
- Known news_item_ids for verification

---

## Test Scenario 1: Local-Only Basic Functionality

**Objective:** Verify reading history works 100% offline (default mode)

### Setup
- Sync disabled (default)
- Device in airplane mode

### Test Steps

1. **Start Reading Session**
   ```dart
   final repo = LocalReadingHistoryRepository();
   final readId = await repo.startReadingSession(
     newsItemId: 123,
     categoryId: 1,
   );
   ```
   - **Expected:** Returns read_id (local autoincrement)
   - **Verify:** Entry created in local SQLite with `started_at`, no `ended_at`

2. **End Reading Session**
   ```dart
   await repo.endReadingSession(readId, DateTime.now());
   ```
   - **Expected:** Entry updated with `ended_at` and `duration_seconds`
   - **Verify:** Duration calculated correctly (ended_at - started_at)

3. **Query Reading History**
   ```dart
   final history = await repo.getAllHistory(limit: 10);
   ```
   - **Expected:** Returns list ordered by `created_at DESC`
   - **Verify:** Most recent read is first

4. **Get Statistics**
   ```dart
   final stats = await repo.getStatistics();
   print(stats); // {total_entries: X, total_reading_time_seconds: Y, ...}
   ```
   - **Expected:** Correct totals for reading time and article count
   - **Verify:** `unsynced_entries: 0` (local-only mode)

### Acceptance Criteria
- ✅ All operations work offline
- ✅ No network calls made
- ✅ Data persists after app restart
- ✅ Duration calculated correctly
- ✅ Query ordering correct

---

## Test Scenario 2: Offline-Repeat Reading

**Objective:** Verify multiple reads of same article are tracked separately

### Setup
- Sync disabled (default)
- Offline mode

### Test Steps

1. **Read Article A (1st time)**
   - Start session → wait 10 seconds → end session
   - **Expected:** Entry #1 created with duration ~10s

2. **Read Article A (2nd time, same day)**
   - Start session → wait 15 seconds → end session
   - **Expected:** Entry #2 created with duration ~15s

3. **Read Article A (3rd time, next day)**
   - Start session → wait 5 seconds → end session
   - **Expected:** Entry #3 created with duration ~5s

4. **Query History for Article A**
   ```dart
   final history = await repo.getHistoryForNewsItem(newsItemId: articleA_id);
   ```
   - **Expected:** 3 entries returned, ordered by created_at DESC
   - **Verify:** Each has different timestamps and durations

5. **Get Total Reading Time for Article A**
   ```dart
   // Manual calculation from query result
   final totalTime = history.fold(0, (sum, h) => sum + (h.durationSeconds ?? 0));
   ```
   - **Expected:** ~30 seconds (10 + 15 + 5)

### Acceptance Criteria
- ✅ Multiple reads of same article tracked separately
- ✅ No deduplication (each read is unique)
- ✅ Timestamps and durations unique per read
- ✅ Total time aggregation correct

---

## Test Scenario 3: History View Operations

**Objective:** Verify delete and clear operations work correctly

### Setup
- Create 10 history entries with different timestamps
- Mix of recent (today) and old (30 days ago)

### Test Steps

1. **Delete Single Entry**
   ```dart
   await repo.deleteHistoryEntry(readId: entry_id);
   final history = await repo.getAllHistory();
   ```
   - **Expected:** Entry removed from local DB
   - **Verify:** Other entries unaffected

2. **Delete Old Entries (>30 days)**
   ```dart
   final deletedCount = await repo.deleteOldHistory(30);
   print('Deleted $deletedCount old entries');
   ```
   - **Expected:** Only entries >30 days old removed
   - **Verify:** Recent entries still present

3. **Clear All History**
   ```dart
   await repo.clearAllHistory();
   final history = await repo.getAllHistory();
   ```
   - **Expected:** Empty list returned
   - **Verify:** All entries removed from SQLite

4. **Verify Stats After Clear**
   ```dart
   final stats = await repo.getStatistics();
   ```
   - **Expected:** All counters = 0

### Acceptance Criteria
- ✅ Single delete works correctly
- ✅ Bulk delete by age works correctly
- ✅ Clear all removes everything
- ✅ No orphaned data in SQLite

---

## Test Scenario 4: Optional Server Sync (Batch Upload)

**Objective:** Verify batch upload to server when sync is enabled

### Setup
- Enable sync: `syncEnabled: true`
- Create HybridReadingHistoryRepository with Supabase backend
- Online mode (WiFi connected)
- Pre-create 5 local history entries (unsynced)

### Test Steps

1. **Check Unsynced Count**
   ```dart
   final hybridRepo = HybridReadingHistoryRepository(syncEnabled: true);
   final unsyncedCount = await hybridRepo.getUnsyncedCount();
   print('Unsynced entries: $unsyncedCount');
   ```
   - **Expected:** 5 unsynced entries

2. **Manual Sync Trigger**
   ```dart
   final syncedCount = await hybridRepo.syncToServer();
   print('Synced $syncedCount entries to server');
   ```
   - **Expected:** Returns 5
   - **Verify:** Entries marked as `is_synced=1` in local DB

3. **Verify Server Data**
   - Query Supabase `news_read_history` table
   - **Expected:** 5 new rows with matching `news_item_id`, `started_at`, `duration_seconds`
   - **Verify:** `user_profile_id` matches authenticated user

4. **Check Unsynced Count After Sync**
   ```dart
   final unsyncedCount = await hybridRepo.getUnsyncedCount();
   ```
   - **Expected:** 0 (all synced)

5. **Idempotency Test: Re-run Sync**
   ```dart
   final syncedCount = await hybridRepo.syncToServer();
   ```
   - **Expected:** Returns 0 (nothing to sync)
   - **Verify:** No duplicate rows in server DB

### Acceptance Criteria
- ✅ Batch upload sends all unsynced entries
- ✅ Server rows match local data
- ✅ Local entries marked as synced
- ✅ Idempotent (no duplicates on re-sync)
- ✅ RLS enforced (can only upload own history)

---

## Test Scenario 5: Sync Failure Handling

**Objective:** Verify graceful handling of sync failures

### Setup
- Enable sync: `syncEnabled: true`
- Create 3 unsynced entries

### Test Steps

1. **Sync While Offline**
   - Turn on airplane mode
   - Trigger sync: `await hybridRepo.syncToServer()`
   - **Expected:** Returns 0 (no sync, no crash)
   - **Verify:** Entries remain unsynced (`is_synced=0`)
   - **Verify:** `last_sync_attempt` updated

2. **Sync With Server Error (Invalid Token)**
   - Invalidate Supabase token (logout/delete token)
   - Trigger sync: `await hybridRepo.syncToServer()`
   - **Expected:** Returns 0 (error caught)
   - **Verify:** Entries remain unsynced
   - **Verify:** Error logged but app doesn't crash

3. **Sync After Reconnect**
   - Restore connectivity + valid token
   - Trigger sync: `await hybridRepo.syncToServer()`
   - **Expected:** Returns 3 (all entries synced)
   - **Verify:** Server receives data

### Acceptance Criteria
- ✅ No crash on network error
- ✅ Entries remain unsynced on failure
- ✅ Retry mechanism works after reconnect
- ✅ Last sync attempt timestamp recorded

---

## Test Scenario 6: Background Worker (Periodic Sync)

**Objective:** Verify WorkManager periodic sync (if enabled)

### Setup
- Enable sync in settings
- Register periodic worker: `ReadingHistorySyncWorker.registerPeriodicSync(syncEnabled: true)`

### Test Steps

1. **Verify Worker Registered**
   - Check WorkManager queue
   - **Expected:** Task named `reading_history_sync_worker` present
   - **Verify:** Frequency = 24 hours

2. **Manual Trigger (Simulate Periodic Run)**
   ```dart
   await ReadingHistorySyncWorker.syncNow();
   ```
   - Wait for worker to execute (check logs)
   - **Expected:** Worker syncs unsynced entries
   - **Verify:** Logs show "Synced X entries"

3. **Verify Cleanup (Old Entries)**
   - Worker should also delete entries >90 days old
   - **Expected:** Logs show "Cleaned up X old entries"
   - **Verify:** Local DB has fewer rows after cleanup

4. **Disable Sync (Cancel Worker)**
   ```dart
   await ReadingHistorySyncWorker.cancelSync();
   ```
   - **Expected:** Worker removed from WorkManager queue
   - **Verify:** No more periodic syncs happen

### Acceptance Criteria
- ✅ Worker runs on schedule (24h)
- ✅ Worker respects network constraints (WiFi preferred)
- ✅ Worker respects battery constraints (not low battery)
- ✅ Worker can be cancelled when sync disabled
- ✅ Cleanup of old entries works

---

## Test Scenario 7: Privacy & GDPR Compliance

**Objective:** Verify user can delete history from both local and server

### Setup
- Sync enabled
- Create 5 synced entries (present in both local + server)

### Test Steps

1. **Delete Single Entry (Synced)**
   ```dart
   await hybridRepo.deleteHistoryEntry(readId: synced_entry_id);
   ```
   - **Expected:** Entry removed from local DB
   - **Expected:** Entry removed from server DB (if sync enabled)
   - **Verify:** Server row deleted via RLS

2. **Clear All History**
   ```dart
   await hybridRepo.clearAllHistory();
   ```
   - **Expected:** All local entries deleted
   - **Expected:** All server entries deleted (if sync enabled)
   - **Verify:** Server table empty for this user

3. **Delete Old History**
   ```dart
   await hybridRepo.deleteOldHistory(30);
   ```
   - **Expected:** Old entries removed from both local and server
   - **Verify:** Recent entries remain

### Acceptance Criteria
- ✅ Delete operations propagate to server (if sync enabled)
- ✅ RLS prevents deleting other users' history
- ✅ User can fully erase their history (GDPR right to deletion)
- ✅ Local delete always succeeds (even if server fails)

---

## Test Scenario 8: Statistics Accuracy

**Objective:** Verify reading statistics calculations are correct

### Setup
- Create controlled test data:
  - Article A: 3 reads (10s, 15s, 20s) = 45s total
  - Article B: 2 reads (5s, 10s) = 15s total
  - Total: 5 reads, 2 unique articles, 60s total

### Test Steps

1. **Get Total Reading Time**
   ```dart
   final totalTime = await repo.getTotalReadingTime();
   ```
   - **Expected:** 60 seconds

2. **Get Unique Articles Count**
   ```dart
   final articlesCount = await repo.getArticlesReadCount();
   ```
   - **Expected:** 2 (A and B)

3. **Get Time Since Yesterday**
   ```dart
   final yesterday = DateTime.now().subtract(Duration(days: 1));
   final recentTime = await repo.getTotalReadingTime(since: yesterday);
   ```
   - **Expected:** Only includes reads from last 24h

4. **Get Full Statistics**
   ```dart
   final stats = await repo.getStatistics();
   print(stats);
   ```
   - **Expected:**
     ```json
     {
       "total_entries": 5,
       "total_reading_time_seconds": 60,
       "unique_articles_read": 2,
       "unsynced_entries": 5 (if sync disabled) or 0 (if synced)
     }
     ```

### Acceptance Criteria
- ✅ Total reading time calculated correctly
- ✅ Unique articles counted correctly (no duplicates)
- ✅ Date range filters work correctly
- ✅ Statistics survive app restart

---

## Helper Functions for Testing

### Debug: Print Reading History
```dart
Future<void> debugPrintHistory(ReadingHistoryRepository repo) async {
  final history = await repo.getAllHistory(limit: 50);
  print('\n=== Reading History (${history.length} entries) ===');
  for (var entry in history) {
    print('ID: ${entry.readId}, News: ${entry.newsItemId}, '
          'Duration: ${entry.durationSeconds}s, Synced: ${entry.isSynced}');
  }
  print('=====================================\n');
}
```

### Debug: Print Statistics
```dart
Future<void> debugPrintStats(ReadingHistoryRepository repo) async {
  final stats = await repo.getStatistics();
  print('\n=== Reading Statistics ===');
  stats.forEach((key, value) {
    print('$key: $value');
  });
  print('==========================\n');
}
```

### Manual Sync Trigger (for testing)
```dart
// Force sync now (bypass periodic schedule)
await ReadingHistorySyncWorker.syncNow();
```

### Clear Test Data
```dart
// Reset for fresh test
await repo.clearAllHistory();
```

---

## Edge Cases to Test

### 1. Rapid Session Changes
- Start session → immediately end session (<1s)
- **Expected:** Duration = 0 or 1 second

### 2. Incomplete Sessions (App Crash)
- Start session but never call endSession
- **Expected:** Entry exists with null `ended_at`
- **Note:** These entries are NOT synced (only complete sessions sync)

### 3. Clock Change (Device Time Adjustment)
- Start session at time T1
- Change device time to T2 (1 hour ahead)
- End session
- **Expected:** Duration calculated from actual timestamps (may be negative or huge)
- **Note:** This is a known limitation of client-side timestamps

### 4. Very Long Sessions (>1 hour)
- Start session → leave app open for 2 hours → end session
- **Expected:** Duration = ~7200 seconds
- **Verify:** No overflow or truncation

### 5. Concurrent Reads (Multiple Articles Open)
- Start session for Article A
- Start session for Article B (without ending A)
- End both sessions
- **Expected:** 2 separate entries with overlapping timestamps

---

## Performance Tests

### Large Dataset (10,000 entries)
1. Create 10,000 history entries
2. Query with pagination: `getAllHistory(limit: 50)`
3. **Expected:** Query returns in <100ms
4. **Verify:** No UI lag

### Batch Upload (1,000 entries)
1. Create 1,000 unsynced entries
2. Trigger sync: `syncToServer()`
3. **Expected:** Completes in <30 seconds
4. **Verify:** No timeout errors

---

## Acceptance Criteria Summary

### Must Have (MVP)
- ✅ Local-only mode works 100% offline (default)
- ✅ Read sessions tracked with start/end/duration
- ✅ Multiple reads of same article tracked separately
- ✅ Delete single entry works
- ✅ Clear all history works
- ✅ Statistics calculated correctly
- ✅ Data persists after app restart

### Optional (Server Sync)
- ✅ Batch upload to server when sync enabled
- ✅ Entries marked as synced after upload
- ✅ Idempotent sync (no duplicates)
- ✅ Error handling (offline, server errors)
- ✅ Background worker (periodic sync every 24h)
- ✅ Privacy: delete from server when user deletes local

### Nice to Have (Future)
- ⏳ Cross-device sync (fetch server history and merge)
- ⏳ Conflict resolution (if same read tracked on 2 devices)
- ⏳ Analytics dashboard (server-side aggregations)

---

## Test Report Template

```
# Reading History Test Report

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Environment:** [Device/Emulator, OS Version]

## Results

| Scenario | Status | Notes |
|----------|--------|-------|
| 1. Local-Only Basic | ✅ PASS | All operations work offline |
| 2. Offline-Repeat | ✅ PASS | Multiple reads tracked correctly |
| 3. History View Ops | ✅ PASS | Delete/clear work as expected |
| 4. Batch Upload | ✅ PASS | Sync successful, 5 entries uploaded |
| 5. Sync Failure | ✅ PASS | Graceful error handling |
| 6. Background Worker | ✅ PASS | Periodic sync works |
| 7. Privacy/GDPR | ✅ PASS | Server delete works |
| 8. Statistics | ✅ PASS | Calculations correct |

## Issues Found
- [Issue #1]: [Description]
- [Issue #2]: [Description]

## Recommendations
- [Recommendation 1]
- [Recommendation 2]
```

---

**Document Version:** 1.0  
**Last Updated:** November 28, 2025
