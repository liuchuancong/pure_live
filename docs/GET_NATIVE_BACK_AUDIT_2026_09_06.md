# Get 原生过渡与 Android 预测返回审计（2026-09-06）

> 2026-09-16 后续：Issue #852 的厂商系统报告与 Flutter 上游仍开放的共享元素预测返回输入阻塞问题
> 形成一致风险边界。`6fbc1685` 已让普通 Android 路由使用不接管 start/update 的 `FadeForwards`
> 策略，同时保留 commit 的标准 Navigator 回退、cancel 语义及直播页自有返回仲裁。源码与相邻回归
> **21/21 PASS**，ColorOS 14 实机仍待复验；见
> [专项审计](ISSUE_852_COLOROS_SYSTEM_BACK_AUDIT_2026_09_16.md)。

## 范围与复现

应用基线 `6babe449`，证据文档提交 `12f2384f`，Flutter 3.47.0。沿实际内置 GetMaterialApp / GetPageRoute 的 `Transition.native` 路由检查；未连接手机，未合并上游。

新增 `test/get_native_predictive_back_test.dart` 向真实 `flutter/backgesture` 通道发送 start、update、commit / cancel，检查中途 animation 值、popGestureInProgress 与最终导航页面。另注入自定义 PageTransitionsBuilder，验证实际主题对象与调用计数。

- 首次门禁因未格式化夹具终止，`20260905T230754166Z-quality-focused.json`，不作为行为红测。
- 格式化后的有效红基线：**2 通过 / 1 失败**，`20260905T231413306Z-quality-focused.json`，194.418 秒，结束活跃重型进程 1。
- 标准 Android 预测返回提交和取消均通过。自定义主题过渡 builder 调用次数为 0，稳定失败。

## 第一处错误与修复

`lib/get/get_navigation/src/routes/get_transition_mixin.dart` 的 `Transition.native` 分支硬编码 `const PageTransitionsTheme()`，绕过 `Theme.of(context).pageTransitionsTheme`；同文件 default 分支已尊重应用主题，因此两条原生选择路径不一致。

局部修复只替换主题读取，不改返回通道、手势检测、动画参数、页面栈或直播 PopScope。原始 raw animation 与手势包装保持。恢复旧行为的回滚点是此单行，不需要改 SDK 或全局关闭预测返回。

本地 `v3.1.2` 同路径已含硬编码，属于已有缺陷，而非本次画质改动引入；尚未进一步断言外部上游最新状态。该主题配置缺陷与 #852 的 ColorOS 卡住现象分开跟踪：前者已复现，后者仍 `not-reproduced`。标准 Widget 路由通过不证明厂商系统实机已通过。

## 验证状态

修复后一次检查因该旧文件 import 分组格式退出（`20260905T232503511Z-quality-focused.json`）；格式化仅补两处空行。最终三组（新预测返回、直播返回作用域、竖屏房间过渡）**14/14**，`20260905T233151949Z-quality-focused.json`。一次 analyze 239.3 秒，无错误，一项新夹具冗余 typed_data import 提示已删除；不把该运行写成零诊断，也未为删除 import 重复整仓分析。竖屏旧夹具存在 localization key 警告，保留证据，不混作生产翻译缺失。未构建包含此修复的新安装包，未发布 3.2.0。
