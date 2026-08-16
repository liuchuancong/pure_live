# Pure Live v2.0.26

本版本合并上游 `master@2cd1877` 的直播播放架构与平台更新，并集中处理上游仓库近期反馈的播放器、弹幕、音量、字体、全屏、Windows 退出和直播间闪退问题。

## 上游反馈修复

- 修复弹幕显示区域重新进入直播间后回到 100% 的问题，并迁移早期无效速度值（[#731](https://github.com/liuchuancong/pure_live/issues/731)、[#732](https://github.com/liuchuancong/pure_live/issues/732)、[#733](https://github.com/liuchuancong/pure_live/issues/733)）。
- 本地修补 `flame_barrage 0.0.4` 的逐条速度计算，让多行弹幕恢复自然速度差异并保留防追尾计算（[#732](https://github.com/liuchuancong/pure_live/issues/732)）。
- 串行等待播放器关闭、销毁和重新初始化，消除点击刷新后旧播放器延迟暂停新会话的竞态（[#731](https://github.com/liuchuancong/pure_live/issues/731)）。
- 所有桌面播放器统一应用房间或默认音量，音量变更完成后同步持久化和界面提示（[#735](https://github.com/liuchuancong/pure_live/issues/735)）。
- 串行加载字体清单和用户字体，等待 Hive 写入完成，并在字体加载后刷新主题（[#736](https://github.com/liuchuancong/pure_live/issues/736)）。
- Windows/macOS/Linux 全屏统一使用 `window_manager`，修复 Windows 侧边任务栏导致的全屏黑边，同时补齐 macOS 窗口全屏（[#708](https://github.com/liuchuancong/pure_live/issues/708)、[#480](https://github.com/liuchuancong/pure_live/issues/480)）。
- 修复 Windows 单实例互斥体句柄释放、命名管道超时和进程退出路径，规避 WebView2/Geolocation DLL 卸载挂起导致的二次启动失败（[#738](https://github.com/liuchuancong/pure_live/issues/738)）。
- 直播页子控制器使用独立标签并由父控制器直接持有，路由入口校验平台和房间号，状态对象支持显式清空旧错误与弹幕房间，降低偶发进房失败和搜索结果闪退（[#730](https://github.com/liuchuancong/pure_live/issues/730)、[#739](https://github.com/liuchuancong/pure_live/issues/739)）。
- 全局关闭弹幕时仍显示“弹幕设置”和“屏蔽列表”，保留主播放器及小窗弹幕调整入口。

## 新增与优化

- 更新虎牙弹幕注册身份、Tars 加入房间字段和 `OnUserHeartBeat` 心跳包，修复视频正常但弹幕长时间无消息的问题。
- 全平台原生搜索支持滚动加载下一页、结果去重、直播优先排序和分页失败隔离。
- “刷新设置”新增缩略图自动刷新开关与 5 分钟至 6 小时周期；缓存统计/清理改用异步 I/O 并增加并发保护，默认关闭定时刷新以避免额外流量。
- 接口探测新增虎牙直播间数字 `uid` 校验；协议序列化新增确定性单元测试。
- 更新 `better_player_plus`、`flame_barrage` 和 `file_picker` 到当前稳定兼容版本。
- 在系统“设置”和“视频设置”中新增独立小窗弹幕入口，提供实时样式预览、默认值恢复及完整的颜色、字号、速度、透明度、区域、数量、间隔和 FPS 调节。
- 全局弹幕关闭时仍保留直播间的“弹幕设置”和“屏蔽列表”标签，避免设置入口随弹幕列表一同消失。
- Android 默认请求当前分辨率支持的最高刷新率，设置页显示当前/最高 Hz，并支持用户关闭高刷新率模式。
- 恢复 Android API 29+ 的 Impeller 默认渲染路径；直播封面按显示尺寸解码并统一缓存，弹幕增加重绘隔离并限制图片缓存，降低列表滚动和高密度弹幕卡顿。
- 新增 Windows 本机一键质量门禁、Android 分架构 APK、Windows 便携包、EXE 安装包和 SHA-256 校验流程。
- 固定 Flutter 3.44.9、Dart 3.12.2、Git 依赖提交及原生媒体产物，提交 `pubspec.lock`，提高构建可复现性。
- 新增 Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC 公开接口探测。
- 移除失效的斗鱼第三方 HTML 签名中转；抖音匿名 Cookie 改为运行时获取，避免硬编码过期值。
- 备份格式升级到 v3，本地导出、Firebase、WebDAV 和 TV 同步默认排除 Cookie 与 WebDAV 凭据。
- 清理仓库中的签名私钥、证书和构建报告；正式 Android 签名改为仓库外部配置。
- 修复播放器、小窗弹幕、直播切换、分享监听、定时器和订阅的资源释放问题。
- 修复 Bilibili 弹幕节点端口处理，增加动态节点轮换、认证回应确认、30 秒心跳和有界重连。
- 增加缩略图链接归一化、浏览器兼容请求头和“刷新直播缩略图”，修复部分平台封面长期停留在占位图的问题。
- 小窗弹幕样式预览改为实时动画，颜色、字号、速度、透明度、区域、数量、间隔和 FPS 调整后立即反映。
- 首页、分区、收藏和搜索统一改用固定高度懒加载网格，降低瀑布流布局和超大封面解码带来的滚动抖动。
- 增加全平台原生直播搜索、直播优先排序、跨平台去重与部分平台故障提示。
- 区分热度、在线、累计观看和粉丝数，避免把平台不同口径的字段统一显示成在线人数。
- 增加 Android ASMR 助眠模式、纯音频后台保活和可配置自动停止时间。
- 增加本地昵称、头衔、字幕、体验币、等级和礼物特效；相关数据仅保存在本机。
- GitHub Actions 改为手动兜底并缩短产物保留时间，取消每日定时任务和标签自动构建。

## 下载说明

- Android：当前优先发布 `arm64-v8a` APK。
- Windows：优先下载 `PureLive-2.0.26-windows-x64-setup.exe`，也可使用便携 ZIP。
- `SHA256SUMS.txt` 可用于校验下载文件完整性。

Android APK 使用此仓库专用的发布签名。若设备上已有其他签名来源的同包名应用，需要先备份应用数据再安装本版本。本机构建未配置发布密钥时会生成包名为 `com.mystyle.purelive.qa` 的 QA 包，可与正式版并存，不作为正式 Release 附件。
