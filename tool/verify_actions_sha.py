import re
import urllib.request
import json
from pathlib import Path

WORKFLOW = Path(".github/workflows/build_pure_live_release.yml")

PATTERN = re.compile(
    r"^\s*uses:\s*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@([0-9a-fA-F]{40})(?:\s*#\s*(.*))?$"
)

def github_api(url):
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "PureLive-Actions-SHA-Verifier",
        },
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))

def get_version(repo, sha):
    try:
        data = github_api(f"https://api.github.com/repos/{repo}/commits/{sha}/branches-where-head")
        branches = [item.get("name") for item in data if item.get("name")]
    except Exception:
        branches = []

    try:
        tags_data = github_api(
            f"https://api.github.com/repos/{repo}/git/ref/tags/{sha}"
        )
        tag = tags_data.get("ref", "").removeprefix("refs/tags/")
        if tag:
            return tag, branches
    except Exception:
        pass

    try:
        data = github_api(
            f"https://api.github.com/repos/{repo}/git/commits/{sha}"
        )
        return None, branches
    except Exception:
        return None, branches

def get_tags(repo, sha):
    try:
        data = github_api(
            f"https://api.github.com/repos/{repo}/commits/{sha}/tags"
        )
        return [item.get("name") for item in data if item.get("name")]
    except Exception:
        return []

def main():
    if not WORKFLOW.exists():
        print(f"找不到 workflow: {WORKFLOW}")
        return

    text = WORKFLOW.read_text(encoding="utf-8")

    matches = []
    seen = set()

    for line_number, line in enumerate(text.splitlines(), 1):
        match = PATTERN.match(line)
        if not match:
            continue

        repo = match.group(1)
        sha = match.group(2).lower()
        comment = match.group(3) or ""

        key = (repo, sha)

        if key in seen:
            continue

        seen.add(key)

        matches.append(
            {
                "line": line_number,
                "repo": repo,
                "sha": sha,
                "comment": comment,
            }
        )

    total = len(matches)
    passed = 0
    failed = 0

    print()
    print("================================")
    print(f"发现 Action : {total}")
    print("================================")

    for item in matches:
        repo = item["repo"]
        sha = item["sha"]
        line = item["line"]
        comment = item["comment"]

        print()
        print(f"[第 {line} 行]")
        print(f"Action : {repo}")
        print(f"SHA    : {sha}")

        try:
            github_api(
                f"https://api.github.com/repos/{repo}/commits/{sha}"
            )
        except Exception as e:
            failed += 1
            print("状态   : ❌ SHA 不存在或无法访问")
            print(f"错误   : {e}")
            continue

        tags = get_tags(repo, sha)

        passed += 1

        if tags:
            print(f"版本   : {', '.join(tags)}")
        elif comment:
            print(f"版本   : {comment}")
        else:
            print("版本   : 未找到对应 Tag")

        print("状态   : ✅ SHA 有效")

    print()
    print("================================")
    print(f"Action 总数 : {total}")
    print(f"校验通过   : {passed}")
    print(f"校验失败   : {failed}")
    print("跳过       : 0")
    print("================================")

    if failed:
        raise SystemExit(1)

if __name__ == "__main__":
    main()