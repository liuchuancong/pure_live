# HTTP(S) 目标校验与 IPTV 网络导入审计

## 范围与稳定复现

本轮以 `c5a5dded` 为基线，代码修订提交为 `e46ffbc4`。范围限 `FileUtils` 的 HTTP(S) 目标识别、外部打开分支，以及 IPTV 设置页的网络导入入口；未构建 Android/Windows 候选，未访问生产网络，未执行 ADB、设备 UI、Windows GUI 或 Computer Use，Astra Light 使用 **0 次**。

旧实现以未锚定正则表达式搜索输入中的任意匹配片段，并把顶级域名限制在 1～6 个字符，形成两类确定性问题：

1. `http://localhost:8080`、IPv6 回环地址、`.technology` 等长顶级域名和大写 HTTP scheme 会被拒绝，合法 IPTV 播放列表或 EPG 地址无法提交。
2. `prefix https://example.com/list.m3u`、包含 URL 片段的本地路径等输入只要局部命中即被接受，IPTV 设置页会把整段文本交给网络导入。
3. 外部打开先用正则分类，再重新解析原始文本；校验和启动没有共享同一个结构化结果，后续规则容易分裂。

## 修订

- 新增 `FileUtils.parseHttpUrl` 作为单一结构化入口：先去除首尾空白，再要求完整输入可解析、scheme 为 HTTP/HTTPS、host 非空，显式端口位于 1～65535。
- 接受公网域名、长顶级域名、`localhost`、IPv4/IPv6 回环地址、大写 scheme，以及编码后的路径、查询和 fragment；scheme 统一为小写，URI 的其余结构保持原义。
- 拒绝嵌入前后缀、输入内部空白、无 scheme 主机、FTP/file/javascript、空 host、越界端口和包含 URL 片段的 Windows 路径。
- `isValidUrl` 与 `isHostUrl` 统一委托结构化入口；`openFileOrUrl` 直接复用同一个已验证 URI，避免分类后再次解析原始文本。
- IPTV 网络导入继续通过 `FileUtils.isValidUrl` 进入既有提交事务，因此同步获得完整 URL 合同；Widget 回归同时核对长顶级域名提交一次，以及嵌入 URL 文本显示既有本地化错误且不发起第二次请求。

## 确定性证据

- `local-artifacts/build-records/20260913T085839867Z-quality-focused.json` 记录新增结构化入口尚未存在时的编译红灯；该记录只证明测试先于实现进入门禁。
- `local-artifacts/build-records/20260913T090056867Z-quality-focused.json` 使用临时旧规则包装器直接捕获旧行为，三组测试为 **0/3 PASS**：localhost 被拒、嵌入 URL 被接受、去空白并规范 scheme 的 URI 没有返回。
- 产品修订后，`local-artifacts/build-records/20260913T090324758Z-quality-focused.json` 的结构化 URL 单元测试为 **3/3 PASS**。
- 加入 IPTV 页面集成回归后，`local-artifacts/build-records/20260913T090610679Z-quality-focused.json` 共 44 项，仅新增夹具因等待故意保持 pending 的导入 future 而超时；改用单次 pump 捕获提交后，`local-artifacts/build-records/20260913T090832925Z-quality-focused.json` 为 **45/45 PASS**。
- 最终门禁 `local-artifacts/build-records/20260913T091432223Z-quality-focused.json` 覆盖 10 个测试文件，共 **128/128 PASS**；包括 URL 结构合同、IPTV 设置/管理、APK 下载、备份布局、路径管理、录制设置/持久化/页面及字体管理相邻路径。
- 同一最终门禁只执行一次全库 `flutter analyze`，结果为 **No issues found**；仓库审计、格式和差异检查通过，实际 ADB 命令为 0。

## 验收边界

本轮补强 A1-05 的 IPTV 网络导入与 A2-01 的设置界面确定性证据，两项继续保持 `RUN`。Android/Windows 候选仍需验证真实外部浏览器启动、本地 IPv4/IPv6 服务、长顶级域名播放列表与 EPG 导入、嵌入无效文本反馈，以及远端服务自身的协议兼容性。Windows GUI 批次开始时按仓库规则只创建一个 Astra Light 任务，并复用至该批次结束。宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
