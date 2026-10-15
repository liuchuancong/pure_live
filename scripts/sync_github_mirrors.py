
#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit


SOURCE_REPOSITORY = "XIU2/UserScript"
SOURCE_FILE = "GithubEnhanced-High-Speed-Download.user.js"

DEFAULT_GENERIC_PRESETS = [
    "https://gh-proxy.org/",
    "https://v4.gh-proxy.org/",
    "https://cdn.gh-proxy.org/",
]

RAW_ORIGIN = "https://raw.githubusercontent.com"
GITHUB_ORIGIN = "https://github.com"

MAX_SOURCE_BYTES = 2 * 1024 * 1024
MIN_SOURCE_BYTES = 10_000
MAX_ENTRIES_PER_GROUP = 200

URL_ENTRY_RE = re.compile(
    r"""^\s*\[\s*(['"])(https://[^'"]+)\1\s*,"""
)


def validate_https_url(value: str) -> str:
    """Validate an HTTPS endpoint while preserving its path and query."""
    value = value.strip()
    parsed = urlsplit(value)

    if parsed.scheme.lower() != "https":
        raise ValueError(f"Non-HTTPS endpoint: {value}")

    if not parsed.hostname:
        raise ValueError(f"Missing hostname: {value}")

    if parsed.username or parsed.password:
        raise ValueError(f"Credentials are not allowed: {value}")

    try:
        port = parsed.port
    except ValueError as exc:
        raise ValueError(f"Invalid port in URL: {value}") from exc

    if port is not None and not 1 <= port <= 65535:
        raise ValueError(f"Invalid port in URL: {value}")

    if any(ord(char) < 32 for char in value):
        raise ValueError("Control characters are not allowed in URLs.")

    return value


def read_array(
    source: str,
    variable: str,
    next_variable: str,
) -> list[str]:
    """Extract the first URL from each active array entry."""
    start_match = re.search(
        rf"\b{re.escape(variable)}\s*=\s*\[",
        source,
    )
    if not start_match:
        raise ValueError(f"Upstream array not found: {variable}")

    end_match = re.search(
        rf"\]\s*,\s*{re.escape(next_variable)}\s*=",
        source[start_match.end():],
    )
    if not end_match:
        raise ValueError(
            f"Cannot find the end of {variable} before {next_variable}."
        )

    section = source[
        start_match.end():
        start_match.end() + end_match.start()
    ]

    entries: list[str] = []

    for line in section.splitlines():
        # Array entries are single-line in the upstream script.
        # Full-line comments are intentionally ignored.
        if line.lstrip().startswith("//"):
            continue

        match = URL_ENTRY_RE.match(line)
        if not match:
            continue

        endpoint = validate_https_url(match.group(2))
        entries.append(endpoint)

    if not entries:
        raise ValueError(f"No active URL entries found in {variable}.")

    if len(entries) > MAX_ENTRIES_PER_GROUP:
        raise ValueError(f"Too many entries in {variable}.")

    return list(dict.fromkeys(entries))


def classify_raw(url: str) -> dict | None:
    # The official Raw URL is the direct fallback, not a mirror.
    if url.rstrip("/") == RAW_ORIGIN:
        return None

    if url.startswith(RAW_ORIGIN + "/"):
        return None

    if url.startswith("https://fastly.jsdelivr.net/gh"):
        return {
            "url": url,
            "strategy": "jsdelivrGh",
        }

    if url.startswith("https://gcore.jsdelivr.net/gh"):
        return {
            "url": url,
            "strategy": "jsdelivrGh",
        }

    if url.startswith("https://jsdelivr.pai233.top/gh"):
        return {
            "url": url,
            "strategy": "jsdelivrGh",
        }

    if url.startswith("https://jsd.proxy.aks.moe/gh"):
        return {
            "url": url,
            "strategy": "jsdelivrGh",
        }

    if url.startswith(RAW_ORIGIN):
        return {
            "url": url,
            "strategy": "replaceUrlPrefix",
            "sourcePrefix": RAW_ORIGIN,
        }

    # Raw endpoints such as raw.bgithub.xyz use a different URL layout.
    # Preserve the endpoint, but don't guess how to rewrite its path.
    return {
        "url": url,
        "strategy": "manualReview",
    }


def classify_download(url: str) -> dict:
    if url.startswith(GITHUB_ORIGIN):
        return {
            "url": url,
            "strategy": "direct",
        }

    if url.endswith("/https://github.com"):
        return {
            "url": url,
            "strategy": "replaceUrlPrefix",
            "sourcePrefix": GITHUB_ORIGIN,
        }

    if url.endswith("/github.com"):
        return {
            "url": url,
            "strategy": "replaceUrlPrefix",
            "sourcePrefix": GITHUB_ORIGIN,
        }

    if "?https://github.com" in url:
        return {
            "url": url,
            "strategy": "queryProxy",
            "sourcePrefix": GITHUB_ORIGIN,
        }

    # Some services have a provider-specific URL layout.
    # Keep them out of automatic rewriting until explicitly supported.
    return {
        "url": url,
        "strategy": "manualReview",
    }


def deduplicate_objects(entries: list[dict]) -> list[dict]:
    result: list[dict] = []
    seen: set[tuple[str, str]] = set()

    for entry in entries:
        key = (entry["url"], entry["strategy"])
        if key not in seen:
            seen.add(key)
            result.append(entry)

    return result


def load_existing(path: Path) -> dict:
    if not path.exists():
        return {}

    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"Cannot read existing config: {exc}") from exc

    if not isinstance(value, dict):
        raise ValueError("Existing configuration must be a JSON object.")

    return value


def build_config(source: str, existing: dict) -> dict:
    if "Github Enhancement - High Speed Download" not in source:
        raise ValueError("Unexpected upstream userscript signature.")

    download_urls = read_array(
        source,
        "download_url_us",
        "clone_url",
    )
    raw_urls = read_array(
        source,
        "raw_url",
        "svg",
    )

    raw_entries = deduplicate_objects([
        item
        for url in raw_urls
        if (item := classify_raw(url)) is not None
    ])

    download_entries = deduplicate_objects([
        classify_download(url)
        for url in download_urls
    ])

    if not raw_entries:
        raise ValueError("No Raw mirror entries were extracted.")

    if not download_entries:
        raise ValueError("No download mirror entries were extracted.")

    previous_sources = existing.get("sources", {})
    if not isinstance(previous_sources, dict):
        previous_sources = {}

    previous_generic = previous_sources.get("genericProxy", {})
    if not isinstance(previous_generic, dict):
        previous_generic = {}

    previous_presets = previous_generic.get(
        "presets",
        DEFAULT_GENERIC_PRESETS,
    )
    if not isinstance(previous_presets, list):
        previous_presets = DEFAULT_GENERIC_PRESETS

    generic_presets = list(dict.fromkeys(
        DEFAULT_GENERIC_PRESETS
        + [
            value
            for value in previous_presets
            if isinstance(value, str)
            and value.startswith("https://")
        ]
    ))

    return {
        "schemaVersion": 2,
        "source": {
            "repository": SOURCE_REPOSITORY,
            "file": SOURCE_FILE,
            "license": "GPL-3.0",
        },
        "sources": {
            "genericProxy": {
                "presets": generic_presets,
            },
            "raw": {
                "presets": raw_entries,
            },
            "download": {
                "presets": download_entries,
            },
        },
        "updatedAt": datetime.now(timezone.utc).isoformat(
            timespec="seconds"
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        if not args.source.is_file():
            raise ValueError(f"Source file not found: {args.source}")

        if args.source.stat().st_size > MAX_SOURCE_BYTES:
            raise ValueError("Upstream source exceeds the size limit.")

        if args.source.stat().st_size < MIN_SOURCE_BYTES:
            raise ValueError("Upstream source is unexpectedly small.")

        source = args.source.read_text(encoding="utf-8")
        existing = load_existing(args.output)
        config = build_config(source, existing)

        output = json.dumps(
            config,
            ensure_ascii=False,
            indent=2,
        ) + "\n"

        args.output.parent.mkdir(parents=True, exist_ok=True)
        temp_path = args.output.with_suffix(
            args.output.suffix + ".tmp"
        )
        temp_path.write_text(output, encoding="utf-8")
        temp_path.replace(args.output)

        print(
            "Raw mirrors:",
            len(config["sources"]["raw"]["presets"]),
        )
        print(
            "Download mirrors:",
            len(config["sources"]["download"]["presets"]),
        )
        print(
            "Generic proxies:",
            len(config["sources"]["genericProxy"]["presets"]),
        )
        print(f"Generated: {args.output}")
        return 0

    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
