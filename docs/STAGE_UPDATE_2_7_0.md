# Pure Live v2.7.0 阶段稳定版

版本：`2.7.0+4077`  
发布日期：2026-08-23  
维护仓库：`wzgrx/pure_live`  
上游冻结点：`liuchuancong/pure_live@81ec372a`

## 1. 上游整合

- 使用真实 merge 同步上游 `81ec372a`，共同祖先和后续增量同步关系保持完整。
- 合入 `PopularController` 的关闭状态、generation、平台设置防抖和延迟任务隔离，页面销毁或平台列表变化后，旧加载与相邻平台预热不再回写当前页面。
- 合入取消关注弹窗的路由修复，并让取消、确认按钮使用弹窗自身上下文关闭对应路由。
- 上游同时修改了 Windows PiP 状态归属、图片磁盘缩放缓存、仓库更新源、Windows AppId、Android ABI 清单和一套并发全平台工作流。逐项对照后保留维护版已回归的完整 PiP 位置/大小和跨屏恢复、有界图片缓存、覆盖升级 AppId、`wzgrx` 更新源、实际发布 ABI 及串行构建策略。

## 2. 关注页下拉刷新

根因是 `EasyRefresh` 位于横向 `TabBarView` 外层，而真正产生顶部越界拖动的是每个平台内部的纵向 `GridView`/`CustomScrollView`。横向分页层使外层刷新器无法稳定收到活动列表的垂直越界通知，因此界面仍声明 `enableRefresh`，实际手势入口却消失。

本轮调整：

- `BasePageView` 增加嵌套页面自行承载移动端刷新器的能力，其他普通列表维持原行为。
- 关注页关闭外层刷新包装，每个平台房间列表直接拥有自己的 `EasyRefresh`，纵向手势不再穿过横向分页层。
- 有内容时的 `GridView` 和空结果时的 `CustomScrollView` 均保留 `AlwaysScrollableScrollPhysics`，空关注、当前平台无结果及开播筛选为空时也能下拉核验。
- 刷新 Future 继续调用 `FavoriteController.refreshData()`，沿用启动刷新合并、并发上限、房间超时、refresh epoch 和一次性快照发布逻辑。

## 3. 质量门禁

最终修改完成后只执行一次完整门禁：

| 检查 | 结果 |
| --- | --- |
| 构建策略与设备 UI 地图 | 通过 |
| Built-in Kotlin 审计 | 10 个 Gradle 文件通过 |
| Flutter Analyze | 0 issue |
| 单元/Widget 测试 | 226/226 通过 |
| 公开平台接口探测 | 26/26 通过 |
| 总耗时 | 682.596 秒 |
| 峰值进程资源 | CPU 42.73%，工作集 5,379,764,224 bytes，5 个重型进程 |
| 完成后活跃重型任务 | 0 |

质量记录：`20260823T000757112Z-quality-full.json`。

新增回归覆盖关注页直接刷新包装，以及嵌套横向分页关闭外层刷新包装的约束；播放器、弹幕、PiP 恢复、音频模式、实时人数、搜索排序、Windows 升级迁移和长时间资源边界继续由既有测试覆盖。

## 4. 发布矩阵

本轮目标按 Android → Windows → Linux → macOS → iOS 串行构建：

| 平台 | 目标 |
| --- | --- |
| Android | arm64-v8a 正式签名 APK |
| Windows | x64 安装程序与便携 ZIP |
| Linux | x64 tar.gz |
| macOS | Universal DMG 与 ZIP |
| iOS | arm64 unsigned app ZIP 与 TrollStore IPA |

最终运行链接、产物尺寸、SHA-256、签名与归档校验将在全平台阶段完成后写入本节，并同步到 Release 的 `BUILD_METADATA.json` 与 `SHA256SUMS.txt`。

## 5. 验收边界

- 本轮按代码审查、自动化回归、公开接口探测和 Windows 本机运行验证执行，未接入 Android 设备操作。
- 平台公开接口会随站点策略变化；运行时保留超时、失败降级、旧请求隔离和重新连接逻辑。
- Release 只声明实际生成并完成校验的 ABI 和平台文件。
