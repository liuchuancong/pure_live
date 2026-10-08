# 发布计划

## 版本策略

- v2 期间发 **Alpha(自用)/ Beta(可信用户)/ RC / 4.0.0 正式**;语义化版本,major=4 标记 v2 代际。
- 分支:`v2` 长期开发;发布从 `v2` 打 tag;`master` 保持 v1 可发布态直至 v2 正式。

## 阶段发布物

| 阶段 | 内容 | 渠道 |
|---|---|---|
| Alpha(M3 后) | B 站单插件闭环,自装自用 | GitHub Release(draft)/手动分发 |
| Beta(M5-M6) | 音乐+直播铺量+TVBox | GitHub Release(prerelease) |
| RC(M8) | 全功能+迁移器+全平台 | Release + 应用内更新灰度 |
| 4.0.0(M9) | 正式版 | Release + 应用内更新全量 |

## 门禁

见 [../development/release.md](../development/release.md)(全仓测试/契约测试/指标抽样/崩溃清零/迁移测试/签名哈希一致性)。

## 发布说明

version_desc 由仓库 `assets/version.json` 提供(发布流水线既有机制);措辞遵守既有规范(不提外部项目)。

## 回滚

应用内更新指回上一版;数据迁移带 Rollback;发布 tag 不可删除只可标记 latest 调整。
