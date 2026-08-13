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
