# 观看记录保留数量弹窗布局与校验审计（2026-09-14）

## 范围与结论

本批沿 Android / Windows 公共界面清单复核“历史 → 保留数量”，基线为 `a1cf7342067758643877b8a28235a0e302a6db89`，实现提交为 `0272de8a66b3804d02df55cc3f9ecda82bd46a1b`。

旧弹窗只让正文内部滚动，标题、正文与底部动作仍由 `AlertDialog` 外层纵向排列；在 320×480、3.0 倍英文文字下稳定向下溢出 260 px，“Apply”中心位于窗口外的 y=484，滚动后也不能命中。自定义值解析失败时直接返回，页面没有解释，用户无法区分空值、非数字和操作未响应。

现改为一个由 `AlertDialog(scrollable: true)` 管理的统一滚动面，使用 16/20 边距、有界 360 px 正文、纵向全宽 48 px 应用动作和可换行底部动作；自定义输入在弹窗自己的 State 中校验并显示双语行内错误。预设、自定义值和“不限”仍只是草稿，只有确认才写入 `HistoryController`。

## 交互合同

1. 预设、任意非负整数和“不限”都只更新弹窗草稿；取消和系统返回不写历史设置。
2. 空白、非整数和负数保留当前草稿，显示“请输入大于或等于 0 的整数”一类行内说明。
3. 用户继续编辑后立即清除旧错误；按键盘完成或点击“应用”走同一校验函数。
4. `0` 延续既有 `unlimitedHistoryLimit` 语义；正整数延续既有保留上限和截断逻辑。
5. 输入框、应用、取消和确认在 320×480 / 3.0 倍中英文布局下都处于可滚动、可命中的路由内。
6. 输入控制器继续由弹窗 State 持有，退出反向动画结束后再释放。

## 有效红灯

- 记录：`local-artifacts/build-records/20260913T205240401Z-quality-focused.json`
- 原有场景 **19 PASS**，新增两项 **2 FAIL**。
- 非法输入场景找不到预期说明，证明旧操作是静默返回。
- 窄屏大字号场景捕获 `RenderFlex overflowed by 260 pixels on the bottom`；“Apply”命中点为 `(167.9, 484.0)`，超过 480 px 根视口，后续草稿仍为 50。

## 最终验证

- 记录：`local-artifacts/build-records/20260913T205758510Z-quality-focused.json`
- `history_page_test.dart`、`history_metadata_test.dart`、`translation_contract_test.dart` 联合 **30/30 PASS**。
- 新增覆盖非法输入 → 行内错误 → 继续编辑清错 → 应用草稿 → 确认落盘，以及 320×480 / 3.0 倍英文文字的完整输入/应用/确认链。
- 本批最后一次 Dart 编辑后的唯一一次 analyze：`No issues found`。
- 中英文 JSON 解析、翻译键合同、仓库完整性审计及构建策略静态检查通过，仓库审计为 0 error。

## 验收边界与下一步

- 本批增加 AND-HISTORY-01、A1-05 和 W1-01 的源码/Widget 证据，三项继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批没有构建候选、启动 Windows GUI、操作手机或发布 3.2.0；Astra Light 使用 0 次。
- 后续累计候选需分别验证触控/鼠标、键盘完成、系统返回、预设/自定义/不限、取消/确认、历史实际截断、重启保持和清空确认。进入 Windows Computer Use GUI 批次时只创建并复用一个 Astra Light 任务。
