# Windows 标题栏 Overlay 异常：实窗复现与修订（2026-09-24）

## 运行现象与根因

`52be1624` 的本地 Windows Debug 客户端一启动就显示 Flutter 红色异常条，提示 `No Overlay widget found. RawTooltip widgets require an Overlay widget ancestor within the closest LookupBoundary.`。该现象在首屏、热门、搜索、多画面和录制中心持续存在；GUI 截图保留在本批 Computer Use 工具输出中，没有另存文件。

标题栏由 `MaterialApp.builder` 的 `DesktopManager.buildWithTitleBar` 放在 Navigator 的兄弟位置。标题栏链接与窗口按钮的 `Tooltip` 因而位于 Navigator Overlay 外；当前 Flutter 的 `RawTooltip` 在构建时即检查 Overlay，不以鼠标悬停为前提。无障碍 `Semantics` 名称、键盘操作及悬停/焦点样式原本独立存在。

新增与生产相同的 `MaterialApp.builder` 层级 Widget 回归。修订前 `test/windows_title_bar_overlay_test.dart` **0/1**，堆栈定位 `desktop_manager.dart` 标题栏 Tooltip，记录 `20260923T183200154Z-quality-focused.json`。修订移除标题栏这两个 Overlay 依赖，保留 Semantics 标签、点击、键盘与悬停/焦点反馈；导航内部的其他 Tooltip 保持。

修订提交 `d1437fe5822e089becb0459ac18af620a1362b3c` 已同步 GitHub。标题栏三个测试文件 **11/11**、全仓 Analyze 无问题，记录 `20260923T183556506Z-quality-focused.json`；本批源码修订后的 Full 仍待后续收敛门禁。

## 新 Windows 候选与 GUI 复验

从干净修订提交串行重建 Windows x64 Debug：`20260923T183912700Z-build-windowsx64-debug.json` 成功，ZIP `PureLive-3.1.8-4121-windows-x64-debug.zip` 143795103 B，SHA-256 `6B6B3413AD929D457DFC4CAD4CC0B6F85ABB5F5F1D995A7F99589BDE296FC5F6`；实测 EXE SHA-256 `AA35D1F49E5D41AAD388098D6B229A84161E0FB37BECF841FD23C7ADBEA3BD37`。仍是未签名 Debug 候选，未发布。

单次 Windows Computer Use 批次中，新候选重新启动后标题与最小化/最大化/关闭控件正常，异常条不再出现；最大化 1536×912、恢复 1276×718，2×2 多画面及 1536×960 全屏与 Escape 恢复正常。导航内部“全屏”提示仍显示。设置首页、Bilibili/虎牙公开热门卡片、搜索首页与平台筛选、录制中心空状态均可见；测试实例正常退出。修复前候选的 1+3、1×2、1×1 空布局、槽位回归、斗鱼热门、Bilibili 分区与录制失败筛选也在同批检查，但这些旧候选结果不移作新候选的完整验收。

本批未执行实际多路播放、音频焦点、长时停帧、真实录制或登录后平台验证；Issue #875 与 #767 保持待原生媒体/性能证据。GUI 自动化的 `sky.type_text` 未产生搜索文字，直接按键可触发 IME 组合态；先按工具与输入法交互疑点记录，不据此判定搜索业务故障。Android 手机只读核对 `25102RKBEC` / `myron`，前台为其他应用；本批没有安装或触控。
