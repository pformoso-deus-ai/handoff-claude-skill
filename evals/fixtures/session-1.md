# Simulated prior session — token-bucket rate limiter

> Use this as if it were the conversation that just happened with the user. The user is now asking you to write a handoff doc.

**User:** Need a token-bucket rate limiter for our API gateway. 100 req/sec per API key, burst of 20. Should live in `src/middleware/rateLimiter.ts`.

**Assistant:** Sketched the type, capacity=20, refillRate=100/sec, in-memory `Map<apiKey, BucketState>`. Drafted `src/middleware/rateLimiter.ts` with `take()` and `refill()` methods.

**User:** Looks good. Add tests.

**Assistant:** Created `src/middleware/rateLimiter.test.ts`. Covered: empty bucket rejects, full bucket allows burst, refill restores tokens after 1s.

**User:** The refill test is flaky in CI — passes locally, fails about 1 in 10 in CI.

**Assistant:** Investigated. Hypothesis 1: `setTimeout` jitter in CI. Tried bumping the wait from 1000ms to 1100ms — still flaky. Hypothesis 2: the refill math uses `Date.now()` deltas, and if the system clock isn't monotonic the delta can go negative, dumping the bucket. Confirmed in `refill()` at line 47: `const elapsed = now - bucket.lastRefill;` — no guard against negative elapsed.

**User:** Yeah I think you're onto something. But also wait — we have a race condition between concurrent `take()` calls right? Two requests arriving at the same time both read the bucket, both decide there's a token, both consume it, and we go negative.

**Assistant:** Right. There are two bugs:

  1. `refill()` doesn't guard `elapsed < 0` — easy fix, clamp to zero.
  2. `take()` has a TOCTOU race — read-then-write on `bucket.tokens` with no lock. In a Node single-threaded context this only matters across `await` points, but our `take()` does `await this.persistBucket()` after the decrement, so two concurrent calls absolutely can interleave.

**User:** OK fix the clock thing now, the race is bigger and I want to think about whether we use a mutex or just move the decrement before the await.

**Assistant:** Applied the clock fix at `src/middleware/rateLimiter.ts:47`. Added a regression test in `rateLimiter.test.ts` that mocks `Date.now()` to return a decreasing value.

**User:** Nice. Did the original flaky test stop being flaky?

**Assistant:** Ran the test in a loop locally 50 times — all pass. CI hasn't run yet. Pushed to feature branch `rate-limiter-fix`.

**User:** ok we'll see what CI says. The race condition though — I was reading and I think the right move is just reordering: do the decrement synchronously, then await the persist. If persist fails we can re-increment. That's simpler than a mutex.

**Assistant:** Agreed. Started drafting the reorder. Got partway through `take()` — moved the decrement to before the `await this.persistBucket()` call, but haven't written the rollback-on-persist-failure path yet. Left it at line 88 of rateLimiter.ts, mid-function.

**User:** ok i need to stop for the day...
