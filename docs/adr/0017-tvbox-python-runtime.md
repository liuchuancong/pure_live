# ADR 0017:TVBox 生态跑在嵌入式 CPython 上(serious_python)

- 状态:已接受(2026-10-08)
- 相关:[../architecture/external-ecosystem.md](../architecture/external-ecosystem.md)、[../sources/vod/tvbox.md](../sources/vod/tvbox.md)、[dependency-rules.md](../architecture/dependency-rules.md) §4

## 背景

TVBox 生态的可执行部分是 **spider 脚本**:catvod / FongMi 系的 jar 里带 Java 编译产物,而 `webtv-main`(WebHomeTV,`catvod` + `chaquo` 模块)用 ChaquPy 把 spider 直接写成 Python —— `chaquo/src/main/python/base/spider.py` 定义了 `init / homeContent / homeVideoContent / categoryContent / detailContent / searchContent / playerContent / liveContent / localProxy / action / destroy` 这套接口,`app.py` + `runner.py` + `trigger.py` 负责装载与调用。

PureLive v2 是 Flutter 应用。要"直接导入直接运行"这些源([external-ecosystem.md](../architecture/external-ecosystem.md) 的核心结论),就必须有一个能跑 Python 的宿主;应用侧已经引入 `serious_python: ^5.0.0`。

## 决策

1. **宿主 = serious_python 5.x**(嵌入式 CPython,iOS / Android / macOS / Linux / Windows 全覆盖,web 走 Pyodide 分支)。新增 `packages/integrations/python_runtime` 作为唯一封装点:厂商 SDK 只允许出现在 integrations 层。
2. **Dart 不直接调 Python 函数**。这是 serious_python 自身的硬约束:两侧通过 Python 程序暴露的接口通信(本机 HTTP / socket / SQLite / 文件)。本仓采用**本机 HTTP**:`python_runtime` 启动运行时并拿到 base URL,`packages/ecosystem/external_tvbox` 用 HTTP 调 spider 端点,再把结果映射成 `ContentRef` / `MediaTicket`。
3. **spider 接口面按 webtv-main 对齐**,不另造一套:Python 侧实现同一组方法名与返回结构,Dart 侧的 `LiveSource` / `VodSource` 契约保持不变,映射只发生在 `external_tvbox` 内部。参考实现路径记在代码注释里,不把上游代码搬进本仓。
4. **CPython 版本在构建里钉死**:通过 `SERIOUS_PYTHON_VERSION` 固定一档(3.12 / 3.13 / 3.14 之一),写进 `toolchain` 配置而不是留给默认值,否则同一份源码两次打包会带不同的解释器。
5. **分层例外入白名单**:`ecosystem/external_tvbox → integrations/python_runtime`。L1 依赖 L0.5 与"L1 → L0"的规则冲突,但外部生态运行时必须宿主在厂商插件之上,记入 [dependency-rules.md](../architecture/dependency-rules.md) §4。
6. `localProxy` 与 spider 自发的网络请求**不绕过权限体系**:Python 侧的出网仍要经 `integrations/python_runtime` 暴露的受控通道,与 JS 插件只能走 PluginNetwork 是同一条规则([../security/plugin-sandbox.md](../security/plugin-sandbox.md))。

## 后果

- 正:TVBox 的 jar / 脚本源可以原样导入,不需要用户转换成 PureLive 插件,也不需要我们把 33+ 站点的解析逻辑重写成 Dart。
- 正:同一套 Python 宿主将来复用给 LX Music 源(W6)与用户自带脚本。
- 负:**包体积**:每个平台都要带 CPython 运行时与 wheel,Android 与 iOS 安装包显著变大,需要按 ABI/平台裁剪并在发布说明里写清。
- 负:**启动与内存**:运行时冷启动、GIL 与线程模型、崩溃隔离都要在 W7 实测;本机 HTTP 增加一次序列化往返。
- 负:多一层进程内边界,调试要同时看 Dart 与 Python 栈;诊断必须把两侧关联到同一个 trace(见 [../diagnostics/tracing.md](../diagnostics/tracing.md))。
- 待定:`serious_python` 目前在应用 `pubspec.yaml` 的 **dev_dependencies** 里,那是错的位置;等 `python_runtime` 实装时要移到 `dependencies`,并由 integrations 层持有而不是应用直接持有。
