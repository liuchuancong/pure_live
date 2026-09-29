# 验收流程（claude 分支）

目的：用最少的重复劳动证明「这次改动没有弄坏任何东西、新功能真的能用」。检查项目见 [双端功能测试清单](TEST_CHECKLIST.md)。

## 四级门禁

| 级别 | 内容 | 什么时候跑 | 通过标准 |
| --- | --- | --- | --- |
| L0 | `flutter analyze` + 受影响测试 | 每个修复提交前 | 无分析问题；受影响测试全过；修 bug 必须先有失败的回归测试 |
| L1 | 全量测试：WSL（`flutter test`）与 Windows（`tool/build_local_release.ps1 -FullRegression`） | 一批修复收尾、发版前 | 两端全过。只在 Windows 运行的测试以 Windows 结果为准 |
| L2 | 全平台探针 | 改动平台适配器后；发版前 | 取到媒体的平台数不少于上次，退化的平台逐个给出根因 |
| L3 | 真机冒烟（Android 走设备租约，Windows 本机） | 发版前；涉及播放器、小窗、录制、系统交互的改动 | 清单中本次相关的 D 项全部通过，结论写入本批报告 |

发版前 L0～L3 全部完成，另加发布检查：版本号与 workflow 默认标签同步、`tool/validate_build_policy.ps1` 通过、三平台从同一提交构建、APK 签名 / 包名 / 版本号 / 16 KB 对齐核对、Linux 最高 GLIBC 不超过 2.39、各文件 SHA-256 与 GitHub 附件一致。

## 真机规则

- 手机由 biliroaming、xhs、purelive 三个任务共用。所有安装、启动、点击、输入都在 `purelive` 租约内进行（`C:\Users\123\Documents\Codex\shared-device-test-rotation\Invoke-DeviceTestTurn.ps1 -Lane purelive`）。
- 每一批点击或输入之前先确认前台是 Pure Live；不是就停止，不操作其他应用。
- 真机项集中成批执行：一次租约内按清单顺序跑完本批全部 D 项，避免为单个修复反复占用手机。
- 结束时关闭 Pure Live 的小窗与播放、恢复进入前的前台应用，然后释放租约。

## 判定与记录

- 每个修复说明根因，并附重现条件。靠延时、刷新或重试掩盖的修改不算修复。
- 只在某一平台、某种网络下复现的失败，写明环境差异（例如 Clash 出口地区、TLS 指纹、WebView 依赖），不笼统归为「偶发」。
- 结果只写在一个地方：平台结论写 [全平台探针报告](PLATFORM_PROBE_2026_09_25.md) 的新一期，Issue 结论写 [分诊账本](ISSUE_TRIAGE_LEDGER_3_2_0.md)，版本变化写 [版本说明](../RELEASE_NOTES.md)。
