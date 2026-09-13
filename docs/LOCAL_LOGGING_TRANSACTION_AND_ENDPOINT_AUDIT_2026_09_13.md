# 本地日志事务、端点与隐私边界审计

## 范围与根因

本轮以 `18d764a9` 为基线，代码修订提交为 `bfe935bc`。范围覆盖“备份与恢复”页的本地日志开关、日志文件写入器、浏览器日志页、运行期日志缓冲、设置服务生命周期，以及与相同单飞事务实现相邻的 Windows 开机启动调用结果。未构建 Android/Windows 候选，未执行生产网络、ADB、设备 UI、Windows GUI 或 Computer Use；Astra Light 使用 **0 次**。

源码审查确认六类稳定缺口：

1. 浏览器日志服务器地址与端口写入 Hive。该端点只属于当前进程，进程重建或关闭日志后仍可能展示上一次已经失效的 URL。
2. 日志开关直接改写 Rx，再由未等待的观察器异步启停写入器和 HTTP 服务。连续快速切换时，较早的启用动作可能在较晚的关闭动作之后提交；界面同时缺少忙碌态、失败反馈与状态回滚。
3. HTTP 服务绑定 `0.0.0.0`，同一局域网中的其他主机可访问诊断页；取空闲端口又采用“先临时绑定、关闭、再重新绑定”的两步流程，存在端口被抢占的时间窗口。
4. `Log.i/d/e/w/logPrint` 在设置服务注册前直接读取 `LogController.to`，应用早期日志可能因控制器尚未存在而中断调用方。
5. Release 模式即使用户显式开启本地日志，也不会填充浏览器页面使用的内存缓冲，因此页面可启动但没有本次会话内容。
6. 日志与 Windows 启动项的单飞队列虽然保证“最后目标胜出”，首个调用者仍可能收到后续相反目标的成功结果，调用结果没有表达该调用者自己的目标是否最终成立。

## 修订

- 将 `serverAddress` 与 `serverPort` 改为纯运行期响应状态，进程启动不再恢复历史端点；验证关闭、失败回滚和控制器释放都会清空地址与端口。本地日志启用状态继续采用既有的会话级语义，应用重建后默认关闭。
- 为日志开关增加串行的 latest-target 事务：异步动作成功后才提交界面状态；失败时恢复最后一次确认值并显示双语原因；事务期间禁用整行和 Switch，避免用户点击产生乐观假状态。
- 为每个调用者按自己的目标计算最终结果。快速“开→关”完成后，开请求返回未达成，关请求返回已达成；Windows 启动项的同构事务同步修正并增加回归。
- 日志资源启停增加代次栅栏：先等待当前文件写入器和 HTTP 服务关闭，再创建候选资源；过期代次只清理自己持有的对象，不再提交陈旧端点。
- 直接使用 `HttpServer.bind(InternetAddress.loopbackIPv4, 0)`，由系统原子选择并占用端口，同时把浏览器日志页限制在本机回环地址。
- 在控制器尚未注册时把日志调用保持为诊断内存路径，不触发设置查找；Debug 模式继续保留有界缓冲，Release 仅在用户显式开启本地日志的当前会话中填充该缓冲，使浏览器页展示实际内容。
- 日志文件初始化返回可验证结果；初始化或 HTTP 绑定失败时关闭已创建资源，事务保留真实关闭状态。浏览器入口只在“已启用、事务空闲、当前端口有效”三项同时成立时出现，并使用结构化 `Uri` 构造地址。

## 确定性证据

- 首个有效红灯 `local-artifacts/build-records/20260913T074010242Z-quality-focused.json` 在旧实现上证明缺少事务 API、运行期状态和回环绑定合同。
- 实现迭代记录 `local-artifacts/build-records/20260913T074637192Z-quality-focused.json` 暴露响应值导入和 Widget 可点击位置问题；修正后 `local-artifacts/build-records/20260913T075001350Z-quality-focused.json` 为 **13/13 PASS**。
- 并发红灯 `local-artifacts/build-records/20260913T075239350Z-quality-focused.json` 同时证明日志与 Windows 启动项首个调用者会误收后续目标结果；修订后 `local-artifacts/build-records/20260913T075435974Z-quality-focused.json` 为 **19/19 PASS**。
- 早期日志红灯 `local-artifacts/build-records/20260913T075801655Z-quality-focused.json` 证明设置服务注册前 `Log.i` 会抛出查找异常；修订后的缓冲与 Release 策略记录 `local-artifacts/build-records/20260913T080115967Z-quality-focused.json` 为 **4/4 PASS**。
- 首次扩展门禁 `local-artifacts/build-records/20260913T080646374Z-quality-focused.json` 的全库 analyze 已通过，唯一失败是测试插入动态卡片后目标位于惰性滚动视口之外；补齐可达滚动后，单文件复验 `local-artifacts/build-records/20260913T081329783Z-quality-focused.json` 通过。
- 最终门禁 `local-artifacts/build-records/20260913T082036809Z-quality-focused.json` 覆盖 8 个测试文件，共 **32/32 PASS**；包括运行期端点、启停提交/回滚、直接 Rx 兼容、快速相反目标、早期日志、Release 缓冲策略、备份页窄屏布局、相邻备份路径、Windows 启动事务，以及 FFmpeg HLS 连接停止/请求所有权。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**；仓库策略与工具夹具通过，结束后活跃重型进程为 0，实际 ADB 命令为 0。

## 验收边界

本轮完成源码、确定性单元测试和 Widget 验证，使 A2-01 的设置页/本地诊断路径继续取得证据并保持 `RUN`。当前 Android 与 Windows 候选仍需分别验证真实日志文件写入、回环浏览器 URL、启用/关闭/快速切换、失败注入、Release 页面内容及打开日志目录；这些原生结果不得由源码测试代替。Windows GUI 批次开始时按仓库规则只创建一个 Astra Light 任务，并复用至该批次结束。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
