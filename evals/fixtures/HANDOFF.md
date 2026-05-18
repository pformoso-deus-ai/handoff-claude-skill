# Session Handoff
Created: 2026-05-16 18:42 UTC
Working dir: /home/dev/api-gateway
Status: in-progress

## Goal
Ship a token-bucket rate limiter for the API gateway (100 req/sec per API key, burst of 20) in `src/middleware/rateLimiter.ts`. Two known bugs to close before merge: a `Date.now()` non-monotonic clock issue (fixed) and a TOCTOU race in `take()` (in progress).

## Where I left off
Reordering `take()` to do the token decrement synchronously *before* the `await this.persistBucket()` call, with a rollback path if persist fails. The decrement reorder is done; the rollback path is half-written.

## Decisions made (with rationale)
- Use reorder + rollback instead of a mutex for the TOCTOU race — simpler, no extra dependency, the failure mode (persist throws) is rare and a re-increment is cheap.
- Clamp `elapsed` to zero in `refill()` rather than using `performance.now()` — the persisted `lastRefill` is wall-clock, switching clock sources mid-flight would corrupt existing bucket state.

## Done
- Token-bucket type + `take()`/`refill()` skeleton — [src/middleware/rateLimiter.ts](src/middleware/rateLimiter.ts)
- Tests for empty/full/refill behavior — [src/middleware/rateLimiter.test.ts](src/middleware/rateLimiter.test.ts)
- Clock-skew fix in `refill()` — [src/middleware/rateLimiter.ts:47](src/middleware/rateLimiter.ts:47)
- Regression test for negative `elapsed` — [src/middleware/rateLimiter.test.ts](src/middleware/rateLimiter.test.ts)

## In progress
- Race-condition fix in `take()` — paused at [src/middleware/rateLimiter.ts:88](src/middleware/rateLimiter.ts:88). Decrement is now before the `await persistBucket()` call; still need to wrap the `await` in try/catch and re-increment `bucket.tokens` if it throws. Then add a concurrency test that fires N parallel `take()` calls against a bucket with N-1 tokens and asserts exactly one rejection.

## Dead ends (do not retry)
- Bumping the refill test's wait from 1000ms → 1100ms — didn't fix CI flakiness; root cause was the clock issue, not setTimeout jitter.
- Considered a mutex / async-lock library for the race — rejected as overkill given the reorder works.

## Verification before resuming
Run these to confirm state hasn't drifted since this doc was written:

```bash
git status
git branch --show-current
npm test -- rateLimiter
```

Expected: on branch `rate-limiter-fix`, working tree shows uncommitted changes in `src/middleware/rateLimiter.ts` around line 88, all tests pass except possibly a not-yet-written concurrency test.

## Next steps
1. Open [src/middleware/rateLimiter.ts:88](src/middleware/rateLimiter.ts:88), wrap the `await this.persistBucket()` in try/catch, re-increment `bucket.tokens` on catch, and rethrow.
2. Add a concurrency test in [src/middleware/rateLimiter.test.ts](src/middleware/rateLimiter.test.ts) that fires 5 parallel `take()` calls against a bucket initialized with 4 tokens and asserts exactly one returns false.
3. Push and check CI for the flaky refill test — if it's stable for 10 consecutive runs, mark the clock fix as confirmed.

## Open questions for the user
- Is `persistBucket()` expected to be idempotent? If it can succeed-then-throw (e.g. network blip after the write lands), the re-increment would double-credit. Worth a quick check before finalizing the rollback.
