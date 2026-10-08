# Desktop(桌面形态)

> Windows / macOS / Linux 的体验层约定。

- **窗口**:window_manager + flutter_acrylic(亚克力/毛玻璃)、自定义标题栏(标题本地化,标题栏透出背景画布——v1 方案延续)、单实例、托盘、关闭到托盘策略。
- **输入**:键盘快捷键(空格/Esc/F/M——直播间键位表可测可切,v1 经验)、鼠标 hover 态、滚轮音量/进度、右键菜单。
- **播放**:硬解开关与 mpv 调优(pure_live_media)、桌面歌词(lyric 桌面形态)、多窗口/多画面经 media_core。
- **系统集成**:文件关联(m3u/备份)/ 深链接协议注册 / 开机自启(可选)/ 拖拽导入(desktop_drop)。
- **平台差异**:Linux 打包(deb/portable,libmpv 系统依赖在打包层解决)、macOS 签名公证、Windows MSIX/EXE——全部在 CI 打包层,不影响业务。
