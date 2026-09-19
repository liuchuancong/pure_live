# 2026-09-05 上游最新 Issue 审计

本轮只读检查上游 Issue 与最新代码树，不拉取、不合并、不改写上游提交；维护分支
`wzgrx/pure_live` 继续作为实现基线。按日期优先审查上游新报告 #850、#849、#848，
并复核直播数据相关的 #846、#845、#836，
并把“能在当前分支稳定复现”“当前环境未复现”“报告信息不足”明确分开。

## 结论

| Issue | 来源与首个错误状态 | 维护分支处置 | 验证边界 |
|---|---|---|---|
| [#850 Android 颜色选择器不能调透明度](https://github.com/liuchuancong/pure_live/issues/850) | 上游和维护分支共有的 UI/持久化缺陷。旧页面没有启用 `ColorPicker.enableOpacity`，却把色阶标题写成“选择透明度”；加载颜色保存 `color.hex` 又会丢失 alpha。依赖自身的代码输入框固定为 6 位且只在色轮页可编辑，不能完成 AARRGGBB 编辑 | 新增统一 `AppColorPickerDialog`：需要透明度的加载颜色提供真实 alpha 滑块和始终可见的 8 位 ARGB 输入；主题色与小窗弹幕颜色使用 6 位 RGB，避免与独立不透明度设置冲突；输入支持 `#`/`0x`，错误格式原地提示，取消恢复原值。三个页面不再各自复制不同的弹窗逻辑 | Widget 回归覆盖 RGB/ARGB 解析、完整 ARGB 输入、即时预览、非法值与取消恢复；K90 Pro 共享轮转 cycle 198 使用最终 APK 真实验证主题/加载两个入口、`0x800080DD` 输入和取消恢复。证据：`local-artifacts/diagnostics/android-color-picker-20260905T024906912/summary.json` |
| [#849 Windows 10 在 2.0 后不能启动](https://github.com/liuchuancong/pure_live/issues/849) | 报告缺少精确 Windows build 和 Event Viewer 日志，但包审计找到了与“开发机正常、旧 Win10 双击无反应”相符的确定部署缺陷：Release ZIP/安装器没有携带 Flutter 官方要求的三项 VC++ app-local runtime，构建机已全局安装运行库会掩盖遗漏 | Windows CMake 现在从当前 MSVC toolset 精确解析并只把 `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll` 安装到应用根目录；本机构建脚本把三项列为 Release 阻断门禁，便携 ZIP、Inno 安装器和使用同一 CMake bundle 的工作流共同继承。最终 ZIP 为 1305 项，三项运行库版本均为 14.52.36615.0 | 从最终 ZIP 解压的隔离实例运行 24.534 秒、12/12 样本响应，进程模块确认三项 DLL 全部从应用目录加载而非系统目录。证据：`local-artifacts/diagnostics/windows-startup-20260904T190044783Z/summary.json`。该证据关闭了包自身的运行库缺口；报告者具体 Win10 是否还有过旧系统 build、驱动或 WebView2 问题，仍需其机器复验 |
| [#848 3.1.2 系统字体问题](https://github.com/liuchuancong/pure_live/issues/848) | 报告正文没有截图和字体名称，但代码审查发现一个确定的共享语义错误：Android 选择“System Default”时仍强制 `GoogleFonts.roboto()`，没有遵循设备系统字体和厂商 CJK fallback | 将字体解析提为可测试的单一函数：已下载字体继续按 ID 使用；Windows 保留 `Microsoft YaHei` 性能基线；Android 和其他平台的系统默认返回 `null`，交给 Flutter/操作系统字体回退链。移除只为强制 Roboto 引入的 `google_fonts` 运行依赖；被删除或失效的自定义字体 ID 也安全回落系统字体 | 确定性测试覆盖自定义字体、Android 系统默认、失效字体 ID 和 Windows CJK 回退。由于 #848 没有复现材料，本修复只声明纠正了可证实的“系统默认不是真默认”，不宣称覆盖报告者未描述的所有字体问题 |
| [#846 虎牙未开播收藏只显示数量](https://github.com/liuchuancong/pure_live/issues/846) | 报告者补充连续获取多个虎牙房间容易失败，但未给出具体房间集合与请求日志。维护分支旧版逐卡提交会把传输失败混成离线并产生短列表 | 当前控制器先保留所有关注身份并标记“正在核验”，以 4 路有界并发刷新；失败保留原卡片及 unknown 状态，整批结束后只提交一次快照。启动、下拉、失败传播已有确定性测试 | 当前推荐页 8 个虎牙房间的轻量详情端点串行 8/8、4 路并发 8/8 成功；K90 Pro / cycle 210 冷启动刷新后进入“未开播 → 虎牙”，两个真实虎牙未开播收藏均完整显示封面、标题和主播，没有出现“有数量但空列表”，且无 FATAL。脚本 `tool/android_favorite_bucket_smoke.ps1`，证据 `local-artifacts/diagnostics/android-favorite-offline-20260905T043215093/summary.json`。报告者原房间集合仍未公开，但当前分支已用等价未开播集合排除其可见症状，因此不增加无依据的延时或串行降速 |
| [#845 斗鱼 71415 大量弹幕缺失](https://github.com/liuchuancong/pure_live/issues/845) | 两次 60 秒原始捕获证明 WebSocket 分别收到 69/43 条聊天；旧平台门禁只丢 6/5 条缺少 `dms` 与 `if` 的疑似自动消息，但默认相似弹幕过滤还可能继续吞掉忙碌房间的合法短文本 | 保留跨房间拒绝、合帧全解和空文本门禁；当时新增“过滤斗鱼疑似自动弹幕”开关并默认开启。09-19 的重复报告 #871 证明该默认值仍与聊天完整性目标冲突；当前 `31ee5cd7` 已改为完整聊天默认、启发式过滤显式选择，旧设置和备份中的明确值继续保留 | 09-05 原定向回归 18/18；当前订正的最终相邻回归 53/53、analyze 无问题。71415 两次审查均离线，实时网页/App 数量对照继续。见 [#871 订正审计](ISSUE_871_DOUYU_CHAT_COMPLETENESS_AUDIT_2026_09_19.md) |
| [#836 抖音部分房间没有弹幕](https://github.com/liuchuancong/pure_live/issues/836) | 旧备用端点实际未发生切换、签名查询编码不完整、访客 ID/SDK/Referer 落后，静默半开连接也没有恢复 | 已改为两个 `webcast100` 端点轮换、URI 查询编码、19 位访客 ID、SDK 1.0.15、Referer、Cookie 脱敏和 45 秒静默恢复 | 确定性回归 11/11；另有匿名活跃房间 5 秒 51 条消息、其中 47 chat 的实时证据。Issue 原房间缺少稳定 ID，继续保留原样本边界 |

## 斗鱼弹幕过滤的产品边界

1. `rid` 不匹配、文本为空和损坏协议包属于确定错误，始终拒绝。
2. `dms`、`if` 是装饰/粉丝相关字段，不是稳定的聊天可见性协议；缺少两者只标记为“疑似自动消息”。
3. 09-05 当时默认过滤疑似自动消息；09-19 的 #871 复发证明这会继续隐藏平台已交付聊天。当前默认保留完整非空聊天，用户可在“屏蔽管理”明确启用启发式过滤；已有显式选择继续保留。
4. 相似文本过滤属于内容去重偏好，不属于传输正确性；新安装和旧备份缺少该字段时默认关闭，显式开启过的用户保持原值。
5. 当前参考实现：[bililive-go Douyu client](https://github.com/bililive-go/bililive-go/blob/ef71711a7c573b013d82fec01ee8d0609ee36aca/src/recorders/danmaku/douyu/client.go)、[biliup Douyu protocol](https://github.com/biliup/biliup/blob/906e0f6fdb104d65989d12b76c9a6f02205384cb/crates/danmaku/src/protocols/douyu.rs)。两者均按非空 `chatmsg` 进入上层，没有使用 `dms`/`if` 作为硬门禁。

## 颜色设置的产品语义

1. **应用主题色**：只保存 RGB；主题明暗和 Material 色板负责表面层级，不允许透明主题种子。
2. **加载动画颜色**：保存 ARGB；alpha 滑块、8 位代码和预览使用同一个 `Color` 状态。
3. **小窗弹幕颜色**：保存 RGB；透明度继续由已有 `pipDanmakuOpacity` 独立设置，避免两个 alpha 控件互相覆盖。
4. 所有确认操作保存当前值；取消、系统返回和点遮罩都返回原值，不产生半保存状态。

上游最新代码中的直播卡片颜色入口仍使用旧的 Flex 弹窗参数。该功能尚未合并到维护分支；
以后若选择入站，应直接复用统一弹窗，而不是把同一个缺陷重新带入。

## 字体修复为什么不继续强制 Roboto

Flutter 在未指定 `fontFamily` 时使用平台默认字体及其回退链。Android 的拉丁默认通常为
Roboto，但中文实际会由设备系统 CJK 字体补齐；显式指定通过网络字体包解析出的 Roboto
只改变了“系统默认”的语义，并不能为中文提供更完整字形。返回 `null` 同时减少一次运行时字体
解析和一个未再使用的直接依赖。自定义字体仍由现有下载、注册和持久化流程处理，不受影响。

参考：[Flutter 自定义字体指南](https://docs.flutter.dev/cookbook/design/fonts)、
[Flutter `TextStyle` 字体回退说明](https://api.flutter.dev/flutter/painting/TextStyle-class.html)、
[FlexColorPicker `enableOpacity` API](https://pub.dev/documentation/flex_color_picker/latest/flex_color_picker/ColorPicker-class.html)。

Windows 部署参考：[Flutter Windows 构建与 ZIP 部署说明](https://docs.flutter.dev/platform-integration/windows/building)、
[Microsoft 最新 VC++ v14 Redistributable 说明](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170)。

## 质量与构建证据

- `flutter analyze` 0 issue；颜色、字体、Material 兼容与弹幕设置相邻回归共 15/15 通过。
  记录：`local-artifacts/build-records/20260904T184020806Z-quality-focused.json`。
- Android arm64 Debug 构建通过，包内只有目标 ABI，16 个原生库最小 ELF LOAD 对齐不低于
  `0x4000`，Flutter 资源与版本清单完整。产物：
  `local-artifacts/3.1.8-4121/PureLive-3.1.8-4121-android-arm64-v8a-debug.apk`；
  构建记录：`local-artifacts/build-records/20260904T184549085Z-build-androidarm64-debug.json`。
- Windows x64 Release 从提交 `571765af` 串行生成便携 ZIP 与安装器；最终 ZIP SHA-256 为
  `C21DA63124C80AE17112DD2CCD37D7A3AAC30B0DE5186F4DE5BC6BC41375DF8E`，
  隔离启动和 app-local 模块来源通过。构建记录：
  `local-artifacts/build-records/20260904T185956165Z-build-windowsx64-release.json`。
- 斗鱼协议、平台过滤开关、备份迁移及相似过滤默认值定向回归 18/18。记录：
  `local-artifacts/build-records/20260904T192547043Z-quality-focused.json`。
- 本轮代码完成后只执行一次 `flutter analyze`，结果为 0 issue。记录：
  `local-artifacts/build-records/20260904T192910396Z-quality-focused.json`。
- 从干净提交 `971c2753` 串行构建 Android arm64 Debug：APK 为 299,150,717 B，
  SHA-256 `B0EEAF3434E961EFD10419BEF59AC46164D44CDD61DC5746CCE63C3AFFF259DF`；
  16 个原生库最小 ELF LOAD 对齐不低于 `0x4000`。构建记录：
  `local-artifacts/build-records/20260904T193151421Z-build-androidarm64-debug.json`。
- K90 Pro / Android 17 覆盖安装后在共享轮转 cycle 200 完成冷启动、远端弹幕、
  画质/线路、纯音频往返、系统 PiP、恢复后弹幕 UI 与返回，14/14 门禁通过且无
  FATAL/ANR。证据：`local-artifacts/diagnostics/android-runtime-smoke-20260905T033502392/summary.json`。
- 新增 `tool/android_danmaku_filter_settings_smoke.ps1`，在共享轮转 cycle 203 对最终 APK
  打开真实直播间的“屏蔽管理”：平台分组、斗鱼开关、风险说明及相似过滤分组全部可见；
  斗鱼开关即时切换并恢复原值，相似过滤状态全程不受影响。证据：
  `local-artifacts/diagnostics/android-danmaku-filter-settings-20260905T035024190/summary.json`。

## 本轮边界

- 没有同步上游分支，也没有提交上游 PR。
- 没有把缺少复现信息的 Windows 报告标成已解决。
- 本轮代码改动覆盖已证实的颜色、字体与斗鱼过滤语义；其他平台播放、录制和长时矩阵沿用总验收表继续执行。
