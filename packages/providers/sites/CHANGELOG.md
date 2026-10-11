# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.


## Unreleased

- **Added**: `jdlive` (京东直播) - the gateway's `body=<json>` query shape, the directory that continues by
  `currentCount` under one fixed timestamp (a page past the first asked without that cursor is refused, and a count
  that did not move ends the list), and the room's two containers. `code` and `subCode` are **text** on this
  gateway, so comparing them as numbers turns a working answer into a refusal; `subCode` is the field that means
  "no such live". A card is only a card when its `liveId` and `id` agree and its template is a room, because the
  list interleaves banners and slots. The hls and flv addresses are required to name the **same stream** - the site
  proves they are one encode in two containers, which is why this port lists them as one profile with two lines
  rather than as the two qualities v1's menu showed. The hls grant is read and validated before its address is
  handed out: every child has to stay on the issuing host, under `/live/`, and keep the stream's own stem.
  `secret == 1` is app-only and says so at resolve time. No keyword search is declared: v1 filtered the pages it
  had already walked, which reports "nobody by that name" for the rest of the platform.

- **Added**: `chzzk` - the inclusive-cursor live directory (continuation asks one row more and drops the repeated
  boundary item, and a `next` block that hands back the cursor we just sent ends the list instead of looping it),
  the channel search read as both rooms and people, the two-call room and the renditions read out of the manifests
  the playback bundle names. The channel is the room (`liveId` is per broadcast), and the audience number is
  exposure-gated: when `cvExposure` is not true the room reports no audience at all, because 0 would be a figure
  the site chose to withhold. `livePlaybackJson` is a json *string* naming HLS and LLHLS manifests on the
  akamaized family - other media ids are skipped rather than guessed at - and a rendition that states no
  `RESOLUTION` or no `BANDWIDTH` fails the manifest instead of inventing a menu row. Renditions group by
  `{height}p{60}` so 30fps and 60fps stay two choices, while HLS and LLHLS of one shape merge into one choice whose
  two addresses are the lines. `krOnlyViewing` is the site refusing this path (named as a region reason at resolve
  time, not reported as an offline room), `adult` is a group check the anonymous session cannot prove, and
  `timeMachineActive` is the site's own word for watchable-past so it is the only one that becomes
  [LiveCatchUp]. `qualities`, `lines` and `resolve` each read the room once - an earlier draft read it twice per
  call, which doubled the cost of every menu for the same answer.

- **Added**: `cc` (网易CC直播) - the menu assembled from the Dashen game registry *and* the live-entry
  configuration that selects which of those games are navigable at all (the legacy category endpoint now serves
  the application, not a category list), the fixed-30 grids, the two-call room and the anchor search read as both
  rooms and people. An entry whose game is missing, whose destination is not an `https://cc.163.com` route the
  site owns, whose configuration id does not come back, or whose identity repeats fails the whole menu rather
  than dropping a row. Two audience scales stay apart: `webcc_visitor`/`hot_score`/`visitor`/`total_visitor` are
  heat while `vision_visitor`/`online_num` are the people watching now - keeping both is what stops 50 万热度 from
  being drawn as 50 万人在线. A title starting with the site's `【重播】` mark while the status field says live stays
  playable and gets the site's own word as a tag. Tiers (`blueray`→原画, `ultra`→蓝光, unknown keys keep their own
  name) are qualities and the cdn families inside one are lines, ordered by the site's own preference table; the
  untouched tier states no `vbr`, so its place comes from its name rather than from a missing bitrate. A live
  bundle's line value can be a bare `?sign=` that belongs on the room's own m3u8 - read as a url it would be
  nothing, read as a suffix it is the signed address. `startat` is the site's UTC+8 wall clock and is converted,
  because a local reading turns into "已直播 -3 小时" elsewhere.

- **Added**: `bigo` - the finite homepage block (one snapshot of 20 rows that both pages are sliced from, with a
  real `total` and a 30-second reuse that is *not* cached on failure), the studio status, the token-handed lease and
  the three-way access gate. `bigo_id` is the room and `room_id` is an int64 kept as **text**, because rounding it
  through a double names a broadcast that does not exist. A gated `alive == 0` is not an offline observation, so a
  login or password room reads as `unknown` with the reason in `restriction` - and a gated room, or a room the site
  says is not broadcasting, that ships an `hls_src` is refused as a schema change: presence of a url is not
  permission. The lease needs a two-call jsonp handshake (a server timestamp, then an AES-256-CBC envelope keyed by
  OpenSSL's EVP_BytesToKey from the site's bundle passphrase); a jsonp answer under a different callback name is not
  executed. One stream means a quality menu of one and **no line axis**. The manifest-level
  `BigoHlsProtection` codec ships here and is tested round-trip, but the playback path has no per-segment transform
  hook yet, so a protected room would feed the kernel protected bytes - recorded as a player-layer queue item.

- **Added**: `baidulive` (百度直播) - the session-cursored feed (`session_id` + `refresh_index`, so a page past the
  first asked without its cursor is refused instead of answered as page one, and an answer that repeats its own
  counter ends the list rather than looping the same rooms), the tab block that arrives *with* the feed because the
  site has no category endpoint, the `371` room command, and the `protocol:resolution:codec` manifest. Two status
  numberings are kept apart on purpose: the feed calls broadcasting `1` while the room command calls it `0`, so a
  shared mapping would read every live grid card as a preview. `error_code` 1 and 4 are "no such broadcast" and
  nothing else is. Pull addresses must sit on the site's own host family, start under `/live/`, end with the
  container's extension and **name this room in their path** - and `flv-live.bdstatic.com` is deliberately served
  over http, which the ticket reports as `MediaProtocol.http` rather than pretending otherwise. Preview is
  `notStarted`, replay is `ended` with catch-up offered, and a thin room answer is padded from the card that
  listed it but never for its audience number. No keyword search is declared: the anonymous surface indexes
  broadcasts by room id only, and a search box that answers "nothing found" for every word would be a lie about
  what the site can be asked.

- **Added**: `kuaishou` (快手直播) - the eight static groups with their paged sub-categories, the two grid
  endpoints picked by the **length of the category id** (short = gameboard, long = non-game, both keyed as
  `gameId`), the one-shot recommendation block (its endpoint takes no page, so page 2 asks for nothing), the
  streamer search read as both rooms and people, and the room page's `window.__INITIAL_STATE__` document.
  The room is keyed on the **streamer** while `liveStreamId` is per broadcast, so the latter is
  `LiveRoom.streamId` and never the ref. The manifest is read **per codec**: an H.265 row that the site named
  exactly like its H.264 sibling stays its own quality (a decoder that cannot open it has to be able to see
  that), while rows of one codec merge into one quality whose urls are the lines. Three reading bugs from the v1
  line are pinned fixed here: the state literal was cut at the first `;` it found - including one inside a
  streamer's title - so it is now read by bracket matching; `undefined` was replaced everywhere, including
  inside strings, so only value position is; and a poster's extension was judged on the whole url, so
  `…/cover.jpg?x=1` got a second `.jpg` appended. An offline page reports **no** audience number instead of v1's
  `'0'`, `isLiving` that is neither true nor false is `unknown` and not ended, and a page with no state block is
  retried once only when the first response actually handed out a cookie.
- **Added**: `missevan` (猫耳FM直播) - native 20-row server pages (a caller that asks for 50 is told it got 20,
  otherwise its "short page means the end" logic stops the list early), the `type:id` tab key the list query
  requires, the room/creator identity checks, and the two pull containers. `500030004` is the only code that
  means "no such room"; every other non-zero code is a service failure and is never read as offline. A pull
  address must be in the site's own `*.bilivideo.com` family with a single ten-digit `expires`, normalised to
  https with the signed query kept verbatim. An offline room never looks at its stale channel urls - replaying
  them plays yesterday's show under today's title.

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
