import json
import urllib.request
import urllib.error
import sys
import os

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

def fetch_data(url):
    """获取网络数据并进行严格的前置检查"""
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
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
            if not data:
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

def main():
    # 核心修改：网络获取与严格校验
    data = fetch_data(API_URL)
        
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
        
    print("生成完成:", OUTPUT_FILE)

if __name__ == "__main__":
    main()
