import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# ==================== 接口专属配置区域 ====================
# 请务必填入你在浏览器中抓取到的真实、最新的 Cookie
# 抖音的 a_bogus 和 msToken 必须与对应的 Cookie 严格绑定才能请求成功！

# 接口一：直播基础表情
API_URL_1 = "https://live.douyin.com/aweme/v1/web/emoji/list?aid=6383&app_name=douyin_web&live_id=1&device_platform=web&language=zh-CN&enter_from=web_live&cookie_enabled=true&screen_width=2560&screen_height=1440&browser_language=zh-CN&browser_platform=Win32&browser_name=Chrome&browser_version=148.0.0.0&os_name=Windows&os_version=10&msToken=S_O1fcZtZQhYep2m3m9c99cziBSExXRtfyh5ZtK73NldwqexfG79iHyA9fc4TQykL8GMj2eOWwnj-Sh0rbVzcP4NYocXOYtq6tGuvD5NwPKDitXNrKlav55KrIeNW7vp4brTf1BxL4UP6C-oAGll5hKXOrkIOsCN7cAke1vhxacwSc__38YxUA%3D%3D&a_bogus=Yj0fh77ixNARCdMGuKnt99nlBSVlNBSyCeiQRKaKePFMPwzP9mNSBrCxboz7sYQSEuBwiF174nUMbdVcY9Xs1lnkqmkDSBw6xz%2FVVS0ohqw1GlhsgNSwewYFowszUc7x-%2FcnE1051Gsx1dOWnNCxAdC7w%2FvEBcfZPN37V%2FSCT9KmUW8jio%2F9aVbkTXGquj%3D%3D"
COOKIE_FOR_API_1 = "YOUR_COOKIE_FOR_API_1_HERE"

# 接口二：need_all 全量表情包
API_URL_2 = "https://live.douyin.com/aweme/v1/web/emoji/list?device_platform=webapp&aid=6383&channel=channel_pc_web&publish_video_strategy_type=2&need_all=true&update_version_code=170400&pc_client_type=1&pc_libra_divert=Windows&support_h265=1&support_dash=1&cpu_core_num=20&version_code=170400&version_name=17.4.0&cookie_enabled=true&screen_width=2560&screen_height=1440&browser_language=zh-CN&browser_platform=Win32&browser_name=Chrome&browser_version=148.0.0.0&browser_online=true&engine_name=Blink&engine_version=148.0.0.0&os_name=Windows&os_version=10&device_memory=32&platform=PC&downlink=10&effective_type=4g&round_trip_time=100&webid=7603756561349084708&uifid=3336119d6ecc0f2721002588cf880fbc4753b1582d4c54bc5f80aa9273463f02573ba99c0dc805d8ec34a1201eca68b1ab6381dae0f95bb1abe69412d7bf742e390701f78dfbe830df95a9d4a28f7de71d8100db6bd9e89c0efa57952f155080fbade27c07ab0676c1fae9fdb6b24430e55f8fd9776dcf5b261a137f744e79a44c3fd2eb5ebaa1cadfb961eed69fc489c0b280a4cded845e20885f3c22eab2aa40264ed99109c86279e3b27e7154dda9&msToken=TzCJ_SplMALeRrurzh1ILVUvX_QxI3aHiMQWs8FrrvBP1JFhP6PVB-b3bQQi5zvC0bZpl5LcdDqFiXOWAY8enVbmPtUIJ5qckofBI20-8aw8KVAQuqj1yS9-xu8HHecjmK1wNC0JACTbQdOkLeYzkW27pqCjCGLuPaNyyDZTEttcXXng5igBBQ%3D%3D&a_bogus=OJ45ge67Ed8bcVKtmOGzHVMUyS6%2FrTSyOFixRnquCxO%2FPhtPhbNjBPCEaoulXb5zLuBhiK17XfUMbnncuxXT1IHkLmpvu2X62z%2FAV7fLMqNITthsLryhezuzwwsz0chxeAccEIsR1GBN1dQWnqCOABe7F%2FvE-RfZBH-UV%2FtCY9usUCujh929a5LsFhId"
COOKIE_FOR_API_2 = "enter_pc_once=1; UIFID_TEMP=3336119d6ecc0f2721002588cf880fbc4753b1582d4c54bc5f80aa9273463f02573ba99c0dc805d8ec34a1201eca68b1ab6381dae0f95bb1abe69412d7bf742eb45fd3097f602ca30b9f45c9887c5f19b39bc9c86e2a79c1a98c3e9fc0652c6854013ff96ef45d9e427daffd340e7d02; hevc_supported=true; d_ticket=0cfa43096e075d51699a37f22db0fae10859e; UIFID=3336119d6ecc0f2721002588cf880fbc4753b1582d4c54bc5f80aa9273463f02573ba99c0dc805d8ec34a1201eca68b1ab6381dae0f95bb1abe69412d7bf742e390701f78dfbe830df95a9d4a28f7de71d8100db6bd9e89c0efa57952f155080fbade27c07ab0676c1fae9fdb6b24430e55f8fd9776dcf5b261a137f744e79a44c3fd2eb5ebaa1cadfb961eed69fc489c0b280a4cded845e20885f3c22eab2aa40264ed99109c86279e3b27e7154dda9; SelfTabRedDotControl=%5B%5D; live_use_vvc=%22false%22; xgplayer_user_id=330667148257; fpk1=U2FsdGVkX1/PL7nexlvvlc9dWdpPsappK37bJ0ao3ymemyYVqly2Z3P7aBlwHg0etuYRq9q3FADqI/ZR0+bTgA==; fpk2=3c9fc7ddec9b58823c1c96756dbd45d8; SEARCH_RESULT_LIST_TYPE=%22single%22; bd_ticket_guard_client_web_domain=2; passport_csrf_token=72ccdd21086d1840a758162732646061; passport_csrf_token_default=72ccdd21086d1840a758162732646061; SEARCH_UN_LOGIN_PV_CURR_DAY=%7B%22date%22%3A1777961102960%2C%22count%22%3A1%7D; passport_assist_user=Cjy5dsrJ3RVlp10qO8F6rDNwbkN9pVmQsJN3FHsoK-F3kqD0biayDGd3FmkcMUroY5GkmX3nl1mam3stRIgaSgo8AAAAAAAAAAAAAFBizZX4Bb6vHaV7H9ILczYsxytWiUx7QyHnoJzTFHJQmx1cX6g_gEzGKdhL3_zpEhwREN3OkA4Yia_WVCABIgED3-BQsw%3D%3D; n_mh=6_o2FxRqJFPqs_sygrp9oQwzNsSuxRfWfrPzb-CP9P0; uid_tt=0949b53481855b35ee68ab38f137ae93; uid_tt_ss=0949b53481855b35ee68ab38f137ae93; sid_tt=d1ddf31f6796e0801291fcbe5e247a89; sessionid=d1ddf31f6796e0801291fcbe5e247a89; sessionid_ss=d1ddf31f6796e0801291fcbe5e247a89; is_staff_user=false; has_biz_token=false; _bd_ticket_crypt_cookie=15a8b027ce23266c819ee37a472b5c5a; __security_mc_1_s_sdk_sign_data_key_web_protect=496ae2a1-42c0-8da4; __security_mc_1_s_sdk_cert_key=43b28879-4f85-8b7a; __security_mc_1_s_sdk_crypt_sdk=fe76eb69-4d84-8f7d; login_time=1777961131109; __security_server_data_status=1; ttwid=1%7Cm8F5BLprkCCeiSRG-uEHC-y-tOHwnr--dHFcl87Togg%7C1778859644%7Cfc56a86823b3afd69ae734cbd010df6045045369fd98abab3d9ef6d5e084e45a; s_v_web_id=verify_mp733w1j_KGqZz1Zw_kCES_4k5o_BnwN_VJyi5RWxZNA3; is_support_rtm_web_ts=1; stream_recommend_feed_params=%22%7B%5C%22cookie_enabled%5C%22%3Atrue%2C%5C%22screen_width%5C%22%3A2560%2C%5C%22screen_height%5C%22%3A1440%2C%5C%22browser_online%5C%22%3Atrue%2C%5C%22cpu_core_num%5C%22%3A20%2C%5C%22device_memory%5C%22%3A32%2C%5C%22downlink%5C%22%3A10%2C%5C%22effective_type%5C%22%3A%5C%224g%5C%22%2C%5C%22round_trip_time%5C%22%3A100%7D%22; publish_badge_show_info=%220%2C0%2C0%2C1780155068683%22; FOLLOW_LIVE_POINT_INFO=%22MS4wLjABAAAAojqpqORRTXKforAnjdlCukSkFRGqmpH2amgBYFU-R0Y%2F1780156800000%2F0%2F1780155068919%2F0%22; home_can_add_dy_2_desktop=%221%22; is_dash_user=1; xg_device_score=8.182474460888988; has_avx2=null; device_web_cpu_core=20; device_web_memory_size=32; csrf_session_id=c2e654ecbcd232d802a7acac61c3d943; live_private_user=0; __live_version__=%221.1.5.2437%22; webcast_local_quality=origin; live_local_quality=origin; sdk_source_info=7e276470716a68645a606960273f276364697660272927676c715a6d6069756077273f276364697660272927666d776a68605a607d71606b766c6a6b5a7666776c7571273f275e58272927666a6b766a69605a696c6061273f27636469766027292762696a6764695a7364776c6467696076273f275e5827292771273f27343735373d35303034353d32342778; bit_env=CBbEgGmGXXxCOrO-1mbd6-_WDcTBnMT9_-BVJqbY3rLzkj5Qy6gnDhxnPipPid-XyowlmLrEeDJll2Q0FkHZ6ntMi1TI03zEcDx_vQcab7IYu2Z2R2uYLKfHSTdayUQRyNqt_R13owo5IaZnECBoSDHZVnQaW1ByrQxhavZq0pX21F3JXtQE18lxZnNOgAgJ7Ow36iacdaSowczqfWwyQo2lHbYA2ZhGcdqlUATzVLPrY_2gvKD0UwDOgGEMc2S2QERwPBR2q-X9VGXczOqDp6-YtFGFI0bG32YO3eumlHNj5wsFKc619Sn8bWmGREjDJXtPAQw76f6z12ZlDOQQAfTE77EL1nlysjnSAuSXtNAjN8rYZzEYghNjSwKI_tf2fHKkSWcA3P1ochUtxEFPTBUJwhrCdg9zSHDvLR9y8UtN-a7qFdBJQY4WpVp9L0kqPJlgrlkBYF3yjQeH_zFBQzln7Ny78nM6DdImI0_eo4iVts2ChiFBOlUhPOnVTrF5; gulu_source_res=eyJwX2luIjoiYzI2YmJhYzE0ZTUwZDg3M2I0OGE2ZmEwMGJiODE4NzA5MzQ3N2ZhODY1MmFkYmNjODJkZDcyOWQxOTJhZjhlNCJ9; passport_auth_mix_state=pzwya38pe2nfbf6i1uk5y1yxkz8onwc0; sid_guard=d1ddf31f6796e0801291fcbe5e247a89%7C1780155082%7C5184000%7CWed%2C+29-Jul-2026+15%3A31%3A22+GMT; session_tlb_tag=sttt%7C10%7C0d3zH2eW4IASkfy-XiR6if________-1iYaac9mVicAowZX8XuT7uUTTEx7MdlcbQHP92t2FTzM%3D; sid_ucp_v1=1.0.0-KGI1NGM0ZDIxYmI0MDhjODhlM2RhZWI1MzU0ZWE3ZDI3Y2MwMTA4ZjIKHwjb2-CG_wEQyoXs0AYY7zEgDDDHncvNBTgHQPQHSAQaAmxxIiBkMWRkZjMxZjY3OTZlMDgwMTI5MWZjYmU1ZTI0N2E4OQ; ssid_ucp_v1=1.0.0-KGI1NGM0ZDIxYmI0MDhjODhlM2RhZWI1MzU0ZWE3ZDI3Y2MwMTA4ZjIKHwjb2-CG_wEQyoXs0AYY7zEgDDDHncvNBTgHQPQHSAQaAmxxIiBkMWRkZjMxZjY3OTZlMDgwMTI5MWZjYmU1ZTI0N2E4OQ; download_guide=%222%2F20260530%2F0%22; JXEntranceNegative=1; live_can_add_dy_2_desktop=%221%22; live_debug_info=%7B%22roomId%22%3A%227645683290124962600%22%2C%22resolution%22%3A%7B%22width%22%3A1920%2C%22height%22%3A1080%7D%2C%22fps%22%3A84%2C%22audioDataRate%22%3A48000%2C%22droppedFrames%22%3A10%2C%22totalFrames%22%3A53%2C%22videoBuffer%22%3A%5B%5D%2C%22src%22%3A%22https%3A%2F%2Fpull-flv-q26.douyincdn.com%2Fthirdgame%2Fstream-695924554611557182.flv%3Fexpire%3D6a243d46%26sign%3D790159314e713ea55a27f158619cbf16%26exp_hrchy%3Dh2%26arch_hrchy%3Dh1%26major_anchor_level%3Dcommon%26unique_id%3Dstream-695924554611557182_830_flv%26t_id%3D037-2026053023311772681A55595468F27A8F-u9LKpv%26biz_quality%3Dorigin%26biz_protocol%3Dflv%22%2C%22linkmicInfo%22%3A%7B%22uiLayout%22%3A0%2C%22playModes%22%3A%5B%5D%2C%22allDevices%22%3A%22%E8%BF%9E%E7%BA%BF%E8%AE%BE%E5%A4%87%EF%BC%9A%E7%94%B3%E8%AF%B7%E8%BF%9E%E7%BA%BF%E5%90%8E%E6%89%8D%E8%8E%B7%E5%8F%96%22%2C%22audioInputs%22%3A%5B%5D%2C%22videoInputs%22%3A%5B%5D%7D%2C%22href%22%3A%22https%3A%2F%2Flive.douyin.com%2F632294213263%3Factivity_name%3D%26anchor_id%3D4485622248767680%26banner_type%3Drecommend%26category_name%3Dall%26page_type%3Dlive_main_page%26user_id%3D68465208795%22%7D; bd_ticket_guard_client_data=eyJiZC10aWNrZXQtZ3VhcmQtdmVyc2lvbiI6MiwiYmQtdGlja2V0LWd1YXJkLWl0ZXJhdGlvbi12ZXJzaW9uIjoxLCJiZC10aWNrZXQtZ3VhcmQtcmVlLXB1YmxpYy1rZXkiOiJCQzlLQS9PZStOKzY5VUU4bGNoZDhCbWx5SXdTVVdiVnlic251Ky81WUFDOFBMa3dUYms5d0d2UDRqUjVrbTdDSlJvanh6RDNpS3cvbUNZNVZvb1NBakU9IiwiYmQtdGlja2V0LWd1YXJkLXdlYi12ZXJzaW9uIjoyfQ%3D%3D; IsDouyinActive=true; volume_info=%7B%22isMute%22%3Afalse%2C%22isUserMute%22%3Afalse%2C%22volume%22%3A0.12%7D; odin_tt=a2909e3ab9d8940f9cdc80b7d5b0a1c968d5c9cf99b4a2b9a0425982878af433698cb2a177ce0d1efc1cf411b895376629e9b3c139fe4962d4ea237569533ee1; biz_trace_id=aa723ff0; bd_ticket_guard_client_data_v2=eyJyZWVfcHVibGljX2tleSI6IkJDOUtBL09lK04rNjlVRThsY2hkOEJtbHlJd1NVV2JWeWJzbnUrLzVZQUM4UExrd1Riazl3R3ZQNGpSNWttN0NKUm9qeHpEM2lLdy9tQ1k1Vm9vU0FqRT0iLCJ0c19zaWduIjoidHMuMi5iZWM2YmYyMjFiYmZjZThhMTMyMzZhZDczMDczOTg1OTU0ZTNlYTJmNzVmMTA4ZjI3NmQ0ZDIwNjA3OWYwMGJhYzRmYmU4N2QyMzE5Y2YwNTMxODYyNGNlZGExNDkxMWNhNDA2ZGVkYmViZWRkYjJlMzBmY2U4ZDRmYTAyNTc1ZCIsInJlcV9jb250ZW50Ijoic2VjX3RzIiwicmVxX3NpZ24iOiIwTVJQNnJiUEprWmliY3B4cU55b0ZuQk9BYUNMTyt4V1lRVkhhMEJkTnpJPSIsInNlY190cyI6IiMyclF4ODdpRitFUnM3M21NSFNwVFp6dE9yNmh0WEJHeEhKVmRDTFNhcVBKUDBidzN4YTNSSHJOd0dzWE4ifQ%3D%3D"

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