# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `RetryPolicy`: attempts, exponential curve, ceiling and **obedience to `Retry-After`** on a 429 or 503. The
  client used to retry a rate limit on a fixed 300 ms curve, which is how a fan-out search converts a throttle
  into a ban. `parseRetryAfter` handles both legal forms (delay-seconds and HTTP-date), measured against the
  response's own `Date` so clock skew between the device and the CDN does not become a negative wait.
- `classification.dart`: status-to-kind moved out of the client so a provider holding a `DioException` can name
  the failure without rebuilding it. 404 now produces `notFound` and 5xx produces `server` instead of both
  falling into `httpStatus` - the kinds existed in the vocabulary from the start and were never emitted, so a
  caller could not write the branch for a dead url. 501 and 505 are excluded from retry.
- `NetworkFailure` carries `retryAfter` and `actualUri`; a redirect that left the granted origin is only
  visible from the response, and the retry decision needs the server's own number.
- `HttpHeaderBag` (case-insensitive, multi-value, `redacted()` for logs), `url_reference.dart`
  (`resolveReference` for the four shapes a site emits, answered against the url that *responded*; `redact`,
  `sameOrigin`, `isHttpScheme`).
- `RequestBody`: JSON, url-encoded form with explicit UTF-8 percent-encoding, text, raw bytes, multipart and
  `asIs` for the legacy path. The encoding and its content type are one object now, because a form body that
  arrives labelled `text/plain` is rejected by half the sites this app talks to.
- `ConcurrencyLimiter` and `HostThrottle`: a bound on in-flight requests with a bounded queue, and a minimum
  spacing per host whose slot is reserved at request time.
- `download`: ranged (`Range` header, `isPartial`) reads through `ResponseType.stream` with a ceiling enforced
  **while reading** - a chunked response declares nothing - plus `ProgressReporter` and one-way cancellation
  forwarding from the caller's `CancelToken`.
- Verbs: `put`, `patch`, `delete`, `head`, `getText`, `requestJson`, `requestJsonArray`, `submitJson`,
  `postForm`, `postJson`, `requestBytes`. The Dio-shaped `get`/`getJson`/`post`/`sendBytes` stay and now sit on
  the same internal send path as the rest; `sendBytes` keeps its declared-length refusal.
- `NetworkSettings` gains `retry`, `maxRequestBytes`, `maxConcurrent`, `hostMinSpacing`,
  `refuseOriginChange` and `acceptsGzip`; `attempts`/`retryDelay` are gone in favour of `RetryPolicy`.
- Not implemented, recorded as a gap: the pubspec description still promises a proxy, and exposing dio's
  proxy settings needs `dart:io`, which would take web away from this package.
