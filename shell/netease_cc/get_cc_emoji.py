import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# ==================== 配置区域（仅读取这2个文件） ====================
FILE_1 = "netease_cc.json"  # 独立对象数组文件
FILE_2 = "owl_emt_cdn.json"   # owl/hero 内含 null 的字典文件

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
}
# ====================================================================

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
    if os.path.exists(path) and os.path.getsize(path) > 100:
        return True
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

def parse_cc_minimalist(node, unified_map, download_tasks, output_img_dir):
    """
    深度递归扫描器：
    专门筛选出包含 text 的单体，强行只保留 id, pic, text。
    大 Key 统一包装为 "[text]" 格式。
    """
    if node is None:
        return

    if isinstance(node, dict):
        # 触底目标单体判定：包含 text 并且包含任意级别的图片链接
        if "text" in node and any(k in node for k in ["png_big", "pic", "gif_big"]):
            text_val = str(node.get("text", "")).strip()
            if not text_val:
                return

            # 【核心规则】 pic 字段严格锁定 png_big，如果没有则用 pic 或 gif_big 兜底
            pic_url = node.get("png_big", node.get("pic", node.get("gif_big", "")))
            if not pic_url or not isinstance(pic_url, str) or not pic_url.strip().startswith("http"):
                return
            pic_url = pic_url.strip()

            save_key = f"[{text_val}]"

            # 🛠️ 纯净 3 字段模型组装
            unified_map[save_key] = {
                "id": node.get("id", 0),
                "pic": pic_url,
                "text": text_val
            }
            
            # 图片文件名统一用纯文本名（如：费城融合队.png），同名直接覆盖
            ext = ".gif" if ".gif" in pic_url.lower() or "gif_big" in node else ".png"
            local_name = f"{text_val}{ext}"
            download_tasks.append((pic_url, os.path.join(output_img_dir, local_name), save_key))
            return

        # 如果没有触底，继续深入字典底层剥离
        for value in node.values():
            parse_cc_minimalist(value, unified_map, download_tasks, output_img_dir)

    elif isinstance(node, list):
        # 剥离数组，自动略过其中的 null 脏数据
        for item in node:
            parse_cc_minimalist(item, unified_map, download_tasks, output_img_dir)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    flutter_root = _find_flutter_root(script_dir)
    
    # 建立网易CC存储路径
    output_json_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "json"))
    output_img_dir = os.path.abspath(os.path.join(flutter_root, "assets", "emo", "images", "netease_cc"))
    output_json_path = os.path.join(output_json_dir, "netease_cc.json")

    if not os.path.exists(output_json_dir): os.makedirs(output_json_dir)
    if not os.path.exists(output_img_dir): os.makedirs(output_img_dir)

    unified_map = {}
    download_tasks = []

    # 仅循环处理你拥有的这两个本地文件
    for filename in [FILE_1, FILE_2]:
        file_path = os.path.join(script_dir, filename)
        if os.path.exists(file_path):
            print(f"📖 正在清洗网易CC本地数据源: {filename}")
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    raw_content = json.load(f)
                parse_cc_minimalist(raw_content, unified_map, download_tasks, output_img_dir)
            except Exception as e:
                print(f"❌ 解析 {filename} 失败: {e}")
        else:
            print(f"⚠️  错误：在当前脚本目录下未找到文件【{filename}】！")

    if not unified_map:
        print("❌ 错误：未成功提取出任何有效的网易CC表情资产。")
        return

    # 物理路径重复写去重（直接覆盖）
    unique_downloads = {}
    for task in download_tasks:
        url, path, name = task
        unique_downloads[path] = (url, path, name)
    final_tasks = list(unique_downloads.values())

    # 覆写保存为大字典 json
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(unified_map, f, ensure_ascii=False, indent=2)
    print(f"✨ 极简3字段模型转换成功！配置已覆写至:\n   {output_json_path}")

    # 16 线程火力全开满载下载
    total_tasks = len(final_tasks)
    print(f"\n📥 🚀【火力全开】16 线程满载高并发，开始下载物理图片（共 {total_tasks} 张）...")
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(_download_worker, final_tasks))
        success_count = sum(1 for r in results if r)
        
    print(f"\n🏁 顺利完成！网易CC精简双文件资产已完美落地： {success_count}/{total_tasks} 张。")

if __name__ == "__main__":
    main()
