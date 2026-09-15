# Issue #865 WebDAV 仅恢复关注列表审计（2026-09-15）

## 结论

[上游 Issue #865](https://github.com/liuchuancong/pure_live/issues/865) 报告 Pure Live **3.1.3**
的 WebDAV 恢复只能覆盖全部配置，希望增加只恢复关注列表且保留其余本机设置的选择。当前源码原先
同样只有“同步到本地”这一条全量恢复路径；`a36ee8faae03ee07aa605d9b6c4e998d23faec28`
已增加“恢复全部设置”和“仅恢复关注列表”两个明确动作，并把选择一直传递到备份导入层。

选择“仅恢复关注列表”时，只读取备份中的 `favoriteRooms` 与 `favoriteAreas`。弹幕屏蔽词、屏蔽
用户、首页平台可见范围、首选平台、主题、播放器、历史记录、账号 Cookie、WebDAV 凭据及其他
设置均保持当前本机值。该请求归类为 **implemented-in-current-source / native-recheck-pending**；
尚未把源码回归外推为已安装候选上的原生验收结果。

## 导入合同

1. 当前版本备份从 `favorite` section 精确提取房间与分区关注列表；旧版平铺备份继续读取根级
   `favoriteRooms` / `favoriteAreas`，两种格式均支持对象与既有 JSON 字符串记录。
2. 目标 section 类型、至少一个关注键及目标列表结构会在任何关注列表变更前完成校验；一个目标
   列表损坏时，另一个列表也不会被部分覆盖。
3. 选择性恢复不解析目标之外的 section，因此其他 section 即使来自未来版本或结构损坏，也不会
   阻断有效关注数据的导入。
4. 恢复后的房间身份沿用现有规范化合同，清理平台与房间号空白并按规范身份去重；分区数据沿用
   现有 `LiveArea` 反序列化合同。
5. 全量恢复与仅关注恢复共用一个 `_restoreInProgress` 和 `HivePrefUtil.persistBatch`，不会交错写入；
   Future 只在目标列表写入持久层完成后结束。

## WebDAV 界面合同

- 备份文件菜单明确显示“恢复全部设置”“仅恢复关注列表”和“删除”，不再用一个含义模糊的本地
  同步动作代表恢复范围。
- 仅关注确认弹窗显示完整文件名，并明确说明其他本机设置保持不变；取消和系统返回都发生在远端
  下载及本机变更之前。
- 两种恢复拥有各自的进行中标签与成功反馈；等待期间继续复用现有文件操作门禁，阻止重复恢复、
  上传或删除交错。
- 320×480、3.0 倍文字夹具确认两个恢复入口、长文件名、范围说明、取消及确认动作均可达；成功
  夹具进一步证明下载内容只进入选择性导入器。

## 验证

| 层级 | 结果 |
|---|---|
| 初始合同红灯 | `restoreFavoriteSettings`、`BackupRestoreScope` 与 `scope` 参数不存在；首轮记录同时发现并修正测试夹具缺少 Rx 扩展的问题，因此不把该轮汇总数字作为产品基线 |
| 首轮质量记录 | `local-artifacts/build-records/20260915T104224269Z-quality-focused.json` |
| 直接四文件回归 | **83/83 PASS** |
| 最终六文件回归 | **104/104 PASS** |
| 当前静态分析 | **No issues found**（38.1 秒，本批一次 analyze） |
| 最终质量记录 | `local-artifacts/build-records/20260915T104729052Z-quality-focused.json` |
| 仓库审计 | `local-artifacts/repository-audits/20260915T104606395Z-focused.json`，0 error / 2 warning |
| GitHub 同步 | `origin/master` 已精确核对为 `a36ee8faae03ee07aa605d9b6c4e998d23faec28` |

本批没有构建候选、启动 Windows GUI、连接 ADB、操作设备或发布；Astra Light 使用 **0 次**。

## 后续原生边界

- 在含 `a36ee8fa` 的 Android/Windows 累计候选上，用同时含关注直播间、关注分区及其他设置的真实
  WebDAV 备份分别执行取消、仅恢复关注、全量恢复、损坏目标与重复触发。
- 对仅恢复前后的 Hive/界面状态留证，确认关注房间与分区更新，而屏蔽项、平台选择、主题、播放器、
  历史记录及敏感配置保持原值。
- 该源码增量不改变宏观验收账本：**20 PASS / 42 RUN / 0 NR，共 42 组未闭环**；A1-05、
  A2-01 与 W1-01 保持 `RUN`。
