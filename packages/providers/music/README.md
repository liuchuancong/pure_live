# pure_live_music

> 职责:**lx-music 源宿主** —— 在 JS 沙箱里跑用户导入的 user-api 脚本，Dart 侧提供 bridge 端点、
> crypto/zlib 前置环境与 musicUrl / lyric / pic 三个调用口。
> 本包不带任何源：源是用户拿进来的（壳只跑用户带来的脚本）。

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation + L1 `plugin_api` / `js_runtime`(沙箱桥由宿主注入)；同层禁互依；不得触碰 PlayerAdapter(I1/I5) |
| 禁止依赖 | 任何反向依赖；禁止依赖应用壳(唯一组合根,I9)；**不得依赖 features 层** |
| 公共面 | 只有 `lib/pure_live_music.dart`；内部实现放 `lib/src/` |

## 模块

| 文件 | 提供 |
|---|---|
| `src/music_source_host.dart` | `MusicSourceScriptHost`(`spawn` / `attach` / `awaitInited` / `musicUrl` / `lyric` / `pic` / `dispose`) + `MusicScriptInfo` / `MusicSourceInfo` |
| `src/music_script_crypto.dart` | `handleMusicScriptCryptoApi` + `aesEncrypt` / `rsaNoPaddingEncrypt` + DER 读取 + `kMaxRandomBytes` |
| `src/music_source_prelude.dart` | `musicSourceApiPrelude`：注入沙箱的 lx 环境(JS 字符串，含 `__music_source_dispatch_request`) |

## 行为契约

- **公告是唯一的合同**。脚本用 `lx.send('inited')` 报出它有哪些源、每个源答哪些 action 与质量；
  `musicUrl/lyric/pic` 先对着这份公告验，**没报过的直接拒**，错误里列出它真正报了什么（`actions` 或
  `qualitys` 为空 = 它没说，当作不知道，不拒 —— 否则每个省略该字段的源都废了）。
  把没报过的 action 发进脚本，要么它不答（调用方等自己的超时），要么它在脚本空间里抛一个"未知 action"，
  两种现象都不指向真因。
- `awaitInited` 带硬超时（默认 15s），**超时即 dispose**：一个从不公告的脚本就是坏脚本，而它加载起来的
  JS 上下文还活着，调用方此时手里只有这个 host，没有别的句柄。
- `dispose()` 幂等；`_disposed` 之后所有请求立刻拒（不排队、不重放）。`inited` 这个 future 在被 dispose 时
  **不会**被以 error 完成 —— 没人监听的未来错误会变成 unhandled async error，能把 isolate 带走；要超时就走
  `awaitInited`。
- 返回的 url 必须含 `://`，否则拒（脚本查不到歌时常回一个裸词，播放器会把它当流收下 → 没有错误的静音）。
- 空白歌词 = 没有歌词（trim 后判空），不是"一条空歌词"。
- `MusicSourceInfo` 的 `actions` / `qualitys` 容忍数组、单个值与缺失三种形状：lx 脚本两种都发过，
  在解析公告的环节抛异常等于丢掉整个源。

### crypto / zlib 端点
- 只答这五个（与 prelude 里 JS 侧转发的名字逐一对得上，两边数量已核过）：
  `crypto.md5`、`crypto.randomBytes`、`crypto.aesEncrypt`、`crypto.rsaEncrypt`、`zlib.inflate` / `zlib.deflate`。
  未知 api 返回 null，由沙箱按"没人接这个 api"处理。
- **`aes-<bits>-<mode>` 的名字必须与密钥长度一致**：`aes-128-cbc` 配 32 字节 key 以前会安静地做成 AES-256，
  而 Node 侧读同一个请求当 128 位解，产出对不上；现在拒。
- `randomBytes` 超过 `kMaxRandomBytes`(64 KiB) **拒绝而不是截断**：给了半个随机数，脚本会拿它继续算出
  一个错东西，错在很远的后面才现形。
- RSA 走 `RSA_NO_PADDING`：把输入**右对齐**零填到模数长度，原始 public-encrypt，与桌面版 preload 一致。
- **两种 PEM 形状都支持**（PKCS#1 `BEGIN RSA PUBLIC KEY` 与 SPKI `BEGIN PUBLIC KEY`）。SPKI 的走法本轮修过：
  旧代码钻进 AlgorithmIdentifier 的内容里把 OID 当 key 读，真的 `BEGIN PUBLIC KEY` 直接失败。
- **坏 key 是具名 `FormatException`，不是 RangeError**：`key` 参数来自用户导入的脚本，DER 读取每一步都带
  边界检查并说明停在哪。

## 依赖

`crypto`(md5)、`pointycastle`(AES/RSA)、`pure_live_js_runtime`、`pure_live_plugin_api`、
`pure_live_platform`、`pure_live_capability`。

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / Windows / iOS / macOS / Linux | ✅ | `dart:io`(`zlib`) + pointycastle 纯 Dart |
| Web | ❌ | `music_script_crypto.dart` import `dart:io` 的 `zlib`；要上 Web 得把 zlib 端点换成 `package:flutter/foundation` 之外的实现，不是加条件导入就完事 |

## 验证

- `dart analyze` → No issues found；`dart run tool/check_architecture.dart --strict` → 0 错。
- 包内**没有测试**（台账 §4 第 9 条本轮约定）。crypto 面用一个一次性脚本真跑过 19 条后删除：
  md5("abc") 与 md5("") 的公开向量、zlib deflate/inflate 回环、randomBytes 长度与超限拒绝、
  AES-128-CBC 两段块 + PKCS#7 回环（用 pointycastle 反方向解回来）、模式名与 key 长度不符的拒绝、
  ctr/cbc 缺 iv 的拒绝、**PKCS#1 与 SPKI 两种 PEM 的 RSAEP 比对**（独立用 `BigInt.modPow` 算期望密文，
  不把答案交给产生它的同一个 engine 复核）、超过模数的输入、三种垃圾 key 的具名拒绝。
  **这些观测不可复现**（脚本已删），列在这里是为了说清哪些是跑过的、哪些只是推演。

## 未验证

- **从未跑过一个真 lx 脚本**：`js_runtime` 的 `FjsJsSandbox` 本身零测试（台账 §3 第 9 行），所以
  prelude 在真沙箱里能不能注册、`__music_source_dispatch_request` 的 JSON 往返形状、脚本抛错时
  `outcome.value` 是什么 —— 全是按 preload.js 的行为写的推演。
- **RSA/AES 与 Node 的字节级一致性未证**：上面验的是自洽（回环）+ RSAEP 数学，没有拿 Node 的
  `crypto` 输出当对照。真机上如果某个源签名对不上，先怀疑这里。
- `MusicSourceBridge`（在 `features/music`）的**实现者不存在**：providers 不许反向依赖 features，
  适配器只能长在组合根里，而 `apps/pure_music` 壳还没建（台账 §5）。
- 超时值 15s 与 64 KiB 上限都是自代且可逆的决定，站点/脚本侧没有依据。
