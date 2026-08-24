#!/usr/bin/env python3
"""Dependency-free smoke probes for the public endpoints used by Pure Live."""

from __future__ import annotations

import json
import hashlib
import gzip
import html
import re
import secrets
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


def post_form_json(
    url: str,
    payload: dict[str, object],
    params: dict[str, object] | None = None,
    attempts: int = 3,
    headers: dict[str, str] | None = None,
) -> object:
    """POST form data with bounded retries for platform player endpoints."""
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    body = urllib.parse.urlencode(payload).encode()
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(
                url,
                data=body,
                method="POST",
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "application/json,text/plain,*/*",
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Origin": "https://www.sooplive.co.kr",
                    "Referer": "https://www.sooplive.co.kr/",
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


def douyu_encryption_probe() -> None:
    """Validate the current pure-Dart signing descriptor and its time unit."""
    payload = request_json(
        "https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption",
        {"did": "10000000000000000000000000001501"},
    )
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        raise ValueError("Douyu encryption payload is missing data")
    for key in ("key", "rand_str", "enc_data"):
        if not str(data.get(key, "")).strip():
            raise ValueError(f"Douyu encryption payload is missing {key}")
    enc_time = int(data.get("enc_time", 0))
    expire_at = int(data.get("expire_at", 0))
    if not 1 <= enc_time <= 16:
        raise ValueError("Douyu encryption iteration count is out of bounds")
    if expire_at <= int(time.time()):
        raise ValueError("Douyu encryption descriptor is already expired")


def douyu_playback_probe() -> None:
    """Exercise signing, H5 metadata, CDN URL and the actual FLV header."""
    did = secrets.token_hex(16)
    descriptor_payload = request_json(
        "https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption",
        {"did": did},
    )
    descriptor = descriptor_payload.get("data") if isinstance(descriptor_payload, dict) else None
    if not isinstance(descriptor, dict):
        raise ValueError("Douyu encryption payload is missing data")

    recommendation = request_json("https://www.douyu.com/japi/weblist/apinc/allpage/6/1")
    rooms = recommendation.get("data", {}).get("rl", []) if isinstance(recommendation, dict) else []
    if not isinstance(rooms, list) or not rooms:
        raise ValueError("Douyu recommendation returned no rooms")

    errors: list[str] = []
    for room in rooms[:10]:
        room_id = str(room.get("rid", "")).strip() if isinstance(room, dict) else ""
        if not room_id:
            continue
        try:
            timestamp = int(time.time())
            key = str(descriptor["key"])
            secret = str(descriptor["rand_str"])
            iterations = int(descriptor["enc_time"])
            for _ in range(iterations):
                secret = hashlib.md5(f"{secret}{key}".encode()).hexdigest()
            salt = "" if int(descriptor.get("is_special", 0)) == 1 else f"{room_id}{timestamp}"
            auth = hashlib.md5(f"{secret}{key}{salt}".encode()).hexdigest()
            form = {
                "enc_data": descriptor["enc_data"],
                "tt": timestamp,
                "did": did,
                "auth": auth,
                "cdn": "",
                "rate": -1,
                "hevc": 0,
                "fa": 0,
                "ive": 0,
                "ver": "Douyu_new",
                "iar": 0,
            }
            headers = {
                "Origin": "https://www.douyu.com",
                "Referer": f"https://www.douyu.com/{room_id}",
                "Cookie": f"dy_did={did}; acf_did={did}",
            }
            response = post_form_json(
                f"https://www.douyu.com/lapi/live/getH5PlayV1/{room_id}",
                form,
                attempts=2,
                headers=headers,
            )
            if not isinstance(response, dict) or int(response.get("error", -1)) != 0:
                raise ValueError(f"H5 error={response.get('error') if isinstance(response, dict) else 'invalid'}")
            data = response.get("data")
            if not isinstance(data, dict):
                raise ValueError("H5 playback data missing")
            rates = data.get("multirates")
            cdns = data.get("cdnsWithName")
            if not isinstance(rates, list) or not rates:
                raise ValueError("H5 quality list missing")
            if not isinstance(cdns, list) or not cdns:
                raise ValueError("H5 CDN list missing")
            base = str(data.get("rtmp_url", "")).rstrip("/")
            live = html.unescape(str(data.get("rtmp_live", ""))).lstrip("/")
            stream_url = live if live.startswith(("http://", "https://")) else f"{base}/{live}"
            if not stream_url.startswith(("http://", "https://")):
                raise ValueError("H5 stream URL missing")
            stream_request = urllib.request.Request(
                stream_url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Origin": "https://www.douyu.com",
                    "Referer": f"https://www.douyu.com/{room_id}",
                    "Cookie": f"dy_did={did}; acf_did={did}",
                    "Range": "bytes=0-31",
                    "Connection": "close",
                },
            )
            with urllib.request.urlopen(stream_request, timeout=20) as stream_response:
                prefix = stream_response.read(16)
            if not prefix.startswith(b"FLV"):
                raise ValueError(f"CDN returned a non-FLV prefix: {prefix[:8]!r}")
            return
        except Exception as error:  # noqa: BLE001 - try another active room
            errors.append(f"{room_id}: {error}")
    raise ValueError("; ".join(errors[-3:]) or "no usable Douyu room")


def douyu_search_probe() -> None:
    """Validate the anonymous search contract without relying on one keyword."""
    errors: list[str] = []
    for keyword in ("ASMR", "", "英雄联盟"):
        try:
            response = request_json(
                "https://www.douyu.com/japi/search/api/searchShow",
                {"kw": keyword, "page": 1, "pageSize": 20},
            )
            data = response.get("data") if isinstance(response, dict) and response.get("error") == 0 else None
            if isinstance(data, dict) and isinstance(data.get("relateShow"), list):
                return
            errors.append(f"{keyword or '<empty>'}: invalid response shape")
        except Exception as error:  # noqa: BLE001 - verify bounded query variants
            errors.append(f"{keyword or '<empty>'}: {error}")
    raise ValueError("; ".join(errors))


_yy_room_cache: dict[str, object] | None = None


def yy_live_room() -> dict[str, object]:
    global _yy_room_cache
    if _yy_room_cache is not None:
        return _yy_room_cache
    response = request_json(
        "https://www.yy.com/more/page.action",
        {"page": 1, "pageSize": 10, "biz": "other", "subBiz": "idx", "moduleId": -1},
    )
    rooms = response.get("data", {}).get("data", []) if isinstance(response, dict) else []
    for room in rooms if isinstance(rooms, list) else []:
        room_id = str(room.get("sid", "")).strip() if isinstance(room, dict) else ""
        if not room_id:
            continue
        detail = request_json(f"https://www.yy.com/api/liveInfoDetail/{room_id}/{room_id}/0")
        data = detail.get("data") if isinstance(detail, dict) and detail.get("resultCode") == 0 else None
        if isinstance(data, dict) and str(data.get("sid", "")).strip():
            _yy_room_cache = data
            return data
    raise ValueError("YY recommendation has no verifiable live room")


def yy_room_probe() -> None:
    room = yy_live_room()
    for key in ("sid", "ssid", "uid", "name", "users"):
        if room.get(key) in (None, ""):
            raise ValueError(f"YY room field missing: {key}")


def yy_search_probe() -> None:
    room = yy_live_room()
    keyword = str(room.get("name", "")).strip() or "YY"
    response = request_json(
        "https://www.yy.com/apiSearch/doSearch.json",
        {"q": keyword, "t": 120, "n": 1},
    )
    search_result = response.get("data", {}).get("searchResult", {}) if isinstance(response, dict) else {}
    docs = search_result.get("response", {}).get("120", {}).get("docs", {}) if isinstance(search_result, dict) else {}
    if not isinstance(docs, list):
        raise ValueError("YY live search docs missing")


def yy_anchor_search_probe() -> None:
    room = yy_live_room()
    keyword = str(room.get("name", "")).strip() or "YY"
    response = request_json(
        "https://www.yy.com/apiSearch/doSearch.json",
        {"q": keyword, "t": 1, "n": 1},
    )
    search_result = response.get("data", {}).get("searchResult", {}) if isinstance(response, dict) else {}
    docs = search_result.get("response", {}).get("1", {}).get("docs", []) if isinstance(search_result, dict) else []
    if not isinstance(docs, list) or not docs or not isinstance(docs[0], dict):
        raise ValueError("YY anchor search docs missing")
    for key in ("sid", "name", "liveOn"):
        if key not in docs[0]:
            raise ValueError(f"YY anchor field missing: {key}")


def yy_playback_probe() -> None:
    room = yy_live_room()
    room_id = str(room["sid"])
    sequence = int(time.time() * 1000)
    query = urllib.parse.urlencode(
        {
            "uid": 0,
            "cid": room_id,
            "sid": room_id,
            "appid": 0,
            "sequence": sequence,
            "encode": "json",
        }
    )
    response = post_json(
        f"https://stream-manager.yy.com/v3/channel/streams?{query}",
        {
            "head": {
                "seq": sequence,
                "appidstr": "0",
                "bidstr": "123",
                "cidstr": room_id,
                "sidstr": room_id,
                "uid64": 0,
                "client_type": 108,
                "client_ver": "5.19.4",
                "stream_sys_ver": 1,
                "app": "yylive_web",
                "playersdk_ver": "5.19.4",
                "thundersdk_ver": "0",
                "streamsdk_ver": "5.19.4",
            },
            "client_attribute": {
                "client": "web",
                "model": "web0",
                "cpu": "",
                "graphics_card": "",
                "os": "chrome",
                "osversion": "128.0.0.0",
                "width": "1366",
                "height": "768",
                "client_type": 8,
                "h265": 0,
            },
            "avp_parameter": {
                "version": 1,
                "client_type": 8,
                "service_type": 0,
                "imsi": 0,
                "send_time": int(time.time()),
                "line_seq": -1,
                "gear": 1,
                "ssl": 1,
                "stream_format": 0,
            },
        },
        headers={
            "Content-Type": "application/json",
            "Origin": "https://www.yy.com",
            "Referer": f"https://www.yy.com/{room_id}",
        },
    )
    streams = response.get("channel_stream_info", {}).get("streams", []) if isinstance(response, dict) else []
    lines = response.get("avp_info_res", {}).get("stream_line_addr", {}) if isinstance(response, dict) else {}
    if not isinstance(streams, list) or not streams:
        raise ValueError("YY quality list missing")
    if not isinstance(lines, dict) or not any(
        isinstance(value, dict) and str(value.get("cdn_info", {}).get("url", "")).startswith("https://")
        for value in lines.values()
    ):
        raise ValueError("YY playback lines missing")


def kuaishou_playback_probe() -> None:
    """Validate the current live/replay list shape and room-page status."""
    payload = request_json("https://live.kuaishou.com/live_api/home/list")
    if not isinstance(payload, dict):
        raise ValueError("Kuaishou home payload is not an object")
    groups = payload.get("data", {}).get("list", [])
    candidates: list[dict[str, object]] = []
    for group in groups if isinstance(groups, list) else []:
        for game in group.get("gameLiveInfo", []) if isinstance(group, dict) else []:
            for item in game.get("liveInfo", []) if isinstance(game, dict) else []:
                if isinstance(item, dict):
                    candidates.append(item)
    if not candidates:
        raise ValueError("Kuaishou home list has no room cards")

    selected: dict[str, object] | None = None
    for item in candidates:
        play_urls = item.get("playUrls")
        descriptors = play_urls if isinstance(play_urls, list) else [play_urls]
        for descriptor in descriptors:
            if not isinstance(descriptor, dict):
                continue
            adaptation = descriptor.get("adaptationSet")
            representations = adaptation.get("representation") if isinstance(adaptation, dict) else None
            if isinstance(representations, list) and any(
                isinstance(rep, dict) and str(rep.get("url", "")).startswith(("http://", "https://"))
                for rep in representations
            ):
                selected = item
                break
        if selected is not None:
            break
    if selected is None:
        raise ValueError("Kuaishou list has no playable live/replay descriptor")

    author = selected.get("author")
    room_id = str(author.get("id", "")) if isinstance(author, dict) else ""
    if not room_id:
        raise ValueError("Kuaishou playback card is missing author id")
    request = urllib.request.Request(
        f"https://live.kuaishou.com/u/{urllib.parse.quote(room_id)}",
        headers={"User-Agent": USER_AGENT, "Connection": "close"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        html = response.read().decode("utf-8", errors="replace")
    match = re.search(r"window\.__INITIAL_STATE__=(.*?);", html)
    if match is None:
        raise ValueError("Kuaishou room initial state marker is missing")
    state = json.loads(match.group(1).replace("undefined", "null"))
    rooms = state.get("liveroom", {}).get("playList", []) if isinstance(state, dict) else []
    if (
        not isinstance(rooms, list)
        or not rooms
        or not isinstance(rooms[0], dict)
        or not isinstance(rooms[0].get("isLiving"), bool)
    ):
        raise ValueError("Kuaishou room status is missing")


def douyin_search_probe() -> None:
    """Exercise the anonymous partition fallback used when live search asks for login."""
    cookie_jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))

    def get_json(url: str, params: dict[str, object]) -> object:
        request = urllib.request.Request(
            f"{url}?{urllib.parse.urlencode(params)}",
            headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/json,text/plain,*/*",
                "Accept-Language": "zh-CN,zh;q=0.9",
                "Referer": "https://live.douyin.com/",
                "Connection": "close",
            },
        )
        with opener.open(request, timeout=20) as response:
            payload = response.read()
        if not payload.strip():
            raise ValueError("empty response body")
        return json.loads(payload.decode("utf-8", errors="replace").lstrip("\ufeff"))

    home_request = urllib.request.Request(
        "https://live.douyin.com/?from_nav=1",
        headers={"User-Agent": USER_AGENT, "Connection": "close"},
    )
    with opener.open(home_request, timeout=20) as response:
        response.read(1)
    if not any(cookie.name == "ttwid" for cookie in cookie_jar):
        raise ValueError("anonymous ttwid cookie missing")

    search = get_json(
        "https://live.douyin.com/webcast/web/partition/search/",
        {"keyword": "三角洲", "aid": 6383},
    )
    require_path(search, "data", "SearchResult")
    partitions = search["data"]["SearchResult"]  # type: ignore[index]
    if not isinstance(partitions, list) or not partitions:
        raise ValueError("partition search returned no matching category")
    partition = partitions[0].get("partition") if isinstance(partitions[0], dict) else None
    if not isinstance(partition, dict) or not partition.get("id_str") or partition.get("type") is None:
        raise ValueError("partition search returned an invalid category")

    params = {
        "aid": 6383,
        "app_name": "douyin_web",
        "live_id": 1,
        "device_platform": "web",
        "language": "zh-CN",
        "browser_language": "zh-CN",
        "browser_platform": "Win32",
        "browser_name": "Chrome",
        "browser_version": "140.0.0.0",
        "partition": partition["id_str"],
        "partition_type": partition["type"],
        "count": 5,
        "offset": 0,
        "cookie_enabled": "true",
        "screen_width": 1920,
        "screen_height": 1080,
    }
    errors: list[str] = []
    for endpoint in (
        "https://live.douyin.com/webcast/web/partition/detail/room/v2/",
        "https://webcast.amemv.com/webcast/web/partition/detail/room/v2/",
    ):
        try:
            response = get_json(endpoint, params)
            require_path(response, "data", "data")
            rooms = response["data"]["data"]  # type: ignore[index]
            if isinstance(rooms, list) and rooms:
                return
            errors.append(f"{endpoint}: empty room list")
        except Exception as error:  # noqa: BLE001 - verify both production fallbacks
            errors.append(f"{endpoint}: {error}")
    raise ValueError("; ".join(errors))


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


def bilibili_recommend_probe() -> None:
    """Validate the anonymous popularity feed and a transformed cover URL."""
    response = request_json(
        "https://api.live.bilibili.com/room/v1/Area/getListByAreaID",
        {"areaId": 0, "parent_area_id": 0, "sort": "online", "pageSize": 30, "page": 1},
    )
    if not isinstance(response, dict) or response.get("code") != 0:
        raise ValueError(f"recommend code={response.get('code') if isinstance(response, dict) else 'invalid'}")
    rooms = response.get("data", [])
    if not rooms or not isinstance(rooms[0], dict):
        raise ValueError("popularity room list missing")
    if any(not str(room.get("online", "")).isdigit() for room in rooms if isinstance(room, dict)):
        raise ValueError("popularity value missing")
    cover = str(rooms[0].get("cover", "")).strip()
    if not cover.startswith("https://"):
        raise ValueError("recommend cover URL missing")
    cover_request = urllib.request.Request(
        f"{cover}@400w.jpg",
        headers={"User-Agent": USER_AGENT, "Referer": "https://live.bilibili.com/", "Accept": "image/*"},
    )
    with urllib.request.urlopen(cover_request, timeout=20) as cover_response:
        if cover_response.status != 200 or not cover_response.headers.get_content_type().startswith("image/"):
            raise ValueError(f"cover response={cover_response.status} {cover_response.headers.get_content_type()}")
        if len(cover_response.read(128)) < 64:
            raise ValueError("cover response is empty")


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
        if "data" not in node:
            raise ValueError("Twitch GQL data missing")
        # Twitch may return usable search data together with errors from an
        # unrelated nested field (for example ``latestVideo``).  Match the
        # client behaviour and only reject the response when no data survived.
        if node.get("errors") and node.get("data") is None:
            raise ValueError(f"Twitch GQL errors: {node['errors']}")
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


def twitch_directory_request(slug: str, *, limit: int = 5) -> dict[str, object]:
    return twitch_persisted_request(
        "DirectoryPage_Game",
        "76cb069d835b8a02914c08dc42c421d0dafda8af5b113a3f19141824b901402f",
        {
            "imageWidth": 50,
            "slug": slug,
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
            "limit": limit,
            "includeCostreaming": True,
        },
    )


def twitch_directory_probe() -> None:
    response = twitch_gql([twitch_directory_request("just-chatting")])
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
    # A single category can legitimately be empty for a locale, maturity
    # filter or transient directory rollout. Probe several high-traffic
    # categories in one bounded GQL request and select the first actual live
    # channel instead of treating one empty category as playback breakage.
    slugs = ("just-chatting", "grand-theft-auto-v", "league-of-legends", "valorant", "music")
    directory = twitch_gql([twitch_directory_request(slug) for slug in slugs])
    login = None
    if isinstance(directory, list):
        for result in directory:
            try:
                edges = result["data"]["game"]["streams"]["edges"]
            except (KeyError, TypeError):
                continue
            if not isinstance(edges, list):
                continue
            for edge in edges:
                try:
                    candidate = edge["node"]["broadcaster"]["login"]
                except (KeyError, TypeError):
                    continue
                if isinstance(candidate, str) and candidate.strip():
                    login = candidate.strip()
                    break
            if login:
                break
    if not login:
        raise ValueError("Twitch live channel missing across active categories")
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


_soop_channel_cache: dict[str, object] | None = None


def soop_live_channel() -> dict[str, object]:
    global _soop_channel_cache
    if _soop_channel_cache is not None:
        return _soop_channel_cache
    recommendation = request_json(
        "https://live.sooplive.co.kr/api/main_broad_list_api.php",
        {"selectType": "action", "selectValue": "all", "orderType": "view_cnt", "pageNo": 1, "lang": "ko_KR"},
    )
    rooms = recommendation.get("broad", []) if isinstance(recommendation, dict) else []
    if not rooms:
        raise ValueError("SOOP recommendation returned no live rooms")

    # The popularity feed may put an age-restricted or password-protected room
    # first.  Such a room is live, but the anonymous player endpoint rejects it
    # and used to make all SOOP probes fail spuriously.  Probe a bounded slice
    # of current, public recommendations and cache the first playable channel.
    attempted = 0
    for room in rooms[:20]:
        if not isinstance(room, dict):
            continue
        if str(room.get("is_password", "N")).upper() == "Y":
            continue
        if str(room.get("broad_grade", "0")) not in ("", "0"):
            continue
        room_id = str(room.get("user_id", "")).strip()
        if not room_id:
            continue
        attempted += 1
        try:
            response = post_form_json(
                "https://live.sooplive.co.kr/afreeca/player_live_api.php",
                {
                    "bid": room_id,
                    "bno": str(room.get("broad_no", "")).strip(),
                    "type": "live",
                    "pwd": "",
                    "player_type": "html5",
                    "stream_type": "common",
                    "quality": "HD",
                    "mode": "landing",
                    "from_api": "0",
                    "is_revive": "false",
                },
                {"bjid": room_id},
            )
        except Exception:  # noqa: BLE001 - try another current recommendation
            continue
        channel = response.get("CHANNEL", {}) if isinstance(response, dict) else {}
        if isinstance(channel, dict) and channel.get("RESULT") == 1:
            _soop_channel_cache = channel
            return channel
    raise ValueError(f"SOOP found no anonymous playable channel in {attempted} candidates")


def soop_search_probe() -> None:
    room_id = str(soop_live_channel().get("BJID", "")).strip()
    response = request_json(
        "https://sch.sooplive.co.kr/api.php",
        {
            "l": "DF",
            "m": "liveSearch",
            "c": "UTF-8",
            "w": "webk",
            "isMobile": 0,
            "onlyParent": 1,
            "szType": "json",
            "szOrder": "score",
            "szKeyword": room_id,
            "nPageNo": 1,
            "nListCnt": 5,
            "tab": "live",
            "location": "total_search",
            "isHashSearch": 0,
            "v": "2.0",
        },
    )
    if not isinstance(response, dict) or not isinstance(response.get("REAL_BROAD"), list):
        raise ValueError("SOOP live search result missing")


def soop_room_probe() -> None:
    channel = soop_live_channel()
    for key in ("BNO", "BJID", "CHATNO", "CHDOMAIN", "CHPT", "VIEWPRESET"):
        if key not in channel or channel[key] in (None, "", []):
            raise ValueError(f"SOOP player field missing: {key}")


def soop_playback_probe() -> None:
    channel = soop_live_channel()
    room_id = str(channel["BJID"])
    bno = str(channel["BNO"])
    presets = channel["VIEWPRESET"]
    if not isinstance(presets, list) or not presets or not isinstance(presets[0], dict):
        raise ValueError("SOOP quality presets missing")
    quality = str(presets[0].get("name", "")).strip()
    aid_response = post_form_json(
        "https://live.sooplive.co.kr/afreeca/player_live_api.php",
        {
            "bid": room_id,
            "bno": bno,
            "type": "aid",
            "pwd": "",
            "player_type": "html5",
            "stream_type": "common",
            "quality": quality,
            "mode": "landing",
            "from_api": "0",
            "is_revive": "false",
        },
        {"bjid": room_id},
    )
    require_path(aid_response, "CHANNEL", "AID")


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
        ("douyu.encryption", douyu_encryption_probe),
        ("douyu.playback", douyu_playback_probe),
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
        ("kuaishou.playback", kuaishou_playback_probe),
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
        ("bilibili.popularity_rank", bilibili_recommend_probe),
        ("bilibili.danmaku", bilibili_danmaku_probe),
        ("huya.danmaku_identity", huya_danmaku_identity_probe),
        ("douyin.search", douyin_search_probe),
        ("douyu.search", douyu_search_probe),
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
        (
            "soop.categories",
            lambda: require_path(
                request_json(
                    "https://sch.sooplive.co.kr/api.php",
                    {
                        "m": "categoryList",
                        "szKeyword": "",
                        "szOrder": "view_cnt",
                        "nPageNo": 1,
                        "nListCnt": 5,
                        "nOffset": 0,
                        "szPlatform": "pc",
                    },
                ),
                "data",
                "list",
            ),
        ),
        (
            "soop.recommend",
            lambda: require_path(
                request_json(
                    "https://live.sooplive.co.kr/api/main_broad_list_api.php",
                    {
                        "selectType": "action",
                        "selectValue": "all",
                        "orderType": "view_cnt",
                        "pageNo": 1,
                        "lang": "ko_KR",
                    },
                ),
                "broad",
            ),
        ),
        ("soop.search", soop_search_probe),
        ("soop.room", soop_room_probe),
        ("soop.playback_token", soop_playback_probe),
        (
            "yy.categories",
            lambda: require_path(request_json("https://www.yy.com/yyweb/module/data/header"), "categoryTabs"),
        ),
        (
            "yy.recommend",
            lambda: require_path(
                request_json(
                    "https://www.yy.com/more/page.action",
                    {"page": 1, "pageSize": 5, "biz": "other", "subBiz": "idx", "moduleId": -1},
                ),
                "data",
                "data",
            ),
        ),
        ("yy.search", yy_search_probe),
        ("yy.anchor_search", yy_anchor_search_probe),
        ("yy.room", yy_room_probe),
        ("yy.playback", yy_playback_probe),
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
        last_error: Exception | None = None
        for attempt in range(1, 4):
            try:
                request = urllib.request.Request(
                    "https://live.douyin.com/?from_nav=1",
                    headers={"User-Agent": USER_AGENT, "Connection": "close"},
                )
                with urllib.request.urlopen(request, timeout=20) as response:
                    html = response.read().decode("utf-8", errors="replace")
                    cookies = response.headers.get_all("Set-Cookie") or []
                if r'{\"pathname\":\"/\",\"categoryData\":' not in html:
                    raise ValueError("categoryData marker missing")
                if not any(cookie.startswith("ttwid=") for cookie in cookies):
                    raise ValueError("anonymous ttwid cookie missing")
                break
            except Exception as error:  # noqa: BLE001 - bounded transient retry
                last_error = error
                if attempt < 3:
                    time.sleep(attempt)
        else:
            assert last_error is not None
            raise last_error
        print("PASS douyin.home")
    except Exception as error:  # noqa: BLE001 - command-line diagnostic
        failures.append("douyin.home")
        print(f"FAIL douyin.home: {error}")

    print(f"SUMMARY {len(probes) + 1 - len(failures)}/{len(probes) + 1} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
