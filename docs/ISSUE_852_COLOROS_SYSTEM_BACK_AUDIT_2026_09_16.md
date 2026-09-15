# Issue #852 ColorOS 14 系统手势返回审计（2026-09-16）

## 结论

[上游 Issue #852](https://github.com/liuchuancong/pure_live/issues/852) 报告 OPPO ColorOS 14
在设置、关于、搜索和链接访问等普通页面使用全面屏返回手势后界面卡住，左上角返回正常，直播间
返回也正常；ColorOS 16 未出现。报告没有日志或录屏，因此厂商系统上的永久卡住仍需对应设备复验。

当前源码原先在亮色、暗色主题中都显式注册 `PredictiveBackPageTransitionsBuilder`。该 builder
会成为 `flutter/backgesture` 的手势所有者；提交后，Flutter `TransitionRoute` 会一直保持
`userGestureInProgress`，直到反向路由动画结束。Flutter 的公开 P2 问题
[#153577](https://github.com/flutter/flutter/issues/153577) 仍记录这种共享元素预测返回在视觉动画结束后
继续阻塞输入的现象。它不是 ColorOS 14 实机复现本身，但与 #852 的“普通页面卡住、直播间自有返回
链正常”边界一致。

提交 `6fbc168590082e99b4ff813b236102a8bfa808d7` 将应用页面转场集中到唯一策略，并让 Android
普通路由使用 Flutter 官方 `FadeForwardsPageTransitionsBuilder`。Android Manifest 的
`enableOnBackInvokedCallback` 保持启用：start/update 没有共享元素动画观察者接管时，commit 会按
WidgetsBinding 的标准回退调用 Navigator pop；cancel 保持当前路由。直播页已有的原生返回仲裁、
PopScope、横竖屏恢复和 PiP 返回逻辑均未改动。当前分类为
**implemented-in-current-source / ColorOS-14-native-recheck-pending**。

## 转场与返回合同

1. 亮色和暗色主题共用 `appPageTransitionsTheme`，Android 与 Windows 都使用 `FadeForwards`；后续
   调整不会再让两套主题发生漂移。
2. 普通 Android 路由仍使用 `Transition.native` 和真实 GetPageRoute，只移除 Flutter 共享元素预测
   动画对系统手势的所有权，不移除 Android 系统返回回调。
3. 系统返回 start/update 在生产策略下不改变当前路由 animation，也不把 Navigator 标记为
   `userGestureInProgress`；commit 通过标准导航回退弹出页面。
4. cancel 不弹出页面；commit 完成后的目的页可以立即再次触发导航，证明没有遗留手势门禁。
5. 测试仍显式注入 `PredictiveBackPageTransitionsBuilder` 覆盖 Get 的预测返回 commit/cancel，避免把
   应用兼容策略误写成对底层路由能力的删除。

## 有效红灯与修复验证

| 层级 | 结果 |
|---|---|
| 有效红灯 | `local-artifacts/build-records/20260915T232702851Z-quality-focused.json`；现有生产 builder、commit 回退和 cancel 回退 **3 PASS / 3 FAIL** |
| 直接回归 | `local-artifacts/build-records/20260915T232805784Z-quality-focused.json`；预测 builder 能力与生产回退策略 **6/6 PASS** |
| 最终相邻回归 | 系统返回、直播返回作用域、竖屏房间转场与主题策略 **21/21 PASS** |
| 最终质量记录 | `local-artifacts/build-records/20260915T233023950Z-quality-focused.json` |
| 静态分析 | 本批唯一一次 analyze，**No issues found**（49.3 秒） |
| 仓库审计 | `local-artifacts/repository-audits/20260915T232854544Z-focused.json`，0 error / 2 warning |
| GitHub 同步 | 代码提交已推送至 `origin` 并精确核对：`6fbc168590082e99b4ff813b236102a8bfa808d7` |

本批没有构建候选、启动 Windows GUI、连接 ADB、操作设备或发布；Astra Light 使用 **0 次**。

## 原生复验边界

- 在含 `6fbc1685` 的累计 Android 候选上，以 ColorOS 14 实机逐项进入设置二/三级页、关于、搜索、
  工具箱链接页，分别重复系统手势提交、取消和左上角返回，并验证返回后的首次点击、滚动与再次导航。
- 同轮收集 Flutter/Activity/ANR 日志和页面录屏，区分动画期短暂不可交互、路由未弹出和进程主线程
  卡住；ColorOS 16 或 Android 17 只作为相邻回归，不替代报告系统。
- 直播间返回、横竖屏、PiP 与普通页连续往返继续使用既有原生门禁，确认普通路由策略没有改变直播
  页自有返回所有权。
- A1-04、A1-05、A2-01 保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
