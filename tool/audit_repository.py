#!/usr/bin/env python3
"""Deterministic whole-repository integrity audit for Pure Live."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".c", ".cc", ".cmake", ".cpp", ".css", ".dart", ".gradle", ".h", ".hpp",
    ".html", ".java", ".js", ".json", ".kt", ".kts", ".md", ".m", ".mm",
    ".plist", ".properties", ".ps1", ".py", ".sh", ".swift", ".toml", ".txt",
    ".xml", ".yaml", ".yml",
}
SECRET_PATTERNS = {
    "github_token": re.compile(r"\b(?:gh[opusr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    "aws_access_key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
}
CONFLICT_PATTERN = re.compile(r"^(?:<{7}(?: .*)?|={7}|>{7}(?: .*)?)$", re.MULTILINE)
ACTION_PATTERN = re.compile(r"\buses:\s*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@([^\s#]+)")
SHA40_PATTERN = re.compile(r"^[0-9a-fA-F]{40}$")


def git(*args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    return completed.stdout


def git_file_names(*args: str) -> list[str]:
    return [item for item in git(*args, "-z").split("\0") if item]


def repository_files() -> tuple[list[Path], set[str], set[str]]:
    tracked = set(git_file_names("ls-files"))
    # Include non-ignored worktree additions so a pre-commit local gate cannot
    # accidentally omit the new workflow, test or source file being reviewed.
    untracked = set(git_file_names("ls-files", "--others", "--exclude-standard"))
    names = sorted(tracked | untracked)
    return [ROOT / item for item in names], tracked, untracked


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_text(path: Path) -> str | None:
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return None
    if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {
        ".env.prod", ".fvmrc", "Dockerfile", "Gemfile", "Podfile",
    }:
        try:
            return data.decode("utf-8")
        except UnicodeDecodeError:
            return None
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return None


def category(path: str) -> str:
    rules = (
        ("live_playback", ("lib/modules/live_play/", "lib/player/")),
        ("platform_interfaces", ("lib/core/",)),
        ("persisted_settings", ("lib/common/services/settings/",)),
        ("navigation", ("lib/routes/", "lib/get/")),
        ("native_android", ("android/",)),
        ("native_windows", ("windows/",)),
        ("native_apple", ("ios/", "macos/")),
        ("native_linux", ("linux/",)),
        ("release_build", (".github/", "tool/",)),
        ("dependencies", ("pubspec.yaml", "pubspec.lock", "plugins/", "third_party/")),
        ("tests", ("test/",)),
        ("assets_docs", ("assets/", "docs/")),
        ("app_source", ("lib/",)),
    )
    for name, prefixes in rules:
        if any(path == prefix or path.startswith(prefix) for prefix in prefixes):
            return name
    return "repository_metadata"


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    errors: list[dict[str, object]] = []
    warnings: list[dict[str, object]] = []
    files, tracked_names_raw, untracked_names_raw = repository_files()
    categories: Counter[str] = Counter()
    text_count = 0
    total_bytes = 0
    lifecycle_inventory = {"timer_periodic": 0, "stream_listen": 0, "empty_catch": 0}
    empty_catch = re.compile(r"catch\s*\([^)]*\)\s*\{\s*\}")

    unresolved = [item for item in git("diff", "--name-only", "--diff-filter=U").splitlines() if item]
    for item in unresolved:
        errors.append({"rule": "unresolved_merge", "path": item})

    modes = git("ls-files", "-s").splitlines()
    for entry in modes:
        mode, _, _, path = entry.split(maxsplit=3)
        if mode in {"120000", "160000"}:
            errors.append({"rule": "special_git_entry", "path": path, "mode": mode})

    for path in files:
        rel = relative(path)
        categories[category(rel)] += 1
        try:
            total_bytes += path.stat().st_size
        except OSError:
            errors.append({"rule": "tracked_file_missing", "path": rel})
            continue
        text = read_text(path)
        if text is None:
            continue
        text_count += 1

        if rel.startswith("lib/"):
            lifecycle_inventory["timer_periodic"] += text.count("Timer.periodic(")
            lifecycle_inventory["stream_listen"] += text.count(".listen(")
            lifecycle_inventory["empty_catch"] += len(empty_catch.findall(text))

        conflict = CONFLICT_PATTERN.search(text)
        if conflict:
            errors.append({
                "rule": "conflict_marker",
                "path": rel,
                "line": line_number(text, conflict.start()),
            })

        for rule, pattern in SECRET_PATTERNS.items():
            match = pattern.search(text)
            if match:
                errors.append({"rule": rule, "path": rel, "line": line_number(text, match.start())})

        if rel.startswith(".github/workflows/") and path.suffix in {".yml", ".yaml"}:
            for match in ACTION_PATTERN.finditer(text):
                if not SHA40_PATTERN.fullmatch(match.group(2)):
                    errors.append({
                        "rule": "mutable_action_reference",
                        "path": rel,
                        "line": line_number(text, match.start()),
                        "action": match.group(1),
                        "reference": match.group(2),
                    })
            if re.search(r"(?m)^\s*pull_request_target:\s*$", text):
                errors.append({"rule": "pull_request_target_forbidden", "path": rel})
            if re.search(r"(?m)^\s*permissions:\s*write-all\s*$", text):
                errors.append({"rule": "workflow_write_all_forbidden", "path": rel})
            if re.search(r"(?m)^\s*git\s+clone\s+", text):
                errors.append({"rule": "mutable_git_clone", "path": rel})
            for activation in re.finditer(r"(?m)^\s*dart\s+pub\s+global\s+activate\s+\S+\s*$", text):
                errors.append({
                    "rule": "mutable_dart_global_activation",
                    "path": rel,
                    "line": line_number(text, activation.start()),
                })
            for install in re.finditer(r"(?m)^\s*choco\s+install\s+[^\r\n]+$", text):
                if "--version=" not in install.group(0):
                    errors.append({
                        "rule": "mutable_chocolatey_package",
                        "path": rel,
                        "line": line_number(text, install.start()),
                    })
            for pub_get in re.finditer(r"(?m)^\s*run:\s*flutter\s+pub\s+get\s*$", text):
                errors.append({
                    "rule": "unlocked_workflow_pub_get",
                    "path": rel,
                    "line": line_number(text, pub_get.start()),
                })
            for default_true in re.finditer(r"(?m)^\s*default:\s*true\s*$", text):
                nearby = text[max(0, default_true.start() - 240):default_true.end()]
                # A quality gate may default on; build, platform, upload and
                # release actions remain opt-in to protect Actions quota.
                if "run_full_regression:" not in nearby:
                    errors.append({
                        "rule": "workflow_default_true",
                        "path": rel,
                        "line": line_number(text, default_true.start()),
                    })

    audited_names = {relative(path) for path in files}
    for forbidden in audited_names:
        lower = forbidden.lower()
        if lower.endswith((".jks", ".keystore", ".p12", ".pfx")) or lower == "android/key.properties":
            errors.append({"rule": "tracked_signing_material", "path": forbidden})

    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    for match in re.finditer(r"(?m)^\s+ref:\s*['\"]?([^'\"\s#]+)", pubspec):
        reference = match.group(1)
        if not SHA40_PATTERN.fullmatch(reference):
            errors.append({
                "rule": "mutable_git_dependency",
                "path": "pubspec.yaml",
                "line": line_number(pubspec, match.start()),
                "reference": reference,
            })

    manifest_path = ROOT / "android/app/src/main/AndroidManifest.xml"
    manifest = manifest_path.read_text(encoding="utf-8")
    callback_values = re.findall(r'android:enableOnBackInvokedCallback="([^"]+)"', manifest)
    if not callback_values or any(value != "true" for value in callback_values):
        errors.append({"rule": "predictive_back_disabled", "path": relative(manifest_path)})

    back_scope = ROOT / "lib/modules/live_play/widgets/layout/live_play_back_scope.dart"
    live_page = ROOT / "lib/modules/live_play/pages/live_play_page.dart"
    controller = ROOT / "lib/modules/live_play/controllers/live_play_controller.dart"
    required_back_markers = {
        relative(back_scope): "PopScope<Object?>",
        relative(live_page): "LivePlayBackScope(",
        relative(controller): "exitPresentationForSystemBack",
    }
    for rel, marker in required_back_markers.items():
        path = ROOT / rel
        if not path.is_file() or marker not in path.read_text(encoding="utf-8"):
            errors.append({"rule": "live_back_invariant_missing", "path": rel, "marker": marker})

    banned_back = "back_button_interceptor"
    for rel in ("pubspec.yaml", "pubspec.lock", relative(controller)):
        path = ROOT / rel
        if path.is_file() and banned_back in path.read_text(encoding="utf-8"):
            errors.append({"rule": "global_back_interceptor_forbidden", "path": rel})

    if lifecycle_inventory["empty_catch"]:
        warnings.append({"rule": "empty_catch_inventory", "count": lifecycle_inventory["empty_catch"]})

    result = {
        "schema_version": 1,
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_commit": git("rev-parse", "HEAD").strip(),
        "tracked_file_count": len(tracked_names_raw),
        "untracked_file_count": len(untracked_names_raw),
        "audited_file_count": len(files),
        "text_file_count": text_count,
        "tracked_bytes": total_bytes,
        "category_counts": dict(sorted(categories.items())),
        "lifecycle_inventory": lifecycle_inventory,
        "errors": errors,
        "warnings": warnings,
        "passed": not errors,
        "fingerprint": hashlib.sha256(
            json.dumps({"files": sorted(audited_names), "errors": errors}, sort_keys=True).encode()
        ).hexdigest(),
    }

    output = args.output
    if output:
        if not output.is_absolute():
            output = ROOT / output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(
        f"Repository audit: files={len(files)} "
        f"(tracked={len(tracked_names_raw)}, untracked={len(untracked_names_raw)}), text={text_count}, "
        f"errors={len(errors)}, warnings={len(warnings)}"
    )
    if output:
        print(f"Evidence: {output}")
    for error in errors:
        print(f"ERROR {error}", file=sys.stderr)
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
