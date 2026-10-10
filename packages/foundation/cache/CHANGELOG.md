# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `CacheControl`: parses a `cache-control` header into the directives that actually change a decision
  (max-age, s-maxage, stale-while-revalidate, stale-if-error, no-store, no-cache, must-revalidate, public,
  private, immutable, only-if-cached), dropping unknown ones rather than failing on a directive a CDN invented.
  A malformed number reads as absent, so one bad directive cannot disable caching for every response behind it.
- `decideCacheUse` answers fresh / stale-usable / stale-for-error-only / revalidate / unusable from the entry's
  own facts, measuring age against the origin's `Date` rather than the moment the cache saw it - a body that sat
  in a CDN for an hour is an hour older than its arrival here. Immutable wins over the clock, no-cache loses to
  it, a shared cache refuses `private`, and a stale entry with no validator is unusable rather than guessable.
- `revalidationHeaders` picks `If-None-Match` over `If-Modified-Since` when both exist, and `parseHttpDate`
  reads the three date forms servers send, answering null instead of throwing.
- `HttpCache`: url-keyed byte cache (sha256 keys, since a url is unbounded and carries characters a filename
  should not), one fetch per url with concurrent readers joined to it, conditional revalidation where a 304
  refreshes the freshness facts without re-downloading the body, stale-while-revalidate served immediately with
  the refresh running behind the caller, and a `serveStaleOnError` switch for the callers whose correctness
  outranks their availability. `invalidateHost` clears one misbehaving source without emptying the namespace.
- `LoadingCache<K,V>`: the typed miss-loads-and-stores path with per-key single-flight, byte accounting, an
  eviction callback for widget-level references, `invalidateWhere`, and a `refresh` that keeps the old value
  until the new one lands rather than blanking a list mid-reload. `JsonDocumentLoader` decodes and shape-checks
  a body, so a CDN error page becomes a named `CacheLoadFailure` instead of a cast exception three layers up.
- `CacheStats`: hits, misses, coalesced loads, load count and failures, evictions and evicted bytes, stale
  served (and stale served on error), bytes in and out, total and average load time, and a hit ratio that is
  null before the first read - "no reads yet" and "every read missed" are different facts.

- Skeleton created for layer foundation as `pure_live_cache`: no dependencies and no implementation yet.
