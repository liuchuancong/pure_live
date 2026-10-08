# ADR 0016:MediaTicket 的 MediaTrack 用平台镜像类型

- 状态:已接受(2026-10-08)
- 相关:[../contracts/platform-models.md](../contracts/platform-models.md) §2 / §11、[../architecture/dependency-rules.md](../architecture/dependency-rules.md) §2

## 背景

实现 `packages/ecosystem/platform` 的首切片时撞上两条互相冲突的定稿规则:

- platform-models §2:`MediaTrack` **直接复用** media_core 已有定义,"平台不重定义"。
- dependency-rules §2 / package-architecture §1:`pure_live_platform` 是**纯 Dart 伞包,禁 Flutter 依赖**。

实测:media_core 的 `packages/media_core/pubspec.yaml` 声明 `flutter: sdk: flutter` 与
`environment.flutter: >=3.35.0`。因此平台包一旦 import 它就变成 Flutter 包 —— 伞包就不能再被纯 Dart 的
ecosystem 层、也不能被未来不含 Flutter 的宿主(TV 壳只取 repository 层)使用。§2 自己给的出口是
"经 pure_live_media 导出",但 pure_live_media 属于 L0.5 integrations,而 §3 规定 L1 → L0,
L1 反向依赖 L0.5 同样违反分层。

## 决策

1. `pure_live_platform` 保持纯 Dart,自带 `MediaTrack` **镜像类型**:字段与 media_core 逐一对应
   (uri / kind / headers / mimeType / codec / bitrate / language / startOffset / metadata),
   不引入 media_core 依赖。
2. 映射放在接线层:`packages/integrations/media`(`pure_live_media`,允许依赖厂商 SDK)负责
   平台 `MediaTrack` ↔ media_core `MediaTrack` 的双向转换;同一层负责 §2 里 `SourceDescriptor` 的同名别名映射。
3. 镜像类型的字段增删必须与 media_core 同步评审:两侧任一侧加字段,接线层就要在同一提交里补映射,
   否则编译期即失败(转换函数是显式字段列举,不是反射)。
4. 顺带修正同类命名冲突:foundation 的平台探测包改名 `platform_info`(`pure_live_platform_info`),
   因为 `pure_live_platform` 这个名字按 §18 属于生态伞包,而 pub 要求 workspace 内包名唯一。

## 后果

- 正:边界模型不绑播放器实现,Invariant 1/2/10 由类型系统而非约定保证;TV 壳未来可只依赖纯 Dart 层。
- 正:media_core 升级不强迫平台包跟着引入 Flutter。
- 负:两个同名类型并存,读代码的人必须在接线层看到转换;命名冲突靠 §2 的映射表消解,不靠"看起来一样"。
- 负:字段镜像靠人工同步。若将来 media_core 拆出纯 Dart 的 `media_core_model`,应改为直接复用并删除本镜像 ——
  那是 §2 原本期望的形态,本决策是它的前置替代,不是终态。
