# Pure Live v3.1.4 Android 平板关注刷新修复

## 1. 范围与来源判定

- 版本：`3.1.4+4117`
- 目标平台：Android `arm64-v8a`；Windows 继续使用 v3.1.3。
- 维护基线：当前 `wzgrx/pure_live`；本轮只读取近期上游 Issue，不同步上游提交。
- 对应问题：[#826 平板横屏状态下不能下拉刷新](https://github.com/liuchuancong/pure_live/issues/826)。
- 归因：`shared-current-bug`。Issue 报告版本为上游 v3.0.9，维护分支的关注网格仍保留相同宽度分支，因此当前代码可确定复现，不需要把问题归因于网络接口、刷新任务或设备厂商手势。

## 2. 根因链

1. 关注页包含“直播 / 录播 / 未开播”状态页、平台 `TabBarView` 和每个平台自己的纵向网格。
2. 为避免外层刷新器收不到嵌套平台页的 overscroll，`BasePageView` 在关注页明确设置 `wrapMobileRefresh: false`，由每个平台子页自行包装 `EasyRefresh`。
3. `RoomGridView` 又用 `width > 680` 直接返回裸 `GridView`，原意是让桌面宽屏采用分页/按钮式刷新。
4. Android 平板横屏同样大于 680 px，但 `PlatformUtils.isMobile` 仍为真。宽度判断把它错误归入桌面分支，导致外层和内层两个刷新入口同时消失。
5. 网格、数据控制器和 `refreshData()` 本身均正常；缺失的是把纵向 pointer drag 转交给刷新头的包装层，因此表现为没有动画也没有回调。

## 3. 修复设计

- 新增唯一判定 `shouldWrapFavoritePullToRefresh(viewportWidth, isMobilePlatform)`：
  - Android/iOS 始终保留触控下拉；
  - 桌面宽屏继续不包装移动刷新；
  - 桌面窄窗口仍沿用紧凑移动布局与下拉行为。
- 网格列数、卡片尺寸和缓存范围继续按宽度响应，不与输入平台耦合。
- 每个平台页继续独立持有刷新器；纵向刷新轴和横向平台页轴保持分离。
- 复用现有串行 `FavoriteController.refreshData()`，不增加第二套网络请求、并发池或增量发布路径。

## 4. 自动化证据

- 宽屏移动平台 `1280 px`：刷新包装为真；
- 宽屏桌面 `1280 px`：刷新包装为假；
- 窄桌面窗口 `600 px`：保持紧凑刷新包装；
- 真实 pointer drag 继续验证 Material 指示器出现、释放后只触发一次刷新、任务完成后正确收起；
- 聚焦回归：`test/favorite_pull_refresh_test.dart` 2/2 通过，记录为 `local-artifacts/build-records/20260831T164210088Z-quality-focused.json`。
- 冻结前完整门禁：Analyze 0 issue、Flutter 675/675、公开平台接口 42/42、全仓审计 3895 个文件且 0 error；记录为 `local-artifacts/build-records/20260831T171731254Z-quality-full.json`。

## 5. 运行与交付矩阵

| 场景 | 状态 | 证据边界 |
| --- | --- | --- |
| Android 手机竖屏 | 待最终 APK 快速复验 | 现有手势链不变，确定性真实拖动测试通过 |
| Android 平板横屏 | 待对应设备/可调宽窗口复验 | 根因分支已移除，宽屏移动判定测试通过 |
| Android 空列表/短列表 | 自动化 PASS | 唯一纵向 ScrollView 使用刷新器提供的 physics |
| Windows 宽屏 | 静态隔离 PASS | 仍走桌面分支，不新增触控刷新包装；v3.1.3 包继续有效 |

## 6. 发布门禁

1. 冻结源码执行一次 Analyze、完整 Flutter 测试、公开平台接口探针和全仓审计；
2. Android 仅串行构建 `arm64-v8a` Release，核对版本、Manifest code、唯一 ABI、关键原生库、Flutter 资源、签名状态、大小和 SHA-256；
3. 覆盖安装后核对启动、普通手机关注页下拉和原有数据保留；平板横屏缺少对应设备时保持明确的运行证据边界；
4. GitHub `master`、`v3.1.4`、Release、更新源、构建元数据和 APK 对齐同一冻结提交；
5. Windows 不因 Android 专项补丁重复构建，下载索引继续指向 v3.1.3。

## 7. 回滚边界

回滚只需恢复关注网格的刷新包装条件及对应测试。修复没有修改平台接口、关注状态合并、卡片排序、播放器、弹幕、录制或桌面分页状态机。
