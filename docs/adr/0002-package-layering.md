# ADR 0002:包分层(Package Layering)

- 状态:已接受(2026-10-08)

## 背景

v1 单包内目录分层靠脚本校验,约束弱;插件化后需要更强的结构边界。

## 决策

melos 单仓多包,七层:Foundation(14)→ Integrations(2)→ Ecosystem(6)→ Services(11)→ UI(5)→ Features(repository 10 + UI 9)→ Providers/Plugins(35+);app 唯一组合根。目录形态:仓库根每层一目录、每能力一包;包名 `pure_live_<name>`。依赖规则与例外清单见 [../architecture/dependency-rules.md](../architecture/dependency-rules.md);护栏 `tool/check_architecture.dart`。

## 后果

- 正:边界机械可查;新包脚手架零漂移;TV 等第二宿主可复用 repository 层。
- 负:包多(melos/脚手架消化);过早拆分风险由"目录先行的晋升规则"缓解。
