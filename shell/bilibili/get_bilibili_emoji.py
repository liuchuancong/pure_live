import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# ==================== 接口配置区域 ====================
# Bilibili 官方表情接口
API_URL_BILIBILI = "https://api.live.bilibili.com/xlive/web-ucenter/v2/emoticon/GetEmoticons?platform=pc&room_id=24158116"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive",
    "Cookie":  "buvid3=3CA40A72-FB82-B6AF-FD4D-F97C748CE51116816infoc; b_nut=1767097716; theme_style=light; _uuid=81792DB3-5F37-CB16-D96A-C210510B310FEB513111infoc; buvid_fp=5cafd03fba7f3aa062d87ea6244f1dfe; buvid4=7C18E803-C361-D840-3880-BCC00A511C0C17769-025123020-NhzsO055o6/hPhqHoqbCrrRQ7QAEqOM/R7eq566XUPgBCnQV6SeTyKLUJrlKtA1j; rpdid=0zbfAI3bnj|Q3STAq3a|3sF|3w1VAyQa; DedeUserID=22836336; DedeUserID__ckMd5=b0d5d8a0e137e5b5; theme-tip-show=SHOWED; CURRENT_QUALITY=80; CURRENT_FNVAL=2000; SESSDATA=b14a2354%2C1795523735%2Caadce%2A51CjDNj7QrxkVa3xBGcTkSoYDLLkoqh__KEPV6My7DZeU17r8vOvhgJ_w7B4i3KQWzysISVnV2MTAxMzdPWUdSR1RYUGVuc3JaYkVpN0xkaGVocDB3b1MxOXZqdS1ubXVzc3dnNkEyTmRvQjlTcFNvZ0JNbUhmazlHZ25wYmZKNzlxWWdHSGgyRVFnIIEC; bili_jct=e9be39f228c761a5ab2ceff1c4030ac1; sid=8nsz7trr; bili_ticket=eyJhbGciOiJIUzI1NiIsImtpZCI6InMwMyIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODAyMzA5NDAsImlhdCI6MTc3OTk3MTY4MCwicGx0IjotMX0.eQvTvWG9XWY6FgUtZVkdEFqwUHya6pRLLjuRAtPTk0M; bili_ticket_expires=1780230880; LIVE_BUVID=AUTO5217799717405232; home_feed_column=5; browser_resolution=1611-848; PVID=8; bp_t_offset_22836336=1208258224025763840; b_lsid=23E4EFED_19E79AE890E"
}
# ======================================================

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

    print(f"📡 [全速拉取] B站表情: {name.ljust(12)} | URL末尾: {url[-45:]}")
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
    
    # 建立独立资产目录
    output_json_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "json"))
    output_img_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "images", "bilibili"))
    output_json_path = os.path.join(output_json_dir, "bilibili.json")

    if not os.path.exists(output_json_dir): os.makedirs(output_json_dir)
    if not os.path.exists(output_img_dir): os.makedirs(output_img_dir)

    print("📖 正在通过官方 API 接口拉取 Bilibili 原始配置...")
    try:
        response = requests.get(API_URL_BILIBILI, headers=HEADERS, timeout=15)
        if response.status_code != 200:
            print(f"❌ 接口请求失败，状态码: {response.status_code}")
            return
        res_json = response.json()
    except Exception as e:
        print(f"❌ 请求或解析 B站接口 JSON 失败: {e}")
        return

    data_group_list = res_json.get("data", {}).get("data", [])
    if not data_group_list:
        print("⚠️ 未能提取到任何表情包分组。")
        return

    # 全新 1:1 原装复刻大 Map 容器
    bilibili_official_map = {}
    download_tasks = []

    print(f"✨ 正在 1:1 像素级复刻 B站 原生模型资产...")
    for group in data_group_list:
        emoticons = group.get("emoticons", [])
        if not isinstance(emoticons, list):
            continue
            
        for emo in emoticons:
            if not isinstance(emo, dict):
                continue
                
            emoji_key = emo.get("emoji", "").strip()  # 例如 "[啊]" 或 "[dog]"
            img_url = emo.get("url", "").strip()
            
            if not emoji_key or not img_url:
                continue

            # 纯净的表情名（用于文件名，去掉方括号）
            pure_name = emoji_key.replace("[", "").replace("]", "")
            
            # 自适应选择图片后缀
            ext = ".gif" if emo.get("is_dynamic") == 1 or ".gif" in img_url.lower() else ".png"
            local_file = f"{pure_name}{ext}"

            # 【核心修改点】使用 emo.copy() 彻底保留人家接口的所有原生字段（同名直接覆盖）
            official_model = emo.copy()
            # 仅额外附赠一个本地文件路径，方便 Flutter 渲染时进行映射读取
            official_model["local_file"] = local_file

            bilibili_official_map[emoji_key] = official_model
            
            download_tasks.append((img_url, os.path.join(output_img_dir, local_file), emoji_key))

    if not bilibili_official_map:
        print("❌ 未清洗出任何有效的 B站 数据。")
        return

    # 物理路径写去重保护
    unique_download_tasks = {}
    for task in download_tasks:
        url, file_path, name = task
        unique_download_tasks[file_path] = (url, file_path, name)
    final_download_tasks = list(unique_download_tasks.values())

    # 覆写保存
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(bilibili_official_map, f, ensure_ascii=False, indent=2)
    print(f"✨ B站官方 1:1 原装模型配置已覆写保存至:\n   {output_json_path}")

    # 16 线程满载并发拉取图片
    total_tasks = len(final_download_tasks)
    print(f"\n📥 🚀【火力全开】16 线程满载并发，开始下载 B站 资产（共 {total_tasks} 张）...")
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(_download_worker, final_download_tasks))
        success_count = sum(1 for r in results if r)
        
    print(f"\n🏁 彻底完成！B站官方原装模型资产已全部完美落地： {success_count}/{total_tasks} 张图片。")

if __name__ == "__main__":
    main()
