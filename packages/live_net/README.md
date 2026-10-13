# live_net

The network kernel: one Dio-based transport with typed failures, plus a probe that
answers whether a stream address holds a stream.

## Purpose

Business modules that reach the network directly tend to acquire their own Dio
instance, their own retry count, their own idea of what a 404 means, and their own
`try/catch` that turns everything into a string. This package owns the transport so
those decisions are made once and are describable in types instead of comments.

## Responsibilities

- `DioFactory` + `ClientProfile` — build clients with caching, cookie persistence,
  HTTP/2 and retry defaults chosen from a profile, rather than at each call site.
- `LiveHttp` / `LiveHttpCalls` — the request surface: describe a call as a
  `LiveRequest`, get a `LiveResponse` or a `StreamedResponse` back.
- `TransportFailure` — the typed shape of *transport* failure (DNS, timeout,
  connection refused, cancel), matched on instead of string-parsed.
- `proxy.dart` — proxy configuration for platforms and sources that need it.
- `MediaProbe` — a different question from "did the server reply": read the head of
  the body and match the container signature to decide whether a URL carries a
  playable stream, and roughly what kind.
- Interceptors and storage under `lib/src/` — the mechanics behind the above.

**Status codes are not failures here.** A 4xx/5xx arrives as an ordinary
`LiveResponse`; only the convenience helpers in `LiveHttpCalls` promote a bad status
to `HttpStatusFailure`, so a caller that expects a document and gets a 404 can still
see which one it was.

## Explicitly not owned

Endpoint definitions and site behaviour (`live_sites`), playback decisions
(`live_playback`), channel or library semantics (`live_iptv`), and any policy about
what to do *after* a failure. Nothing in here knows what Pure Live is for.

## Public entry point

`package:live_net/live_net.dart`.

## Dependencies

`dio`, `dio_http2_adapter`, `dio_cache_interceptor`, `dio_cookie_manager`,
`dio_smart_retry`, `cookie_jar`, `live_log`, `meta`. Pure Dart — no Flutter
dependency, so it resolves and tests on any platform, including a headless one.

## Workspace usage

```yaml
dependencies:
  live_net:
    path: ../live_net
```

Depend on this package for transport; do not add Dio elsewhere, or the version
pinning and the failure vocabulary stop meaning anything.

## Testing

```powershell
dart test
```

Four suites cover the four surfaces that could silently differ: `dio_http_test`,
`media_probe_test`, `proxy_test`, `request_test`.

## Known limitations

- `MediaProbe` inspects the beginning of a response; a container whose signature
  sits past the read window, or a server that starts streaming only after a long
  stall, is judged from less information than a full demux would use.
- Caching and cookie storage are on disk per profile; nothing here expires entries
  by business rule.
- HTTP/2 comes from `dio_http2_adapter`, which does not carry every Dio interceptor
  behaviour; profiles that rely on those should stay on the default connector.
