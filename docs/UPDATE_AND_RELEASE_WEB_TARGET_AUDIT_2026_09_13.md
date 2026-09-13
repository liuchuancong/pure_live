# 更新与版本历史 Web 目标归一化审计

## 范围与稳定复现

本轮以 `c281d668` 为基线，代码修订提交为 `ce051c03`。范围限更新源下载地址、版本历史复制链接与下载入口的 HTTP(S) 目标解析和传递；未构建 Android/Windows 候选，未访问生产更新源，未执行 ADB、设备 UI、Windows GUI、Computer Use 或外部网络请求，Astra Light 使用 **0 次**。

旧实现分别维护了两套局部 URI 规则，而且版本历史只校验去除首尾空白后的字符串，随后却把原始字符串交给剪贴板或下载处理器。确定性夹具锁定以下问题：

1. 更新下载与版本历史都会接受包含用户信息的地址，例如凭据样式的 authority。
2. 显式端口超出 1～65535 时，两个入口仍可能把目标视为可用链接。
3. 版本历史的校验值与实际消费值不同，首尾空白和 host 大小写会继续进入剪贴板及注入的下载处理器。

## 修订

- `updateDownloadUri` 复用 `FileUtils.parseHttpUrl` 的完整 URI、HTTP/HTTPS、非空 host、内部无空白与显式端口边界合同。
- 更新资产链接额外拒绝非空 `userInfo`，避免把 authority 中的凭据样式内容交给下载器。
- `releaseHistoryWebUri` 直接复用更新下载入口，不再维护第二套近似判断。
- 复制与下载动作各自只解析一次，并把同一个 `Uri.toString()` 结果交给后续消费者；校验对象与实际消费对象保持一致。
- localhost、IPv4、IPv6、大写 scheme/host、有效端口、路径、查询和片段继续由结构化 URI 统一处理。

## 确定性证据

- 有效红灯 `local-artifacts/build-records/20260913T094910966Z-quality-focused.json` 在旧实现上为 **13 PASS / 3 FAIL**：更新解析、版本历史解析均接受用户信息，版本历史复制动作继续传递未归一化原文。
- 直接修订回归 `local-artifacts/build-records/20260913T095515567Z-quality-focused.json` 覆盖三个相关文件，共 **16/16 PASS**。
- 最终门禁 `local-artifacts/build-records/20260913T101113018Z-quality-focused.json` 覆盖 9 个测试文件，共 **47/47 PASS**；包括更新源、版本历史合同与页面动作、发布资产、状态控制器、布局、下载弹窗和共享 HTTP(S) 解析。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**；仓库审计、格式和差异检查通过，结束后活跃重型进程为 0，实际 ADB 命令为 0。

## 验收边界

本轮补强 A1-05 的真实更新源兼容性以及 A2-01 的复制、打开、下载、安装或 ZIP 分流确定性证据，两项继续保持 `RUN`。Android/Windows 候选仍需以真实更新 feed 覆盖规范地址、带首尾空白地址、用户信息、越界端口及失败恢复。Windows GUI 批次开始时按仓库规则只创建并复用一个 Astra Light 任务；其他步骤继续使用常规模型。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
