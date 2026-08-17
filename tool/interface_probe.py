#!/usr/bin/env python3
"""Dependency-free smoke probes for the public endpoints used by Pure Live."""

from __future__ import annotations

import json
import hashlib
import gzip
import sys
import time
import http.cookiejar
import urllib.parse
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
)
TWITCH_GQL_URL = "https://gql.twitch.tv/gql"
TWITCH_CLIENT_ID = "kimne78kx3ncx6brgo4mv6wki5h1ko"


def request_json(url: str, params: dict[str, object] | None = None, attempts: int = 3) -> object:
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    origin = urllib.parse.urlsplit(url)
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            # Rebuild the request for every retry. Some CDNs close or rate-limit a
            # keep-alive connection after an empty/HTML challenge response.
            request = urllib.request.Request(
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Referer": f"{origin.scheme}://{origin.netloc}/",
                    "Accept": "application/json,text/plain,*/*",
                    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                    "Cache-Control": "no-cache",
                    "Connection": "close",
                },
            )
            with urllib.request.urlopen(request, timeout=20) as response:
                raw_payload = response.read()
                # A few platform CDNs return gzip even when the client did not
                # advertise compression. urllib deliberately leaves it intact.
                if (
                    response.headers.get("Content-Encoding", "").lower() == "gzip"
                    or raw_payload.startswith(b"\x1f\x8b")
                ):
                    raw_payload = gzip.decompress(raw_payload)
                payload = raw_payload.decode("utf-8", errors="replace")
            if not payload.strip():
                raise ValueError("empty response body")
            try:
                return json.loads(payload.lstrip("\ufeff"))
            except json.JSONDecodeError as error:
                content_type = response.headers.get("Content-Type", "unknown")
                preview = payload[:80].replace("\r", " ").replace("\n", " ")
                raise ValueError(f"non-JSON response ({content_type}): {preview!r}") from error
        except Exception as error:  # noqa: BLE001 - preserve endpoint diagnostics
            last_error = error
            if attempt < attempts:
                time.sleep(attempt)
    assert last_error is not None
    raise last_error


def post_json(
    url: str,
    payload: object,
    headers: dict[str, str] | None = None,
    attempts: int = 3,
) -> object:
    """POST JSON with bounded retries and preserve response diagnostics."""
    body = json.dumps(payload, separators=(",", ":")).encode()
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(
                url,
                data=body,
                method="POST",
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "application/json",
                    "Content-Type": "text/plain; charset=UTF-8",
                    **(headers or {}),
                },
            )
            with urllib.request.urlopen(request, timeout=20) as response:
                raw_payload = response.read()
            if not raw_payload.strip():
                raise ValueError("empty response body")
            return json.loads(raw_payload.decode("utf-8", errors="replace").lstrip("\ufeff"))
        except Exception as error:  # noqa: BLE001 - preserve endpoint diagnostics
            last_error = error
            if attempt < attempts:
                time.sleep(attempt)
    assert last_error is not None
    raise last_error


def require_path(value: object, *path: str) -> None:
    current = value
    for part in path:
        if not isinstance(current, dict) or part not in current:
            raise ValueError(f"missing JSON path: {'.'.join(path)}")
        current = current[part]


def bilibili_danmaku_probe() -> None:
    """Validate the signed endpoint and the current secure socket nodes."""
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    def bili_json(url: str) -> dict[str, object]:
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": USER_AGENT,
                "Referer": "https://live.bilibili.com/6",
                "Accept": "application/json,text/plain,*/*",
            },
        )
        with opener.open(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))

    spi = bili_json("https://api.bilibili.com/x/frontend/finger/spi")
    require_path(spi, "data", "b_3")
    nav = bili_json("https://api.bilibili.com/x/web-interface/nav")
    wbi_img = nav.get("data", {}).get("wbi_img", {}) if isinstance(nav.get("data"), dict) else {}
    img_url = str(wbi_img.get("img_url", ""))
    sub_url = str(wbi_img.get("sub_url", ""))
    if not img_url or not sub_url:
        raise ValueError("WBI image keys missing")

    source = "".join(urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1].split(".", 1)[0] for url in (img_url, sub_url))
    table = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
    ]
    mixin_key = "".join(source[index] for index in table if index < len(source))[:32]
    params = {"id": "6", "type": "0", "wts": str(int(time.time()))}
    filtered = {key: "".join(char for char in value if char not in "!'()*") for key, value in params.items()}
    query = urllib.parse.urlencode(sorted(filtered.items()))
    filtered["w_rid"] = hashlib.md5(f"{query}{mixin_key}".encode()).hexdigest()
    response = bili_json(
        "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?"
        + urllib.parse.urlencode(filtered)
    )
    if response.get("code") != 0:
        raise ValueError(f"getDanmuInfo code={response.get('code')}")
    data = response.get("data", {})
    hosts = data.get("host_list", []) if isinstance(data, dict) else []
    if not data.get("token") or not hosts:
        raise ValueError("danmaku token/host_list missing")
    for host in hosts:
        if not host.get("host") or int(host.get("wss_port", 0)) <= 0:
            raise ValueError("invalid secure danmaku endpoint")


def huya_danmaku_identity_probe() -> None:
    """Ensure a live room exposes the numeric uid required by the gateway."""
    recommendation = request_json(
        "https://www.huya.com/cache.php",
        {"m": "LiveList", "do": "getLiveListByPage", "tagAll": 0, "page": 1},
    )
    if not isinstance(recommendation, dict):
        raise ValueError("invalid recommendation response")
    data = recommendation.get("data", {})
    rooms = data.get("datas", []) if isinstance(data, dict) else []
    if not rooms or not isinstance(rooms[0], dict):
        raise ValueError("no live room available for identity probe")
    room_id = str(rooms[0].get("profileRoom", "")).strip()
    if not room_id:
        raise ValueError("recommended room id missing")

    detail = request_json(
        "https://mp.huya.com/cache.php",
        {"m": "Live", "do": "profileRoom", "roomid": room_id, "showSecret": 1},
    )
    if not isinstance(detail, dict) or detail.get("status") != 200:
        raise ValueError(f"room detail status={detail.get('status') if isinstance(detail, dict) else 'invalid'}")
    detail_data = detail.get("data", {})
    profile = detail_data.get("profileInfo", {}) if isinstance(detail_data, dict) else {}
    try:
        uid = int(profile.get("uid", 0)) if isinstance(profile, dict) else 0
    except (TypeError, ValueError) as error:
        raise ValueError("profileInfo.uid is not numeric") from error
    if uid <= 0:
        raise ValueError("profileInfo.uid missing")


def twitch_persisted_request(operation: str, sha256_hash: str, variables: dict[str, object]) -> dict[str, object]:
    return {
        "operationName": operation,
        "variables": variables,
        "extensions": {"persistedQuery": {"version": 1, "sha256Hash": sha256_hash}},
    }


def twitch_gql(payload: object) -> object:
    response = post_json(
        TWITCH_GQL_URL,
        payload,
        headers={"Client-Id": TWITCH_CLIENT_ID, "Device-Id": "12345678901234567890"},
    )
    nodes = response if isinstance(response, list) else [response]
    for node in nodes:
        if not isinstance(node, dict):
            raise ValueError("invalid Twitch GQL response")
        if node.get("errors"):
            raise ValueError(f"Twitch GQL errors: {node['errors']}")
        if "data" not in node:
            raise ValueError("Twitch GQL data missing")
    return response


def twitch_categories_probe() -> None:
    response = twitch_gql(
        twitch_persisted_request(
            "SearchCategoryTags",
            "b4cb189d8d17aadf29c61e9d7c7e7dcfc932e93b77b3209af5661bffb484195f",
            {"userQuery": "", "limit": 5},
        )
    )
    require_path(response, "data", "searchCategoryTags")


def twitch_directory_probe() -> None:
    response = twitch_gql(
        [
            twitch_persisted_request(
                "DirectoryPage_Game",
                "76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f",
                {
                    "imageWidth": 50,
                    "slug": "just-chatting",
                    "options": {
                        "sort": "VIEWER_COUNT",
                        "recommendationsContext": {"platform": "web"},
                        "requestID": "JIRA-VXP-2397",
                        "freeformTags": None,
                        "tags": [],
                        "broadcasterLanguages": [],
                        "systemFilters": [],
                    },
                    "sortTypeIsRecency": False,
                    "limit": 5,
                    "includeCostreaming": True,
                },
            )
        ]
    )
    if not isinstance(response, list) or not response:
        raise ValueError("Twitch directory result missing")
    require_path(response[0], "data", "game", "streams", "edges")


def twitch_search_probe() -> None:
    response = twitch_gql(
        twitch_persisted_request(
            "SearchResultsPage_SearchResults",
            "7f3580f6ac6cd8aa1424cff7c974a07143827d6fa36bba1b54318fe7f0b68dc5",
            {
                "platform": "web",
                "query": "twitch",
                "options": {"targets": None, "shouldSkipDiscoveryControl": False},
                "requestID": "808c9f2e-f52e-431c-8dc7-d2e3c1831d77",
                "includeIsDJ": True,
            },
        )
    )
    require_path(response, "data", "searchFor", "channels", "edges")


def twitch_room_probe() -> None:
    payload = [
        twitch_persisted_request(
            "ChannelShell",
            "fea4573a7bf2644f5b3f2cbbdcbee0d17312e48d2e55f080589d053aad353f11",
            {"login": "twitch"},
        ),
        twitch_persisted_request(
            "StreamMetadata",
            "b57f9b910f8cd1a4659d894fe7550ccc81ec9052c01e438b290fd66a040b9b93",
            {"channelLogin": "twitch", "includeIsDJ": True},
        ),
    ]
    response = twitch_gql(payload)
    if not isinstance(response, list) or len(response) < 2:
        raise ValueError("Twitch room metadata incomplete")
    require_path(response[0], "data", "userOrError", "login")
    require_path(response[1], "data", "user")


def twitch_playback_probe() -> None:
    directory_payload = [
        twitch_persisted_request(
            "DirectoryPage_Game",
            "76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f",
            {
                "imageWidth": 50,
                "slug": "just-chatting",
                "options": {
                    "sort": "VIEWER_COUNT",
                    "recommendationsContext": {"platform": "web"},
                    "requestID": "JIRA-VXP-2397",
                    "freeformTags": None,
                    "tags": [],
                    "broadcasterLanguages": [],
                    "systemFilters": [],
                },
                "sortTypeIsRecency": False,
                "limit": 1,
                "includeCostreaming": True,
            },
        )
    ]
    directory = twitch_gql(directory_payload)
    try:
        login = directory[0]["data"]["game"]["streams"]["edges"][0]["node"]["broadcaster"]["login"]
    except (IndexError, KeyError, TypeError) as error:
        raise ValueError("Twitch live channel missing") from error
    response = twitch_gql(
        twitch_persisted_request(
            "PlaybackAccessToken",
            "ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9",
            {
                "isLive": True,
                "login": login,
                "isVod": False,
                "vodID": "",
                "playerType": "site",
                "isClip": False,
                "clipID": "",
                "platform": "site",
            },
        )
    )
    require_path(response, "data", "streamPlaybackAccessToken", "value")
    require_path(response, "data", "streamPlaybackAccessToken", "signature")


def main() -> int:
    probes = [
        (
            "bilibili.categories",
            lambda: require_path(
                request_json("https://api.live.bilibili.com/room/v1/Area/getList", {"need_entrance": 1, "parent_id": 0}),
                "data",
            ),
        ),
        (
            "douyu.categories",
            lambda: require_path(request_json("https://m.douyu.com/api/cate/list"), "data", "cate1Info"),
        ),
        (
            "douyu.recommend",
            lambda: require_path(request_json("https://www.douyu.com/japi/weblist/apinc/allpage/6/1"), "data", "rl"),
        ),
        (
            "huya.categories",
            lambda: require_path(
                request_json("https://live.cdn.huya.com/liveconfig/game/bussLive", {"bussType": 1}), "data"
            ),
        ),
        (
            "huya.recommend",
            lambda: require_path(
                request_json(
                    "https://www.huya.com/cache.php",
                    {"m": "LiveList", "do": "getLiveListByPage", "tagAll": 0, "page": 1},
                ),
                "data",
                "datas",
            ),
        ),
        (
            "kuaishou.categories",
            lambda: require_path(
                request_json("https://live.kuaishou.com/live_api/category/data", {"type": 1, "page": 1, "size": 30}),
                "data",
                "list",
            ),
        ),
        (
            "kuaishou.home",
            lambda: require_path(request_json("https://live.kuaishou.com/live_api/home/list"), "data", "list"),
        ),
        (
            "cc.categories",
            lambda: require_path(request_json("https://cc.163.com/category/", {"format": "json"}), "game_list"),
        ),
        (
            "cc.recommend",
            lambda: require_path(
                request_json("https://cc.163.com/api/category/live/", {"format": "json", "start": 0, "size": 30}),
                "lives",
            ),
        ),
        ("bilibili.danmaku", bilibili_danmaku_probe),
        ("huya.danmaku_identity", huya_danmaku_identity_probe),
        (
            "douyu.search",
            lambda: require_path(
                request_json(
                    "https://www.douyu.com/japi/search/api/searchShow",
                    {"kw": "ASMR", "page": 1, "pageSize": 20},
                ),
                "data",
                "relateShow",
            ),
        ),
        (
            "huya.search",
            lambda: require_path(
                request_json(
                    "https://search.cdn.huya.com/",
                    {
                        "m": "Search",
                        "do": "getSearchContent",
                        "q": "ASMR",
                        "uid": 0,
                        "v": 4,
                        "typ": -5,
                        "livestate": 0,
                        "rows": 20,
                        "start": 0,
                    },
                ),
                "response",
            ),
        ),
        (
            "cc.search",
            lambda: require_path(
                request_json("https://cc.163.com/search/anchor", {"query": "ASMR", "size": 20, "page": 1}),
                "webcc_anchor",
                "result",
            ),
        ),
        ("twitch.categories", twitch_categories_probe),
        ("twitch.directory", twitch_directory_probe),
        ("twitch.search", twitch_search_probe),
        ("twitch.room", twitch_room_probe),
        ("twitch.playback", twitch_playback_probe),
    ]

    failures: list[str] = []
    for name, probe in probes:
        try:
            probe()
            print(f"PASS {name}")
        except Exception as error:  # noqa: BLE001 - command-line diagnostic
            failures.append(name)
            print(f"FAIL {name}: {error}")

    try:
        request = urllib.request.Request("https://live.douyin.com/?from_nav=1", headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=20) as response:
            html = response.read().decode("utf-8", errors="replace")
            cookies = response.headers.get_all("Set-Cookie") or []
        if r'{\"pathname\":\"/\",\"categoryData\":' not in html:
            raise ValueError("categoryData marker missing")
        if not any(cookie.startswith("ttwid=") for cookie in cookies):
            raise ValueError("anonymous ttwid cookie missing")
        print("PASS douyin.home")
    except Exception as error:  # noqa: BLE001 - command-line diagnostic
        failures.append("douyin.home")
        print(f"FAIL douyin.home: {error}")

    print(f"SUMMARY {len(probes) + 1 - len(failures)}/{len(probes) + 1} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
