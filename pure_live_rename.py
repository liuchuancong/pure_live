import json
# https://cors.isteed.cc/https://api.github.com/repos/liuchuancong/pure_live/releases?per_page=3000
INPUT_FILE = "release.json"
OUTPUT_FILE = "assets/releases.json"


def format_size(size):
    return f"{round(size / 1024 / 1024, 2)}MB"


def clean_name(name):
    return (
        name.replace("app-", "")
            .replace(".apk", "")
            .replace("-release", "")
    )


def main():
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

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

            # 更新日志
            "changelog": release.get("body", "").strip(),

            # 安装包
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

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print("生成完成:", OUTPUT_FILE)


if __name__ == "__main__":
    main()