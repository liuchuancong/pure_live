# W1 进度(目录形态与 Foundation 骨架)

> 验收口径来自 [milestones.md](milestones.md) 的 M1:契约定稿、全仓骨架 analyze 绿、护栏进 CI。
> 工程规范按 [../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md);目录形态按 [../adr/0015-monorepo-layout.md](../adr/0015-monorepo-layout.md)。
> 本文件只记 `v2` 分支的实际状态,不写计划外的乐观结论。

## 1. 本轮完成的两个阶段

### 1.1 目录形态重排(ADR 0015)

| 动作 | 结果 |
|---|---|
| 删除 v1 代码 | `legacy/`(860 个受控文件)整体删除;需要回看 v1 实现走 git 历史(`020f47ffb` 之前)或外部参考仓 `pure_live_TV` |
| 应用壳搬家 | 根 `lib/ android/ ios/ linux/ macos/ windows/ assets/ bin/ pubspec.yaml .metadata devtools_options.yaml build.yaml firebase.json` → `apps/pure_live/`;`assets/` 2095 个文件随迁(Flutter 资源必须位于应用包内) |
| 包伞目录 | 先前误放在仓库根的 `foundation/`、`integrations/` → `packages/foundation/`、`packages/integrations/` |
| vendored 插件 | `plugins/built_in_kotlin/` → `third_party/built_in_kotlin/`(422 文件),应用内 `path:` 改 `../../third_party/...`,hub 覆盖项改 `third_party/...` |
| workspace hub | 根新建 `pubspec.yaml`(包名 `pure_live_workspace`,无代码),`dependency_overrides` 整体上移(pub 只允许 hub 声明);应用包写 `resolution: workspace` |

### 1.2 脚手架与骨架

- `tool/scaffold_package.ps1` 重写:目标路径 `packages/<层>/<名>`、`-Description` 必填(禁占位符)、代码与配置注释英文、barrel 带 `Module/Purpose/Author/Created` 文件头、不再留注释掉的示例依赖、层规则表含 `providers`、未替换占位符直接抛错、LF + 无 BOM。
  修掉的真实缺陷:`Set-Content -Encoding utf8` 写 BOM;双引号 here-string 把 `` `f `` 解释成换页符;`[Parameter(Mandatory)][string[]]` 会拒绝含空行的数组(这正是第一次批量生成 16 连失败的根因);插入 workspace 时用逗号包裹导致返回嵌套数组。
- `tool/test_scaffold_package.ps1` 新建:19 个用例、55 条断言,命名按规范 §6 的 `test_<函数>_<场景>_<期望>`;每个用例在 `%TEMP%` 独立 scratch 仓里跑,不碰真实工作树。**结果:PASS 55/55。**
- L0 骨架 16 包:`packages/foundation/{utils,logging,network,auth,storage,files,platform,cache,events,diagnostics,backup,sync,release,l10n}` + `packages/integrations/{firebase,media}`,每包 pubspec/README(职责一句话)/CHANGELOG/barrel/包级 analysis/`lib/src`/test 占位,全部登记进 hub。

## 2. 验证证据

| 命令 | 结果 |
|---|---|
| `powershell -File tool/test_scaffold_package.ps1` | `PASS: 55 assertions across 19 cases` |
| `tool/flutterw.ps1 pub get`(仓库根) | `Got dependencies!`;单一 `pubspec.lock` 在根;`package_config.json` 内 `pure_live*` 共 18 项(应用 + 16 包 + hub) |
| `dart analyze .`(仓库根) | **No issues found!** |
| 包内 `dart analyze`(如 `packages/foundation/utils`) | No issues found —— 证明 `include: ../../../analysis_options.package.yaml` 链生效 |
| 门禁非空转验证 | 往包内注入 `print` → 报 `avoid_print`;删除后回 0 |
| 密钥忽略覆盖 `git check-ignore` | `apps/pure_live/android/key.properties`、`apps/pure_live/assets/keystore/*.jks`、`apps/pure_live/build/**`、`apps/pure_live/.dart_tool/**`、`apps/pure_live/android/.gradle/**` 全部仍被忽略 |
| 结构漂移扫描(16 包 × 必备文件/包名/include/workspace 登记/断链/BOM/CRLF) | 0 problems |
| 架构护栏 `dart run tool/check_architecture.dart --strict` | `packages=17 errors=0 warnings=0` |
| 护栏回归 `tool/test_check_architecture.ps1` | **PASS: 15 assertions across 14 cases**(含"故意违规必须被抓到"的反例:层向上依赖、依赖 app、未登记成员、缺文件、include 被改、features 缺内层、ui_kit 之外 import wind、provider 引播放器) |
| `dart run tool/check_workflow_yaml.dart` | 4 个 workflow/action 文件全部解析通过。这个检查当场抓到一个真实缺陷:`run: & "$env:..."` 以 `&` 开头会被 YAML 当锚点,已改块标量 |
| CI 入口 | 新增 `.github/workflows/architecture.yml`:pub get → 护栏 --strict → workflow YAML → analyze → 两套 PS 回归。**本机无法执行 workflow,仅验证了其中每条命令。** |

## 3. 已知未完成(搬家带来的欠账,不含乐观声明)

### 3.1 已随搬家改完的部分

- `tool/build_local_release.ps1`、`tool/publish_local_release.ps1`、`tool/validate_build_policy.ps1`、`tool/sync_owner_refs.ps1`、`tool/update_releases.py`、`tool/audit_repository.py`、`tool/audit_built_in_kotlin.py` 里的应用作用域路径改到 `apps/pure_live/`(前三个脚本新增 `$appRoot`);`.dart_tool/` 与 `pubspec.lock` 仍在仓库根,是 pub workspace 的正确位置,未改。
- 设备类脚本(`android_*_smoke.ps1` 等)只按仓库根取 `tool/` 与 `local-artifacts/`,不受搬家影响 —— 逐条核对过,没有应用路径假设。
- 验证:89 个 `tool/*.ps1` 全部 AST 解析通过(0 失败);`python tool/audit_repository.py` 可运行;`tool/test_scaffold_package.ps1` 仍 PASS 55/55。

### 3.2 仍未完成

1. 发布工作流已搬家:`android / windows / linux / apple` 四个 job 加 `defaults.run.working-directory: apps/pure_live`,`quality` 只给 `dart run enven` 与 `flutter test` 两步加(其余步骤仍按仓库根)。随之改掉的根依赖:`enven --env-files` 改 `../../.env,../../.env.prod`;`./.github/actions/get-version` 改用 `$GITHUB_WORKSPACE/apps/pure_live/pubspec.yaml`,不再依赖调用方 cwd;`tool/prefetch_windows_native.ps1` 走 `$env:GITHUB_WORKSPACE`;APK/安装包产物 `path:`、`assets/version.json`、`assets/releases.json`(含 `update_releases.yml`)全部指到新位置。**本机跑不了 workflow,只做了 YAML 解析与逐条路径核对。**
2. ~~`tool/validate_architecture.py` 仍按 v1 布局校验~~ —— 已由 `tool/check_architecture.dart` 取代并删除;护栏与回归见 §2,CI 入口是 `.github/workflows/architecture.yml`。
3. v1 内容耦合的质量规则残留:`tool/audit_repository.py` 现在报 9 条 error,其中 `live_back_invariant_missing` 指向已删除的 `lib/modules/live_play/**`,`workflow_default_true` 指向发布工作流;`tool/validate_build_policy.ps1` 在**搬家之前**就会失败 —— 它要求 `.agents/skills/pure-live-build/SKILL.md`,该文件从未入库(`git show 12eefc302` 已核实)。这三类都要按 v2 语义重定义,不做单点修补。
4. `tool/audit_built_in_kotlin.py` 因本机缺 Java 21 而失败(环境欠账,非搬家引入)。
5. `.fvmrc` 钉 3.47.5,机器上实际是 PATH 里的 Flutter 3.47.6,`tool/flutterw.ps1` 会静默回退。**待用户定**:提 `.fvmrc` 到 3.47.6,还是装 3.47.5。
6. `fluttersdk_artisan` / `fluttersdk_dusk` 与 `.mcp.json`、`apps/pure_live/bin/dispatcher.dart`、`apps/pure_live/lib/app/_plugins.g.dart` 是别处引入的框架栈,`docs/` 全体系无一处提到它。本轮只把 `.mcp.json` 的 cwd 改到 `apps/pure_live`,**未做取舍**。
7. 分支**不可运行**:`apps/pure_live/lib/` 只剩 artisan 生成的两个空文件,没有 `main.dart`;`pubspec.yaml` 的 `flutter: assets/fonts` 段仍指向 v1 资源清单。可运行性随 W2 运行时与组合根重建恢复。

## 4. 环境事故(会影响后续会话)

- 15:47–16:12:共享 Flutter SDK 的 `bin/cache/dart-sdk` 被反复改名成 0 字节 `dart-sdk.oldN`,`dart`/`flutter` 全部不可用;16:12 一次更新成功后自清,现 Flutter 3.47.6 / Dart 3.13.5 可用。嫌疑是常驻的 VS Code Dart language-server/tooling-daemon 锁住 `dart.exe`。本轮未杀任何进程。
- 16:35–16:37:工作树被**本会话之外**的动作改动过 —— `tool/` 下 184 个受控文件从磁盘消失(index 完好),`analysis_options.yaml` 被替换成 122 字节的通用 flutter_lints 配置。我用 `git restore` 复原了两者(复原前把那份 122 字节配置另存到 `/tmp/foreign-analysis_options-1635.yaml`,未直接丢弃),并按新目录形态重写了 exclude。期间丢失的 `tool/scaffold_package.ps1` 改写版与未受控的旧测试脚本已按规范重写。**若另有会话在同一工作树并行施工,需要先协调,否则会互相覆盖。**

## 5. W1 余下(按依赖顺序)

1. ~~补 §3.1/§3.2 的脚本与 CI 路径迁移~~ —— 已做:7 个脚本改 `$appRoot`、发布工作流四个 job 加 `defaults.run.working-directory`、`update_releases.yml` 与 get-version 动作跟进;证据见 §2。
2. ~~`packages/ecosystem/platform` 骨架 + 核心模型~~ —— 已落:`packages/ecosystem/platform`(`pure_live_platform`)实现 §19 首切片 14 类模型,37 个测试通过。media_core 复用盘点的结论是**复用不了**:media_core 的 pubspec 声明 `flutter: sdk: flutter`,与"伞包必须纯 Dart"直接冲突,因此 `MediaTrack` 改为平台镜像 + 接线层映射;同时发现 dependency-rules 的 foundation `platform` 与 package-architecture 的伞包 `pure_live_platform` 撞名(pub 要求包名唯一),foundation 侧改名 `platform_info`。两条都记在 [../adr/0016-platform-media-track-mirror.md](../adr/0016-platform-media-track-mirror.md)。
3. foundation 各包实装 + 单测,序:utils → logging → network → storage/auth → cache/events → diagnostics → files/platform_info → backup/sync/release/l10n。
4. ~~架构护栏~~ —— 已落 `tool/check_architecture.dart` + `tool/test_check_architecture.ps1`(14 例 15 断言)+ `.github/workflows/architecture.yml`;v1 的 `tool/validate_architecture.py` 已删除。
5. 契约测试框架(providers 能力契约 + `fixtures/` 录制响应)。
6. TVBox 运行时决策落地:参考 `webtv-main`(catvod + chaquo 的 `base/spider.py` Python 爬虫基类)与 `serious_python`(已在应用 dev_dependencies),见 [../architecture/external-ecosystem.md](../architecture/external-ecosystem.md)。
