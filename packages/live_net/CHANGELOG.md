# Changelog

## Unreleased

### Added

- `MediaProbe`: decides whether an address carries a stream by reading the head of
  the body and matching the container signature, which is a different question from
  "the server replied" and one no Dio interceptor can answer.
- `ClientProfile` + `DioFactory`: caching, cookie persistence, HTTP/2 and retry
  defaults are properties of a profile instead of per-call-site configuration.
- `TransportFailure`: typed transport failures, so callers match on a cause rather
  than parsing an exception's message.
- Proxy configuration surface for sources and platforms that need one.
- `ReplayHttp` / `ReplaySample` (`package:live_net/testing.dart`): a test transport
  that answers from recorded samples in the capture tooling's layout (fixture schema
  1), matching method, host, path, query, form and JSON fields except the per-run
  ones (signatures, clocks) a test names.

### Changed

- HTTP status codes are ordinary responses, not exceptions. Only the convenience
  helpers in `LiveHttpCalls` promote a bad status to `HttpStatusFailure`; a caller
  that needs to tell 404 from 500 keeps both available.
- Dio usage is confined to this package: business modules go through `LiveHttp`, so
  the retry, caching and failure vocabulary cannot be bypassed by acquiring a client
  elsewhere.

### Breaking Changes

- Initial development release; no stability commitment yet.
