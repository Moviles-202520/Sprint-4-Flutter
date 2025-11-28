# Search Feature - QA Test Plan

**Milestone:** F - Feature 5: Searcher + Search Cache  
**Date:** November 28, 2025  
**Version:** 1.0

## Overview

This document outlines the comprehensive test plan for the Search feature with cache-first architecture. The implementation uses Full-Text Search (FTS) with PostgreSQL tsvector on the backend and LRU+TTL caching on the client.

### Architecture Summary

- **Client Cache:** SQLite with LRU eviction + TTL expiration (default 1 hour)
- **Backend Search:** PostgreSQL FTS with GIN index on search_vector column
- **Strategy:** Cache-first (instant response on hit) → Server fallback → Cache update
- **Offline Support:** Returns cached results when offline; graceful error handling

---

## Test Scenarios

### Scenario 1: Cold Start (Empty Cache)

**Objective:** Verify search works correctly when cache is empty (first-time use or after clear).

**Preconditions:**
- App installed fresh OR cache cleared via settings
- Device has network connectivity
- Backend search_news RPC function is deployed

**Test Steps:**
1. Open app and navigate to Search screen
2. Enter search query: "tecnología innovación"
3. Submit search
4. Observe loading indicator
5. Wait for results to appear

**Expected Results:**
- ✅ Loading indicator shown during server query
- ✅ Results appear within 2-3 seconds (network dependent)
- ✅ Results include news item IDs
- ✅ Snippets/highlights visible with `<mark>` tags around matching words
- ✅ Result source indicator shows "Server" or "Fresh"
- ✅ No error messages displayed
- ✅ Results are now cached for subsequent queries

**Validation:**
```dart
// Check cache statistics after query
final stats = await searchService.getCacheStatistics();
assert(stats['cache_misses'] == 1); // First query = cache miss
assert(stats['server_queries'] == 1); // Queried server
assert(stats['valid_entries'] == 1); // Result now cached
```

---

### Scenario 2: Cache Hit (Repeated Query)

**Objective:** Verify instant response when querying same search again within TTL.

**Preconditions:**
- Scenario 1 completed (cache has at least one entry)
- Less than 1 hour has passed (default TTL)

**Test Steps:**
1. Enter same search query: "tecnología innovación"
2. Submit search
3. Observe response time (should be instant)
4. Check result source indicator

**Expected Results:**
- ✅ Results appear **instantly** (< 100ms, no loading indicator)
- ✅ Result source indicator shows "Cached"
- ✅ Results are identical to previous query
- ✅ No network request made (verify with network monitor)
- ✅ Cache hit counter incremented

**Validation:**
```dart
final stats = await searchService.getCacheStatistics();
assert(stats['cache_hits'] >= 1);
assert(stats['cache_hit_rate'] > 0);
```

**Performance Benchmark:**
- Cache hit latency: < 100ms (target < 50ms)
- No network traffic observed

---

### Scenario 3: Offline Search (Cache Available)

**Objective:** Verify app continues to work offline when cached results exist.

**Preconditions:**
- Cache has entries from previous searches
- Device is offline (airplane mode OR disconnect WiFi/data)

**Test Steps:**
1. Enable airplane mode
2. Navigate to Search screen
3. Enter previously searched query: "tecnología innovación"
4. Submit search
5. Observe results

**Expected Results:**
- ✅ Results appear instantly from cache
- ✅ Offline indicator/banner displayed ("Showing cached results")
- ✅ No error message about network
- ✅ Results are complete and usable
- ✅ User can tap on items to view (if cached locally)

**Validation:**
```dart
// Verify search works offline
await setAirplaneMode(true);
final result = await searchService.searchCacheOnly(query);
assert(result != null);
assert(result.isCached == true);
```

---

### Scenario 4: Offline Search (No Cache)

**Objective:** Verify graceful error handling when offline with no cached results.

**Preconditions:**
- Cache is empty OR query has never been searched
- Device is offline

**Test Steps:**
1. Enable airplane mode
2. Navigate to Search screen
3. Enter new query: "arquitectura moderna"
4. Submit search
5. Observe error handling

**Expected Results:**
- ✅ Error message displayed: "No internet connection. Search results unavailable."
- ✅ Suggestion shown: "Try searching for something you've queried before."
- ✅ No loading spinner stuck forever
- ✅ User can retry when back online
- ✅ App doesn't crash

**Validation:**
```dart
await setAirplaneMode(true);
try {
  await searchService.search(newQuery);
  fail('Should throw exception when offline with no cache');
} catch (e) {
  assert(e.toString().contains('No cached results available'));
}
```

---

### Scenario 5: TTL Expiration (Stale Cache)

**Objective:** Verify cache entries expire after TTL and fresh data is fetched.

**Preconditions:**
- Cache has entries older than TTL (default 1 hour)
- Device is online

**Test Steps:**
1. Perform search and cache result
2. **Wait 1 hour** OR manually set cached_at timestamp to 2 hours ago (test database)
3. Perform same search again
4. Observe behavior

**Expected Results:**
- ✅ Old cache entry ignored (expired)
- ✅ Server queried for fresh results
- ✅ New result cached with updated timestamp
- ✅ Old entry eventually cleaned up by maintenance task

**Validation:**
```dart
// Manually expire cache entry for testing
await storage._database.update(
  'search_cache',
  {'cached_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String()},
  where: 'cache_key = ?',
  whereArgs: [query.cacheKey],
);

// Query should hit server (cache miss due to expiration)
final result = await searchService.search(query);
assert(result.source == SearchResultSource.server);
```

**Maintenance Test:**
```dart
// Cleanup expired entries
final deleted = await searchService.cleanupExpiredCache();
assert(deleted > 0); // Should delete expired entries
```

---

### Scenario 6: LRU Eviction (Cache Full)

**Objective:** Verify least recently used entries are evicted when cache reaches max size.

**Preconditions:**
- Cache max size set to 100 entries (default)
- App has performed 100+ unique searches

**Test Steps:**
1. Fill cache with 100 unique queries (script or manual)
2. Note the oldest accessed entry (cache_key_1)
3. Perform new search (query 101)
4. Check if cache_key_1 was evicted
5. Try to retrieve cache_key_1

**Expected Results:**
- ✅ New entry (query 101) successfully cached
- ✅ Oldest entry (cache_key_1) evicted automatically
- ✅ Total cache entries remains at 100 (not 101)
- ✅ Most recently accessed entries preserved

**Validation:**
```dart
// Fill cache to max
for (int i = 0; i < 100; i++) {
  final query = SearchQuery(query: 'test$i');
  final result = SearchResult(newsItemIds: [], totalCount: 0, source: SearchResultSource.server, query: 'test$i');
  await storage.cacheResult(query, result);
}

// Get oldest cache key
final oldestQuery = SearchQuery(query: 'test0');

// Add one more (should trigger LRU eviction)
final newQuery = SearchQuery(query: 'test_new');
final newResult = SearchResult(newsItemIds: [], totalCount: 0, source: SearchResultSource.server, query: 'test_new');
await storage.cacheResult(newQuery, newResult);

// Verify oldest was evicted
final evictedResult = await storage.getCachedResult(oldestQuery);
assert(evictedResult == null); // Evicted

// Verify total still at max
final stats = await storage.getStatistics();
assert(stats['total_entries'] == 100);
```

---

### Scenario 7: Category Filter

**Objective:** Verify search works correctly with category filters.

**Preconditions:**
- App has multiple categories configured
- Backend supports category_id parameter

**Test Steps:**
1. Navigate to Search screen
2. Enter query: "deportes"
3. Select category filter: "Sports" (UUID: <sports-category-id>)
4. Submit search
5. Verify results are filtered
6. Change category to "Politics"
7. Verify different results returned

**Expected Results:**
- ✅ Results filtered by selected category
- ✅ Different category = different cache entry (unique cache key)
- ✅ Switching categories shows appropriate results
- ✅ No cross-contamination between categories

**Validation:**
```dart
final sportQuery = SearchQuery(query: 'partido', categoryId: sportsCategoryId);
final politicsQuery = SearchQuery(query: 'partido', categoryId: politicsCategoryId);

// Different cache keys for different categories
assert(sportQuery.cacheKey != politicsQuery.cacheKey);

// Different results
final sportResults = await searchService.search(sportQuery);
final politicsResults = await searchService.search(politicsQuery);
assert(sportResults.newsItemIds != politicsResults.newsItemIds);
```

---

### Scenario 8: Pagination

**Objective:** Verify pagination works correctly with cache and server.

**Preconditions:**
- Search query returns > 20 results (default page size)

**Test Steps:**
1. Search for common term: "noticias"
2. Verify first 20 results shown (page 1)
3. Scroll to bottom and tap "Load More"
4. Verify next 20 results loaded (page 2)
5. Go back to page 1
6. Verify instant load from cache

**Expected Results:**
- ✅ Page 1 (offset 0) cached separately
- ✅ Page 2 (offset 20) cached separately
- ✅ Each page has unique cache key
- ✅ Scrolling back shows instant cached results
- ✅ Total count displayed correctly

**Validation:**
```dart
final page1 = SearchQuery(query: 'noticias', limit: 20, offset: 0);
final page2 = SearchQuery(query: 'noticias', limit: 20, offset: 20);

assert(page1.cacheKey != page2.cacheKey); // Different cache entries

final result1 = await searchService.search(page1);
final result2 = await searchService.search(page2);

assert(result1.newsItemIds.length == 20);
assert(result2.newsItemIds.length <= 20);
```

---

### Scenario 9: Force Refresh

**Objective:** Verify user can bypass cache to get fresh results.

**Preconditions:**
- Search result is cached
- User suspects stale data

**Test Steps:**
1. Perform search: "última hora"
2. Results cached
3. Pull-to-refresh OR tap "Refresh" button
4. Observe loading indicator
5. New results appear

**Expected Results:**
- ✅ Cache bypassed (forceRefresh=true)
- ✅ Server queried for fresh data
- ✅ Cache updated with new results
- ✅ User sees latest content
- ✅ Loading indicator shown during refresh

**Validation:**
```dart
// Initial search (cached)
final result1 = await searchService.search(query);
assert(result1.isCached == true);

// Force refresh
final result2 = await searchService.search(query, forceRefresh: true);
assert(result2.source == SearchResultSource.server);

// Cache now updated
final result3 = await searchService.search(query);
assert(result3.cachedAt != result1.cachedAt); // Newer cache time
```

---

### Scenario 10: Special Characters & Edge Cases

**Objective:** Verify search handles special characters, accents, and edge cases.

**Test Cases:**

| Input | Expected Behavior |
|-------|------------------|
| `¿Qué pasa?` | Works correctly (plainto_tsquery handles punctuation) |
| `café` | Matches "cafe" and "café" (Spanish stemming) |
| `   spaces   ` | Trimmed and normalized |
| Empty string | Error message: "Please enter search term" |
| Single letter `a` | Results returned (if any) or "No results" |
| Very long query (500+ chars) | Truncated or handled gracefully |
| Numbers: `2024` | Works correctly |
| Emojis: `🔥` | Handled or filtered |

**Validation:**
```dart
// Test empty query
final emptyQuery = SearchQuery(query: '   ');
assert(emptyQuery.isValid == false);

// Test accents normalization
final accentQuery = SearchQuery(query: 'café');
assert(accentQuery.normalizedQuery == 'café');

// Test special characters
final specialQuery = SearchQuery(query: '¿Qué pasa?');
final result = await searchService.search(specialQuery);
// Should not throw exception
```

---

## Automated Test Suite

### Unit Tests

```dart
// test/search_cache_test.dart
void main() {
  group('SearchQuery', () {
    test('generates correct cache key', () {
      final query = SearchQuery(query: 'Test', categoryId: 'cat-1', limit: 10, offset: 0);
      expect(query.cacheKey, 'q:test|c:cat-1|l:10|o:0');
    });

    test('normalizes query text', () {
      final query = SearchQuery(query: '  UPPERCASE  ');
      expect(query.normalizedQuery, 'uppercase');
    });

    test('validates empty queries', () {
      final query = SearchQuery(query: '   ');
      expect(query.isValid, false);
    });
  });

  group('SearchCacheLocalStorage', () {
    late SearchCacheLocalStorage storage;

    setUp(() async {
      storage = SearchCacheLocalStorage();
      await storage.initialize();
      await storage.clearCache();
    });

    test('caches and retrieves results', () async {
      final query = SearchQuery(query: 'test');
      final result = SearchResult(
        newsItemIds: ['1', '2', '3'],
        totalCount: 3,
        source: SearchResultSource.server,
        query: 'test',
      );

      await storage.cacheResult(query, result);
      final cached = await storage.getCachedResult(query);

      expect(cached, isNotNull);
      expect(cached!.newsItemIds, ['1', '2', '3']);
      expect(cached.isCached, true);
    });

    test('returns null for expired entries', () async {
      final query = SearchQuery(query: 'test');
      final result = SearchResult(newsItemIds: [], totalCount: 0, source: SearchResultSource.server, query: 'test');
      
      // Cache with 1 second TTL
      await storage.cacheResult(query, result, ttl: Duration(seconds: 1));
      
      // Wait for expiration
      await Future.delayed(Duration(seconds: 2));
      
      final cached = await storage.getCachedResult(query);
      expect(cached, isNull); // Expired
    });

    test('LRU eviction works', () async {
      // Fill cache to max (100)
      for (int i = 0; i < 100; i++) {
        final query = SearchQuery(query: 'test$i');
        final result = SearchResult(newsItemIds: [], totalCount: 0, source: SearchResultSource.server, query: 'test$i');
        await storage.cacheResult(query, result);
      }

      // Add one more (should evict oldest)
      final newQuery = SearchQuery(query: 'test_new');
      final newResult = SearchResult(newsItemIds: [], totalCount: 0, source: SearchResultSource.server, query: 'test_new');
      await storage.cacheResult(newQuery, newResult);

      // Verify total still at 100
      final stats = await storage.getStatistics();
      expect(stats['total_entries'], 100);
    });
  });
}
```

---

## Performance Benchmarks

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Cache hit latency | < 50ms | Stopwatch around `getCachedResult()` |
| Server query latency | < 2s | Stopwatch around `search()` with cache miss |
| Cache write time | < 100ms | Stopwatch around `cacheResult()` |
| LRU eviction time | < 200ms | Stopwatch around `_evictIfNeeded()` |
| TTL cleanup time | < 500ms | Stopwatch around `deleteExpiredEntries()` |

---

## Test Data Setup

### Sample Search Queries for Testing

```sql
-- Insert test news items with Spanish content
INSERT INTO public.news_items (news_item_id, title, content, category_id, published_at)
VALUES
  (gen_random_uuid(), 'Avances en tecnología de inteligencia artificial', 'La inteligencia artificial está revolucionando...', '<tech-category-uuid>', NOW()),
  (gen_random_uuid(), 'Elecciones presidenciales 2024: resultados preliminares', 'Los primeros resultados de las elecciones...', '<politics-category-uuid>', NOW()),
  (gen_random_uuid(), 'Cambio climático: nuevos estudios sobre el calentamiento global', 'Científicos advierten que el cambio climático...', '<environment-category-uuid>', NOW()),
  (gen_random_uuid(), 'Partido de fútbol: victoria histórica del equipo nacional', 'El equipo nacional logró una victoria...', '<sports-category-uuid>', NOW()),
  (gen_random_uuid(), 'Economía: mercado de valores alcanza máximo histórico', 'Los mercados financieros celebran...', '<economy-category-uuid>', NOW());
```

---

## Edge Cases & Error Handling

### Network Errors
- **Timeout:** Display "Request timed out. Try again."
- **500 Error:** Display "Server error. Please try again later."
- **403 Error:** Display "Unauthorized. Please log in."

### Database Errors
- **SQLite corruption:** Recreate cache database, log error
- **Disk full:** Display "Storage full. Clear cache to continue."

### Invalid Queries
- **SQL injection attempt:** Sanitized by plainto_tsquery (safe)
- **XSS in results:** Escape HTML before rendering highlights

---

## Checklist for QA Sign-off

- [ ] All 10 test scenarios pass
- [ ] Automated unit tests pass (100% coverage on core logic)
- [ ] Performance benchmarks meet targets
- [ ] Offline functionality verified
- [ ] Cache persistence verified (survives app restart)
- [ ] LRU eviction confirmed working
- [ ] TTL expiration confirmed working
- [ ] No memory leaks detected (profiling)
- [ ] No crashes on edge cases
- [ ] Documentation updated (README, API docs)

---

## Known Limitations

1. **Max cache size:** 100 entries (configurable but hardcoded in v1)
2. **TTL:** Fixed at 1 hour (no per-user customization)
3. **Category filters:** Only one category at a time (no multi-select)
4. **Highlights:** Only first 50 words shown (backend limit)
5. **Offline pagination:** Only cached pages available offline

---

## Future Enhancements

- [ ] Voice search integration
- [ ] Search history/suggestions
- [ ] Fuzzy matching for typos
- [ ] Trending searches (analytics)
- [ ] Advanced filters (date range, source, etc.)
- [ ] Saved searches / alerts

---

**Document Version:** 1.0  
**Last Updated:** November 28, 2025  
**Tested By:** [QA Team Name]  
**Approved By:** [Product Owner]
