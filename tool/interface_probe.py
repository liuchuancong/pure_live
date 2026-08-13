#!/usr/bin/env python3
"""Dependency-free smoke probes for the public endpoints used by Pure Live."""

from __future__ import annotations

import json
import sys
import time
import urllib.parse
import urllib.request

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
                payload = response.read().decode("utf-8", errors="replace")
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
