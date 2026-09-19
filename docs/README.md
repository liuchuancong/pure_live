# Pure Live 文档

本目录保存产品、开发、验证与发布证据。此页只列稳定入口，不再为每个日期化审计追加一行；具体根因报告从中央台账、编号矩阵、专题文档中的反向链接或仓库搜索进入。旧的逐篇索引保存在[历史归档](README_HISTORY_2026_09_19.md)。

## 当前 3.2.0 工作入口

- [完整验收入口](ACCEPTANCE_3_2_0.md)：最短证据链、Android/Windows 批次、质量/构建/发布门禁。
- [当前状态快照](ACCEPTANCE_STATUS_3_2_0.md)：当前候选、编号统计、主要阻塞与下一批顺序。
- [Android / Windows 验收矩阵](ACCEPTANCE_MATRIX_3_1_0.md)：62 个编号行的唯一状态和证据所有者。
- [完整客户端测试计划](FULL_CLIENT_TEST_PLAN_2026_08_28.md)：用户可见功能、界面、操作和测试方法目录。
- [Issue 分流中央台账](ISSUE_TRIAGE_LEDGER_3_2_0.md)：报告版本、当前分类、已有证据和再开条件。
- [平台扩展审计](PLATFORM_EXPANSION_AUDIT_2026_09_07.md)：已注册平台、参考项目差距和未注册分组。

历史时间线仅用于追溯，不作为当前候选指针：

- [验收历史归档](ACCEPTANCE_HISTORY_3_2_0.md)
- [状态时间线归档](ACCEPTANCE_STATUS_HISTORY_3_2_0.md)
- [矩阵增量归档](ACCEPTANCE_MATRIX_HISTORY_3_1_0.md)

## 开发与验证

- [Agent 工作流](AGENT_WORKFLOW.md)：任务路由、快速 Issue lane、文档所有权、验证与构建入口。
- [`AGENTS.md`](../AGENTS.md)：仓库级执行、验证、同步和设备边界。
- [`BUILD_POLICY.md`](../BUILD_POLICY.md)：资源预算、缓存、重型任务与签名规则。
- [`MAINTENANCE_POLICY.md`](../MAINTENANCE_POLICY.md)：缺陷来源分类、修复边界与回归要求。
- [`UPSTREAM_REVIEW_POLICY.md`](../UPSTREAM_REVIEW_POLICY.md)：只读比较和获准入站变更的审查要求。
- [本地构建、测试与发布](BUILD_AND_RELEASE.md)：固定工具链和本地入口。
- [共享 Android 实机轮转](ANDROID_DEVICE_TEST_ROTATION.md)：设备租约、守卫、收尾和证据规则。

## 产品与平台参考

- [平台接口与兼容性](PLATFORM_COMPATIBILITY.md)：目录、搜索、弹幕、人数和能力边界。
- [网络代理链路](NETWORK_PROXY_AUDIT_3_1_0.md)：API、媒体、图片和 WebSocket 的代理所有权。
- [关注刷新设计](FAVORITE_REFRESH_DESIGN.md)：刷新、并发、快照和失败语义。
- [录制参考审计](RECORDER_REFERENCE_AUDIT_3_1_0.md)：录制架构、参考项目和已知边界。
- [WebDAV](WEBDAV.md)：配置、目录和同步使用说明。
- [Android / Windows 性能验证](PERFORMANCE.md)：帧、CPU、GPU、内存和资源回落采样方法。
- [Windows 数据目录与升级](WINDOWS_DATA_AND_UPGRADE.md)：便携/安装版数据、迁移与回滚。
- [依赖与接口审计](DEPENDENCY_AUDIT.md)：锁定依赖、更新边界和接口探针。

## 查找专题证据

日期化 `*_AUDIT_*.md`、`STAGE_UPDATE_*.md` 与候选报告是对应批次的不可变证据，不承担当前总览。按 Issue 号、平台、功能、提交 SHA 或测试名在 `docs/` 搜索；新结论只写入其权威所有者，避免同时复制到 README、验收入口、状态页和矩阵页。
