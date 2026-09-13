# 关注分区取消关注弹窗布局与事务审计（2026-09-14）

## 范围与结论

本批复核分区页右下角关注按钮的取消关注路径。基线为 `3c8d1b0dfb0784dfbf444329b08b2f7c5846950f`，实现提交为 `ff57bcbd011a77902fc142b3b6784086d78f5dcf`。

旧确认弹窗没有统一滚动边界；在 320×480、3.0 倍英文文字和长分区名称下稳定向下溢出 128 px。旧回调还会直接发起 `showDialog(...).then(...)`，没有进行中门禁，同一点击回调被连续触发两次时会叠加两个确认路由。

现将按钮改为有状态单次事务：发起动作时同步设置忙碌门禁并捕获目标分区，取消关注确认由当前页面 Navigator 持有，确认、取消都从弹窗自己的 context 返回。弹窗使用统一可滚动面、16/20 窗口边距、420 px 正文宽度上限、向下动作溢出和至少 48×48 的操作尺寸。

## 交互合同

1. 未关注状态点击后直接新增当前捕获的分区；操作结束再开放下一次点击。
2. 已关注状态只创建一个确认路由；快速重复点击不叠加弹窗或重复提交删除。
3. 取消和系统返回保持关注数据不变；确认只删除弹窗文案所对应的捕获目标。
4. 分区名称缺失时延续双语 `unnamed_area` 回落，不对空字段做强制解包。
5. 320×480、3.0 倍英文文字和长名称下，正文可滚动，取消与确认均保持可见、可命中。
6. 路由结束或控件销毁后清理忙碌状态；状态更新受 `mounted` 保护。

## 有效红灯

- 记录：`local-artifacts/build-records/20260913T210352670Z-quality-focused.json`。
- 原有场景 **4 PASS**，新增两项 **2 FAIL**。
- 窄屏大字号场景捕获 `RenderFlex overflowed by 128 pixels on the bottom`。
- 连续调用同一点击回调后找到两个 `AlertDialog`，证明旧路径可叠加确认路由。

## 最终验证

- 记录：`local-artifacts/build-records/20260913T210846233Z-quality-focused.json`。
- `favorite_areas_page_test.dart`、`favorite_area_identity_test.dart`、`area_artwork_test.dart` 联合 **24/24 PASS**。
- 新增覆盖 320×480 / 3.0 倍英文长名称的动作可达性、取消保持，以及同步双触发仅保留一个确认路由。
- 本批最后一次 Dart 编辑后的唯一一次 analyze：`No issues found`。
- 构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；仓库审计为 0 error。

## 验收边界与下一步

- 本批为 A1-03 补充源码与 Widget 证据，该项保留既有 `PASS`；W1-01 保持 `RUN`。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批没有构建候选、启动 Windows GUI、操作手机或发布 3.2.0；Astra Light 使用 0 次。
- 累计候选继续验证 Android 触控和 Windows 鼠标下的短/长名称、取消/确认、系统返回、快速重复操作、数据保持与重启恢复。进入 Windows Computer Use GUI 批次时只创建并复用一个 Astra Light 任务。
