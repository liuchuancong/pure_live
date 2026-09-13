# 浏览器日志 HTTP 合同与响应式界面审计

## 范围与稳定复现

本轮以 `7edd57b5` 为基线，代码修订提交为 `56c6b9f8`。范围限本地浏览器日志页的 HTTP 路由、清空操作、响应头、日志文本呈现和窄屏动作布局，并复用上一轮已完成的回环绑定与会话级资源事务。未构建 Android/Windows 候选，未执行生产网络、ADB、设备 UI、Windows GUI 或 Computer Use；Astra Light 使用 **0 次**。

源码和有效红灯确认以下用户可见缺口：

1. `GET /clear` 直接清空当前会话日志，且任意其他路径都会返回完整日志页面；路由、方法和错误状态没有明确合同。
2. 清空动作没有确认，也不携带动作头。其他网页只要命中本地端口即可发出简单跨来源请求；旧服务没有区分浏览器页面读操作与破坏性操作。
3. HTML 与 JSON 响应没有禁缓存、禁止嗅探、禁止嵌入、同来源资源和无引用来源策略，诊断内容可能进入浏览器缓存或被嵌入其他页面。
4. 顶栏不换行，四个按钮与标题在手机窄屏上争用同一横排；按钮缺少移动端 44 px 触控高度，徽章还有无效的 `2Fpx` 圆角值。
5. 四个按钮使用内联 `onclick`；复制只有成功弹窗，失败没有页面内反馈；清空失败也只恢复自动刷新。空日志页则展示空表格，没有明确会话状态。

## 修订

- 建立显式请求分类：只有 `GET /` 返回页面；`POST /clear` 且包含 `X-PureLive-Log-Action: clear` 才提交清空。错误方法返回 405 和 `Allow`，缺少动作头返回 403，未知路径返回 404；所有错误均返回结构化 JSON。
- 清空按钮先显示确认框，再发出带自定义动作头的 POST。该头使普通跨来源脚本请求进入浏览器预检，而服务不开放 CORS；结合上一轮随机回环端口，破坏性入口不再是可直接触发的 GET。
- 全部响应统一设置 `no-store`/`no-cache`、`nosniff`、`DENY` framing、same-origin resource policy、no-referrer 与限制默认资源/嵌入/base/form 的 CSP；HTML 明确使用 UTF-8。
- 顶栏和按钮组允许换行；640 px 以下使用 8 px 页面边距、双列弹性动作、44 px 最小触控高度及更窄的时间列。徽章圆角修正为有效值，键盘焦点增加可见轮廓。
- 移除全部内联点击处理，通过 `DOMContentLoaded` 绑定具名按钮；清空增加确认与失败保留提示，复制成功/失败进入 `aria-live` 状态区，空会话显示明确占位行，复制逻辑安全跳过占位行。
- 既有日志内容 HTML 转义继续保留，并增加脚本标签、换行、空格与 `&` 的回归；新增真实回环 `HttpServer`/`HttpClient` 测试，直接核对页面、方法、动作头、状态码、响应头、保留和清空结果。

## 确定性证据

- `local-artifacts/build-records/20260913T082942810Z-quality-focused.json` 与 `20260913T083230524Z-quality-focused.json` 记录新增测试文件进入格式门禁前的非产品预检失败；格式化后继续执行真实红灯，未用这些记录证明产品缺口。
- 有效红灯 `local-artifacts/build-records/20260913T083525845Z-quality-focused.json` 在旧代码上因缺少请求分类、安全响应头和可测试页面合同而稳定编译失败。
- 首轮实现 `local-artifacts/build-records/20260913T083925630Z-quality-focused.json` 覆盖页面与相邻日志事务，共 **14/14 PASS**。
- 加入实际回环 HTTP 请求后，`local-artifacts/build-records/20260913T084205200Z-quality-focused.json` 为 **15/15 PASS**；真实请求确认 GET 页面、GET 清空 405、缺头 POST 403、正确 POST 200 并清空、未知路径 404。
- 最终门禁 `local-artifacts/build-records/20260913T084937120Z-quality-focused.json` 覆盖 9 个测试文件，共 **37/37 PASS**；包含浏览器页面、日志事务/缓冲、备份页布局/目录相邻路径、Windows 启动事务及 FFmpeg HLS 连接停止/请求所有权。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**；仓库策略、工具夹具、格式和差异检查通过，结束后活跃重型进程为 0，实际 ADB 命令为 0。

## 验收边界

本轮完成浏览器日志页的确定性 HTTP、内容与响应式 UI 合同，使 A2-01 继续取得证据并保持 `RUN`。当前 Android/Windows 候选仍需用外部浏览器验证真实页面加载、窄屏/宽屏布局、自动刷新、主题、复制、清空确认及关闭日志后的端点失效；Release 会话还需与真实文件写入、打开目录一起验收。Windows GUI 批次开始时按仓库规则只创建一个 Astra Light 任务并复用至批次结束。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
