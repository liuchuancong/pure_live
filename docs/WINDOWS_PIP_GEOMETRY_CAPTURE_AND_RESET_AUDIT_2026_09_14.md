# Windows 小窗几何捕获与重置事务审计（2026-09-14）

## 范围与结论

本批复核 Windows 小窗从原生窗口几何捕获、显示器身份持久化、备份导出到视频设置页手动重置的完整链路。基线为 `806c5b8b401afea263dcfb456618edac4fc366be`，实现提交为 `b13d8dea6d0b54ba2ec0de5f461d2149279f925c`。

审查确认两个相邻根因。第一，运行时 `WindowPipGeometry.update()` 和 `toJson()` 把 `displayId` 放在顶层，归一化器只从当前嵌套结构 `windowsPip.displayId` 或旧别名 `windowsPipDisplayId` 读取它；尺寸与坐标因此保留，显示器 ID 却稳定变为空串。空 ID 在播放器里又被当成任意显示器均匹配，主窗口换屏后可能继续采用另一屏保存的小窗边界，备份也失去精确显示器身份。第二，设置页旧重置入口直接创建普通 `AlertDialog`，没有页面事务门禁；同一回调连续触发会叠加两个确认路由，在 320×480、3.0 倍英文文字下每个弹窗均向下溢出 704 px，动作仍使用含义较弱的通用“确认”。

现将运行时捕获与导出统一为同一个规范嵌套快照，显示器 ID 会裁剪首尾空白并与尺寸、坐标一起保存。重置入口改为独立有状态组件，在创建路由前同步取得单次事务所有权；取消、遮罩、系统返回、确认或页面销毁后统一释放，旧回调再次触发也由同步门禁截断。确认后核对页面与窗口设置控制器生命周期，一次性清空显示器 ID、宽、高、横坐标和纵坐标，并显示双语完成反馈。

确认框统一使用根 Navigator、16/20 窗口边距、420 px 正文宽度上限、滚动正文和向下动作溢出。取消与红色 Filled“重置”动作均至少 48×48，在 320×480、3.0 倍英文文字下保持完整可见和可命中。

## 数据与交互合同

1. 有效的运行时捕获把显示器 ID、尺寸和位置作为一个规范快照提交；显示器 ID 去除首尾空白。
2. 当前备份导出保留同一显示器身份，不把规范字段误降级为空字符串或旧别名。
3. 重置确认出现前后，同一页面只持有一个事务；快速重复触发只创建一个路由。
4. 取消、点击遮罩或系统返回不修改任何已存几何，门禁随后允许重新进入。
5. 确认只提交一次，并同时清空五个字段，避免留下可被误判为有效的部分矩形。
6. 页面或窗口设置控制器退出后不提交旧页面动作，也不发布迟到反馈。

## 有效红灯

- 设置页记录：`local-artifacts/build-records/20260914T025057366Z-quality-focused.json`。旧实现上既有 **4 PASS**，新增一项 **1 FAIL**；连续触发创建两个弹窗，并分别稳定报告 704 px 底部溢出。
- 首轮弹窗修订后，`local-artifacts/build-records/20260914T025238831Z-quality-focused.json` 的同一用例继续以 **4 PASS / 1 FAIL** 暴露捕获后的显示器 ID 为空。
- 控制器记录：`local-artifacts/build-records/20260914T025419531Z-quality-focused.json`。既有 **4 PASS**，新增一项 **1 FAIL**；有效尺寸与坐标写入后 `isValid` 仍为 false。
- 修正运行时捕获后，联合记录 `local-artifacts/build-records/20260914T025519425Z-quality-focused.json` 为 **9 PASS / 1 FAIL**，进一步精确定位到 `toJson()` 再次丢弃显示器 ID。两个结构错配分别修订，没有用放宽断言掩盖。

## 最终验证

- 初步联合记录：`local-artifacts/build-records/20260914T025625521Z-quality-focused.json`，设置页与窗口边界 **10/10 PASS**。
- 最终记录：`local-artifacts/build-records/20260914T025833852Z-quality-focused.json`，以下五个文件联合 **31/31 PASS**：
  - `test/video_settings_resolution_dialog_test.dart`
  - `test/window_size_settings_boundary_test.dart`
  - `test/windows_pip_geometry_test.dart`
  - `test/backup_import_validation_test.dart`
  - `test/translation_contract_test.dart`
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（46.3 秒）。
- 构建策略静态检查、仓库完整性审计及 `git diff --check` 通过；仓库审计为 0 error。

## 验收边界与下一步

- 本批增加 W1-01 与 W2-01 的源码/Widget/持久化证据，两组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批没有启动 Windows 原生候选、移动真实小窗、构建安装包、操作手机或发布 3.2.0；Astra Light 使用 0 次。
- 后续 Windows 候选需在主副屏间分别验证首次打开、拖动与缩放、退出再进、小窗期间切屏、主窗口换屏后的显示器匹配、取消/系统返回/连续点击、确认后默认右下角位置，以及进程重开和备份往返。该 Computer Use GUI 验收批次只创建并复用一个 Astra Light 任务。
