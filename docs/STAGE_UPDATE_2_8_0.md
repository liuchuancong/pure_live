# v2.8.0 阶段稳定版

版本：`2.8.0+4078`
维护仓库：`wzgrx/pure_live`
上游基线：`liuchuancong/pure_live@4ca626d9`
发布日期：2026-08-23

## 本轮范围

- 合并上游抖音搜索、恢复关注刷新、Windows PiP 几何校验、RTX VSR 可选项与结构整理。
- 修复关注页手动下拉、前台恢复和请求失败后的陈旧开播状态，保持逐平台列表稳定。
- 加固抖音匿名搜索回退、Cookie 生命周期、分页、房间身份和备用接口。
- 继续覆盖 Windows 高 DPI 视频纹理限幅、播放器资源释放、弹幕/PiP/横竖屏生命周期与长时间运行稳定性。

## 质量门禁

- Flutter Analyze：0 issue（发布源码修改完成后仅执行 1 次）。
- 单元/Widget 测试：235/235 通过；包含关注权威刷新、抖音搜索、弹幕/PiP 生命周期、播放器切换、Windows 视口纹理和旧配置迁移。
- 公开接口探测：27/27 通过。
- 质量记录：`local-artifacts/build-records/20260823T064043566Z-quality-focused.json`、`local-artifacts/build-records/20260823T064708611Z-quality-full-tests-only.json`。

## 发布产物

| 平台 | 产物 | SHA-256 | 来源/记录 |
|---|---|---|---|
| Android arm64-v8a | 待构建 | 待校验 | 本机编译、正式证书签名 |
| Windows x64 | 待构建 | 待校验 | 本机 Release |
| Linux x64 | 待构建 | 待校验 | GitHub-hosted Linux |
| macOS Universal | 待构建 | 待校验 | GitHub-hosted macOS |
| iOS arm64 | 待构建 | 待校验 | unsigned app / TrollStore IPA |
