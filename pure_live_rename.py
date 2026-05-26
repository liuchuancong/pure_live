import json
import urllib.request

# 直接配置在线 API 地址
API_URL = "https://cors.isteed.cc/https://api.github.com/repos/liuchuancong/pure_live/releases?per_page=3000"
OUTPUT_FILE = "assets/releases.json"

def format_size(size):
    return f"{round(size / 1024 / 1024, 2)}mb"

def clean_name(name):
    return (
        name.replace("app-", "")
        .replace(".apk", "")
        .replace("-release", "")
    )

def main():
    # 使用 urllib 直接请求网络数据，无需第三方库
    req = urllib.request.Request(API_URL, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode('utf-8'))
        
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
        
    import os
    # 自动创建 assets 文件夹以防报错
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        
    print("生成完成:", OUTPUT_FILE)

if __name__ == "__main__":
    main()
