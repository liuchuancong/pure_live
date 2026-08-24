# Pure Live v2.9.1 阶段更新

## 范围

- 版本：`2.9.1+4080`
- 源码基线：延续上游 `liuchuancong/pure_live@25f833ea`
- 本轮交付：Android `arm64-v8a` Release
- 其他平台：继续使用 v2.9.0 对应资产

## 设计与实现

1. 横屏清晰度/线路、直播记录和本地弹幕样式采用靠右半屏内容优先布局；手机半屏保持纵向紧凑，桌面宽屏允许内部双栏。
2. 直播记录使用双栏 16:9 封面卡片，平台、热度/观看时间叠加到封面，标题与主播收敛到底部 48 px 信息区。
3. 本地弹幕增加 6 组模板、12 种主色、独立效果色、三种位置、四种字体、透明度、字距、粗体、斜体、描边、阴影/微光和固定停留时间。
4. 共享编辑器继续服务竖屏输入、横屏输入、本地互动页和设置页；`LiveMessageStyle` 携带最终样式，主画面和 PiP 均在消息进入渲染器时解析。
5. 个性化效果编译进 `Paragraph`/`Picture` 缓存；缓存键覆盖全部新增参数，固定弹幕轨道按每条消息的独立时长释放。

## 研究依据

- DanmakuFlameMaster：实时弹幕、字体与多种显示效果的可扩展设计。
- weizhenye/Danmaku：滚动、顶部、底部模式，以及字号、颜色、描边、阴影和速度组合。
- windowsair/bilibili_danmaku：字体、透明度、粗体、描边、阴影、显示范围和持续时间配置。
- Flutter 渲染建议：将效果保持为可缓存的文字绘制，避免在每帧引入额外透明/裁剪层。

## 验证

- JSON 翻译文件解析通过。
- `test/live_play_navigation_ui_test.dart`：半屏尺寸与桌面内部拆分策略。
- `test/local_interaction_controller_test.dart`：样式归一化、模板和边界值。
- `test/barrage_queue_test.dart`：个性化缓存键、队列、帧率与缓存边界。
- 构建命令、耗时、资源峰值、缓存状态、APK 路径和 SHA-256 由 `local-artifacts/build-records/` 与 GitHub Release 元数据记录。
