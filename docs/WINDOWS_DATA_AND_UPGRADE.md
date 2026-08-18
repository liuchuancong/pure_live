# Windows 数据目录与升级

## 存储位置

2.1.2 起，普通 EXE 安装和便携版都以程序所在目录为根目录：

```text
{app}\
  pure_live.exe
  AppData\
    HIVE_DB\                 # 设置、关注、历史、屏蔽规则
    IPTV_CACHE\              # IPTV 频道、数据库、EPG
    IMAGE_CACHE\             # 直播封面缓存
    EMOJI_CACHE\             # 弹幕表情缓存
    DOWNLOADS\               # 应用内下载的字体等资源
    RECORDS\                 # 录制文件
    LOGS\                    # 应用日志
    CACHE\                   # path_provider 缓存
    TEMP\                    # 播放、录制、IPTV/EPG 临时文件
    PLUGIN_SUPPORT\          # shared_preferences 与插件状态
    MIGRATION_BACKUP\        # 升级前回滚备份和迁移工作目录
```

Inno Setup 使用当前稳定 AppId，覆盖安装时优先复用上次目录，同时保留“浏览”选择其他磁盘。卸载或重装默认保留 `{app}\AppData`，避免正常升级删除关注和自定义源。

Windows 会为安装器、卸载信息、快捷方式和启动项使用系统临时目录或注册表；这些是 Windows 安装机制，不存放直播账号、关注、历史或 IPTV 业务数据。安装到受保护且当前用户没有写入权限的目录时，应用会使用用户应用支持目录作为启动保护；使用默认的当前用户安装或选择可写目录即会保持全部业务数据在 `{app}\AppData`。

## 升级合并规则

启动页面和设置控制器之前会执行以下步骤：

1. 枚举当前和旧版 AppId 的安装位置、同级 `PureLive/pure_live`、旧文档目录与历史搬迁索引。
2. 把当前和待导入的 `app_settings.hive` 复制到 `MIGRATION_BACKUP\settings-v4`，并记录原路径、大小和修改时间。
3. 同时识别 2.0.x 的 `List<String>` 和 2.1.x 的 JSON `{"list": [...]}` 集合格式。
4. 关注直播间按 `platform + roomId` 去重，关注分区、历史、WebDAV 条目、屏蔽用户/关键词和菜单配置分别合并。
5. 历史保留最新 50 条；目标中已存在的新配置优先，仅从旧数据补齐缺少字段。
6. IPTV 优先选择数据库最完整的来源，只补入目标中不存在的文件。
7. 已成功导入的源会记录指纹，后续启动不重复导入；损坏或当时被锁定的旧文件会在下次启动再试。

## 从其他磁盘搬迁

在安装向导中选择新目录后，安装器会在新目录生成：

```text
AppData\previous_install_locations.txt
```

首次启动会沿该索引查找上一个安装目录，完成上述备份与合并。验证新版关注、历史和 IPTV 正常后，旧目录可由用户手动归档。

## 恢复检查

- 启动后先检查“收藏”、“历史”、“屏蔽管理”和 IPTV 自定义源。
- 迁移备份位于 `{app}\AppData\MIGRATION_BACKUP\settings-v4`，不要把该目录打包到公开问题附件。
- 新版退出流程会先调用 Hive `flush()` 再销毁托盘和窗口，减少关机、更新或快速重启时最后一次配置变更丢失。
