# Issue #874 关注列表单独同步（2026-09-23）

[上游 Issue #874](https://github.com/liuchuancong/pure_live/issues/874) 希望在 Windows 和移动端之间只交换关注列表，保留设备各自的其他设置。既有 #865 已实现 WebDAV 文件的“仅恢复关注列表”，但原发送端仍只有完整配置上传；本批补齐成对的发送和本地文件入口。

## 实现合同

- WebDAV 页“更多操作 → 仅上传关注列表”输出 `purelive_favorites_<时间>_<UUID>.txt`；普通悬浮按钮继续输出完整配置。接收端沿用“仅恢复关注列表”。
- 本地备份页增加“仅导出关注列表 / 仅导入关注列表”，同样使用文件选择器与既有持久化恢复事务。
- 专用格式保留 v3 `backupVersion`，增加 `backupScope: favorites`；`favorite` section 精确包含 `favoriteRooms` 与 `favoriteAreas`。不包含 Cookie、WebDAV 凭据、历史、IPTV 源或其他设备设置。
- 完整恢复入口检查范围标记，若选到专用文件则在任何配置写入前报格式错误；用户再选择关注列表入口即可。旧完整 v2/v3/平铺备份的选择性关注恢复合同不变。
- 上传仍使用现有单操作门禁、服务所有权和目录 epoch 检查，不与恢复交错；文件名使用 UUID 避免同秒覆盖。

## 验证与后续

源码回归覆盖专用数据包字段边界、误用完整恢复保护、恢复后非关注设置不变、WebDAV 独立文件名及入口、并发门禁、本地导出路径。四个受影响测试文件分组执行共 **92/92 PASS**（WebDAV 页面 31、备份往返 10、目录状态及本地备份页 51）；记录分别为 `20260923T010219447Z-quality-focused.json`、`20260923T010530295Z-quality-focused.json`、`20260923T010617673Z-quality-focused.json`。九个修改过的 Dart 文件 Analyze **No issues found**；文档对齐测试 3/3，工作流审计 0 error。

本轮额外消除了 3 倍大字下 WebDAV 菜单项的横向溢出，并让窗口夹具的 WebDAV 选择/本地目录写入使用同步可控的假持久层；原有“持久化失败后内存值应保持新值”的旧断言已与实际回滚合同对齐。真实 WebDAV 跨设备回读、本地文件互导及 Windows/Android 可视布局留到统一候选原生验收批次。
