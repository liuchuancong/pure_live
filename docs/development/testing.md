# 测试体系

## 层级

| 类型 | 范围 | 运行 |
|---|---|---|
| Unit Test | utils/domain/repository | 每包,离线 |
| Contract Test | Capability 契约(内置源与 JS 源同断言) | plugin_api 契约套件 |
| Fixture Test | 源解析对真实响应快照断言 | 每 source 包 `test/fixtures/` |
| Integration Test | 跨包(源→媒体→历史) | integration_test/ |
| Golden Test | ui_kit 组件(明暗两套主题) | ui_kit |
| Plugin Sandbox Test | JS 沙箱装载/超时/崩溃隔离 | plugin_host |
| Playback Test | 起播/换链/恢复路径 | media(用假引擎) |
| Recovery Test | TTL/403/404/断网/线路切换/引擎回退 | media |
| Migration Test | v1 数据/备份版本迁移 | migration |
| Performance Test | 起播延迟/内存 | 抽样 |

## 重点场景(必测)

URL TTL 到期预取、403/404、网络断开恢复、线路切换、引擎回退、auth 过期、插件崩溃与超时隔离、数据迁移。

## 门禁

PR:受影响包 analyze + test + 护栏;主干:全仓 + 集成。
