# pure_live_external_tvbox

> 职责:TVBox 仓库与 spider 源适配:经 Python 宿主映射成 ContentRef 与 MediaTicket

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_external_tvbox.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 平台矩阵

| 平台 | 能不能跑 | 依据 |
|---|---|---|
| Android / Android TV / iOS / macOS / Windows / Linux | 需要 Flutter 宿主 | 本包自己只 import `dart:convert`,但 js spider 走 `pure_live_js_runtime`(fjs = Rust/QuickJS 的 ffiPlugin),Python 宿主走 `integrations/python_runtime` —— 平台边界是**传进来的**,不是这里的代码产生的。 |
| Web | ❌ | fjs 没有 web 产物;且仓库里没有为 web 准备的宿主实现。要支持 Web 得先有另一条 spider 执行路径,不是加条件导入能解决的。 |

## 未验证

- **整包零 App 消费者**(台账 §2bis 第 1 组):`providers/iptv` 与 `python_runtime` 互相依赖,但没有宿主 App 装配过,
  所以下面这些不是"验过但薄",是真的没跑过。
- js spider 与 drpy spider 的**真实脚本**没有在 fjs 里跑过:仓库里没有一条本包测试,`spawn()` 的必需方法检查、
  超时与 `dispose()` 路径都只是代码面。
- TVBox 仓库(`tvbox_repository` / `tvbox_repo_fetcher`)解析过的配置样本只有一个来源:写代码时参照的 v1 结构,
  没有真实站点导出的 config 做对照。
- Python 宿端的 worker 生命周期(`spider_worker.py` 起停、崩溃后回收)没有测试。
## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
