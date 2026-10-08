# 插件开发指南

> 面向插件作者的最短路径;契约细节见 [../contracts/plugin-contract.md](../contracts/plugin-contract.md)。

## 1. 选择形态

- 站点协议复杂、要性能 → Native(Dart,随 App 分发)
- 标准 Web API、想快速接入 → JS 脚本
- 只有配置(TVBox/M3U/EPG)→ Data 插件(零代码)

## 2. Native 插件步骤

1. `tool/scaffold_package.ps1 plugins/<name>` 生成骨架;
2. 填 `manifest.yaml`(capabilities/permissions);
3. 实现 capability 接口(resolve/refresh 必须给真实 `expiresAt`);
4. 录制 fixtures(真实响应存 `test/fixtures/`);
5. 跑契约测试(`melos run test --no-flutter` 过滤本包);
6. 在 PluginRegistry 登记 → 首页/搜索自动可见。

## 3. JS 插件步骤

1. 复制模板脚本;2. 填 manifest;3. 实现 capability 对象;4. 本地导入调试(日志走 talker);5. 分发(文件/URL/Repository)。

## 4. 验收标准(缺一不可)

- [ ] 契约测试绿(对应 capability)
- [ ] fixtures 齐全且来自真实响应
- [ ] Manifest 权限最小化
- [ ] 无对其他插件/内部包的依赖
- [ ] README(能力范围/已知限制)
