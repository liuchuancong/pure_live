# media_session 底座迁移方案（弃用 audio_service_win）

**日期**：2026-10-30 定稿，2026-10-31 改道
**动机**：仲裁层（media_core_mediasession 的 bootstrap/driver/surfaces）是自写，但 OS 底座仍是 `audio_service`（+`audio_service_win`/`audio_service_mpris`）。
**改道记录（2026-10-31）**：原"参考 mpv_audio_kit 自写原生 SMTC"方案（自写包 media_session_smtc_win）已实施至可编译，用户中途改判——**改用 pub 包 `flutter_media_session`（wyrin.dev，v3.0.9，MIT，Win/macOS/iOS/Android/Web，Linux planned）**；自写包已删。现架构：media_core_mediasession 内 `media_session_flutter_bottom.dart` 桥接（AudioServicePlatform → flutter_media_session），Windows 注册之；Linux 仍走 audio_service_mpris。media_core 2482932 已推，app 构建绿+15s 烟测过。
**参考源**：`C:\Users\XA-158\AppData\Local\Temp\mpv_audio_kit_audit`（BSD-3，须带署名移植）——`hook/build.dart` 下载逻辑无关；只取五平台会话原生代码。

## 可搬清单（实测行数）

| 平台 | 参考文件 | 量 | 落点 |
|---|---|---|---|
| Windows | `windows/media_session_smtc.cpp` + `media_session_channel_win.cpp` | ~830 | media_core_mediasession plugin 化后的 `windows/` |
| Linux | `linux/mpris_server.cc` + `mpris_introspection.h` | ~966 | 同上 `linux/` |
| iOS/macOS | `darwin/Sources/mpv_audio_kit/MediaSessionPlugin.swift` | ~1144 | 同上 `ios/`、`macos/` |
| Android | `android/.../media_session/*.kt`（Manager/Mappers/Service/Focus/Interruption/Ownership） | ~1751 | 同上 `android/` |

参考实现的数据模型：`lib/src/models/media_session.dart`（title/artist/album/artwork/duration/…）与命令回路（play/pause/next/prev/seek）。

## 架构定稿

1. **仲裁层不动**：`MediaSessionSurfaces`/`MediaSessionDriver`/`MediaSessionBootstrap` 的对外 API 保持，调用方（music_playback、房间域）零改动。
2. **底座缝**：driver 内部抽出 `_SessionBottom` 接口（activate/updateMetadata/updatePlaybackState/deactivate/命令流）；实现两个：
   - `_NativeBottom`——走自有 MethodChannel（`media_core_mediasession/native`）到移植的原生插件
   - `_AudioServiceBottom`——现状逻辑原样（未移植平台过渡用）
   按平台常量选择，过渡期逐平台切 `_NativeBottom`。
3. **channel 协议**（自定，不抄 mpv 的 per-player 协议，我们的语义是 app 级仲裁会话）：activate{sessionId,title}/update{metadata,playbackState}/deactivate + 命令回调 play|pause|next|previous|seek。
4. **Android 注意**：前台服务生命周期是 audio_service 的真价值；移植须包含 `MpvMediaSessionService` 对等物 + manifest 改动；app 已有 audio_session 管焦点，参考里的 AudioFocusController 只在需要补位时引入。
5. **收尾**：全部平台切完后删 `audio_service`/`audio_service_win`/`audio_service_mpris` 依赖；音乐域在引擎换道后另有 mpv_audio 自带会话路线（`setMediaSession`），两线并存时 OS 面以"最后激活者"显示——音乐域是否改挂自带会话单独拍板。

## 波次（每波独立可验可提交）

- **波A Windows**：plugin 化 media_core_mediasession（加 `windows/` CMake+注册），移植 smtc.cpp（BSD-3 署名注释），driver 加底座缝，Windows 切 `_NativeBottom`；本机构建+SMTC 手验。
- **波B Linux**：移植 mpris_server.cc，切 Linux。需 Linux 真机验证。
- **波C iOS/macOS**：移植 Swift 插件。需 mac 真机。
- **波D Android**：移植 Kotlin 全套+manifest。需 Android 真机。
- **波E 收尾**：删三个 audio_service 依赖+清理。

## 风险

- audio_service_win 曾是坑源（VS2026 STL1011）；自写 Windows 波反而消灭它。
- Android 波最大（1751 行+服务生命周期），最后做、真机验证门槛最高。
- driver 1044 行重构底座缝时，过渡期两底座并存——务必保持默认平台表驱动，防止半成品混合态。
