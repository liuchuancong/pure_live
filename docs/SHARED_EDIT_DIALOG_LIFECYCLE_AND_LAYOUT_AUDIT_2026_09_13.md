# 共享文本编辑弹窗生命周期与布局审计

## 范围与稳定复现

本轮以 `d7f70c2e` 为基线，代码修订提交为 `85ca7a73`。范围限 `Utils.showEditTextDialog` 及其 Firebase 邮箱认证配置粘贴调用链；未构建 Android/Windows 候选，未执行 ADB、设备 UI、Windows GUI、Computer Use 或外部网络请求，Astra Light 使用 **0 次**。

旧实现由静态方法在弹窗路由外创建 `TextEditingController`，并在 `Get.dialog` 返回后立即释放。Flutter 的路由结果会先于退出动画子树卸载完成，因此点击确认后，仍处于反向动画中的 `TextField` 会再次访问已经释放的控制器。窄屏和大字号下，固定 420 宽、4～5 行输入区与独立动作区也缺少统一的视口边界。

## 修订

- 将共享编辑器收敛为自有状态的 `_EditTextDialog`；输入控制器在 `initState` 创建，只在弹窗子树真正卸载的 `dispose` 中释放。
- 确认与取消都使用弹窗自身 `BuildContext` 关闭所属路由，确认结果继续逐字返回输入内容，取消继续返回 `null`。
- 弹窗宽度上限为 468，四周保留 16/20 的窗口边距；内容进入具名滚动面，屏幕可用高度成为明确上限。
- 窄窗口或文字缩放达到 1.6 倍时，动作改为纵向全宽排列；大字号使用固定可用视口分配，让标题与 4～5 行编辑区滚动，动作保持可见。
- 普通窗口继续保留紧凑内容高度和右对齐横向动作，不把大字号专用全高布局扩散到桌面常规尺寸。

## 确定性证据

- 有效红灯 `local-artifacts/build-records/20260913T104947924Z-quality-focused.json` 在旧实现上为 **0/2 PASS**；确认退出稳定触发 `A TextEditingController was used after being disposed`，后续帧同时出现渲染与焦点级联异常。
- 修订过程的直接回归先锁定控制器生命周期已恢复，再以 320×480、3.0 倍文字夹具调整可用高度和动作排列；中间布局诊断仅用于定位，不作为完成证据。
- 最终门禁 `local-artifacts/build-records/20260913T121448341Z-quality-focused.json` 覆盖共享编辑器、Firebase 邮箱认证生命周期与 Get 根 Overlay，共 **14/14 PASS**。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**；格式、仓库审计与差异检查通过。共享机器在门禁结束采样仍有 1 个其他任务的活跃重型进程，本批自有测试进程已正常退出，实际 ADB 命令为 0。

## 验收边界

本轮补强 A2-01 的共享配置编辑、认证页粘贴入口、窄屏大字号和系统返回生命周期证据，该项继续保持 `RUN`。Android/Windows 当前候选仍需分别执行真实键盘输入、粘贴、确认、取消、系统返回和连续重开；Windows GUI 批次开始时按仓库规则只创建并复用一个 Astra Light 任务。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
