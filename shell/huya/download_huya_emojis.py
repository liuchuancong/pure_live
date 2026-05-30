import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive"
}

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
    url, path, sid, name = task
    max_retries = 3
    
    if os.path.exists(path) and os.path.getsize(path) > 100:
        return True

    print(f"📡 [全速拉取] ID: {sid.ljust(6)} | 含义: {name} | URL: {url[-45:]}")
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

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    flutter_root = _find_flutter_root(script_dir)
    
    taf_file = os.path.join(script_dir, "huya_taf.json") if os.path.exists(os.path.join(script_dir, "huya_taf.json")) else os.path.join(script_dir, "huya_taf.txt")
    map_file = os.path.join(script_dir, "huya_map.json") if os.path.exists(os.path.join(script_dir, "huya_map.json")) else os.path.join(script_dir, "huya_map.txt")
    
    output_json_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "json"))
    output_img_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "images", "huya"))
    output_json_path = os.path.join(output_json_dir, "huya.json")

    if not os.path.exists(output_json_dir): os.makedirs(output_json_dir)
    if not os.path.exists(output_img_dir): os.makedirs(output_img_dir)

    emoji_dict = {}

    if os.path.exists(taf_file):
        print(f"📖 正在扫描原始 TAF 配置: {taf_file}")
        try:
            with open(taf_file, "r", encoding="utf-8") as f:
                taf_data = json.load(f)
            taf_items = taf_data.get("data", []) if isinstance(taf_data, dict) else (taf_data if isinstance(taf_data, list) else [])
            for item in taf_items:
                if not isinstance(item, dict): continue
                sid = str(item.get("sId", "")).strip()
                if sid:
                    emoji_dict[sid] = {
                        "sId": sid,
                        "sName": item.get("sName", ""),
                        "sEscape": item.get("sEscape", ""),
                        "sUrl": item.get("sUrl", ""),
                        "sFlexiUrl": item.get("sFlexiUrl", ""),
                        "sExtraUrl": item.get("sExtraUrl", ""),
                        "sExtraFlexiUrl": item.get("sExtraFlexiUrl", ""),
                        "iType": item.get("iType", 0),
                        "lPackageId": item.get("lPackageId", 0),
                        "iFrameSize": item.get("iFrameSize", 0),
                        "iPrice": item.get("iPrice", 0)
                    }
        except Exception as e: 
            print(f"❌ 读取 TAF 失败: {e}")

    if os.path.exists(map_file):
        print(f"📖 正在扫描原始 MAP 配置: {map_file}")
        try:
            with open(map_file, "r", encoding="utf-8") as f:
                map_data = json.load(f)
            if isinstance(map_data, dict):
                for item in map_data.values():
                    if not isinstance(item, dict): continue
                    sid = str(item.get("sId", "")).strip()
                    if not sid: continue
                    
                    def _pick(k):
                        new_v = item.get(k)
                        if new_v is not None and str(new_v).strip() != "":
                            return new_v
                        return emoji_dict.get(sid, {}).get(k, "")

                    emoji_dict[sid] = {
                        "sId": sid,
                        "sName": _pick("sName"),
                        "sEscape": _pick("sEscape"),
                        "sUrl": _pick("sUrl"),
                        "sFlexiUrl": _pick("sFlexiUrl"),
                        "sExtraUrl": _pick("sExtraUrl"),
                        "sExtraFlexiUrl": _pick("sExtraFlexiUrl"),
                        "iType": item.get("iType") if "iType" in item else emoji_dict.get(sid, {}).get("iType", 0),
                        "lPackageId": item.get("lPackageId") if "lPackageId" in item else emoji_dict.get(sid, {}).get("lPackageId", 0),
                        "iFrameSize": item.get("iFrameSize") if "iFrameSize" in item else emoji_dict.get(sid, {}).get("iFrameSize", 0),
                        "iPrice": item.get("iPrice") if "iPrice" in item else emoji_dict.get(sid, {}).get("iPrice", 0)
                    }
        except Exception as e: 
            print(f"❌ 读取 MAP 失败: {e}")

    final_emoji_list = list(emoji_dict.values())
    
    # 🚀【核心修改】在保存 JSON 前，直接把数据源字典里所有包含 steam.png 的链接替换为 steam_3.png
    for item in final_emoji_list:
        if "steam.png" in item["sFlexiUrl"]:
            item["sFlexiUrl"] = item["sFlexiUrl"].replace("steam.png", "steam_3.png")
        if "steam.png" in item["sUrl"]:
            item["sUrl"] = item["sUrl"].replace("steam.png", "steam_3.png")

    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(final_emoji_list, f, ensure_ascii=False, indent=2)
    print(f"✨ 原始数据全量解构成功！包含 '_3' 的纯净配置已无损覆写保存至:\n   {output_json_path}")

    # 3. 提取具有真实物理下载长链的任务队列
    download_tasks = []
    for item in final_emoji_list:
        sid = item["sId"]
        name = item["sName"]
        url = item["sFlexiUrl"].strip() if item["sFlexiUrl"].strip() else item["sUrl"].strip()
        if url and url.startswith("http"):
            download_tasks.append((url, os.path.join(output_img_dir, f"{sid}.png"), sid, name))

    total_tasks = len(download_tasks)
    print(f"📥 🚀【火力全开】16 线程满载高并发，全面向下倾泻下载（总计 {total_tasks} 个有效包通道）...")
    
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(_download_worker, download_tasks))
        success_count = sum(1 for r in results if r)
        
    print(f"🏁 彻底清洗合流通关！所有大表情和高清梗图已完美下载存盘： {success_count}/{total_tasks} 张 PNG 图片。")

if __name__ == "__main__":
    main()
