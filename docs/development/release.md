# 发布(Release)

## 渠道

- GitHub Release(全平台产物:Android APK 分 ABI / Windows EXE+MSIX+Portable / Linux deb+portable / macOS zip+dmg / iOS TrollStore IPA)。
- 应用内更新:release 包消费 `version.json`(应用内检查)+ `releases.json`(版本页)。

## 门禁(全部绿才发)

1. 全仓 analyze + test + 护栏。
2. 契约测试与 fixtures 通过(33 站源至少冒烟)。
3. 关键指标抽样:play_success_rate / 起播延迟(v10 观测体系)。
4. 崩溃样本清零或已知可解释。
5. 迁移测试通过(若跨版本含数据变更)。
6. APK/签名/哈希/版本号一致性检查(CI 现有流程延续)。

## 流程

tag(如 v4.0.0)→ CI 全平台并行打包 → Release(说明含 version_desc)→ releases.json 机器人提交 → 应用内更新灰度(可按比例放开)。

## 回滚

应用内更新支持指回上一版;数据迁移已带 Rollback(见 [../services/backup.md](../services/backup.md))。
