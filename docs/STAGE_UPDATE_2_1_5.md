# v2.1.5 阶段更新说明

v2.1.5 是本地互动、弹幕列表阅读和 Windows 鼠标滚轮专项更新，源码版本为 `2.1.5+53`，上游同步基线保持 `liuchuancong/pure_live@18e2afaf`。

## 主要修复

- 本地弹幕延迟 2 秒后同时进入消息列表和直播画面，播放器缓冲期间也保留本地互动结果。
- 延迟消息绑定房间代次，切房和退出时取消，避免本地弹幕串房。
- Android 第一次真实上滑立即暂停列表自动跟随，阅读期间冻结列表并累计新消息。
- 弹幕观看模板改为匹配实时设置值，模板选中标记与实际渲染参数保持一致。
- Windows 主要纵向列表采用 Chromium Impulse 动画滚动控制器，连续鼠标滚轮输入合并成平滑轨迹。

## 构建目标

| 平台 | 产物 |
| --- | --- |
| Android | `PureLive-2.1.5-53-arm64-v8a-release.apk` |
| Windows | `PureLive-2.1.5-windows-x64-setup.exe`、`PureLive-2.1.5-53-windows-x64-portable.zip` |
| Linux | `PureLive-2.1.5-53-linux-x64.tar.gz` |
| macOS | `PureLive-2.1.5-53-macos-universal.zip`、`.dmg` |
| iOS | `PureLive-2.1.5-53-ios-arm64-unsigned-app.zip` |

## 本地门禁

- Built-in Kotlin 审计通过。
- Flutter Analyze 零问题。
- 92 项单元/Widget 测试通过。
- 26/26 平台公开接口探测通过。
- Android arm64 与 Windows x64 Release 完整编译通过，Windows 便携程序完成启动烟雾测试。
