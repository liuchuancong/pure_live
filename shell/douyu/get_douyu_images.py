import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# ==================== 接口配置区域 ====================
# 建议填入你抓取的真实斗鱼 Cookie（如有防盗链或鉴权需求）
COOKIE = "mantine-color-scheme-value=light; dy_did=73d91171ec9e4614d1f5532c00011701; dy_did=73d91171ec9e4614d1f5532c00011701; acf_ccn=d073ed958eafbcbf7738fc5726d89249; acf_web_id=7645710959964609038; acf_ab_pmt=20100212%23webnewhome%23B%2C20100395%23webslidetag%23B%2C20100249%23webTagRank%23B%2C20100248%23webTagHover%23B%2C20100254%23WebTool0703%23new%2C20100272%23all_lists_sort%23c; acf_ab_ver_all=20100212%2C20100395%2C20100249%2C20100248%2C20100254%2C20100272; acf_ab_vs=webnewhome%3DB%2Cwebslidetag%3DB%2CwebTagRank%3DB%2CwebTagHover%3DB%2CWebTool0703%3Dnew%2Call_lists_sort%3Dc; acf_ssid=1729747294807327115; Hm_lvt_e99aee90ec1b2106afe7ec3b199020a7=1780155805; Hm_lpvt_e99aee90ec1b2106afe7ec3b199020a7=1780155805; HMACCOUNT=498D2F764FF3F7F0; acf_did=73d91171ec9e4614d1f5532c00011701"

# 接口一：斗鱼热梗表情 API
API_URL_POPULAR = "https://www.douyu.com/japi/interact/comm/dfans/emojis?rid=5720533" # 请替换为你抓取的真实热梗完整 URL
# 接口二：斗鱼系统普通表情 API
API_URL_COMMON = "https://www.douyu.com/wgapi/yuba/api/feed/webEmoji"  # 请替换为你抓取的真实系统表情完整 URL

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "keep-alive",
    "Cookie": COOKIE
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

    print(f"📡 [全速拉取] 斗鱼表情: {name.ljust(12)} | URL末尾: {url[-45:]}")
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

def parse_deep_node_overwrite(node, final_emoji_map, download_tasks, output_img_dir):
    """
    深度探测器（直接覆盖模式）：
    深入多层嵌套 Map 抓取单体。自动将大 Key 清洗为 "[xxxx]" 格式。
    如果遇到同名表情，直接进行无情覆盖，不再追加序列号尾缀。
    """
    if isinstance(node, dict):
        if "img_url" in node and isinstance(node["img_url"], str) and node["img_url"].strip().startswith("http"):
            if node.get("is_deleted") == 1:
                return
                
            simple_name = node.get("simple_name", "").strip()
            img_url = node["img_url"].strip()
            
            if not simple_name or not img_url:
                return
                
            # 【核心规则】普通表情大 Key 统一格式化为 "[指责]" 形式
            save_key = f"[{simple_name}]"

            # 1:1 像素级复刻原接口单体数据模型（同名时直接覆盖前面的数据）
            final_emoji_map[save_key] = {
                "simple_name": simple_name,
                "img_url": img_url,
                "is_deleted": node.get("is_deleted", 0),
                "sort": int(node.get("sort", 0))
            }
            
            # 本地物理文件名：直接使用纯净的表情名，不带数字尾缀（如：惊恐.png）
            ext = ".gif" if ".gif" in img_url.lower() else ".png"
            local_name = f"{simple_name}{ext}"
            
            download_tasks.append((img_url, os.path.join(output_img_dir, local_name), save_key))
            return
            
        for value in node.values():
            parse_deep_node_overwrite(value, final_emoji_map, download_tasks, output_img_dir)
            
    elif isinstance(node, list):
        for item in node:
            parse_deep_node_overwrite(item, final_emoji_map, download_tasks, output_img_dir)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    flutter_root = _find_flutter_root(script_dir)
    
    output_json_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "json"))
    output_img_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "images", "douyu"))
    output_json_path = os.path.join(output_json_dir, "douyu.json")

    if not os.path.exists(output_json_dir): os.makedirs(output_json_dir)
    if not os.path.exists(output_img_dir): os.makedirs(output_img_dir)

    final_emoji_map = {}
    download_tasks = []

    # ----------------------------------------------------
    # 解析接口一：热梗表情 (popular) -> 保持格式为 梗已老实
    # ----------------------------------------------------
    print("📖 正在请求斗鱼接口一（热梗表情）...")
    try:
        res1 = requests.get(API_URL_POPULAR, headers=HEADERS, timeout=15).json()
        popular_list = res1.get("data", {}).get("popularEmojis", {}).get("list", [])
        
        for item in popular_list:
            name = item.get("name", "").strip()
            img_url = item.get("webPic", "").strip() or item.get("appPic", "").strip()
            
            if not name or not img_url:
                continue

            final_emoji_map[name] = {
                "simple_name": name,
                "img_url": img_url,
                "is_deleted": 0,
                "sort": int(item.get("msgId", 0))
            }

            ext = ".gif" if ".gif" in img_url.lower() else ".png"
            local_name = f"{name}{ext}"
            download_tasks.append((img_url, os.path.join(output_img_dir, local_name), name))
        print(f"✅ 成功重构热梗表情 {len(popular_list)} 个")
    except Exception as e:
        print(f"⚠️ 解析热梗接口失败: {e}")

    # ----------------------------------------------------
    # 解析接口二：系统普通表情 (common) -> 强转为 [指责] 格式（直接覆盖模式）
    # ----------------------------------------------------
    print("📖 正在请求斗鱼接口二（系统普通表情，直接覆盖同名项）...")
    try:
        res2 = requests.get(API_URL_COMMON, headers=HEADERS, timeout=15).json()
        common_data_root = res2.get("data", [])
        
        # 深度探测抓取，重名时后方的表情直接覆盖前方表情
        parse_deep_node_overwrite(common_data_root, final_emoji_map, download_tasks, output_img_dir)
            
        print(f"✅ 系统表情组深度清洗完毕。当前大 Map 内的唯一键值数: {len(final_emoji_map)} 个")
    except Exception as e:
        print(f"⚠️ 解析普通表情接口失败: {e}")

    # ----------------------------------------------------
    # 资产持久化与多线程下载
    # ----------------------------------------------------
    if not final_emoji_map:
        print("❌ 两个接口均未解析出任何有效资产，请检查配置。")
        return

    # 由于 download_tasks 中可能存在因重名导致的重复下载任务（下载到同一个路径）
    # 我们在多线程下载前，对下载任务按“本地保存路径”进行去重，避免对同一个物理文件并发写
    unique_download_tasks = {}
    for task in download_tasks:
        url, file_path, name = task
        unique_download_tasks[file_path] = (url, file_path, name)
    final_download_tasks = list(unique_download_tasks.values())

    # 完美保存为纯净无暇的大 Map 字典结构
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(final_emoji_map, f, ensure_ascii=False, indent=2)
    print(f"✨ 斗鱼双端资产清洗完成！直接覆盖重名项，配置已覆写至:\n   {output_json_path}")

    # 16 线程火力全开满载倾泻下载
    total_tasks = len(final_download_tasks)
    print(f"\n📥 🚀【火力全开】16 线程满载并发，开始向下倾泻下载物理图片（去重后共 {total_tasks} 张）...")
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(_download_worker, final_download_tasks))
        success_count = sum(1 for r in results if r)
        
    print(f"\n🏁 彻底通关！所有纯净的 [转义符] 表情与热梗图已成功落地： {success_count}/{total_tasks} 张图片。")

if __name__ == "__main__":
    main()