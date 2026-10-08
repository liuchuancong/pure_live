# ADR 0015:Monorepo 目录形态(apps + packages)

- 状态:已接受(2026-10-08)
- 取代:ADR 0002 中"仓库根每层一目录"的**目录形态**表述;分层数量与依赖规则不变。

## 背景

v1 把应用代码、原生工程、仓库脚本、依赖补丁全放在仓库根。v2 单仓多包后,若每层再在根上占一个目录(`foundation/`、`ecosystem/`、`services/` …),仓库根会同时长出十几个与 `docs/`、`tool/` 平级的目录,应用壳与包分不清。ADR 0002 只规定了"每层一目录、每能力一包",没有规定这些目录挂在哪里。

## 决策

仓库根固定为 6 类入口,新增包不改变根的形态:

```text
pure_live/
├── apps/pure_live/     # 组合根:lib/ + 原生工程 + assets/ + bin/ + tool/(需要应用依赖的 Dart 脚本)
├── packages/           # 全部包:packages/<层>/<短名>;层 = foundation|integrations|ecosystem|services|ui|features|providers
├── third_party/        # vendored 上游源码与补丁(原 plugins/built_in_kotlin;media_kit fork)
├── fixtures/           # 跨包共享的录制样本(jar / m3u / 站点响应);provider 专属样本留在各自包内
├── tool/               # 仓库级脚本入口(构建 / 质量 / 发布 / 设备)
├── docs/               # 本文档体系
└── pubspec.yaml        # workspace hub:无代码,只有 workspace 成员清单与 dependency_overrides
```

- **机制用 pub workspace**:根 `pubspec.yaml` 是 hub(包名 `pure_live_workspace`),成员写 `resolution: workspace`,全仓共用根 `pubspec.lock` 与根 `.dart_tool/package_config.json`。melos 之后可直接叠在同一份 `workspace:` 列表上,不改目录。
- `dependency_overrides` 只能写在 hub(pub 的硬约束),所以覆盖项里的 `path:` 一律相对仓库根;应用包内的本地路径相对 `apps/pure_live`。
- L5 目录名由 docs 原先的 `plugins/` 改为 `packages/providers/`:根目录 `plugins/` 已被 vendored Android 插件占用,同名会让"这是谁的代码"含糊。
- 包骨架只能由 `tool/scaffold_package.ps1` 生成并登记进 `workspace:`,手写目录视为漂移。

## 后果

- 正:根目录恒定;应用壳与包一眼可分;护栏可机械校验包路径必须形如 `packages/<层>/<名>`。
- 负:所有假设"仓库根即 Flutter 工程"的脚本与 CI 需要改到 `apps/pure_live/...`;`flutter build` / `flutter run` 必须在 `apps/pure_live` 下执行。迁移状态与未完成项逐条记在 [../roadmap/w1-progress.md](../roadmap/w1-progress.md)。
- 负:原生工程搬家会触碰签名与 Gradle 相对路径,`.gitignore` 的密钥规则同步改到 `apps/pure_live/**`,已用 `git check-ignore` 对 `key.properties`、`*.jks`、`build/`、`.dart_tool/`、`.gradle/` 逐条验证仍被忽略。
