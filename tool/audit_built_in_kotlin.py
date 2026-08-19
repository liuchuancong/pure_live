#!/usr/bin/env python3
"""Fail fast when a local Android module regresses to the standalone KGP."""

from __future__ import annotations

from pathlib import Path
import os
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
GRADLE_PROPERTIES = ROOT / "android" / "gradle.properties"
SETTINGS = ROOT / "android" / "settings.gradle.kts"
APP_GRADLE = ROOT / "android" / "app" / "build.gradle.kts"
GRADLE_WRAPPER = ROOT / "android" / "gradle" / "wrapper" / "gradle-wrapper.properties"
LOCAL_PLUGIN_ROOTS = (
    ROOT / "plugins" / "built_in_kotlin",
    ROOT / "plugins" / "flv_lzc",
)

FORBIDDEN = {
    "standalone Kotlin Android plugin": re.compile(
        r"(?:id\s*\(\s*['\"]org\.jetbrains\.kotlin\.android['\"]|"
        r"id\s*\(\s*['\"]kotlin-android['\"]|"
        r"apply\s+plugin\s*:\s*['\"]kotlin-android['\"]|"
        r"apply\s*\(\s*plugin\s*=\s*['\"]kotlin-android['\"])",
    ),
    "Kotlin Gradle Plugin classpath": re.compile(r"kotlin-gradle-plugin"),
    "module-local Android Gradle Plugin classpath": re.compile(
        r"com\.android\.tools\.build:gradle:"
    ),
    "legacy android.kotlinOptions DSL": re.compile(r"\bkotlinOptions\s*\{"),
    "Kotlin sources attached as Java": re.compile(
        r"java\.srcDirs?[^\n]*(?:src/(?:main|test)/kotlin)"
    ),
    "local JVM target below 17": re.compile(r"(?:JVM_11|VERSION_11|VERSION_1_8)"),
}


def find_java() -> str | None:
    executable = "java.exe" if os.name == "nt" else "java"
    candidates: list[Path] = []
    for variable in ("PURE_LIVE_JAVA_HOME", "JAVA_HOME"):
        value = os.environ.get(variable, "").strip()
        if value:
            candidates.append(Path(value) / "bin" / executable)

    if os.name == "nt":
        program_files = Path(os.environ.get("ProgramFiles", r"C:\Program Files"))
        local_app_data = os.environ.get("LOCALAPPDATA", "").strip()
        candidates.append(program_files / "Android" / "Android Studio" / "jbr" / "bin" / executable)
        if local_app_data:
            candidates.append(Path(local_app_data) / "Programs" / "Android Studio" / "jbr" / "bin" / executable)

    resolved = shutil.which("java")
    if resolved:
        candidates.append(Path(resolved))
    return next((str(candidate) for candidate in candidates if candidate.is_file()), None)


def without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"(?m)^\s*//.*$", "", text)


def gradle_files() -> list[Path]:
    files = [SETTINGS, APP_GRADLE]
    for root in LOCAL_PLUGIN_ROOTS:
        if root.exists():
            files.extend(root.rglob("build.gradle"))
            files.extend(root.rglob("build.gradle.kts"))
    return sorted(set(files))


def main() -> int:
    errors: list[str] = []
    properties = GRADLE_PROPERTIES.read_text(encoding="utf-8")
    if not re.search(r"(?m)^android\.builtInKotlin\s*=\s*true\s*$", properties):
        errors.append("android/gradle.properties must enable android.builtInKotlin=true")
    if not re.search(r"(?m)^skipDependencyChecks\s*=\s*true\s*$", properties):
        errors.append("Flutter 3.47 requires the documented built-in KGP validation workaround")

    java_path = find_java()
    java_output = ""
    java_returncode = 1
    if java_path is not None:
        java = subprocess.run(
            [java_path, "-version"],
            check=False,
            capture_output=True,
            text=True,
        )
        java_output = f"{java.stdout}\n{java.stderr}"
        java_returncode = java.returncode
    java_match = re.search(r'version\s+"(\d+)', java_output)
    if java_returncode or not java_match or int(java_match.group(1)) < 21:
        errors.append("Java 21 or newer is required to run the AGP 9.3 lint toolchain")

    settings = SETTINGS.read_text(encoding="utf-8")
    agp_match = re.search(
        r'id\(\s*"com\.android\.application"\s*\)\s*version\s*"([0-9.]+)"',
        settings,
    )
    if not agp_match or tuple(map(int, agp_match.group(1).split("."))) < (9, 3, 1):
        errors.append("android/settings.gradle.kts must use AGP 9.3.1 or newer")

    wrapper = GRADLE_WRAPPER.read_text(encoding="utf-8")
    gradle_match = re.search(r"gradle-([0-9.]+)-(?:all|bin)\.zip", wrapper)
    if not gradle_match or tuple(map(int, gradle_match.group(1).split("."))) < (9, 5, 0):
        errors.append("Gradle wrapper must use 9.5.0 or newer for AGP 9.3")

    for path in gradle_files():
        text = without_comments(path.read_text(encoding="utf-8"))
        for description, pattern in FORBIDDEN.items():
            if pattern.search(text):
                errors.append(f"{path.relative_to(ROOT)}: {description}")

    if errors:
        print("Built-in Kotlin audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Built-in Kotlin audit passed ({len(gradle_files())} Gradle files checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
