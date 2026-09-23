# 当前源码完整门禁与双端 Debug 候选（2026-09-24）

输入为干净提交 `6872304256beb2ba2aa726a63ff08c33f6d0fc2e`，包含此前微博精确场次搜索、聚合搜索并发、房间详情与切房状态修订；本批仅将 PandaLive 测试夹具的可选字段写法调整为 null-aware 语法，定向 **5/5** 通过（`20260923T172556028Z-quality-focused.json`）。本次没有合并上游、操作手机或发布版本。

## 完整质量门

`tool/local_ci.ps1 -Scope Full` 在干净输入上成功：全仓 Analyze **No issues found**；Flutter **5310/5310**；公共接口探针 **42/42**；仓库审计 5118 个跟踪文件、0 error、2 项既有清单 warning（已审查的本地 TLS 测试钥匙及空 catch 盘点）。记录 `20260923T173235870Z-quality-full.json`，输入期间源码未变化、结束后无活跃重型进程。这证明源码/夹具门禁，不替代原生客户端场景。

## 串行构建

| 平台 | 本地 Debug 产物 | 核验 |
| --- | --- | --- |
| Windows x64 | `PureLive-3.1.8-4121-windows-x64-debug.zip`，143791330 B；SHA-256 `CB78102432AE4F5DAC9FA36FE4FBEB48A1359596E123E8C97523F2CF8FA993E7` | `20260923T173604049Z-build-windowsx64-debug.json`，构建成功，未签名 |
| Android arm64-v8a | `PureLive-3.1.8-4121-android-arm64-v8a-debug.apk`，290059168 B；SHA-256 `7EDC3D994898541155107F233FFBE07D6929A9BD466B67519D43531BBC76D29B` | `20260923T174057849Z-build-androidarm64-debug.json`；包名 `com.mystyle.purelive`，Manifest code 6121、minSdk 26、16 个原生库、ELF LOAD 至少 `0x4000`、Flutter 资源完整性通过 |

两个构建共用上述源码提交，依次完成，未并行构建。仍是 **3.1.8+4121 Debug 候选**：未覆盖安装手机，Windows GUI/播放/录制与 Android 原生验收尚待执行；无正式签名、Release 产物或 3.2.0 发布证据。

## 下一批

以同一源码/候选完成 Android A0～A8 与 Windows 公共矩阵、平台连接/录制、长时与性能场景。若原生验收暴露业务缺陷，修订后按受影响组重验并为新输入生成候选；在发布前再固定 3.2.0 版本、全平台 Release、签名和更新日志。
