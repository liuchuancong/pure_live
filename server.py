import os

# 1. 在这里修改您的目标目录
target_dir = r"D:\flutter\pure_live\lib\modules\auth\components"

# 2. 更新后的文件列表
files_to_create = [
    "user_detail_main_page.dart",
    "user_config_app.dart",
    "user_config_theme.dart",
    "user_config_font.dart",
    "user_config_player.dart",
    "user_config_danmaku.dart",
    "user_config_volume.dart",
    "user_config_favorite.dart",
    "user_config_history.dart",
    "user_config_tags.dart",
    "user_config_iptv.dart",
    "user_config_proxy.dart",
    "user_config_cookie.dart",
    "user_config_webdav.dart",
    "user_config_exit.dart",
    "user_config_startup.dart",
    "user_config_windowSize.dart",
    "user_config_refresh.dart",
    "user_config_page.dart"
]

# 3. 自动创建不存在的文件夹
if not os.path.exists(target_dir):
    os.makedirs(target_dir)
    print(f"[目录] 成功创建目标文件夹: {target_dir}")

# 4. 遍历并创建文件
for file_name in files_to_create:
    file_path = os.path.join(target_dir, file_name)
    
    if os.path.exists(file_path):
        print(f"[-] 文件已存在，跳过: {file_name}")
    else:
        # 使用 'x' 模式确保只在文件不存在时创建，防止意外覆盖
        with open(file_path, 'x', encoding='utf-8') as f:
            pass
        print(f"[+] 成功创建文件: {file_name}")

print("\n新文件列表创建完成！")
