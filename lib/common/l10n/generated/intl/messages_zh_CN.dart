// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh_CN';

  static String m0(number) => "已添加${number}个关键词（点击移除）";

  static String m1(level) => "相似度大于${level}%的弹幕会被合并";

  static String m2(level) => "低于${level}级的用户粉丝牌的弹幕会被过滤";

  static String m3(version) => "发现新版本: ${version}";

  static String m4(name) => "${name}未开始直播.";

  static String m5(name) => "${name}轮播视频中.";

  static String m6(site) => "输入或粘贴 ${site} 的链接";

  static String m7(site) => "确定要退出 ${site} 账号吗？";

  static String m8(site) => "使用${site}APP扫描二维码登录";

  static String m9(version) => "发现新版本: v${version}";

  static String m10(number) => "群号: ${number}";

  static String m11(roomid, platform, nickname, title, livestatus) =>
      "房间号: ${roomid}\n平台: ${platform}\n昵称: ${nickname}\n标题: ${title}\n状态: ${livestatus}";

  static String m12(error) => "发生意外错误：${error}";

  static String m13(time) => "${time} 分钟";

  static String m14(name) => "确定要取消关注${name}吗？";

  static String m15(level) => "低于${level}级的用户等级的弹幕会被过滤";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("关于"),
    "add": MessageLookupByLibrary.simpleMessage("添加"),
    "all": MessageLookupByLibrary.simpleMessage("全部"),
    "app_legalese": MessageLookupByLibrary.simpleMessage(
      "本项目是一个纯本地直播转码应用，登录使用第三方SupaBase服务，本人不收集用户信息，应用程序直接请求直播官方接口，所有操作生成的数据由用户本地保留，可选择性使用SupaBase同步数据。",
    ),
    "app_name": MessageLookupByLibrary.simpleMessage("纯粹直播"),
    "areas_title": MessageLookupByLibrary.simpleMessage("分区"),
    "auto_backup": MessageLookupByLibrary.simpleMessage("备份目录"),
    "auto_refresh_time": MessageLookupByLibrary.simpleMessage("定时刷新时间"),
    "auto_refresh_time_subtitle": MessageLookupByLibrary.simpleMessage(
      "定时刷新关注直播间状态",
    ),
    "auto_rotate_screen": MessageLookupByLibrary.simpleMessage("自动旋转屏幕"),
    "auto_rotate_screen_info": MessageLookupByLibrary.simpleMessage(
      "当全屏播放时,会自动旋转屏幕",
    ),
    "auto_shutdown_time": MessageLookupByLibrary.simpleMessage("定时关闭时间"),
    "auto_shutdown_time_subtitle": MessageLookupByLibrary.simpleMessage(
      "定时关闭app",
    ),
    "backup_directory": MessageLookupByLibrary.simpleMessage("备份目录"),
    "backup_recover": MessageLookupByLibrary.simpleMessage("备份与恢复"),
    "backup_recover_subtitle": MessageLookupByLibrary.simpleMessage("创建备份与恢复"),
    "bilibili": MessageLookupByLibrary.simpleMessage("哔哩哔哩"),
    "bilibili_need_login_info": MessageLookupByLibrary.simpleMessage(
      "哔哩哔哩账号需要登录才能看高清晰度的直播，其他平台暂无此限制。",
    ),
    "bit_rate_0": MessageLookupByLibrary.simpleMessage("原画"),
    "bit_rate_1000": MessageLookupByLibrary.simpleMessage("高清"),
    "bit_rate_2000": MessageLookupByLibrary.simpleMessage("超清"),
    "bit_rate_250": MessageLookupByLibrary.simpleMessage("流畅"),
    "bit_rate_4000": MessageLookupByLibrary.simpleMessage("蓝光"),
    "bit_rate_500": MessageLookupByLibrary.simpleMessage("标清"),
    "cache_manage": MessageLookupByLibrary.simpleMessage("缓存管理"),
    "cache_manage_clear_all": MessageLookupByLibrary.simpleMessage("清理全部缓存"),
    "cache_manage_clear_area": MessageLookupByLibrary.simpleMessage("清理分区缓存"),
    "cache_manage_clear_image": MessageLookupByLibrary.simpleMessage("清理图片缓存"),
    "cache_manage_clear_prompt": MessageLookupByLibrary.simpleMessage(
      "确定要清除缓存吗？",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cc": MessageLookupByLibrary.simpleMessage("网易CC"),
    "change_language": MessageLookupByLibrary.simpleMessage("切换语言"),
    "change_language_subtitle": MessageLookupByLibrary.simpleMessage(
      "切换软件的显示语言",
    ),
    "change_player": MessageLookupByLibrary.simpleMessage("切换播放器"),
    "change_player_subtitle": MessageLookupByLibrary.simpleMessage("切换直播间播放器"),
    "change_theme_color": MessageLookupByLibrary.simpleMessage("主题颜色"),
    "change_theme_color_subtitle": MessageLookupByLibrary.simpleMessage(
      "切换软件的主题颜色",
    ),
    "change_theme_mode": MessageLookupByLibrary.simpleMessage("主题模式"),
    "change_theme_mode_subtitle": MessageLookupByLibrary.simpleMessage(
      "切换系统/亮色/暗色模式",
    ),
    "check_update": MessageLookupByLibrary.simpleMessage("检查更新"),
    "check_update_failed": MessageLookupByLibrary.simpleMessage("检查更新失败"),
    "clear_history": MessageLookupByLibrary.simpleMessage("清除历史记录"),
    "clear_history_confirm": MessageLookupByLibrary.simpleMessage(
      "确定要清除历史记录吗？",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("确认"),
    "contact": MessageLookupByLibrary.simpleMessage("联系"),
    "cookie_check_failed": MessageLookupByLibrary.simpleMessage("Cookie校验失败!"),
    "copy_to_clipboard": MessageLookupByLibrary.simpleMessage("已复制到剪贴板"),
    "copy_to_clipboard_failed": MessageLookupByLibrary.simpleMessage(
      "复制到剪贴板失败",
    ),
    "create_backup": MessageLookupByLibrary.simpleMessage("创建备份"),
    "create_backup_failed": MessageLookupByLibrary.simpleMessage("创建备份失败"),
    "create_backup_subtitle": MessageLookupByLibrary.simpleMessage("可用于恢复当前数据"),
    "create_backup_success": MessageLookupByLibrary.simpleMessage("创建备份成功"),
    "custom": MessageLookupByLibrary.simpleMessage("定制"),
    "danmu_filter": MessageLookupByLibrary.simpleMessage("弹幕过滤"),
    "danmu_filter_info": MessageLookupByLibrary.simpleMessage("自定义关键词过滤弹幕"),
    "danmu_filter_keyword": MessageLookupByLibrary.simpleMessage("弹幕关键词屏蔽"),
    "danmu_filter_keyword_add_info": m0,
    "danmu_merge": MessageLookupByLibrary.simpleMessage("弹幕合并"),
    "danmu_merge_format": m1,
    "dark": MessageLookupByLibrary.simpleMessage("深色模式"),
    "day": MessageLookupByLibrary.simpleMessage("天"),
    "develop_progress": MessageLookupByLibrary.simpleMessage("开发进度"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免责声明"),
    "dlan_button_info": MessageLookupByLibrary.simpleMessage("DLNA投屏"),
    "dlan_device_not_found": MessageLookupByLibrary.simpleMessage("未发现DLNA设备"),
    "dlan_title": MessageLookupByLibrary.simpleMessage("DLNA投屏"),
    "double_click_to_exit": MessageLookupByLibrary.simpleMessage("双击退出"),
    "douyin": MessageLookupByLibrary.simpleMessage("抖音"),
    "douyu": MessageLookupByLibrary.simpleMessage("斗鱼"),
    "download_address": MessageLookupByLibrary.simpleMessage("下载地址"),
    "download_address_enter": MessageLookupByLibrary.simpleMessage("请输入下载地址"),
    "download_address_enter_check": MessageLookupByLibrary.simpleMessage(
      "请输入正确的下载链接",
    ),
    "email": MessageLookupByLibrary.simpleMessage("邮件"),
    "empty_areas_room_subtitle": MessageLookupByLibrary.simpleMessage(
      "下滑/上滑刷新数据",
    ),
    "empty_areas_room_title": MessageLookupByLibrary.simpleMessage("未发现直播"),
    "empty_areas_subtitle": MessageLookupByLibrary.simpleMessage("请点击下方按钮切换平台"),
    "empty_areas_title": MessageLookupByLibrary.simpleMessage("未发现分区"),
    "empty_favorite_offline_subtitle": MessageLookupByLibrary.simpleMessage(
      "请先关注其他直播间",
    ),
    "empty_favorite_offline_title": MessageLookupByLibrary.simpleMessage(
      "无未开播直播间",
    ),
    "empty_favorite_online_subtitle": MessageLookupByLibrary.simpleMessage(
      "请先关注其他直播间",
    ),
    "empty_favorite_online_title": MessageLookupByLibrary.simpleMessage(
      "无已开播直播间",
    ),
    "empty_favorite_subtitle": MessageLookupByLibrary.simpleMessage(
      "请先关注其他直播间",
    ),
    "empty_favorite_title": MessageLookupByLibrary.simpleMessage("无关注直播"),
    "empty_history": MessageLookupByLibrary.simpleMessage("无观看历史记录"),
    "empty_live_subtitle": MessageLookupByLibrary.simpleMessage("请点击下方按钮切换平台"),
    "empty_live_title": MessageLookupByLibrary.simpleMessage("未发现直播"),
    "empty_search_subtitle": MessageLookupByLibrary.simpleMessage("请输入其他关键字搜索"),
    "empty_search_title": MessageLookupByLibrary.simpleMessage("未发现直播"),
    "enable_auto_check_update": MessageLookupByLibrary.simpleMessage("自动检查更新"),
    "enable_auto_check_update_subtitle": MessageLookupByLibrary.simpleMessage(
      "在每次进入软件时，自动检查更新",
    ),
    "enable_background_play": MessageLookupByLibrary.simpleMessage("后台播放"),
    "enable_background_play_subtitle": MessageLookupByLibrary.simpleMessage(
      "当暂时切出APP时，允许后台播放",
    ),
    "enable_codec": MessageLookupByLibrary.simpleMessage("开启硬解码"),
    "enable_dense_favorites_mode": MessageLookupByLibrary.simpleMessage("紧凑模式"),
    "enable_dense_favorites_mode_subtitle":
        MessageLookupByLibrary.simpleMessage("关注页面可显示更多直播间"),
    "enable_dynamic_color": MessageLookupByLibrary.simpleMessage("动态取色"),
    "enable_dynamic_color_subtitle": MessageLookupByLibrary.simpleMessage(
      "启用Monet壁纸动态取色",
    ),
    "enable_fullscreen_default": MessageLookupByLibrary.simpleMessage("自动全屏"),
    "enable_fullscreen_default_subtitle": MessageLookupByLibrary.simpleMessage(
      "当进入直播播放页，自动进入全屏",
    ),
    "enable_screen_keep_on": MessageLookupByLibrary.simpleMessage("屏幕常亮"),
    "enable_screen_keep_on_subtitle": MessageLookupByLibrary.simpleMessage(
      "当处于直播播放页，屏幕保持常亮",
    ),
    "error": MessageLookupByLibrary.simpleMessage("失败"),
    "exit": MessageLookupByLibrary.simpleMessage("退出"),
    "exit_app": MessageLookupByLibrary.simpleMessage("确定退出吗?"),
    "exit_no": MessageLookupByLibrary.simpleMessage("取消"),
    "exit_yes": MessageLookupByLibrary.simpleMessage("确定"),
    "experiment": MessageLookupByLibrary.simpleMessage("实验"),
    "fans": MessageLookupByLibrary.simpleMessage("粉丝牌"),
    "fans_level_danmu_format": m2,
    "favorite_areas": MessageLookupByLibrary.simpleMessage("关注分区"),
    "favorites_title": MessageLookupByLibrary.simpleMessage("关注"),
    "file_name": MessageLookupByLibrary.simpleMessage("文件名"),
    "file_name_input": MessageLookupByLibrary.simpleMessage("请输入文件名"),
    "float_overlay_ratio": MessageLookupByLibrary.simpleMessage("悬浮窗尺寸"),
    "float_overlay_ratio_subtitle": MessageLookupByLibrary.simpleMessage(
      "视频小窗播放时，悬浮窗横向相对比例",
    ),
    "float_window_play": MessageLookupByLibrary.simpleMessage("小窗播放"),
    "follow": MessageLookupByLibrary.simpleMessage("关注"),
    "followed": MessageLookupByLibrary.simpleMessage("已关注"),
    "found_new_version_format": m3,
    "general": MessageLookupByLibrary.simpleMessage("通用"),
    "github": MessageLookupByLibrary.simpleMessage("Github"),
    "grant_access_album": MessageLookupByLibrary.simpleMessage("请授予相册访问权限"),
    "grant_access_file": MessageLookupByLibrary.simpleMessage("请授予文件访问权限"),
    "help": MessageLookupByLibrary.simpleMessage("帮助"),
    "help_and_support": MessageLookupByLibrary.simpleMessage("帮助与支持"),
    "hide_offline_rooms": MessageLookupByLibrary.simpleMessage("隐藏未直播的直播间"),
    "history": MessageLookupByLibrary.simpleMessage("历史记录"),
    "hour": MessageLookupByLibrary.simpleMessage("小时"),
    "huya": MessageLookupByLibrary.simpleMessage("虎牙"),
    "import_live_streaming_source": MessageLookupByLibrary.simpleMessage(
      "导入M3u直播源",
    ),
    "info_is_offline": m4,
    "info_is_replay": m5,
    "input_cookie": MessageLookupByLibrary.simpleMessage("请输入Cookie"),
    "iptv": MessageLookupByLibrary.simpleMessage("网络"),
    "is_new_version": MessageLookupByLibrary.simpleMessage("当前已经是最新版本了"),
    "issue_feedback": MessageLookupByLibrary.simpleMessage("问题反馈"),
    "juhe": MessageLookupByLibrary.simpleMessage("聚合"),
    "keyword_input": MessageLookupByLibrary.simpleMessage("请输入关键词"),
    "kuaishou": MessageLookupByLibrary.simpleMessage("快手"),
    "license": MessageLookupByLibrary.simpleMessage("开源许可证"),
    "light": MessageLookupByLibrary.simpleMessage("浅色模式"),
    "link_empty": MessageLookupByLibrary.simpleMessage("链接不能为空"),
    "live": MessageLookupByLibrary.simpleMessage("直播"),
    "live_room_clarity_line": MessageLookupByLibrary.simpleMessage("线路"),
    "live_room_clarity_line_select": MessageLookupByLibrary.simpleMessage(
      "选择线路",
    ),
    "live_room_clarity_parse_failed": MessageLookupByLibrary.simpleMessage(
      "读取直链失败,无法读取清晰度",
    ),
    "live_room_clarity_select": MessageLookupByLibrary.simpleMessage("选择清晰度"),
    "live_room_jump": MessageLookupByLibrary.simpleMessage("直播间跳转"),
    "live_room_link_access": MessageLookupByLibrary.simpleMessage("链接访问"),
    "live_room_link_direct": MessageLookupByLibrary.simpleMessage("获取直链"),
    "live_room_link_direct_copied": MessageLookupByLibrary.simpleMessage(
      "已复制直链",
    ),
    "live_room_link_direct_read_failed": MessageLookupByLibrary.simpleMessage(
      "读取直链失败",
    ),
    "live_room_link_input": m6,
    "live_room_link_jump": MessageLookupByLibrary.simpleMessage("链接跳转"),
    "live_room_link_parse_failed": MessageLookupByLibrary.simpleMessage(
      "无法解析此链接",
    ),
    "live_room_link_parsing": MessageLookupByLibrary.simpleMessage("链接解析"),
    "live_room_open_external": MessageLookupByLibrary.simpleMessage("打开直播间"),
    "live_room_search": MessageLookupByLibrary.simpleMessage("搜索直播"),
    "local_import": MessageLookupByLibrary.simpleMessage("本地导入"),
    "login_account_exit": m7,
    "login_by_cookie_info": MessageLookupByLibrary.simpleMessage(
      "手动输入Cookie登录",
    ),
    "login_by_qr_info": m8,
    "login_by_username_password": MessageLookupByLibrary.simpleMessage(
      "填写用户名密码登录",
    ),
    "login_expired": MessageLookupByLibrary.simpleMessage("登录已失效，请重新登录"),
    "login_failed": MessageLookupByLibrary.simpleMessage("获取用户信息失败，可前往账号管理重试"),
    "login_not": MessageLookupByLibrary.simpleMessage("未登录"),
    "menu": MessageLookupByLibrary.simpleMessage("菜单"),
    "minute": MessageLookupByLibrary.simpleMessage("分钟"),
    "move_to_top": MessageLookupByLibrary.simpleMessage("移到顶部"),
    "network": MessageLookupByLibrary.simpleMessage("网络"),
    "network_import": MessageLookupByLibrary.simpleMessage("网络导入"),
    "new_version_info": m9,
    "no_new_version_info": MessageLookupByLibrary.simpleMessage("已在使用最新版本"),
    "not_supported": MessageLookupByLibrary.simpleMessage("尚不支持"),
    "offline": MessageLookupByLibrary.simpleMessage("未直播"),
    "offline_room_title": MessageLookupByLibrary.simpleMessage("未开播"),
    "online_room_title": MessageLookupByLibrary.simpleMessage("已开播"),
    "only_living": MessageLookupByLibrary.simpleMessage("只搜索直播中"),
    "platform_settings": MessageLookupByLibrary.simpleMessage("平台设置"),
    "platform_settings_info": MessageLookupByLibrary.simpleMessage(
      "自定义观看喜爱的平台",
    ),
    "platform_show": MessageLookupByLibrary.simpleMessage("平台显示"),
    "play_video_failed": MessageLookupByLibrary.simpleMessage("无法播放直播"),
    "player": MessageLookupByLibrary.simpleMessage("播放器"),
    "player_ali": MessageLookupByLibrary.simpleMessage("阿里"),
    "player_system": MessageLookupByLibrary.simpleMessage("系统"),
    "popular_title": MessageLookupByLibrary.simpleMessage("热门"),
    "prefer_platform": MessageLookupByLibrary.simpleMessage("首选直播平台"),
    "prefer_platform_subtitle": MessageLookupByLibrary.simpleMessage(
      "当进入热门/分区，首选的直播平台",
    ),
    "prefer_resolution": MessageLookupByLibrary.simpleMessage("首选清晰度"),
    "prefer_resolution_mobile": MessageLookupByLibrary.simpleMessage("移动网络清晰度"),
    "prefer_resolution_mobile_subtitle": MessageLookupByLibrary.simpleMessage(
      "当进入直播播放页，移动网络首选的视频清晰度",
    ),
    "prefer_resolution_subtitle": MessageLookupByLibrary.simpleMessage(
      "当进入直播播放页，首选的视频清晰度",
    ),
    "project": MessageLookupByLibrary.simpleMessage("项目"),
    "project_alert": MessageLookupByLibrary.simpleMessage("项目声明"),
    "project_page": MessageLookupByLibrary.simpleMessage("项目主页"),
    "qq_group": MessageLookupByLibrary.simpleMessage("QQ群"),
    "qq_group_num": m10,
    "qr_confirm": MessageLookupByLibrary.simpleMessage("已扫描，请在手机上确认登录"),
    "qr_loading_expired": MessageLookupByLibrary.simpleMessage("二维码已失效"),
    "qr_loading_failed": MessageLookupByLibrary.simpleMessage("二维码加载失败"),
    "qr_loading_refresh": MessageLookupByLibrary.simpleMessage("刷新二维码"),
    "read_and_agree": MessageLookupByLibrary.simpleMessage("已阅读并同意"),
    "reading_clipboard_content_failed": MessageLookupByLibrary.simpleMessage(
      "读取剪切板内容失败",
    ),
    "recover_backup": MessageLookupByLibrary.simpleMessage("恢复备份"),
    "recover_backup_failed": MessageLookupByLibrary.simpleMessage("恢复备份失败"),
    "recover_backup_subtitle": MessageLookupByLibrary.simpleMessage("从备份文件中恢复"),
    "recover_backup_success": MessageLookupByLibrary.simpleMessage(
      "恢复备份成功，请重启",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("删除"),
    "replay": MessageLookupByLibrary.simpleMessage("录播"),
    "retry": MessageLookupByLibrary.simpleMessage("重试"),
    "room_info_content": m11,
    "screen_caste": MessageLookupByLibrary.simpleMessage("投屏"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "search_input_hint": MessageLookupByLibrary.simpleMessage("输入直播关键字"),
    "second": MessageLookupByLibrary.simpleMessage("秒"),
    "select_recover_file": MessageLookupByLibrary.simpleMessage("选择备份文件"),
    "select_transparency": MessageLookupByLibrary.simpleMessage("选择透明度"),
    "settings_app": MessageLookupByLibrary.simpleMessage("外观设置"),
    "settings_close": MessageLookupByLibrary.simpleMessage("关闭"),
    "settings_danmaku_amount": MessageLookupByLibrary.simpleMessage("弹幕数量"),
    "settings_danmaku_area": MessageLookupByLibrary.simpleMessage("弹幕区域"),
    "settings_danmaku_colour": MessageLookupByLibrary.simpleMessage("只显示彩色弹幕"),
    "settings_danmaku_fontBorder": MessageLookupByLibrary.simpleMessage("描边宽度"),
    "settings_danmaku_fontsize": MessageLookupByLibrary.simpleMessage("弹幕字号"),
    "settings_danmaku_opacity": MessageLookupByLibrary.simpleMessage("不透明度"),
    "settings_danmaku_open": MessageLookupByLibrary.simpleMessage("弹幕开关"),
    "settings_danmaku_speed": MessageLookupByLibrary.simpleMessage("弹幕速度"),
    "settings_danmaku_title": MessageLookupByLibrary.simpleMessage("弹幕设置"),
    "settings_danmuku_controller": MessageLookupByLibrary.simpleMessage(
      "弹幕控制器",
    ),
    "settings_danmuku_controller_info": MessageLookupByLibrary.simpleMessage(
      "切换直播间弹幕控制器",
    ),
    "settings_delay": MessageLookupByLibrary.simpleMessage("延迟"),
    "settings_delay_close": MessageLookupByLibrary.simpleMessage("延迟关闭"),
    "settings_delay_close_info": MessageLookupByLibrary.simpleMessage(
      "定时关闭已到时,是否延迟关闭?",
    ),
    "settings_favorite": MessageLookupByLibrary.simpleMessage("关注设置"),
    "settings_home": MessageLookupByLibrary.simpleMessage("主页设置"),
    "settings_log": MessageLookupByLibrary.simpleMessage("日志管理"),
    "settings_other": MessageLookupByLibrary.simpleMessage("其他设置"),
    "settings_player": MessageLookupByLibrary.simpleMessage("直播设置"),
    "settings_time_close": MessageLookupByLibrary.simpleMessage("定时关闭"),
    "settings_timedclose_title": MessageLookupByLibrary.simpleMessage("定时关闭"),
    "settings_title": MessageLookupByLibrary.simpleMessage("设置"),
    "settings_videofit_title": MessageLookupByLibrary.simpleMessage("比例设置"),
    "show": MessageLookupByLibrary.simpleMessage("显示"),
    "show_offline_rooms": MessageLookupByLibrary.simpleMessage("显示未直播的直播间"),
    "soop": MessageLookupByLibrary.simpleMessage("Soop"),
    "success": MessageLookupByLibrary.simpleMessage("成功"),
    "supabase_back_sign_in": MessageLookupByLibrary.simpleMessage("返回登录"),
    "supabase_enter_email": MessageLookupByLibrary.simpleMessage("请输入邮箱地址"),
    "supabase_enter_password": MessageLookupByLibrary.simpleMessage("请输入密码"),
    "supabase_enter_valid_email": MessageLookupByLibrary.simpleMessage(
      "请输入有效的邮箱地址",
    ),
    "supabase_enter_valid_password": MessageLookupByLibrary.simpleMessage(
      "请输入至少6个字符的密码",
    ),
    "supabase_forgot_password": MessageLookupByLibrary.simpleMessage("忘记密码?"),
    "supabase_has_account": MessageLookupByLibrary.simpleMessage("已有帐户? 登录"),
    "supabase_log_out": MessageLookupByLibrary.simpleMessage("退出登录"),
    "supabase_mine": MessageLookupByLibrary.simpleMessage("我的"),
    "supabase_mine_profiles": MessageLookupByLibrary.simpleMessage("上传用户配置文件"),
    "supabase_mine_streams": MessageLookupByLibrary.simpleMessage("关注直播间以及主题等"),
    "supabase_no_account": MessageLookupByLibrary.simpleMessage("没有账户? 注册"),
    "supabase_reset_password": MessageLookupByLibrary.simpleMessage("重置邮箱密码"),
    "supabase_sign_confirm": MessageLookupByLibrary.simpleMessage("请打开邮箱确认"),
    "supabase_sign_failure": MessageLookupByLibrary.simpleMessage("登录失败!"),
    "supabase_sign_in": MessageLookupByLibrary.simpleMessage("登录"),
    "supabase_sign_success": MessageLookupByLibrary.simpleMessage("登录成功!"),
    "supabase_sign_up": MessageLookupByLibrary.simpleMessage("注册"),
    "supabase_unexpected_err": m12,
    "supabase_update_password": MessageLookupByLibrary.simpleMessage("更新密码"),
    "support_donate": MessageLookupByLibrary.simpleMessage("捐赠支持"),
    "switch_platform": MessageLookupByLibrary.simpleMessage("切换直播平台"),
    "synchronize_tv_data": MessageLookupByLibrary.simpleMessage("同步TV数据"),
    "synchronize_tv_data_info": MessageLookupByLibrary.simpleMessage(
      "将数据远程同步到TV",
    ),
    "system": MessageLookupByLibrary.simpleMessage("跟随系统"),
    "telegram": MessageLookupByLibrary.simpleMessage("Telegram"),
    "thank_info": MessageLookupByLibrary.simpleMessage(
      "如果您觉得有更好的建议或者意见，欢迎您联系我们。",
    ),
    "thank_title": MessageLookupByLibrary.simpleMessage("感谢您的使用！"),
    "theme_color_and_transparency": MessageLookupByLibrary.simpleMessage(
      "主题颜色及透明度",
    ),
    "three_party_authentication": MessageLookupByLibrary.simpleMessage("三方认证"),
    "timedclose_time": m13,
    "unable_to_read_clipboard_contents": MessageLookupByLibrary.simpleMessage(
      "无法读取剪贴板内容",
    ),
    "unfollow": MessageLookupByLibrary.simpleMessage("取消关注"),
    "unfollow_message": m14,
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "user_level": MessageLookupByLibrary.simpleMessage("用户等级"),
    "user_level_danmu_format": m15,
    "version": MessageLookupByLibrary.simpleMessage("版本"),
    "version_history": MessageLookupByLibrary.simpleMessage("历史记录"),
    "version_history_info": MessageLookupByLibrary.simpleMessage("历史版本更新记录"),
    "version_history_updates": MessageLookupByLibrary.simpleMessage("版本历史更新"),
    "video": MessageLookupByLibrary.simpleMessage("视频"),
    "videofit_contain": MessageLookupByLibrary.simpleMessage("默认比例"),
    "videofit_cover": MessageLookupByLibrary.simpleMessage("居中裁剪"),
    "videofit_fill": MessageLookupByLibrary.simpleMessage("填充屏幕"),
    "videofit_fitheight": MessageLookupByLibrary.simpleMessage("适应高度"),
    "videofit_fitwidth": MessageLookupByLibrary.simpleMessage("适应宽度"),
    "what_is_new": MessageLookupByLibrary.simpleMessage("最新特性"),
    "yy": MessageLookupByLibrary.simpleMessage("YY"),
  };
}
