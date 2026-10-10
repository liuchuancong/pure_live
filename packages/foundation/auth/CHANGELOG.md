# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Added `AuthCookie` and `AuthCookieJar`: RFC 6265 parsing of `Set-Cookie` (domain, path, Expires and
  Max-Age - where a non-positive Max-Age is a deletion instruction, not a 1969 date, and a domain the request
  did not come from is rejected rather than stored narrowed), host and path matching at separator boundaries so
  `/app` never covers `/application`, a `Cookie:` builder ordered longest-path-first, per-domain and total caps
  with session cookies dropped last, expiry pruning, JSON round-trip for the vault, and `describe()` which
  reports names and scopes but never values.
- Added `TokenRefreshCoordinator`: renews an account inside a jittered lead window (the jitter shortens the
  lead, never lengthens it, so the worst case is still a renewal before the credential dies), one refresh per
  account at a time with late callers joined to it, exponential backoff capped at `maxBackoff` after each
  refusal, and a permanent refusal or a hit failure limit marking the account `expired` so no other screen
  retries it. `authorizedSecret` is the call sites' entry point: ask for a secret, get one that still works.
- Added `RefreshFailure.permanent`, which is the distinction the backoff needs: a timeout may be retried, an
  invalid refresh token must not be asked again on the next screen.
- Added `AuthScheme`, `RequestAuthorizer` and `AuthRequest`: the four placements a provider expects its
  credential in (bearer, bare header, cookie line, query parameter) plus fixed headers, described as data
  instead of re-typed per provider, with `requireCredential` so a private screen cannot silently fall back to
  fetching and displaying the public version of the user's own list. `AuthRequest.redact()` shortens every
  credential header to its length, because a request log is the easiest way to publish someone's session.

- Skeleton created for layer foundation as `pure_live_auth`: no dependencies and no implementation yet.
