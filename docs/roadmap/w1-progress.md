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
| 架构护栏 `dart run tool/check_architecture.dart --strict` | `packages=21 errors=0 warnings=0` |
| 能力契约 `packages/ecosystem/capability` | 包内 `dart analyze` No issues found;`dart test` **29 全绿**;`pure_live_platform` 侧因 `RefreshReason` 改名回文档集合(9 项)重跑全绿 |
| 格式化宽度缺陷(本轮发现并修) | `dart format` **不会**从仓库根 `analysis_options.yaml` 继承 `formatter.page_width`,包目录里按默认 80 列跑,与 `docs/development/coding-style.md` 规定的 120 打架 —— W1 写的包其实从没被真正格式化过。已在 `analysis_options.package.yaml` 补 `formatter.page_width: 120`,全量 `dart format packages tool/check_*.dart` 收敛(87 文件,复跑 0 changed),并加 CI 步骤 `--set-exit-if-changed`。`tool/probes/**` 三个 v1 探针被顺手改到的格式化已 `git checkout` 还原,不混进本批 |
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

## 5. W1 状态与余下项

已完成(每项都有测试或门禁证据,见 §2 与 git log):

- 目录形态与 pub workspace(ADR 0015)、包脚手架与回归、架构护栏与 CI(ADR 0015/0016/0017 全落)
- `packages/ecosystem/platform`:§19 首切片 14 类模型 + §9 分页/选择模型 + §12 权限与网络模型,68 测试
- **L0 全部 14 包实装完**:utils 36、logging 10、network 12、storage 16、auth 14、cache 11、events 5、diagnostics 9、files 22、release 15、l10n 19、platform_info 13、backup 11、sync 11 —— L0 合计 **194 测试**(逐包 `dart test` 实跑,不是估算;先前记的 241 是把这几项加错了)
- 脚本与 CI 路径迁移(§3.1/§3.2)
- TVBox 运行时决策(ADR 0017)+ `integrations/python_runtime`、`ecosystem/external_tvbox` 骨架
- **能力契约与契约测试框架**:`packages/ecosystem/capability` —— `CapabilityKind`(§1 全部 22 个 kind 名)、
  `BrowseCapability` / `SearchCapability` / `ResolveCapability` / `FeedCapability` / `CapabilitySet`,
  以及二级入口 `lib/testing.dart`(`ContractProbe` / `ContractSubject` / `checkCapabilityContract`,返回带稳定
  `code` 的 `ContractViolation` 清单,不绑 `package:test`,所以单测与插件校验 CLI 跑同一套断言)。
  错误码表与 `expiresAt` 的读法写在包 README;文档名→实现名的对应写进
  [capability-contract.md](../contracts/capability-contract.md) §5。
  顺带修掉一处与文档不符:`RefreshReason` 先前用了自造的四值,现按 media-contract §3 / media-ticket §2 的
  九值(`expiring/expired/networkError/http403/http404/decodeError/manual/qualityChanged/lineChanged`)落地,
  因为 evolution.md 规定枚举一经发布不得改名或重排。

余下:

1. `packages/ecosystem/plugin_api`(Manifest/Permission/生命周期)与契约测试的**插件侧装载**;
   能力断言本身已就位,W4 第一个参考插件(Bilibili)可直接套用。
2. `.fvmrc` 3.47.5 与实际 3.47.6 的不一致(§3.2 第 5 条)仍待用户定。
3. artisan 栈取舍(§3.2 第 6 条)仍待定;`serious_python` 在应用 `pubspec.yaml` 里还挂在 dev_dependencies,等 `python_runtime` 实装时移到 dependencies 并由 integrations 层持有。
4. `MediaTicketRefreshInfo`(`supported/expiresAt/refreshBefore`,platform-models §11)未进首切片(§19 未列),
   到期预取的"提前量"因此还没有落点;随 media 接线一并补。

