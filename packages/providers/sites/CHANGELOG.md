# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Added**: `kugou` (酷狗直播 / 繁星) - the recommend directory and per-category directory (two different paths,
  the category one needing `cid`), the category table scraped from the site's own HTML with its personal routes
  filtered out and a last-known fallback when the scrape yields nothing, the jsonp anchor search (the callback
  we asked for has to come back, or the answer is an error page wearing a jsonp costume), the room endpoint and
  the multi-line stream-address endpoint. **This is the first site that uses both axes**: a profile is
  `container:rate:codec:layout` and the cdn urls inside one profile are the lines - flattening them into one list
  is what makes "1080p line 2" unaddressable. On-air is `liveType != -1` **and** a non-empty `liveSessionId`; a
  room missing the session is `unknown`, not ended. Pull urls are validated against the site's own host family,
  `/live/`, the container extension and a `txSecret`/`txTime` pair, and anything else is dropped rather than
  opened.
- **Added**: `inke` (一直播) - the three finite website catalogues, their tabs, the room endpoint and the one
  verbatim pull url. Two distinctions this site lives on: `error_code 1099999920` on the room endpoint is the
  only answer that means "no broadcast in progress" (an unknown code, a 5xx or a catalogue with no verified
  address all mean something else and are refused rather than reported as offline), and a signed flv url is
  accepted only on the site's own pull host with the path pinned to this broadcast - no synthesised hls, no url
  borrowed from another broadcast under the same uid, because a url we assembled is one nobody can debug when it
  403s. `liveStatus` deliberately does not read the catalogues, so a follow-list poll costs one request.
- **Added**: `weibo` - the anonymous recommendation snapshot (`PageMode.singleShot`: it is not a pagination
  endpoint, and asking it for page 2 without refusing would loop the same rooms forever), the room answer with
  its identity check, and the gated play url. `watch_limit` / `play_switch` become `LiveRoom.requiresAuth` and a
  named refusal at resolve time; a trial url present under a paid gate is **not** handed out, because presence
  is not permission. Weibo declares no search and no categories, because its anonymous surface has neither.
- **Added**: `room()` (the `LiveRoomCapability` answer) on huya, douyu and acfun, each built by a reader in that
  site's own api file: huya's profileRoom, douyu's `betard` document, acfun's live/info envelope. The room's facts
  are fields now - `state`, `anchorName`, `area`, `viewers`, `startedAt`, `streamId`, `requiresAuth` - instead of
  `extra` keys each site spelled differently. acfun is the only one of the three that states a paid-show gate, so
  it is the only one that sets `requiresAuth`; huya and douyu leave it false rather than inferring a gate from an
  empty CDN list.
- **Added**: `acfun` - the live directory by cursor (`nextCursor`, and a page number asked without its cursor is
  refused rather than answered as page one), the filter-pair category table, the anchor search read as both rooms
  and people, the visitor session shared across rooms, the quality menu ordered by the site's own `level` (its
  bitrate is a different scale, and mixing them sorts 高清 above 蓝光), and the play ticket.
- **Added**: the package. Every live site is a directory here rather than a package of its own, in the shape the
  reference product uses: `lib/src/<site>/<site>_api.dart` (urls, identity, signing, response readers) and
  `<site>_site.dart` (the capability answers). No per-site model file - callers receive the shared
  `pure_live_platform` models.
- **Added**: `common/site_json.dart`, the reading rules the sites share. A field arrives as a map, a number, a
  numeric string, a `{value: …}` box or absent, and *absent is not zero*: an unknown viewer count drawn as `0` is
  a number the source never claimed, and a page whose rows failed to parse shown as "no rows" is a lie a pager
  follows.
- **Moved**: `huya.live` and `douyu.live` from their own packages (`pure_live_huya`, `pure_live_douyu`), which
  existed only while there were two sites. Source ids, ticket metadata keys and the shape of every answer are
  unchanged - only the import surface moved.
