# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**:`fillAntiCodeTemplate` (was four chained `replaceFirst`s) let a substituted value feed the next
  substitution. Filling the stream name first and then hunting for `$2` finds the `$2` *inside a room name* -
  rooms have such names - leaving the real placeholder unfilled and the signature computed over a string the
  server never templated. It is one left-to-right pass now, each placeholder filled at its first occurrence,
  and nothing written in is re-scanned.
- **Fixed**:`categories()` caught only `FormatException`, so the ordinary way one group fails - a refused
  socket, a non-JSON body - ended the whole tree instead of that group's rows, and a partial tree was then
  cached for the life of the process. Failures are caught per group and only a complete tree is memoised.
- **Fixed**: response fields were hard-cast (`row! as Map<String, Object?>`, `data!['liveData'] as Map?`), so a
  single row that came back differently threw and cost the entire page. Rows that are not maps are skipped and
  every field read goes through a checked accessor; the gid convergence (map / double / int / string) is
  preserved.
- **Fixed**:`_asInt` returned 0 for a value it could not parse, so an unknown viewer count was drawn as an
  empty room. Numeric fields are nullable now and a non-number is null.
- The stream url prefers the server's own `sHlsUrl`. Rewriting `sFlvUrl` with `replaceFirst('flv','hls')` is
  kept only as the fallback it always should have been, because it rewrites the **first** `flv` anywhere in the
  string, including one inside a path segment. The container is `sHlsUrlSuffix` when the hls url was used and
  `m3u8` otherwise - using the flv base while keeping its `.flv` suffix hands the player a stream that does not
  match the protocol the ticket declares.
- A `line` selection is a 1-based ordinal over the CDN entries: an unparseable or out-of-range one is refused
  rather than played as entry one (silently switching CDN turns "this line is down" into "every line is
  down"), and the chosen ordinal travels in the ticket so `refresh` renews **the same line**.
- A `quality` ask is recorded (`huya.requestedQuality`) and not honoured, because this slice serves the
  anonymous stream only; a silently dropped choice is the hardest kind of "my setting did nothing" to find.
- `hasMore` no longer guesses when the endpoint gave nothing to guess from: a missing `totalPage` is false, and
  an empty `datas` on the last page is an answer rather than a malformed one (a missing `datas` still is).
- `profileRoom` refusals carry the site's `message`; `refresh` returns a rejected future like every other
  contract method instead of throwing synchronously out of a call site that was awaiting it.
- The emitted anti-code query keeps unknown fields and drops `fm`, and the lease is checked against an injected
  `Clock` (`ticket.createdAt` too) rather than the wall clock read at three different moments.
- `createFallbackViewerUid` draws from `Random.secure()`; the signing nonce no longer uses the unseeded
  `Random()`.
- Declared `pure_live_utils` (`Clock`) and, as a dev dependency, `dio` for the transport fake.
- Added `test/huya_signing_test.dart` (13 cases) and `test/huya_source_test.dart` (17 cases). The package had
  no tests. `dart test`: 30 passing.
- Earlier: skeleton created for layer providers as `pure_live_huya`, then the first anonymous-HLS slice.
