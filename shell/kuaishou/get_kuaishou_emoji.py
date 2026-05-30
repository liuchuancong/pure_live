import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# ==================== CONFIGURATION AREA ====================
# Kuaishou Live Emoji API Panel URL
API_URL_KUAISHOU = "https://live.kuaishou.com/live_api/emoji/panel"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive"
}
# ============================================================

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

    print(f"📡 [Full Speed] Kuaishou Emo: {name.ljust(12)} | URL End: {url[-45:]}")
    for attempt in range(max_retries):
        try:
            with requests.Session() as session:
                res = session.get(url, headers=HEADERS, timeout=12)
                if res.status_code == 200 and len(res.content) > 100:
                    with open(path, "wb") as img_f:
                        img_f.write(res.content)
                    return True
        except Exception:
            pass
    return False

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    flutter_root = _find_flutter_root(script_dir)
    
    # Standardized asset directories for Kuaishou
    output_json_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "json"))
    output_img_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "images", "kuaishou"))
    output_json_path = os.path.join(output_json_dir, "kuaishou.json")

    if not os.path.exists(output_json_dir): os.makedirs(output_json_dir)
    if not os.path.exists(output_img_dir): os.makedirs(output_img_dir)

    print("📖 Fetching Kuaishou raw configurations from API...")
    try:
        response = requests.get(API_URL_KUAISHOU, headers=HEADERS, timeout=15)
        if response.status_code != 200:
            print(f"❌ API Request Failed, Status Code: {response.status_code}")
            return
        res_json = response.json()
    except Exception as e:
        print(f"❌ Failed to request or parse Kuaishou JSON: {e}")
        return

    # Extract the target mapping dictionary from the root "data" block
    raw_emoji_map = res_json.get("data", {})
    if not raw_emoji_map:
        print("⚠️ No emoji data extracted. Check if Cookie or custom Headers are required.")
        return

    kuaishou_native_map = {}
    download_tasks = []

    print(f"✨ Formatting Kuaishou model (fixing https:) and processing {len(raw_emoji_map)} emojis...")
    for emoji_key, img_url in raw_emoji_map.items():
        emoji_key = emoji_key.strip()
        img_url = img_url.strip()
        
        if not emoji_key or not img_url:
            continue

        # 🛠️ Rule Fix: Ensure the scheme starts with absolute https:
        if img_url.startswith("//"):
            img_url = f"https:{img_url}"
        elif not img_url.startswith("http"):
            img_url = f"https://{img_url}"

        # Clean string brackets for filename matching (e.g. "[666]" -> "666.png")
        pure_name = emoji_key.replace("[", "").replace("]", "")
        ext = ".gif" if ".gif" in img_url.lower() else ".png"
        local_file = f"{pure_name}{ext}"

        # 1:1 replication of Kuaishou's native structure (Mapping key to its exact string metadata)
        # We append a minor "local_file" property for seamless Flutter parsing
        kuaishou_native_map[emoji_key] = {
            "url": img_url,
            "local_file": local_file
        }
        
        download_tasks.append((img_url, os.path.join(output_img_dir, local_file), emoji_key))

    # Path deduplication to eliminate download write locks
    unique_download_tasks = {}
    for task in download_tasks:
        url, file_path, name = task
        unique_download_tasks[file_path] = (url, file_path, name)
    final_download_tasks = list(unique_download_tasks.values())

    # Safely save the dictionary structure to assets
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(kuaishou_native_map, f, ensure_ascii=False, indent=2)
    print(f"✨ Kuaishou native-aligned JSON saved successfully to:\n   {output_json_path}")

    # Fire high-concurrency downloads via 16 workers
    total_tasks = len(final_download_tasks)
    print(f"\n📥 🚀 [Firepower Active] Initializing 16-threaded downloads for {total_tasks} assets...")
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(_download_worker, final_download_tasks))
        success_count = sum(1 for r in results if r)
        
    print(f"\n🏁 Finished! Kuaishou assets deployed: {success_count}/{total_tasks} downloaded successfully.")

if __name__ == "__main__":
    main()
