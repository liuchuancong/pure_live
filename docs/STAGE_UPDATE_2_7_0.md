# Pure Live v2.7.0 阶段稳定版

版本：`2.7.0+4077`  
发布日期：2026-08-23  
维护仓库：`wzgrx/pure_live`
上游冻结点：`liuchuancong/pure_live@81ec372a`

## 1. 上游整合

- 使用真实 merge 同步上游 `81ec372a`，共同祖先和后续增量同步关系保持完整。
- 合入 `PopularController` 的关闭状态、generation、平台设置防抖和延迟任务隔离，页面销毁或平台列表变化后，旧加载与相邻平台预热不再回写当前页面。
- 合入取消关注弹窗的路由修复，并让取消、确认按钮使用弹窗自身上下文关闭对应路由。
- 上游同时修改了 Windows PiP 状态归属、图片磁盘缩放缓存、仓库更新源、Windows AppId、Android ABI 清单和一套并发全平台工作流。逐项对照后保留维护版已回归的完整 PiP 位置/大小和跨屏恢复、有界图片缓存、覆盖升级 AppId、`wzgrx` 更新源、实际发布 ABI 及串行构建策略。

## 2. 关注页下拉刷新

首次修复把 `EasyRefresh` 下沉到平台页，但内部 `GridView` / `CustomScrollView` 又显式安装了 Android `ClampingScrollPhysics`。边界位移先被子列表物理模型消耗，刷新器仍然只有回调配置，真实手指拖动既不显示动画也不进入刷新状态。冷启动核验还会与 450 ms 后的 resumed 刷新通过 epoch 互相取消，失败房间因而继续沿用旧开播状态。

本轮调整：

- `BasePageView` 增加嵌套页面自行承载移动端刷新器的能力，其他普通列表维持原行为。
- 每个平台页使用 `EasyRefresh.builder`，builder 提供的 physics 直接安装到当前唯一纵向列表；Material 刷新头固定纵向触发，空列表和短列表均可下拉核验。
- 启动、恢复、定时和手动刷新经单锁串行；启动任务存在时直接合并后续全量请求，手动刷新绕过失败冷却。
- 启动期间保留封面、标题与卡片位置，但状态统一显示为 unknown；所有请求结束后只写入和发布一次最终快照，失败项显示“状态待确认”。
- CC、Twitch、SOOP 的刷新路径传播网络与结构异常；虎牙 `REPLAY` 进入录播分组，规范化房间号仍绑定原收藏键。
- Widget 回归由直接调用 callback 升级为真实 pointer drag，并检查 Material 动画与刷新次数。

## 3. 质量门禁

最终修改完成后只执行一次完整门禁：

| 检查 | 结果 |
| --- | --- |
| 构建策略与设备 UI 地图 | 通过 |
| Built-in Kotlin 审计 | 10 个 Gradle 文件通过 |
| Flutter Analyze | 0 issue |
| 单元/Widget 测试 | 229/229 通过 |
| 公开平台接口探测 | 26/26 通过 |
| 总耗时 | 682.596 秒 |
| 峰值进程资源 | CPU 42.73%，工作集 5,379,764,224 bytes，5 个重型进程 |
| 完成后活跃重型任务 | 0 |

质量记录：`20260823T000757112Z-quality-full.json`。

新增回归覆盖关注页真实拖动动画、启动未知态分桶、平台返回不同规范房间号时的收藏合并，以及严格平台刷新能力；播放器、弹幕、PiP 恢复、音频模式、实时人数、搜索排序、Windows 升级迁移和长时间资源边界继续由既有测试覆盖。维护构建中 Twitch 单一目录样本短暂为空，探针改为从多个高流量分类动态选择在线频道后重新执行，26/26 通过。

## 4. 发布矩阵

本轮目标按 Android → Windows → Linux → macOS → iOS 串行构建：

原全平台冻结源码：`a7c6f5f25a7f58f38fd1910423fcd9ac9074572c`。Android 维护构建源码：`3ce3588b3e861133801cc053bae860113ba40643`。

| 平台 | 产物 | 字节数 | SHA-256 | 构建来源 |
| --- | --- | ---: | --- | --- |
| Android arm64-v8a | `PureLive-2.7.0-4077-arm64-v8a-release.apk` | 120,068,897 | `c5edd531f3a42591bcd30f6c654f100ab5cfda6316dfd3961d79c4a13c465f5a` | 本机编译；[22 秒正式签名 32618152342](https://github.com/wzgrx/pure_live/actions/runs/32618152342) |
| Windows x64 | `PureLive-2.7.0-windows-x64-setup.exe` | 56,408,107 | `69298593007c582275c17d0042bf3ba91b08dc9b31fedfeb36bb052fff8bec82` | 本机 Release |
| Windows x64 | `PureLive-2.7.0-4077-windows-x64-portable.zip` | 72,841,836 | `345e00752103f320fc249b537e378fb368451ad9373da6c607d6cad35752f42a` | 本机 Release |
| Linux x64 | `PureLive-2.7.0-4077-linux-x64.tar.gz` | 37,456,662 | `c452cefdb816388f14adf34641eb544aa929e82fe0bbe92f5ae010df7563467f` | [Actions 32608227446](https://github.com/wzgrx/pure_live/actions/runs/32608227446) |
| macOS Universal | `PureLive-2.7.0-4077-macos-universal.dmg` | 113,971,783 | `2e4ff5b628dc3436f8f6e5f86e2a0c285365e270a1e86379b4bfe26f3cb01d05` | [Actions 32608464856](https://github.com/wzgrx/pure_live/actions/runs/32608464856) |
| macOS Universal | `PureLive-2.7.0-4077-macos-universal.zip` | 101,234,766 | `0ead73c263f0d2091aad82769cd85233eb4980f88718e000ebd26824aa5a9179` | [Actions 32608464856](https://github.com/wzgrx/pure_live/actions/runs/32608464856) |
| iOS arm64 | `PureLive-2.7.0-4077-ios-arm64-unsigned-app.zip` | 57,936,393 | `86803cfb72fbcc0ee0a709be28697c31138e981604af1abbea64a70e5a28e270` | [Actions 32609700256](https://github.com/wzgrx/pure_live/actions/runs/32609700256) |
| iOS arm64 | `PureLive-2.7.0-4077-ios-arm64-trollstore.ipa` | 58,776,645 | `b528459c230950a94aba3a19a5508149953476becceb68e708570d9207615fdf` | [Actions 32609700256](https://github.com/wzgrx/pure_live/actions/runs/32609700256) |

Android 复核为包名 `com.mystyle.purelive`、versionName `2.7.0`、versionCode `6077`、minSdk 24、targetSdk 37、仅 `arm64-v8a`；APK Signature Scheme v2 有效，RSA-4096 发布证书 SHA-256 为 `c0bb95744c81f9c7dd4535a9552775038eb5a59c5922f791d1695f45ac34ceaf`。Linux 归档包含可执行文件，Windows/macOS/iOS ZIP 与 IPA 均通过结构检查，远端产物侧车校验与本机 SHA-256 一致。

Windows 本机构建耗时 478.301 秒，结束后活跃重型进程为 0。随后用隔离实例执行 371.975 秒、37 个采样点的 Release 烟雾测试：工作集从 312,360,960 B 降至 228,642,816 B，私有字节从 787,902,464 B 降至 688,254,976 B，CPU 累计增加 3.65625 秒；记录为 `20260823T002818941Z-windows-release-smoke.json`。

## 5. 验收边界

- 本轮按代码审查、自动化回归、公开接口探测和 Windows 本机运行验证执行，未接入 Android 设备操作。
- 平台公开接口会随站点策略变化；运行时保留超时、失败降级、旧请求隔离和重新连接逻辑。
- Release 只声明实际生成并完成校验的 ABI 和平台文件。
