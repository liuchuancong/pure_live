# 下载文件名 UTF-8 边界与冲突审计

## 范围与稳定复现

本轮以 `090caa64` 为基线，代码修订提交为 `83f38ecc`。范围限更新页、版本历史与下载弹窗共用的安全文件名生成，以及 `.part` 暂存和 `.previous` 回滚文件所需的单目录项边界；未构建 Android/Windows 候选，未访问生产更新源，未执行 ADB、设备 UI、Windows GUI 或 Computer Use，Astra Light 使用 **0 次**。

旧实现把下载文件名限制为 160 个 Dart UTF-16 code unit，但 Android/Linux 常见文件系统按 UTF-8 字节限制单个目录项。稳定夹具确认两类问题：

1. 160 个中文字符可远超 255 UTF-8 字节，再追加 `.part` 或 `.previous` 后，下载会在建立暂存/回滚文件时触发路径错误。
2. 直接按 code unit 截断会切开 emoji 的代理项对，生成无法完整 UTF-8 往返的字符串。
3. 两个仅在长名称尾部不同的发布资产会得到相同截断名，第二次下载可能覆盖第一份已提交文件。

## 修订

- 文件名先通过 Unicode scalar 重建，清除截断前已有的孤立代理项；既有路径分隔符、控制字符、双向控制字符、Windows 保留名和首尾点/空格规则继续保留。
- 将最终 basename 限制为 **240 UTF-8 字节**，为最长的 `.previous` 后缀预留空间，使回滚名保持在 255 字节以内；`.part` 暂存名同步满足该边界。
- 截断按完整 Unicode scalar 逐个计量 UTF-8 字节，不切开中文、emoji 或其他补充平面字符。
- 保留最多 32 UTF-8 字节的扩展名；长名称加入原始安全候选的 12 位 SHA-256 摘要，使共享超长前缀但尾部不同的资产保持不同文件名。
- 既有原子下载链不变：新内容先写 `.part`，提交前把旧成品移到 `.previous`，成功后移除回滚文件，失败则恢复旧成品。

## 确定性证据

- 有效红灯 `local-artifacts/build-records/20260913T092357265Z-quality-focused.json` 在旧实现上为 **8 PASS / 2 FAIL**：超长中文资产发生截断碰撞，emoji 名称无法完整 UTF-8 往返。
- `local-artifacts/build-records/20260913T092555789Z-quality-focused.json` 与 `20260913T092733984Z-quality-focused.json` 只记录实现后的格式门禁调整，不作为行为结果。
- 直接修订回归 `local-artifacts/build-records/20260913T093535084Z-quality-focused.json` 为 **10/10 PASS**；新增断言同时核对扩展名、不同摘要、`.previous` 总字节数和 Unicode 往返。
- 最终门禁 `local-artifacts/build-records/20260913T094231406Z-quality-focused.json` 覆盖 8 个测试文件，共 **39/39 PASS**；包括下载生命周期、更新源、发布资产、更新页/版本历史布局与动作、路径管理和 HTTP(S) 目标合同。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**；仓库审计、格式和差异检查通过，结束后活跃重型进程为 0，实际 ADB 命令为 0。

## 验收边界

本轮补强 A1-05 的更新/版本历史/系统下载链与 A2-01 的下载弹窗确定性证据，两项继续保持 `RUN`。Android/Windows 候选仍需以真实长中文、emoji、共享超长前缀和既有同名成品验证下载、打开、安装或解压、取消、失败恢复及重新下载。Windows GUI 批次开始时按仓库规则只创建一个 Astra Light 任务，并复用至该批次结束。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
