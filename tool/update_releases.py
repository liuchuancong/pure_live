import json
import urllib.request
import urllib.error
import sys
import os

# GitHub Actions 中自动使用当前仓库，本地运行时默认使用维护分支仓库。
REPOSITORY = os.environ.get("GITHUB_REPOSITORY", "wzgrx/pure_live")
UPSTREAM_REPOSITORY = "liuchuancong/pure_live"
OUTPUT_FILE = "assets/releases.json"
PAGE_SIZE = 100

def format_size(size):
    return f"{round(size / 1024 / 1024, 2)}mb"

def clean_name(name):
    return (
        name.replace("app-", "")
        .replace(".apk", "")
        .replace("-release", "")
    )

def fetch_data(url, *, allow_empty=False):
    """获取网络数据并进行严格的前置检查"""
    headers = {
        "User-Agent": "PureLive-Release-Updater",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        print(f"正在尝试连接服务器: {url}")
        with urllib.request.urlopen(req, timeout=30) as response:
            # 1. 检查 HTTP 状态码
            if response.status != 200:
                print(f"❌ 错误：服务器响应状态码为 {response.status}", file=sys.stderr)
                sys.exit(1)

            raw_data = response.read()

            # 2. 检查返回内容是否为空
            if not raw_data:
                print("❌ 错误：网络请求成功，但返回的内容为空（0字节）", file=sys.stderr)
                sys.exit(1)

            print("解析 JSON 数据中...")
            data = json.loads(raw_data.decode('utf-8'))

            # 3. 验证数据结构是否符合预期
            if not data and not allow_empty:
                print("❌ 错误：获取到的 JSON 数据内容为空列表或空字典", file=sys.stderr)
                sys.exit(1)

            print("网络数据校验通过，成功获取到发布历史。")
            return data

    except urllib.error.HTTPError as e:
        print(f"❌ HTTP 错误：[{e.code}] {e.reason}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"❌ 网络连接失败（可能超时或域名无法解析）: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print("❌ 错误：成功获取到内容，但内容不是合法的 JSON 格式", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ 未知错误: {str(e)}", file=sys.stderr)
        sys.exit(1)


def fetch_all_releases(repository):
    """Fetch every release page instead of silently dropping old versions."""
    releases = []
    page = 1
    while True:
        url = (
            f"https://api.github.com/repos/{repository}/releases"
            f"?per_page={PAGE_SIZE}&page={page}"
        )
        batch = fetch_data(url, allow_empty=page > 1)
        if not isinstance(batch, list):
            print("❌ 错误：发布历史接口返回了非列表数据", file=sys.stderr)
            sys.exit(1)
        releases.extend(batch)
        if len(batch) < PAGE_SIZE:
            break
        page += 1
    return releases

def main():
    # 核心修改：网络获取与严格校验
    data = fetch_all_releases(REPOSITORY)

    # 维护分支保留上游旧版本记录；同名标签优先使用当前仓库的 Release。
    if REPOSITORY != UPSTREAM_REPOSITORY:
        upstream_data = fetch_all_releases(UPSTREAM_REPOSITORY)
        current_tags = {release.get("tag_name") for release in data}
        data.extend(release for release in upstream_data if release.get("tag_name") not in current_tags)
        data.sort(key=lambda release: release.get("published_at") or "", reverse=True)

    if isinstance(data, dict):
        data = [data]

    result = []
    for release in data:
        author = release.get("author", {})
        item = {
            "version": release.get("tag_name", "").replace("v", ""),
            "title": release.get("name"),
            "date": release.get("published_at", "")[:10],
            "github": release.get("html_url"),
            "author": {
                "name": author.get("login"),
                "avatar": author.get("avatar_url"),
                "profile": author.get("html_url")
            },
            "changelog": release.get("body", "").strip(),
            "files": []
        }

        for asset in release.get("assets", []):
            item["files"].append({
                "name": clean_name(asset.get("name", "")),
                "size": format_size(asset.get("size", 0)),
                "downloads": asset.get("download_count", 0),
                "url": asset.get("browser_download_url")
            })
        result.append(item)

    # 自动创建 assets 文件夹
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("生成完成:", OUTPUT_FILE)

if __name__ == "__main__":
    main()
