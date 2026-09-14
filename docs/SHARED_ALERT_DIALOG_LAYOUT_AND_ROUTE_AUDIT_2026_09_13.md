# 共享确认与消息弹窗布局及路由审计

## 范围与稳定复现

本轮以 `ccd28d3c` 为基线，代码修订提交为 `1edf8a67`。范围限 `Utils.showAlertDialog`、`Utils.showMessageDialog` 及账号、WebDAV、Web 搜索调用链；未构建 Android/Windows 候选，未执行 ADB、设备 UI、Windows GUI、Computer Use 或外部网络请求，Astra Light 使用 **0 次**。

旧确认弹窗把正文限制为独立的 400 高滚动容器，再由 `AlertDialog` 追加标题和动作；旧消息弹窗则没有正文滚动边界。320×480、3.0 倍文字夹具分别稳定产生底部 **320 px** 与 **140 px** 的 `RenderFlex` 溢出，关键动作随之离开安全可达区域。两个入口的内置动作还通过全局 `Get.context` 查找 Navigator，而不是关闭构建该动作的弹窗路由。

## 修订

- 两个公开入口共用 `_SharedAlertDialog`，继续保留 `AlertDialog` 类型、确认/取消布尔返回、可选文本、自定义附加动作与遮罩关闭语义。
- 启用 `AlertDialog.scrollable`，让标题和正文共享弹性滚动区域；正文宽度上限为 420，窗口四周保留 16/20 边距。
- 动作横向空间不足时由 `OverflowBar` 按向下顺序换为纵向排列，并保留 8 间距；内置动作最小命中尺寸为 48×48。
- 内置动作使用弹窗自身 `BuildContext` 关闭所属路由；空标题不再创建空白标题节点。

## 确定性证据

- 有效红灯 `local-artifacts/build-records/20260913T123521011Z-quality-focused.json` 在旧实现上为 **0/2 PASS**，两例分别记录 320 px 与 140 px 底部溢出。
- 修订后直接目标回归为 **2/2 PASS**；最终门禁 `local-artifacts/build-records/20260913T131825713Z-quality-focused.json` 覆盖共享弹窗、账号导航、WebDAV 页面、Web 搜索生命周期和 Get 根 Overlay，共 **45/45 PASS**。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**（603.0 秒）；格式、构建策略、仓库审计与差异检查通过，结束时活跃重型进程为 0，实际 ADB 命令为 0。

## 验收边界

本轮补强 A2-01 的共享确认/消息弹窗、窄屏大字号、调用链兼容与路由归属证据，该项继续保持 `RUN`。Android/Windows 当前候选仍需分别执行真实长文案、可选择文本、确认、取消、遮罩关闭和系统返回；Windows GUI 批次开始时按仓库规则只创建并复用一个 Astra Light 任务。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
