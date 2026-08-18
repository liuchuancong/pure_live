import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# Supply short-lived request URLs and cookies through process environment only.
# Never paste browser sessions into this source file.
API_URL_1 = os.environ.get("DOUYIN_EMOJI_API_URL_1", "").strip()
COOKIE_FOR_API_1 = os.environ.get("DOUYIN_EMOJI_COOKIE_1", "").strip()
API_URL_2 = os.environ.get("DOUYIN_EMOJI_API_URL_2", "").strip()
COOKIE_FOR_API_2 = os.environ.get("DOUYIN_EMOJI_COOKIE_2", "").strip()

COMMON_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive",
    "Referer": "https://douyin.com"
}
# ==========================================================================

def _find_flutter_root(start_dir):
    current = os.path.abspath(start_dir)
    while True:
        if os.path.exists(os.path.join(current, "pubspec.yaml")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return os.path.abspath(os.path.join(start_dir, ".."))
        current = parent

def _download_worker(task):
    url, path, name = task
    max_retries = 3
    if os.path.exists(path) and os.path.getsize(path) > 100:
        return True

    headers = COMMON_HEADERS.copy()
    print(f"📡 [全速拉取] 表情: {name.ljust(10)} | URL末尾: {url[-45:]}")
    for attempt in range(max_retries):
        try:
            with requests.Session() as session:
                res = session.get(url, headers=headers, timeout=12)
                if res.status_code == 200 and len(res.content) > 100:
                    with open(path, "wb") as img_f:
                        img_f.write(res.content)
                    return True
        except Exception:
            pass
    return False

def fetch_api_data(url, cookie):
    headers = COMMON_HEADERS.copy()
    headers["Cookie"] = cookie
    try:
        res = requests.get(url, headers=headers, timeout=15)
        if res.status_code == 200:
            return res.json().get("emoji_list", [])
        else:
            print(f"⚠️ 接口请求失败，状态码: {res.status_code}")
    except Exception as e:
        print(f"❌ 接口请求或解析 JSON 发生崩溃: {e}")
    return []

def main():
    required = {
        "DOUYIN_EMOJI_API_URL_1": API_URL_1,
        "DOUYIN_EMOJI_COOKIE_1": COOKIE_FOR_API_1,
        "DOUYIN_EMOJI_API_URL_2": API_URL_2,
        "DOUYIN_EMOJI_COOKIE_2": COOKIE_FOR_API_2,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise SystemExit("Missing environment variables: " + ", ".join(missing))
    script_dir = os.path.dirname(os.path.abspath(__file__))
    flutter_root = _find_flutter_root(script_dir)
    
    output_json_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "json"))
    output_img_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "images", "douyin"))
    output_json_path = os.path.join(output_json_dir, "douyin.json")

    if not os.path.exists(output_json_dir): os.makedirs(output_json_dir)
    if not os.path.exists(output_img_dir): os.makedirs(output_img_dir)

    # 1. 分别请求两个接口
    print("📖 正在请求接口一（直播基础表情）...")
    list_1 = fetch_api_data(API_URL_1, COOKIE_FOR_API_1)
    print(f"✅ 接口一成功获取到 {len(list_1)} 个原始数据")

    print("📖 正在请求接口二（need_all全量表情）...")
    list_2 = fetch_api_data(API_URL_2, COOKIE_FOR_API_2)
    print(f"✅ 接口二成功获取到 {len(list_2)} 个原始数据")

    # 2. 对两个接口的数据进行【严格去重合并】
    combined_raw_list = list_1 + list_2
    seen_uris = set()  # 用来记录已经存在过的 origin_uri
    
    final_emoji_list = []
    download_tasks = []

    print("✨ 正在双流合流，自动剔除重复项，并 1:1 构建纯净数据体...")
    duplicate_count = 0
    
    for item in combined_raw_list:
        if not isinstance(item, dict): 
            continue
            
        origin_uri = item.get("origin_uri", "")
        if not origin_uri:
            continue
            
        # 【核心去重逻辑】如果该 origin_uri 已经处理过，直接作为重复项剔除
        if origin_uri in seen_uris:
            duplicate_count += 1
            continue
            
        seen_uris.add(origin_uri)
        display_name = item.get("display_name", "")
        
        emoji_url_obj = item.get("emoji_url", {})
        url_list = emoji_url_obj.get("url_list", []) if isinstance(emoji_url_obj, dict) else []
        
        if not url_list:
            continue

        # 完全按要求的单体 1:1 格式装填，并无损追加 local_file 属性
        final_emoji_list.append({
            "origin_uri": origin_uri,
            "display_name": display_name,
            "hide": item.get("hide", 0),
            "emoji_url": {
                "uri": emoji_url_obj.get("uri", ""),
                "url_list": url_list
            },
            "local_file": origin_uri  # 🚀 为 Flutter 全地化离线缓存提供标准路径字段支持
        })

        # 提取资源用于物理下载
        primary_url = url_list[0]
        file_path = os.path.join(output_img_dir, origin_uri)
        download_tasks.append((primary_url, file_path, display_name))

    print(f"♻️  去重处理完成！成功发现并自动剔成了 {duplicate_count} 个重复的表情。")

    if not final_emoji_list:
        print("❌ 两个接口均未获取到有效数据，请检查配置区域的 Cookie 是否已失效。")
        return

    # 3. 写入最终合并无损的本地 json
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(final_emoji_list, f, ensure_ascii=False, indent=2)
    print(f"✨ 双接口全量合流且去重成功！包含 'local_file' 的纯净配置已保存至:\n   {output_json_path}")

    # 4. 开启多线程满载高并发下载
    total_tasks = len(download_tasks)
    print(f"\n📥 🚀【火力全开】16 线程高并发，开始下载去重后的全量抖音资产（总计 {total_tasks} 个有效包通道）...")
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(_download_worker, download_tasks))
        success_count = sum(1 for r in results if r)
        
    print(f"\n🏁 通关！所有去重并集成 local_file 的表情图片已完美下载存盘： {success_count}/{total_tasks} 张。")

if __name__ == "__main__":
    main()