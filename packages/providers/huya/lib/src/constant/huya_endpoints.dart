// Module: lib/src/constant/huya_endpoints.dart
// Purpose: Every huya url this package asks, in one place.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md. Provenance: the v1-maintained huya line's endpoint set (UPSTREAM_REVIEW_POLICY
// governs how that knowledge is used - these are names, not merged code). Kept together because a platform that
// moves an endpoint moves it for every call site, and a grep for one url should find one definition.

/// `www.huya.com/cache.php` - the live list page (recommend feed and per-category rooms).
const String huyaListUrl = 'https://www.huya.com/cache.php';

/// `mp.huya.com/cache.php` - profileRoom: the one endpoint that describes a room fully, including its CDN list.
const String huyaProfileRoomUrl = 'https://mp.huya.com/cache.php';

/// `search.cdn.huya.com/` - the search endpoint. Rows are capped at 50 and paging runs through `start`.
const String huyaSearchUrl = 'https://search.cdn.huya.com/';

/// `live.cdn.huya.com/liveconfig/game/bussLive` - one top group's game table.
const String huyaGameConfigUrl = 'https://live.cdn.huya.com/liveconfig/game/bussLive';

/// The four top category groups, with the ids the web config has always used.
const List<(String bussType, String groupName)> huyaTopGroups = <(String, String)>[
  ('1', '网游'),
  ('2', '单机'),
  ('8', '娱乐'),
  ('3', '手游'),
];

/// A desktop Chrome UA: the web endpoints answer to it without a login.
const String huyaUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36';

/// The headers the web endpoints expect from a browser-shaped client.
const Map<String, String> huyaWebHeaders = <String, String>{
  'user-agent': huyaUserAgent,
  'origin': 'https://www.huya.com',
  'referer': 'https://www.huya.com/',
};

/// The OSS thumbnail suffix the web list asks the CDN for; the raw screenshot is several times larger.
const String huyaCoverThumbQuery = '?x-oss-process=style/w338_h190&';
