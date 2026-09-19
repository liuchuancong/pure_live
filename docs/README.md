# Pure Live 文档

本文档目录保存开发、验证和用户功能说明。仓库根目录只保留 GitHub 会自动识别的入口文档与项目配置。

## 开发与发布

- [Issue #871 / #845 斗鱼弹幕完整性审计](ISSUE_871_DOUYU_CHAT_COMPLETENESS_AUDIT_2026_09_19.md)：`dms` / `if` 启发式误过滤的确定性复现、3.1.4 缺字段迁移、完整聊天默认合同、显式过滤偏好保留、53 项回归及实时网页对照边界。
- [Issue #869 Android 进房覆盖系统音量审计](ISSUE_869_ANDROID_ROOM_VOLUME_RESTORE_AUDIT_2026_09_19.md)：共享设备媒体音量与单房间快照的所有权、3.1.2/3.1.4 历史核对、全局静音例外、确定性红灯、253 项回归及 K90 原生复验边界。
- [Issue #867 房间卡片简洁布局回归审计](ISSUE_867_ROOM_CARD_COMPACT_LAYOUT_AUDIT_2026_09_19.md)：3.1.4 可见字段型简洁预设的稳定复现、3.1.2 无封面行历史合同、共享布局几何、旧快照迁移、82 项回归及 Windows 原生复验边界。
- [Issue #852 ColorOS 14 系统手势返回审计](ISSUE_852_COLOROS_SYSTEM_BACK_AUDIT_2026_09_16.md)：Flutter 共享元素预测返回的输入持有风险、普通路由 FadeForwards 回退策略、commit/cancel 与目的页再交互回归，以及 ColorOS 14 原生复验边界。
- [Issue #865 WebDAV 仅恢复关注列表审计](ISSUE_865_WEBDAV_FAVORITES_ONLY_RESTORE_AUDIT_2026_09_15.md)：全量/仅关注双入口、版本化与旧版备份兼容、目标范围预校验、共享恢复事务、窄屏大字号确认及 104 项回归。
- [Issue #866 抖音多画面黑屏源码审计](ISSUE_866_DOUYIN_MULTIVIEW_AUDIT_2026_09_15.md)：3.1.3 纯音频 `ao` 被选作小格最低档的历史红灯、当前过滤修复、严格详情/视频源/播放请求头跨层回归，以及普通播放偶发失败、平板横屏和 Windows 卡顿的独立待验边界。
- [标签编辑冲突与所有权审计](TAG_EDITOR_CONFLICT_AND_OWNERSHIP_AUDIT_2026_09_15.md)：同 ID 对象替换、原对象并发更新与控制器换代保护，以及具备 live-region 的可核对冲突状态。
- [标签删除确认与目标身份审计](TAG_DELETE_CONFIRMATION_AND_IDENTITY_AUDIT_2026_09_15.md)：完整双语确认句、48 px 破坏性动作，以及确认期间控制器和标签对象身份替换保护。
- [标签置顶状态与拖拽所有权审计](TAG_TOP_STATE_AND_DRAG_OWNERSHIP_AUDIT_2026_09_15.md)：首项已置顶状态与禁用语义、非首项具名置顶、连续顺序更新，以及整卡长按拖拽的唯一所有者。
- [标签编辑器校验、可访问性与布局审计](TAG_EDITOR_VALIDATION_ACCESSIBILITY_AND_LAYOUT_AUDIT_2026_09_15.md)：字段内空名称/重名反馈、具名 48 px 清除动作、窄屏大字号滚动，以及房间弹窗异步路由和控制器生命周期。
- [标签房间映射迁移与导入完整性审计](TAG_ROOM_MAPPING_MIGRATION_AND_IMPORT_INTEGRITY_AUDIT_2026_09_15.md)：旧房间号向多平台无损合并、映射键/ID 规范化、导入前身份修复、孤儿映射清理和深拷贝持久化快照。
- [标签身份与改名完整性审计](TAG_MANAGEMENT_IDENTITY_AND_RENAME_INTEGRITY_AUDIT_2026_09_15.md)：快速新建唯一 ID、旧碰撞身份启动修复并写回、连续顺序，以及排除当前项的大小写改名重复检查。
- [标签管理卡片动作可访问性审计](TAG_MANAGEMENT_CARD_ACTION_ACCESSIBILITY_AUDIT_2026_09_15.md)：置顶/编辑/删除均携带目标标签名、独立按钮与点击语义、完整 Tooltip、48 px 命中和等待期禁用。

- [标签管理详情可访问性与路由事务审计](TAG_MANAGEMENT_DETAIL_ACCESSIBILITY_AND_ROUTE_AUDIT_2026_09_15.md)：具名 48 px 详情动作、独立按钮/点击语义、应用字号感知卡片高度，以及新增/详情/编辑/删除共享的页面级 single-flight 路由。

- [桌面托盘菜单事件与事务所有权审计](DESKTOP_TRAY_CONTEXT_MENU_EVENT_AND_TRANSACTION_AUDIT_2026_09_15.md)：右键按下唯一入口、释放事件去重、刷新/弹出 single-flight、异常收口与失败后重试。

- [Windows 标题栏项目链接可访问性与打开事务审计](WINDOWS_TITLE_BAR_PROJECT_LINK_TRANSACTION_AUDIT_2026_09_15.md)：具名链接与 Tooltip、键盘焦点/激活、单次外部打开、等待门禁、false/异常反馈，以及窄宽大字号收束。

- [Windows 标题栏控制按钮可访问性与动作事务审计](WINDOWS_TITLE_BAR_CONTROL_ACCESSIBILITY_AUDIT_2026_09_15.md)：三个系统动作的双语语义与 Tooltip、键盘焦点/激活、可见焦点、异步 single-flight、失败反馈与可重试合同。

- [Windows 窗口几何捕获所有权审计](WINDOWS_WINDOW_GEOMETRY_CAPTURE_OWNERSHIP_AUDIT_2026_09_14.md)：普通窗口/PiP 统一宿主队列、最小化/最大化/真全屏隔离、异步二次核对与事件异常收口。

- [Windows 小窗呈现事务与回滚审计](WINDOWS_PIP_PRESENTATION_TRANSACTION_AUDIT_2026_09_14.md)：全屏/宽屏快照所有权、进出 single-flight、跨宿主呈现回滚、可重试退出与真实宿主状态同步。

- [Windows 小窗宿主事务与回滚审计](WINDOWS_PIP_HOST_TRANSACTION_AND_ROLLBACK_AUDIT_2026_09_14.md)：原生窗口串行队列、成功后模式提交、失败逐项回滚、几何隔离与 400×300 最小尺寸恢复。

- [Windows 小窗进出事务与生命周期审计](WINDOWS_PIP_TRANSITION_OWNERSHIP_AUDIT_2026_09_14.md)：进出 single-flight、原生失败反馈、迟到进入清理、关闭/销毁恢复与关闭后重入栅栏。

- [Windows 小窗置顶开关事务审计](WINDOWS_PIP_ALWAYS_ON_TOP_TRANSACTION_AUDIT_2026_09_14.md)：原生窗口层级成功后的延迟提交、等待态、旧层级恢复、失败反馈与单次重试事务。

- [视频设置后台播放开关事务审计](VIDEO_SETTINGS_BACKGROUND_PLAYBACK_TRANSACTION_AUDIT_2026_09_14.md)：权限/后台服务完成后的延迟提交、开关等待态、失败保留与重试，以及助眠/纯音频保活兼容。

- [视频设置 ASMR 模式开关事务审计](VIDEO_SETTINGS_ASMR_MODE_TRANSACTION_AUDIT_2026_09_14.md)：权限/定时服务完成后的延迟提交、开关等待态、失败保留与重试，以及共享开关的显式事务合同。

- [视频设置 ASMR 定时路由与保存事务审计](VIDEO_SETTINGS_ASMR_TIMER_TRANSACTION_AUDIT_2026_09_14.md)：页面单次路由、行内范围/失败反馈、保存等待态与服务成功后的延迟持久化。

- [视频设置清晰度路由与选择事务审计](VIDEO_SETTINGS_RESOLUTION_ROUTE_TRANSACTION_AUDIT_2026_09_14.md)：双入口共享单次路由、类型化延迟提交、明确取消动作与页面/控制器生命周期栅栏。

- [Windows 小窗几何捕获与重置事务审计](WINDOWS_PIP_GEOMETRY_CAPTURE_AND_RESET_AUDIT_2026_09_14.md)：显示器身份规范持久化、响应式单次重置、取消保留与五字段原子清空。

- [精细字号恢复默认布局与事务审计](FONT_SETTINGS_RESET_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)：五项字号单次恢复、窄屏大字号动作合同、取消后重入与页面/控制器退出栅栏。

- [观看记录单项删除可访问性与事务审计](HISTORY_ENTRY_DELETE_ACCESSIBILITY_AND_TRANSACTION_AUDIT_2026_09_14.md)：具名 48×48 删除入口、长标题响应式确认、单次历史变更路由，以及确认期间同房间重新观看保护。

- [观看记录清空确认与快照事务审计](HISTORY_CLEAR_CONFIRMATION_AND_SNAPSHOT_AUDIT_2026_09_14.md)：具名数量确认、320×480 / 3.0 倍中英文动作可达、单次路由，以及确认期间新增/重新观看记录的身份快照保护。

- [本地缓存清理确认与事务审计](CACHE_CLEAR_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)：320×480 / 3.0 倍文字动作可达、破坏性层级、单次确认/清理任务及 10 项回归。

- [账号退出确认与事务审计](ACCOUNT_LOGOUT_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)：七个平台具名确认、320×480 / 3.0 倍中英文动作可达、单次路由/清理任务及 16 项回归。

- [版本历史下载确认与事务审计](VERSION_HISTORY_DOWNLOAD_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)：具名文件确认、320×480 / 3.0 倍文字动作可达、单次路由/下载任务及 19 项回归。

- [WebView2 缺失提示布局与事务审计](WEBVIEW2_MISSING_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)：320×480 / 3.0 倍文字标题溢出、显式下载动作、单次路由/外部启动、退出栅栏及 101 项回归。

- [录制中心取消监控布局与事务审计](RECORDER_MONITOR_REMOVAL_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)：具名且明确保留文件的确认、320×480 / 3.0 倍文字布局、单次路由/底层调用及 43 项回归。

- [关注分区取消关注弹窗布局与事务审计](FAVORITE_AREA_UNFOLLOW_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)：320×480 / 3.0 倍文字下的 128 px 溢出、重复确认路由、捕获目标身份及 24 项回归。

- [观看记录保留数量弹窗布局与校验审计](HISTORY_RETENTION_DIALOG_LAYOUT_AND_VALIDATION_AUDIT_2026_09_14.md)：320×480 / 3.0 倍文字下的 260 px 溢出、静默非法输入、统一滚动面、草稿提交语义及 30 项回归。

- [Windows 视频输出 fit 尺寸所有权审计](WINDOWS_VIDEO_OUTPUT_FIT_SIZING_AUDIT_2026_09_14.md)：Issue #767 的 viewport / DPR 尺寸策略遗漏显示模式、`cover` 等模式的纹理放大链、26 项回归及 Windows Debug 构建边界。

- [Windows 副屏亮度所有权审计](WINDOWS_SECONDARY_MONITOR_BRIGHTNESS_OWNERSHIP_AUDIT_2026_09_14.md)：Issue #863 的无 Dart 调用原生 DDC/CI 写入链、旧 CMake 开关失效原因、移动端实现保留、245 项回归及 Windows Debug 依赖/打包边界。

- [房间卡片设置回归与恢复审计](ROOM_CARD_SETTINGS_REGRESSION_AND_RESTORATION_AUDIT_2026_09_14.md)：Issue #864 的 3.1.3 设置入口缺失来源、当前架构下的移动/桌面独立预设身份与实时预览、3.1.2 持久值迁移、备份合同及 154 项回归；简洁的无封面拓扑见后续 #867 订正。

- [WebDAV 恢复确认与事务审计](WEBDAV_RESTORE_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)：具名覆盖确认、窄屏大字号动作可达、确认前零读取/零本地变更、单次恢复事务及服务/目录代次栅栏。

- [WebDAV 文件行与删除确认审计](WEBDAV_FILE_ROW_AND_DELETE_DIALOG_AUDIT_2026_09_14.md)：超长文件名两行收束与完整提示、窄屏大字号动作可达、具名危险确认、页面路由所有权及单次删除事务。

- [WebDAV 面包屑可见性与父级路由审计](WEBDAV_BREADCRUMB_VISIBILITY_AND_ROUTE_AUDIT_2026_09_14.md)：深层路径当前段自动可见、稳定滚动范围校准、超长目录名完整提示，以及根目录父级请求的页面所有权。

- [WebDAV 配置表单响应式布局审计](WEBDAV_CONFIG_FORM_RESPONSIVE_AUDIT_2026_09_14.md)：长编辑标题收束与完整提示、单一纵向滚动面、窄屏大字号字段/动作可达性及 48×48 动作合同。

- [WebDAV 配置抽屉路由与布局审计](WEBDAV_CONFIG_DRAWER_ROUTE_AND_LAYOUT_AUDIT_2026_09_14.md)：长配置名称收束与完整提示、编辑/删除动作可达性、页面所有的配置/删除路由、抽屉精确关闭及控制器导航解耦。

- [桌面退出弹窗与动作事务审计](DESKTOP_EXIT_DIALOG_AND_ACTION_TRANSACTION_AUDIT_2026_09_13.md)：退出动作归一化、窄屏大字号布局、single-flight 路由、偏好落盘、原生失败后的窗口/拦截恢复及备份合同。

- [共享选项弹窗布局与选择语义审计](SHARED_OPTION_DIALOG_LAYOUT_AND_SELECTION_AUDIT_2026_09_13.md)：选项文字收缩换行、长列表滚动、48 px 整行命中、当前值语义及系统返回合同。

- [共享确认与消息弹窗布局及路由审计](SHARED_ALERT_DIALOG_LAYOUT_AND_ROUTE_AUDIT_2026_09_13.md)：长正文滚动边界、窄屏大字号动作可达性、48 px 命中尺寸、所属路由关闭及既有调用链兼容。

- [共享文本编辑弹窗生命周期与布局审计](SHARED_EDIT_DIALOG_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_13.md)：路由子树控制器所有权、确认/取消返回语义、窄屏大字号滚动视口及响应式动作排列。

- **Windows Computer Use 模型说明**：仅在 Windows 客户端 GUI 验收开始时创建一个 Astra Light 任务，并在同一验收批次内持续复用；源码、测试、构建、文档、Android 与其他非 Computer Use 工作使用常规模型。权威规则见 [`AGENTS.md`](../AGENTS.md#device-and-collaboration-boundaries) 与 [`AGENT_WORKFLOW.md`](AGENT_WORKFLOW.md#model-and-task-handoff)。

- [更新与版本历史 Web 目标归一化审计](UPDATE_AND_RELEASE_WEB_TARGET_AUDIT_2026_09_13.md)：共享 HTTP(S) 解析、用户信息/端口边界、单次 URI 归一化及复制与下载消费一致性。

- [下载文件名 UTF-8 边界与冲突审计](DOWNLOAD_FILENAME_UTF8_AND_COLLISION_AUDIT_2026_09_13.md)：240 字节 basename、暂存/回滚后缀预算、完整 Unicode scalar、扩展名保留及长名称摘要去碰撞。

- [HTTP(S) 目标校验与 IPTV 网络导入审计](HTTP_TARGET_VALIDATION_AND_IPTV_IMPORT_AUDIT_2026_09_13.md)：完整结构化 URI、长顶级域名/回环地址、端口边界、嵌入片段拒绝及外部打开与网络导入共享决策。

- [浏览器日志 HTTP 合同与响应式界面审计](LOG_BROWSER_HTTP_AND_RESPONSIVE_UI_AUDIT_2026_09_13.md)：严格 GET/POST 路由、受保护的清空动作、安全响应头、HTML 转义、空状态和移动端 44 px 响应式动作。

- [本地日志事务、端点与隐私边界审计](LOCAL_LOGGING_TRANSACTION_AND_ENDPOINT_AUDIT_2026_09_13.md)：启停验证事务、运行期端点、回环绑定、原子端口、早期日志安全、Release 浏览器缓冲及双语忙碌/失败反馈。

- [Windows 启动项事务与注册表命令审计](WINDOWS_STARTUP_TRANSACTION_AND_REGISTRY_COMMAND_AUDIT_2026_09_13.md)：注册表回读验证、失败回滚、旧便携路径识别、动态 UTF-16 读取、FFI 资源所有权及双语忙碌/失败反馈。

- [真实在线人数平台偏好持久化审计](AUDIENCE_PLATFORM_PREFERENCE_PERSISTENCE_AUDIT_2026_09_13.md)：同长度旧值修复、小写/去空白/去重/能力过滤合同、备份与导出归一化及安全设置开关。

- [播放器显示模式与首选画质持久化审计](PLAYER_DISPLAY_PREFERENCE_PERSISTENCE_AUDIT_2026_09_13.md)：六种显示模式索引、五个稳定画质键、启动/运行时/备份修复、安全 UI 消费及单一有序来源。

- [Windows 窗口尺寸持久化、PiP 几何与弹窗事务审计](WINDOW_SIZE_PERSISTENCE_AND_DIALOG_TRANSACTION_AUDIT_2026_09_13.md)：400×300～16384 单边合同、首帧/Hive/备份修复、瞬态窗口事件、PiP 有限矩形及路由拥有的事务弹窗。

- [主题设置持久化、备份与首帧安全审计](THEME_SETTINGS_PERSISTENCE_AND_FIRST_FRAME_AUDIT_2026_09_13.md)：模式/语言/颜色/加载样式支持项、0～64 有限间距、启动与运行时修复、旧版字段兼容及安全首帧消费。

- [单页数量设置边界与弹窗生命周期审计](PAGE_SIZE_SETTINGS_BOUNDARY_AND_LIFECYCLE_AUDIT_2026_09_13.md)：1～100 持久化/备份合同、默认值归属、无副作用保存、双语输入反馈与路由退出控制器所有权。

- [代理端点持久化与备份边界审计](PROXY_ENDPOINT_PERSISTENCE_AUDIT_2026_09_13.md)：应用/播放器代理的 Hive 修复、严格备份类型、1～65535 端口合同、7897 回落值与导出归一化。

- [应用退出与 IPTV 自动同步计时设置审计](DEFERRED_TIMER_SETTINGS_AUDIT_2026_09_13.md)：退出分钟数、同步小时数的持久化/备份/调度边界，超范围输入反馈及单次重启语义。

- [网络故障诊断与播放恢复审计](NETWORK_FAILURE_RECOVERY_AUDIT_2026_09_13.md)：Android/curl/POSIX/Windows DNS 语法、HTTP 5xx、具体错误优先级及既有有界线路/源/内核恢复链。

- [Windows PowerShell 5.1 工具链兼容性审计](POWERSHELL_5_TOOLCHAIN_COMPATIBILITY_AUDIT_2026_09_13.md)：非 ASCII 脚本 UTF-8 BOM 合同、代理 journal 跨代解码、双 PowerShell 夹具与端到端质量门禁。

- [录制目录、存储耗尽与自动恢复权限审计](RECORDER_STORAGE_FAILURE_AUDIT_2026_09_13.md)：事务式目录选择、并发安全写探针、自动恢复静默权限探测、独立存储耗尽诊断、续接阻断、计入活动输出的安全额度回收及设置变更即时应用。

- [分享口令交接与导入弹窗审计](SHARE_COMMAND_HANDOFF_AND_IMPORT_DIALOG_AUDIT_2026_09_13.md)：消费者成功提交、失败重试、并发合并、有界自分享抑制、响应式导入弹窗，以及 K90 系统分享面板和返回原应用验证。

- [房间卡片长按与标签分配布局/完整性审计](ROOM_CARD_TAG_ASSIGNMENT_LAYOUT_AND_INTEGRITY_AUDIT_2026_09_13.md)：权威映射、旧键清理、响应式弹窗、所属 Navigator 的关注/取消确认、新增标签自动选择，以及 K90 覆盖安装和原生重开保持验证。

- [2026-09-13 GitHub Issue 增量审计](ISSUE_AUDIT_2026_09_13.md)：维护/参考仓库当前 open 计数、最新更新时间，以及 #859/#860/#861 现有专项窗口复核。

- [Android MPV 音频输出后端审计](ANDROID_AUDIO_OUTPUT_BACKEND_AUDIT_2026_09_13.md)：AudioTrack→AAudio→OpenSL ES 回退、Android `auto`/`null` 语义、原生五项菜单与 K90 五后端真实播放矩阵。

- [主画面与小窗弹幕呈现一致性审计](DANMAKU_RENDERING_CONSISTENCY_AUDIT_2026_09_12.md)：速度/FPS/密度/字体/描边/区域源码矩阵、共享紧凑排版策略、K90 候选回归与 120 Hz 原生待验边界。

- [当前累计 Android 候选覆盖安装与冒烟](CURRENT_ANDROID_CANDIDATE_2026_09_12.md)：基础候选同签名覆盖安装、16/16 播放冒烟、标准流 7/7、竖屏流 9/9、#858 首页软件音量路由，以及小窗设置增量候选专项。

- [Android 小窗弹幕设置原生审计](ANDROID_PIP_DANMAKU_SETTINGS_NATIVE_AUDIT_2026_09_12.md)：K90 实测语义路由、目标页断言、开关即时预览、双向重启持久化、失败夹具修订与规范 Hive 精确恢复。

- [Android 小窗弹幕无障碍与默认恢复审计](ANDROID_PIP_DANMAKU_ACCESSIBILITY_RESET_AUDIT_2026_09_12.md)：具名整行开关、滑块设置名/格式化值、完整恢复范围、当前候选覆盖安装、取消/确认重启持久化与精确数据恢复。

- [Android 物理音量键媒体流路由审计](ANDROID_HARDWARE_VOLUME_ROUTING_AUDIT_2026_09_12.md)：Issue #858 源码宿主缺口、`onResume` 媒体流归属、定向回归、精确提交 arm64 Debug 构建及物理按钮待验矩阵。

- [IPTV 频道 HTTP 请求头、播放与录制链路审计](IPTV_HTTP_HEADER_PLAYBACK_AND_RECORDING_AUDIT_2026_09_12.md)：VLC/EXTHTTP/KODIPROP/URL suffix 解析、schema 9 幂等迁移，以及主播放器、多画面、纯音频和录制字段一致性。

- [IPTV 提供方回看元数据、归档窗口与 URL 策略审计](IPTV_PROVIDER_CATCHUP_METADATA_AND_WINDOW_AUDIT_2026_09_12.md)：M3U/XMLTV 元数据持久化、schema 8 幂等迁移、提供方窗口判定，以及 default/append/shift/Flussonic/Xtream/VOD 地址回归。

- [竖屏播放选择器布局与事务审计](PORTRAIT_PLAYBACK_PICKER_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_12.md)：房间方向/记忆策略的原子提交、竖屏全屏显示模式、取消/系统返回及 320×480 三倍字号回归。

- [Windows 虎牙候选复验与同页面资源对照](WINDOWS_HUYA_CANDIDATE_RECHECK_2026_09_05.md)：b231449e 的 AOT 身份、11 分钟播放、全屏与退出、空载热门页对照，以及 Esc 未闭合观察。

- [关闭与快速重进的播放意图](PLAYER_CLOSE_INTENT_AUDIT_2026_09_05.md)：关闭后旧恢复接管、旧关闭覆盖新播放、取消请求仍开流的受控复现，派发代次修复与相邻回归。

- [HLS 录制排空与地址生命周期](RECORDER_HLS_DRAIN_AUDIT_2026_09_05.md)：停止时冻结媒体列表、完成当前分片、旧地址回收，以及 TS/AES/fMP4/长分片四类 native 回归。

- [FLV 录制停止与输出排空](RECORDER_GRACEFUL_FLV_STOP_2026_09_05.md)：本机固定输入复现取消截断、完整 tag 输入结束、重复停止边界，以及虎牙 325 秒真实录制和 TS/MP4 完整解码复验。

- [虎牙录制租约与停止收尾](HUYA_RECORDER_LEASE_AUDIT_2026_09_05.md)：健康连接不再定时取消、异步凭据所有权，以及原始 TS 保留后定位的取消写尾/封装完整性问题。

- [Windows 虎牙实际客户端与录制审查](WINDOWS_HUYA_GUI_AUDIT_2026_09_05.md)：新源码候选、14 分钟连续播放、12 分半录制、占用采样、菜单 Esc 焦点冲突修复及未覆盖项。

- [虎牙恢复语义与帧看门狗复查](HUYA_RECOVERY_SEMANTICS_AUDIT_2026_09_05.md)：上游 WUP 对比、尾帧误取消明确 EOF 重试的红测与修复、按类型匹配恢复证据、单调截止点和实际原生 500ms 通知边界。

- [录制权限与用户操作顺序审计](RECORDER_USER_INTENT_AUDIT_2026_09_05.md)：权限迟到、开始/停止/移除、启动文件恢复预约、原生取消与实际收尾的区别，以及确定性回归。

- [音频事件与播放器绑定所有权](AUDIO_SESSION_OWNERSHIP_AUDIT_2026_09_05.md)：旧中断/通知串房、停止收尾覆盖新焦点、事件队列饥饿、音量恢复与 131 项定向回归；历史 PiP 观察分开保留。

- [录制轮询与启动意图审计](RECORDER_POLL_OWNERSHIP_AUDIT_2026_09_05.md)：迟到请求、停止/退出、启动历史状态、并发上限、开关逻辑与确定性回归。

- [维护范围与问题处置策略](../MAINTENANCE_POLICY.md)：Android/Windows 维护边界、Issue 分流、Bug 来源判定、上游 Issue 优先级、验证和回滚标准。
- [上游同步审查策略](../UPSTREAM_REVIEW_POLICY.md)：三方差异、全入站文件审查、语义变更台账、冲突处置与合并门禁。
- [Bug 根因分析模板](BUG_TRIAGE_TEMPLATE.md)：复现基线、来源分类、首次错误状态、影响矩阵与分层证据模板。
- [上游同步审计模板](UPSTREAM_AUDIT_TEMPLATE.md)：审查脚本要求的逐文件台账、Issue 映射、质量评估、处置和回归字段。
- [上游同步审计（9e80f3be）](UPSTREAM_AUDIT_9E80F3BE.md)：竖屏比例、直播记录、录播与播放器布局入站提交的逐项处置。
- [上游同步审计（c7d99cc3）](UPSTREAM_AUDIT_C7D99CC3.md)：上游吸收维护分支后的返回、录制权限、初始化与 FFmpeg 参数冲突处置。
- [竖屏比例与直播记录根因审计](BUG_AUDIT_2026_08_26_PORTRAIT_HISTORY.md)：移动端单一可信比例、完整观看日期与不限数量回归证据。
- [直播连续性与录制中心根因审计](BUG_AUDIT_2026_08_28_PLAYBACK_RECORDER.md)：意外暂停、音频焦点、录制真实状态/大小、滚动边界与十一项发布门禁。
- [v3.1.8 录制会话时间修复](STAGE_UPDATE_3_1_8.md)：自动续接尝试与用户录制会话时间解耦、持久化兼容及 Android/Windows 双平台交付。
- [v3.1.8 K90 Pro Android 运行审计](ANDROID_RUNTIME_AUDIT_3_1_8_K90PRO.md)：新主设备覆盖安装、UI 地图、首页/热门、120 Hz 与资源基线，以及待执行的直播矩阵。
- [共享 Android 实机轮转](ANDROID_DEVICE_TEST_ROTATION.md)：哔哩哔哩模块、小红书模块与 Pure Live 按 A→B→C 串行占用同一部手机的默认规则与调用方式。
- [2026-09-04 平台传输与 K90 Pro 实机审计](PLATFORM_TRANSPORT_AUDIT_2026_09_04.md)：Twitch 完整性头、SOOP 安全弹幕端口、YY H5 协议、WebSocket 半开恢复、临时代理和锁屏防误判。
- [2026-09-04 Issue 与弹幕传输审计](ISSUE_AUDIT_2026_09_04.md)：最新上游 Issue 映射、斗鱼 71415 原始捕获，以及抖音双端点/签名/访客 ID/匿名实时弹幕验证。
- [2026-09-05 最新 Issue 审计](ISSUE_AUDIT_2026_09_05.md)：#850 Android 颜色/透明度、#849 Win10 启动证据边界与 #848 系统字体语义修复。
- [虎牙完整链路与后台预取复核](HUYA_PREFETCH_OWNERSHIP_AUDIT_2026_09_05.md)：上游与本分支差异、预取所有权、双 CDN 原画连续解码、868 项回归及发布包证据边界。
- [虎牙已派发重试与错误去重](HUYA_DISPATCHED_RETRY_AUDIT_2026_09_05.md)：Timer 到点后的旧重试再次打断播放，以及重复错误取消必要恢复的红测、修复与内核边界。
- [虎牙醒目留言 HTTP 生命周期](HUYA_MESSAGE_BOARD_HTTP_AUDIT_2026_09_05.md)：默认超时单位、连接释放、重复实现合并、实际 Dio/TARS 回归与公开 HTTPS 验证。
- [AcFun 目录与搜索接入](ACFUN_NAVIGATION_AUDIT_2026_09_05.md)：官网分类、稀疏分页、取消/缓存边界、平台入口和设置迁移；协议、接口与设备验收分开记录。
- [录制调度与 MP4 收尾生命周期](RECORDER_LIFECYCLE_AUDIT_2026_09_05.md)：同步异常容量泄漏、总时限、取消与写盘所有权、异常进度修复，919 项回归与 Windows 实际录制/完整解码证据。
- [v3.1.7 虎牙醒目留言事件身份修复](STAGE_UPDATE_3_1_7.md)：平台事件 ID、合法重复留言、有界去重缓存与 Android/Windows 交付。
- [v3.1.6 虎牙醒目留言实时刷新修复](STAGE_UPDATE_3_1_6.md)：通知先于 WUP 留言板更新的时序根因、非阻塞有界补偿、Android/Windows 交付与证据边界。
- [v3.1.5 Android / Windows 双平台发布](STAGE_UPDATE_3_1_5.md)：同一冻结源码、双平台版本对齐、串行构建、安装包与校验说明。
- [v3.1.4 Android 平板关注刷新修复](STAGE_UPDATE_3_1_4.md)：宽屏移动设备误判、平台内纵向刷新链路、回归与 Android 交付证据。
- [v3.1.3 Android / Windows 阶段更新](STAGE_UPDATE_3_1_3.md)：多画面真全屏退出入口、安全区适配、触控隔离与双平台交付证据。
- [v3.1.2 Android / Windows 阶段更新](STAGE_UPDATE_3_1_2.md)：Windows 真全屏根因、窗口往返、定向回归与发布证据。
- [v3.1.1 Android / Windows 阶段更新](STAGE_UPDATE_3_1_1.md)：多画面全布局音量、声音来源、弹幕目标、按房间持久化与发布证据。
- [v3.1.0 Android / Windows 阶段更新](STAGE_UPDATE_3_1_0.md)：后台策略、弹幕有界解析、统一代理、安装包与证据边界。
- [v3.1.0 Android / Windows 验收矩阵](ACCEPTANCE_MATRIX_3_1_0.md)：全功能测试账本、平台接口、播放录制、性能与发布门禁。
- [v3.1.0 网络代理链路审计](NETWORK_PROXY_AUDIT_3_1_0.md)：API、封面头像、弹幕 WebSocket、全角地址与代理故障根因。
- [v3.0.18 Android 真机播放与录制加固](STAGE_UPDATE_3_0_18.md)：硬解截图探测隔离、虎牙独立签名、跨重试录制统计和真机证据边界。
- [v3.0.19 Windows x64 稳定版](STAGE_UPDATE_3_0_19_WINDOWS.md)：启动按需初始化、播放器释放、录制统计、Escape、弹幕交互与正式安装/便携包验证。
- [v3.0.17 Android 阶段更新](STAGE_UPDATE_3_0_17.md)：直播连续性、录制真实统计、固定成本分片跟踪和录制中心边界。
- [本地构建、测试与发布](BUILD_AND_RELEASE.md)：固定工具链、一键质量门禁、Android 签名、Windows 打包与本地发布。
- [Windows 数据目录与升级](WINDOWS_DATA_AND_UPGRADE.md)：安装目录数据、旧版关注合并、换盘迁移与回滚。
- [依赖与接口审计](DEPENDENCY_AUDIT.md)：依赖锁定策略、暂缓升级原因和直播平台接口探测边界。
- [平台接口与兼容性](PLATFORM_COMPATIBILITY.md)：各平台分区、搜索、弹幕和人数指标的当前能力。
- [Android/Windows 性能验证](PERFORMANCE.md)：120 Hz 请求、渲染/滑动优化和实机采样方法。
- [关注页刷新与状态一致性](FAVORITE_REFRESH_DESIGN.md)：下拉手势、启动核验、并发事务和失败语义。
- [上游问题审计（2026-08-24）](ISSUE_AUDIT_2026_08_24.md)：#778、#779、#780、#782、#783、#784, #785 的根因、代码落点和验证状态。
- [上游问题审计（2026-08-25）](ISSUE_AUDIT_2026_08_25.md)：#791 录制根因，以及 #789、#786、#783、#767 的当前处理状态。
- [v3.0.0 全平台稳定版](STAGE_UPDATE_3_0_0.md)：最新上游状态绑定、录制恢复、依赖锁与全平台发布门禁。
- [v3.0.0 build 4088 全仓审查](REPOSITORY_AUDIT_3_0_0_BUILD_4088.md)：Android 返回根因、全上游/全仓流程、供应链、Windows 刷新率与 MSIX 修正。
- [v3.0.1 Android 竖屏直播适配](STAGE_UPDATE_3_0_1.md)：源方向稳定识别、普通页自适应、全屏策略、画中画比例与房间覆盖。
- [v3.0.2 Android 播放比例修复](STAGE_UPDATE_3_0_2.md)：普通横屏 16:9 边界、竖屏适配隔离、原生单层缩放与弹幕主题布局。
- [v3.0.3 Android 竖屏 Surface 修复](STAGE_UPDATE_3_0_3.md)：原生/应用层几何统一、切换时序和横屏直播记录自适应双列。
- [v3.0.4 Android 可信画面比例修复](STAGE_UPDATE_3_0_4.md)：普通页、全屏、系统画中画和应用内小窗共享单一可信比例，并增强历史记录日期与容量。
- [v3.0.5 Android 有效画面识别](STAGE_UPDATE_3_0_5.md)：双证据几何引擎、黑边内嵌竖屏裁边、普通页/横屏/小窗三种呈现。
- [v3.0.6 Android 竖屏几何仲裁修复](STAGE_UPDATE_3_0_6.md)：抖音平台分辨率证据、裁边代际隔离、延迟有界采样与渲染比例一致性门禁。
- [v3.0.7 Android 竖屏真实画布修复](STAGE_UPDATE_3_0_7.md)：截图/解码坐标隔离、原生纹理防拉伸与显式横屏全屏入口。
- [v3.0.8 Android 竖屏与小窗比例修复](STAGE_UPDATE_3_0_8.md)：抖音选中流几何、可逆居中裁边、应用小窗动态尺寸与 PiP 可视区域。
- [v3.0.11 Android 跨模式比例隔离修复](STAGE_UPDATE_3_0_11.md)：清理 3.0.10 错误草稿、共享播放器 fit 污染回滚、全屏局部视频视口与整屏控件。
- [v3.0.12 录制与全平台画质审计](RECORDING_AND_QUALITY_AUDIT_3_0_12.md)：十个平台画质显示/排序/实际请求，录制重连、分片隔离、原子合并和资源生命周期。
- [v3.0.13 十个平台录制修复](RECORDING_AUDIT_3_0_13.md)：严格房间状态、播放完整元数据、Android 首次初始化、原始 FFmpeg 参数向量和可见失败诊断。
- [v3.0.13 Android 阶段更新](STAGE_UPDATE_3_0_13.md)：版本范围、关键修复、质量门禁与正式交付要求。
- [v3.0.9 Android 竖屏原生缩放修复](STAGE_UPDATE_3_0_9.md)：抖音官方几何模型、移动端原生单层缩放、实测裁边与四种呈现统一。
- [Video Geometry Engine](VIDEO_GEOMETRY_ENGINE_2026_08_26.md)：编码画布、有效节目区域与呈现窗口的统一识别和普通直播保护设计。
- [v2.9.7 Android update](STAGE_UPDATE_2_9_7.md): cross-platform audience semantics, stable popular ranking and SOOP PC/mobile totals.
- [v2.9.6 Android update](STAGE_UPDATE_2_9_6.md): upstream synchronization, Douyin/Bilibili repairs and 40 interface probes.
- [v2.9.5 Android update](STAGE_UPDATE_2_9_5.md): Douyu playback, YY integration and 36 interface probes.
- [v2.9.4 全平台稳定版](STAGE_UPDATE_2_9_4.md)：多画面、录制数据保护、纯 Dart 平台签名/快手兼容与全平台交付。
- [v2.1.0 阶段更新](STAGE_UPDATE_2_1_0.md)：上游同步、Twitch、SOOP Live、依赖迁移、全平台构建矩阵与验收范围。
- [v2.1.5 阶段更新](STAGE_UPDATE_2_1_5.md)：本地弹幕同步、列表阅读、模板状态和 Windows 平滑滚动。
- [v2.1.6 Android 播放修复](STAGE_UPDATE_2_1_6.md)：音频/视频切换灰白画面与后台音频生命周期。
- [v2.2.0 阶段更新](STAGE_UPDATE_2_2_0.md)：播放器快速恢复、弹幕合并、Windows 多开与最终验证。
- [v2.3.0 稳定性更新](STAGE_UPDATE_2_3_0.md)：PiP 返回弹幕恢复、启动逐批刷新、横屏输入与长时间资源边界。
- [v2.7.0 阶段稳定版](STAGE_UPDATE_2_7_0.md)：最新上游整合、热门页生命周期和全平台阶段发布。
- [v2.6.0 阶段稳定版](STAGE_UPDATE_2_6_0.md)：近期 Issue、字体/SC/播放器稳定性和全平台阶段发布。
- [v2.5.0 阶段稳定版](STAGE_UPDATE_2_5_0.md)：首页有界并发、三档刷新率、Windows 视频纹理与依赖/上游审计。
- [参与贡献](../CONTRIBUTING.md)：分支、提交、测试和 Pull Request 约定。
- [版本说明](../RELEASE_NOTES.md)：当前开发版本变更。
- [安全策略](../SECURITY.md)：漏洞报告、凭据和签名材料管理。

## 功能说明

- [WebDAV 配置](WEBDAV.md)：服务地址、账号、应用密码、目录和故障排查。
- [README](../README.md)：功能概览、小窗弹幕、下载和常见问题。

## 维护原则

1. Android/Android TV 与 Windows 是主要维护目标；其他平台按社区证据记录。
2. Bug 先判定上游、维护分支、整合冲突、外部漂移或本地数据来源，再设计修复。
3. 上游同步先完成三方语义审查和处置台账，再创建 merge。
4. 命令以仓库根目录为工作目录，优先调用 `tool/` 中的包装脚本。
5. 工具链版本以 `.fvmrc`、Gradle 配置和 `pubspec.lock` 为准。
6. 外部接口和依赖状态具有时效性，发布前重新运行质量门禁。
7. 构建产物进入 `local-artifacts/`，不提交到 Git。
8. 文档中的密钥、账号、Cookie 和本地绝对路径只使用占位符。
