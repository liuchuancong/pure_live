# 3.2.0 剩余工作与当前候选（2026-09-16）

- **09-16 Issue #852 的 ColorOS 14 普通页面系统手势卡住已落地兼容策略**：[专项审计](ISSUE_852_COLOROS_SYSTEM_BACK_AUDIT_2026_09_16.md)。当前亮/暗主题原先都让 Flutter 共享元素预测返回持有手势；Flutter P2 #153577 仍记录视觉完成后输入被继续阻塞。`6fbc1685` 集中页面转场并让 Android 普通路由采用 `FadeForwards`，保留 Manifest 系统回调、commit 的标准 Navigator pop、cancel 语义和直播页自有返回仲裁。有效红灯 **3 PASS / 3 FAIL**，直接回归 **6/6 PASS**，最终四文件 **21/21 PASS**、本批一次 analyze 无问题，代码提交已推送至 `origin` 并精确核对。ColorOS 14 实机仍待复验；A1-04/A1-05/A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；未构建候选、启动 GUI 或操作设备，Astra Light 0 次。

- **09-15 Issue #865 的 WebDAV 仅恢复关注列表已在当前源码实现**：[专项审计](ISSUE_865_WEBDAV_FAVORITES_ONLY_RESTORE_AUDIT_2026_09_15.md)。旧入口只能全量覆盖；`a36ee8fa` 增加“恢复全部设置”和“仅恢复关注列表”，后者只导入 `favoriteRooms` / `favoriteAreas`，保留屏蔽项、平台选择及所有其他本机设置。版本化和旧版平铺备份均受支持，目标结构先于变更校验，目标外损坏 section 不阻断选择性导入，全量/仅关注共享单次持久化事务。320×480 / 3.0 倍文字入口与确认可达，最终六文件 **104/104 PASS**、本批一次 analyze 无问题，`origin/master` 已精确同步该提交。未构建候选、启动 GUI 或操作设备；A1-05/A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 Issue #866 的抖音多画面纯音频选源缺陷已在当前源码隔离并补齐跨层回归**：[专项审计](ISSUE_866_DOUYIN_MULTIVIEW_AUDIT_2026_09_15.md)。报告版本 3.1.3 会保留 `origin / md / ao`，而小格最低档路径取列表末项，独立历史夹具实际 **0 PASS / 1 FAIL**；`56cd4d97` 已排除 `ao` 与 `only_audio` rendition，`09a716e6` 证明严格详情解析后的最低档仍为视频 URL，并携带 User-Agent / Origin / Referer / Cookie。当前抖音解析器与多画面联合 **59/59 PASS**、本批一次 analyze 无问题。历史 K90 cycle 46 只证明普通页/录制的纯音频项隔离，不替代当前多画面、平板横屏或 Windows 卡顿复验；A3-06/A3-08/W3-03 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；本批未构建候选、启动 GUI 或操作设备，Astra Light 0 次。

- **09-15 标签编辑已增加乐观冲突与控制器所有权保护**：[专项审计](TAG_EDITOR_CONFLICT_AND_OWNERSHIP_AUDIT_2026_09_15.md)。旧编辑器提交时只按 ID 搜索当前列表，同 ID 新对象会继承旧草稿，原对象被其他状态发布更新时也会被静默覆盖；弹窗持有的旧控制器实例同样没有换代检查。`af19b610` 捕获对象身份及初始名称/说明，提交前核对当前注册控制器、精确对象和字段快照；重新排序仍可编辑，对象替换、字段更新或控制器换代则保留当前状态和草稿，显示双语 live-region 冲突提示、释放焦点并禁用确认。有效红灯 **15 PASS / 2 FAIL**，页面专项 **17/17 PASS**，最终六文件 **66/66 PASS**、最终 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签删除已统一完整本地化确认、破坏性动作与目标身份**：[专项审计](TAG_DELETE_CONFIRMATION_AND_IDENTITY_AUDIT_2026_09_15.md)。旧弹窗在 Dart 中拼接通用句首、标签名和标点，英文形成不自然句式；两个普通文字动作也没有明确的破坏性层级。确认回调又按可复用 ID 搜索当前列表，确认期间恢复/导入的同 ID 新对象会继承旧确认并被删除。`0af360f2` 将完整句移入双语资源，使用 420 px 滚动正文、48 px 取消动作和错误色填充删除动作；弹窗只返回类型化结果，页面随后核对生命周期、控制器实例和精确对象身份。同 ID 替换保留新标签与映射，原对象确认才删除并清理映射。有效红灯 **14 PASS / 1 FAIL**，页面专项 **15/15 PASS**，最终六文件 **64/64 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签首项置顶状态与整卡拖拽所有权已明确分离**：[专项审计](TAG_TOP_STATE_AND_DRAG_OWNERSHIP_AUDIT_2026_09_15.md)。旧首项仍显示并暴露“移到顶部”的可点击动作，但控制器收到索引 0 后只返回；动作图标还额外包裹核心 `ReorderableDragStartListener`，与实际持有整卡长按的 `ReorderableBuilder` 重叠。`2b039c00` 让首项显示填充图钉和双语“已位于顶部”，保留按钮角色但移除点击动作；其他项保留具名置顶，完成后连续化 `order` 并立即切换新首项状态，同时移除多余拖拽监听器。有效红灯 **13 PASS / 1 FAIL**，最终四文件 **51/51 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签管理与房间新增编辑器已统一校验反馈、可访问动作和窄屏布局**：[专项审计](TAG_EDITOR_VALIDATION_ACCESSIBILITY_AND_LAYOUT_AUDIT_2026_09_15.md)。旧两个入口对空名称/重名只发全局 Toast，错误不与名称字段关联；名称/说明清除图标没有目标名称，房间入口在 320×480、3.0 倍英文下又出现 773 px 空状态与 220 px 表单溢出。`dd6fcb6f` 以共享类型化校验统一新增/编辑，把空名称与重名放进字段内并在修改时清除；四个清除动作补齐双语名称、按钮语义、稳定 Key 与 48 px 命中，空状态/表单改为有界滚动。房间路由显式返回并派发 Future，结束后集中释放文本、滚动和焦点对象。有效红灯 **21 PASS / 2 FAIL**；窄屏布局红灯 **10 PASS / 1 FAIL**；房间专项 **11/11 PASS**，最终六文件 **62/62 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签房间映射迁移、加载与导入已统一完整性合同**：[专项审计](TAG_ROOM_MAPPING_MIGRATION_AND_IMPORT_INTEGRITY_AUDIT_2026_09_15.md)。旧迁移对平台键使用 `putIfAbsent`，已有平台分配时不会合并旧房间号中的其他标签，随后仍删除旧键；新平台又原样复制重复与孤儿 ID。启动和备份导入也直接发布空白键、重复/空标签身份及失效映射。`4d8ed292` 统一标签列表与映射规范化：trim、稳定去重、当前身份过滤、规范键碰撞合并；旧键与既有平台分配无损合并并扇出到每个匹配平台，导入在发布前修复身份，仅标签替换同步清理孤儿映射，保存/导出使用深拷贝快照。有效红灯 **23 PASS / 3 FAIL**，三个直接专项 **27/27 PASS**，最终六文件 **59/59 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签新建身份、旧数据修复与大小写改名已统一完整性合同**：[专项审计](TAG_MANAGEMENT_IDENTITY_AND_RENAME_INTEGRITY_AUDIT_2026_09_15.md)。旧新增直接使用毫秒时间戳，确定性红灯中 256 个标签只得到 21 个不同 ID；旧加载又保留碰撞，导致卡片 Key、房间映射及按 ID 编辑/删除失去唯一目标。旧改名还把当前项纳入不区分大小写的重复搜索，`Travel` → `travel` 被自身阻断。`79266c7e` 改用单调微秒分配并扫描现有集合；加载时保留旧 ID 第一项、重建空/重复身份、连续化顺序并写回，改名查重则排除当前索引。有效红灯 **7 PASS / 2 FAIL**，补入旧数据迁移后直接红灯 **7 PASS / 3 FAIL**；页面专项 **11/11 PASS**，最终六文件 **50/50 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签卡片置顶/编辑/删除已补齐目标身份与可访问动作**：[专项审计](TAG_MANAGEMENT_CARD_ACTION_ACCESSIBILITY_AUDIT_2026_09_15.md)。旧三个图标只有通用 Tooltip，多卡片列表无法从语义确认即将操作哪个标签，`InkWell` 也没有明确按钮与点击合同。`267c56ab` 用共享组件为每项建立独立 `Semantics`，以中英文“置顶/编辑/删除 + 标签名”同时作为完整 Tooltip 与可访问名称，并统一按钮角色、点击动作、48 px 高度和弹窗等待期禁用。有效红灯 **6 PASS / 1 FAIL**，页面 **7/7 PASS**，最终五文件 **22/22 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 标签管理详情入口已补齐可访问动作并统一页面路由所有权**：[专项审计](TAG_MANAGEMENT_DETAIL_ACCESSIBILITY_AND_ROUTE_AUDIT_2026_09_15.md)。旧标签名称只是文字大小的 `GestureDetector`，没有 Tooltip、可访问名称、按钮/点击语义或 48 px 命中高度；新增、详情、编辑和删除也没有共享页面门禁，快速重复输入可叠加路由，卡片高度未计入应用内可调字号。`2daabafe` 增加具名 `Semantics` 容器与 `InkWell`，统一触摸、鼠标、键盘和辅助功能激活；四类弹窗共享同步 single-flight、根 Navigator 与 `finally` 重试，并按实际样式行高计算卡片尺寸。有效红灯 **4 PASS / 2 FAIL**，页面 **6/6 PASS**，最终五文件 **21/21 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 桌面托盘右键菜单已统一事件与事务所有权**：[专项审计](DESKTOP_TRAY_CONTEXT_MENU_EVENT_AND_TRANSACTION_AUDIT_2026_09_15.md)。旧实现同时在右键按下和释放时弹出菜单，一次物理手势可形成两次请求；释放路径还会额外聚焦窗口并以无异常边界的 `.then` 再次弹出，连续右键会让刷新、聚焦与弹出交错。`cd9fed8d` 以右键按下为唯一入口、释放为空回调；新增协调器将“刷新菜单 → 弹出菜单”组成 single-flight，重复请求共享 Future，异常后释放门禁并由外围收口，所有托盘 void 回调显式派发 Future。有效红灯 **0 PASS / 1 FAIL**，新专项 **3/3 PASS**，最终七文件 **35/35 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 Windows 标题栏项目链接已补齐可访问性、打开事务与布局边界**：[专项审计](WINDOWS_TITLE_BAR_PROJECT_LINK_TRANSACTION_AUDIT_2026_09_15.md)。旧应用名区域是无名称 `InkWell`，以 `canLaunchUrl` 加默认模式 `launchUrl` 分两次调用，false/异常没有反馈，快速重复输入可并发启动浏览器；32 px 标题栏也未收束长名称、大字号与尺寸文本。`a21492bf` 抽出具名链接，用 Tooltip、Tab 焦点、Enter/Space、可见焦点与等待期禁用统一输入；项目 URI 只调用一次外部应用打开，false/异常显示既有双语反馈并恢复重试，`FittedBox.scaleDown` 让 120×32 / 64 px 长文本夹具不溢出。有效红灯 **0 PASS / 1 FAIL**，新专项 **5/5 PASS**，最终八文件 **45/45 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-15 Windows 标题栏控制按钮已补齐可访问输入与异步动作事务**：[专项审计](WINDOWS_TITLE_BAR_CONTROL_ACCESSIBILITY_AUDIT_2026_09_15.md)。旧三个系统按钮只有图标和鼠标手势，没有 Tooltip、可访问名称、键盘焦点或焦点指示；同步 `VoidCallback` 也不持有原生 Future，快速重复输入可并发派发动作，异常没有界面反馈。`0e654db8` 增加双语语义与 Tooltip，以 Material `InkWell` 提供 Tab 焦点、Enter/Space 激活和可见焦点边框，并在 `_runAction` 内等待单次动作、等待期禁用、收口异常、显示本地化 SnackBar 后恢复重试。有效红灯 **0 PASS / 1 FAIL**，新专项 **5/5 PASS**，最终十文件 **62/62 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W1-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-14 Windows 普通窗口与 PiP 已统一几何捕获所有权**：[专项审计](WINDOWS_WINDOW_GEOMETRY_CAPTURE_OWNERSHIP_AUDIT_2026_09_14.md)。旧桌面事件在队列外按旧模式分流，普通分支直接异步读取并保存尺寸；读数期间进入/退出 PiP 会污染下次启动大小，最小化、最大化和真全屏尺寸也未隔离，被动 Future 异常另会泄漏。`30c2e4cf` 将 Windows 普通尺寸与 PiP 矩形统一串入宿主队列，执行时按最终模式提交；普通尺寸在读取前后两次核对三种非普通呈现，失败后的队列可重试，桌面事件统一记录异常，非 Windows 路径保持。有效红灯 **7 PASS / 1 FAIL**，宿主专项 **13/13 PASS**，最终十文件 **121/121 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W1-01/W2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-14 Windows 小窗呈现层已建立跨宿主事务与失败回滚**：[专项审计](WINDOWS_PIP_PRESENTATION_TRANSACTION_AUDIT_2026_09_14.md)。旧 `WindowService` 在退出全屏后若宿主进入异常不会恢复呈现，重试会覆盖原始快照；退出又在全屏/宽屏恢复前先清快照，恢复异常会让原生宿主、播放器和全局 PiP 状态分离。`b08a33f3` 增加呈现 seam、进出 single-flight 和原始快照所有权：进入失败恢复原呈现；退出呈现失败则恢复 PiP 呈现并重新进入宿主，宿主回滚也异常时以类型化结果让 `PlayerManager` 采用真实的普通窗口状态；全局 PiP 状态保留唯一发布者。有效红灯 **2 PASS / 3 FAIL**，最终七文件 **97/97 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-14 Windows 小窗宿主已建立原生窗口事务与失败回滚**：[专项审计](WINDOWS_PIP_HOST_TRANSACTION_AND_ROLLBACK_AUDIT_2026_09_14.md)。旧 `WindowHelper` 在宿主调用前先改逻辑模式，进出任一步失败都会留下错误模式和部分窗口状态；重复直接调用可并发写窗口，进入未完成时还能保存混合几何，退出又把应用最小尺寸从统一的 400×300 扩大为 800×600。`57ea9a85` 将进出、置顶更新和几何捕获串入同一宿主队列，只在完整成功后提交模式；失败逐项恢复进入前窗口并允许重试，重复进出共享 Future，退出恢复统一最小尺寸。有效红灯 **0 PASS / 5 FAIL**，加强专项 **7/7 PASS**，最终六文件 **80/80 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-14 Windows 小窗进出已建立宿主事务与生命周期所有权**：[专项审计](WINDOWS_PIP_TRANSITION_OWNERSHIP_AUDIT_2026_09_14.md)。旧控制栏以未等待回调进入小窗，Windows 进出没有转换门禁；重复点击会并发调用宿主，原生失败没有反馈，关闭期间迟到完成的进入及已激活小窗关闭/销毁也不会可靠恢复主窗口。`c069dcf2` 以修订号、会话 ID 和播放器身份串行进出，只在宿主成功且仍持有事务时提交状态；等待期间禁用入口，失败保留旧状态并允许重试，关闭/销毁补齐主窗口恢复及关闭后重入栅栏。两轮有效红灯为 **42 PASS / 1 FAIL、43 PASS / 1 FAIL**，播放器专项 **46/46 PASS**，最终六文件 **81/81 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR**、仍有 42 组未闭环；Astra Light 0 次。

- **09-14 Windows 小窗置顶开关已建立原生窗口事务**：[专项审计](WINDOWS_PIP_ALWAYS_ON_TOP_TRANSACTION_AUDIT_2026_09_14.md)。旧共享开关会在原生窗口操作前立即写偏好，同一旧回调可并发派发多次请求，异常后当前层级、显示值和持久值可能分离。`0c38ec34` 改为页面 single-flight，原生成功后才提交；等待期间禁用，失败保持旧值、尽力恢复旧层级、显示双语长文本并允许重试。有效红灯 **13 PASS / 1 FAIL**，最终五文件 **38/38 PASS**、最后一次 analyze 无问题。未构建候选或启动 GUI；A2-01/W2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 视频设置后台播放开关已建立权限/保活事务**：[专项审计](VIDEO_SETTINGS_BACKGROUND_PLAYBACK_TRANSACTION_AUDIT_2026_09_14.md)。旧共享开关会在权限/服务结果前立即写偏好，等待期间可重复触发，服务异常保留新值且没有反馈。`cbac24f4` 改为页面 single-flight，按尚未持久化的目标值同步保活，兼容助眠/纯音频会话，并在权限和服务成功后才提交；失败保留旧值、显示双语长文本并允许重试。有效红灯 **12 PASS / 1 FAIL**，最终六文件 **30/30 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 视频设置 ASMR 模式开关已建立权限/服务事务**：[专项审计](VIDEO_SETTINGS_ASMR_MODE_TRANSACTION_AUDIT_2026_09_14.md)。共享开关旧实现会在业务回调前立即写 `RxBool` 且始终可点，ASMR 开启会先显示开启再等待权限，关闭也会先落盘再等待定时服务；重复触发可并发工作，异常没有反馈。`d842cb05` 增加默认兼容的禁用/延迟提交合同，并由页面 single-flight、当前路由/控制器栅栏只在权限或服务成功后提交；失败保留旧值、显示双语长文本并允许重试。有效红灯 **10 PASS / 1 FAIL**，最终五文件 **28/28 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 视频设置 ASMR 定时已建立路由与异步保存事务**：[专项审计](VIDEO_SETTINGS_ASMR_TIMER_TRANSACTION_AUDIT_2026_09_14.md)。旧入口连续触发会叠加弹窗，保存又先写偏好再等待定时服务，失败时留下已变更值且没有可重试反馈。`1ac4919b` 以页面 single-flight、当前路由/生命周期栅栏和根 Navigator 持有弹窗；非法输入改为行内错误，服务等待期间输入、预设、取消、保存和系统返回均停止重复工作，成功后才持久化，失败保留旧值与草稿并允许重试。有效红灯 **8 PASS / 1 FAIL**，最终四文件 **23/23 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 视频设置清晰度双入口已建立页面路由事务**：[专项审计](VIDEO_SETTINGS_RESOLUTION_ROUTE_TRANSACTION_AUDIT_2026_09_14.md)。旧 Wi-Fi/移动网络入口通过全局 `Get.context` 各自创建弹窗，连续触发会叠加两条路由；页面销毁后旧回调抛错，被新页面覆盖后又会把弹窗盖到当前路由。`89bfb10c` 改由页面共享 single-flight，以页面/当前路由/控制器栅栏和 `showDialog<String>` 延迟提交精确目标；滚动内容、16/20 边距、420 px 上限和 48×48 取消动作覆盖 320×480 / 3.0 倍文字。主红灯 **5 PASS / 2 FAIL**，当前路由红灯 **7 PASS / 1 FAIL**，最终两文件 **23/23 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 Windows 小窗捕获与重置已统一几何事务**：[专项审计](WINDOWS_PIP_GEOMETRY_CAPTURE_AND_RESET_AUDIT_2026_09_14.md)。旧运行时捕获/导出把 `displayId` 写在归一化器不读取的层级，尺寸和坐标保留但显示器身份稳定丢失；旧重置回调连续触发还会创建两个弹窗，在 320×480 / 3.0 倍英文下各溢出 704 px。`b13d8dea` 统一规范嵌套快照，并以页面单次门禁、根 Navigator、滚动正文、48×48 红色“重置”动作和生命周期栅栏完成五字段清空。四轮有效红灯分别为 **4 PASS / 1 FAIL、4 PASS / 1 FAIL、4 PASS / 1 FAIL、9 PASS / 1 FAIL**；最终五文件 **31/31 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；W1-01/W2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 精细字号恢复默认已建立响应式单次事务**：[专项审计](FONT_SETTINGS_RESET_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧弹窗已具备五项字号说明和滚动正文，但同一 AppBar 回调连续触发会稳定叠加两个确认路由，动作也没有显式 48×48 与溢出合同。`2f7df9ef` 让页面在路由前同步持有恢复事务，取消、遮罩、系统返回、确认或页面销毁后统一释放；入口在事务期间置灰，并在提交前核对页面及控制器生命周期。根 Navigator、16/20 边距、420 px 正文和红色 Filled 动作覆盖 320×480 / 3.0 倍文字。有效红灯 **6 PASS / 1 FAIL**，最终页面 **7/7 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 观看记录单项删除已建立可访问确认与精确事务**：[专项审计](HISTORY_ENTRY_DELETE_ACCESSIBILITY_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧卡片使用 28×28 裸 `GestureDetector`，没有 Tooltip、键盘按钮语义和取消机会，点击即按房间身份删除。`a85becfc` 保留小圆形视觉并把入口扩为具名 48×48 `IconButton`；页面以完整直播间标题显示响应式危险确认，与清空共用单次历史变更门禁，并按对象身份只删除确认时捕获的实例。确认期间重新观看同一房间的新对象仍保留。有效红灯 **24 PASS / 3 FAIL**，最终四测试文件 **46/46 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A1-05/A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 观看记录清空已建立具名确认与身份快照事务**：[专项审计](HISTORY_CLEAR_CONFIRMATION_AND_SNAPSHOT_AUDIT_2026_09_14.md)。旧页面使用通用确认和普通文本动作，连续触发会叠加弹窗；弹窗出现后新增、重新观看或由刷新/恢复替换的记录也会被最终 `clearHistory()` 一并删除。`db3ef116` 在打开路由前捕获对象快照并持有页面门禁，以 `Set.identity()` 只移除确认时拥有的实例；同房间后续观看仍保留。弹窗补齐双语数量、滚动正文、16/20 边距、420 px 正文与 48×48 红色 Filled 动作。旧实现专项门禁退出失败，最终三文件 **34/34 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A1-05/A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 本地缓存清理已建立响应式确认与单次事务**：[专项审计](CACHE_CLEAR_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧页面在确认阶段没有忙碌门禁，连续触发会叠加两个弹窗；清理动作也缺少明确的破坏性层级和 48×48 命中合同。`6bcbcb8b` 从确认前到 `clearCache()` 完成持有页面事务，与底层清理合并形成两层门禁，并补齐根 Navigator、滚动正文、16/20 边距、420 px 正文和红色 Filled 动作。有效红灯 **1 PASS / 2 FAIL**，最终两文件 **10/10 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 账号退出已建立具名确认与单次事务**：[专项审计](ACCOUNT_LOGOUT_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧确认没有目标平台，同一账号行连续触发会叠加两个弹窗，Bilibili 页面侧事务也没有覆盖浏览器 Cookie 清理。`86939e0d` 让七个平台共用具名的响应式退出确认，并由账号控制器从弹窗到清理完成持有单次任务；320×480 / 3.0 倍中英文下平台名、取消和退出均可达。有效红灯 **4 PASS / 2 FAIL**，最终三文件 **16/16 PASS**、最后一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 版本历史下载已建立具名确认与单次事务**：[专项审计](VERSION_HISTORY_DOWNLOAD_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧确认没有目标文件名；同一下载动作连续触发会叠加两个弹窗，下载回调执行期间也缺少重复工作门禁。`cdc18971` 以规范 URI、捕获文件身份和页面级忙碌状态串行确认与平台下载，文件名缺失时回退 URL 路径或本地化占位；滚动弹窗、16/20 边距、420 px 正文和 48×48 动作覆盖 320×480 / 3.0 倍文字。有效红灯 **3 PASS / 2 FAIL**，最终四文件 **19/19 PASS**、本批唯一一次 analyze 无问题。未启动真实下载、构建候选、GUI 或设备；A1-05/A2-01/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 WebView2 缺失提示已补齐响应式布局与单次事务**：[专项审计](WEBVIEW2_MISSING_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧水平标题在 320×480 / 3.0 倍文字下中文向右溢出 240 px、英文溢出 1536 px，动作仍是通用确认；启动探测与搜索动作连续触发还会叠加两个弹窗。`5eea37ec` 以同步门禁、类型化弹窗结果和控制器退出栅栏串行路由与外部启动，使用可滚动弹窗、可换行标题、48×48 动作及明确的双语“打开下载页”，下载目标改为微软官方语言中立入口。有效红灯 **0 PASS / 3 FAIL**，最终六文件 **101/101 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A1-04/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 录制中心取消监控已建立具名确认与单次事务**：[专项审计](RECORDER_MONITOR_REMOVAL_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧通用确认没有目标任务和文件保留说明，在 320×480 / 3.0 倍英文下向下溢出 320 px，平台标签另向右溢出 61 px；同一按钮回调连续触发会叠加两个路由。`b85217f4` 以任务捕获、页面 Navigator、同步忙碌门禁和等待式 `unRecorder` 建立单次事务，确认正文显示完整标题并明确保留既有文件，滚动弹窗与可换行标签覆盖大字号。有效红灯 **38 PASS / 4 FAIL**，最终两文件 **43/43 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；AND-REC-06/A6-02/W3-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 关注分区取消关注弹窗已补齐窄屏布局与单次路由**：[专项审计](FAVORITE_AREA_UNFOLLOW_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧确认弹窗在 320×480 / 3.0 倍英文长名称下稳定向下溢出 128 px；同一点击回调连续触发两次还会叠加两个确认路由。`ff57bcbd` 以同步忙碌门禁、捕获目标身份、页面 Navigator 和弹窗自身 context 建立单次事务，并使用统一滚动面、16/20 边距及至少 48×48 的动作尺寸。有效红灯 **4 PASS / 2 FAIL**，最终三文件 **24/24 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；A1-03 保留 PASS、W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 观看记录保留数量弹窗已补齐窄屏布局与输入校验**：[专项审计](HISTORY_RETENTION_DIALOG_LAYOUT_AND_VALIDATION_AUDIT_2026_09_14.md)。旧弹窗在 320×480 / 3.0 倍英文文字下稳定向下溢出 260 px，“Apply”命中点落在窗口外；空白、非数字或负数还会静默返回。`0272de8a` 统一标题/正文滚动边界、纵向全宽 48 px 应用动作和可换行底部动作，并以弹窗 State 提供双语行内错误、继续编辑清错、键盘完成与点击共用校验。有效红灯 **19 PASS / 2 FAIL**，最终三文件 **30/30 PASS**、本批唯一一次 analyze 无问题。未构建候选、启动 GUI 或操作设备；AND-HISTORY-01/A1-05/W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 Windows 视频输出尺寸已纳入实际显示模式**：[专项审计](WINDOWS_VIDEO_OUTPUT_FIT_SIZING_AUDIT_2026_09_14.md)。旧 viewport / DPR 策略始终按 `contain` 的最小轴分配原生纹理；1920×1080 源在 500×500 视口选择 `cover` / `fitHeight` 时仍只分配 500×282，再由 Flutter 放大到约 889×500。`7715e0fa` 将有效 `BoxFit` 传到尺寸策略和尺寸器，按主导轴分配、保持源宽高比与源尺寸上限，并在显示模式变化时重新发布 `setSize`。有效红灯为缺少 `fit` 合同，最终四文件 **26/26 PASS**、本批唯一一次 analyze 无问题；Windows x64 Debug 构建成功，ZIP 为 142,778,353 B / `8B823AC8…5B43`。未启动 GUI、采集 GPU 或操作设备；W3-03/#767 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 Windows 副屏亮度的原生所有权已从构建边界移除**：[专项审计](WINDOWS_SECONDARY_MONITOR_BRIGHTNESS_OWNERSHIP_AUDIT_2026_09_14.md)。Issue #863 的 `screen_brightness_windows` 在没有 Dart 调用时仍会监听窗口大小/激活/关闭消息，并通过 DDC/CI 把捕获值写到当前物理显示器；旧 `6cf42712` 的 CMake 变量没有消费者。`a0bbe074` 改为平台接口与 Android/iOS 直接实现，Windows/macOS 注册器、锁文件和新 ZIP 均移除桌面亮度插件，移动端 MethodChannel 保持。有效红灯 **1/4 PASS**，最终 13 文件 **245/245 PASS**、本批唯一一次 analyze 无问题；Windows x64 Debug 构建成功，日志/安装清单/1,301 项 ZIP 均 0 命中，EXE 依赖表也不含亮度 DLL。未启动 GUI、写显示器亮度或操作设备；W1-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 房间卡片设置已按当前架构恢复并兼容 3.1.2 持久值**：[专项审计](ROOM_CARD_SETTINGS_REGRESSION_AND_RESTORATION_AUDIT_2026_09_14.md)。本地标签对照确认 `upstream-v3.1.2` 到 `upstream-v3.1.3` 删除了设置目录九个文件、共 6,736 行，主题入口随之消失，与 Issue #864 的稳定版现象一致。`230ad13d` 恢复移动/桌面独立配置、简洁/标准/详细预设、真实卡片预览、可见字段和 0～32 圆角，兼容旧四键与字段名并纳入 V2/V3/旧版备份。14 个受影响测试文件 **154/154 PASS**，最后一次 Dart 编辑后的最终 analyze 无问题；未构建候选或操作设备。A1-02/A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 WebDAV 本机设置恢复已建立具名确认与目录事务合同**：[专项审计](WEBDAV_RESTORE_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md)。旧“同步到本地”会立即读取远端文件并覆盖本机全部设置，也只在读取后核对服务身份。`79d8965f` 在任何远端读取或本地变更前显示完整文件名和覆盖说明，共用响应式页面弹窗，并在确认后、读取后和恢复后核对服务代次与目录路径。有效红灯 **0/1 PASS**，页面 **27/27 PASS**、目录状态 **44/44 PASS**、最终七文件 **90/90 PASS**，一次全库 analyze 无问题；未连接真实服务器、构建候选或操作设备。A1-05 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 WebDAV 文件行已建立长名称动作可达与具名删除合同**：[专项审计](WEBDAV_FILE_ROW_AND_DELETE_DIALOG_AUDIT_2026_09_14.md)。旧标题没有行数边界，320×480、3.0 倍文字和五段重复名称会把动作菜单中心推到纵坐标 1844 px；删除确认也只显示通用正文，并由控制器创建全局弹窗。`0684adb8` 将名称限制两行并保留完整 Tooltip、时间限制一行，以路径末段补齐空白名称；页面所有的响应式危险弹窗明确显示目标名，控制器只管理单次删除事务。有效红灯 **0/1 PASS**，页面 **26/26 PASS**、最终七文件 **85/85 PASS**，一次全库 analyze 无问题；未连接真实服务器、构建候选或操作设备。A1-05 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 WebDAV 深层面包屑已建立当前段可见与父级路由合同**：[专项审计](WEBDAV_BREADCRUMB_VISIBILITY_AND_ROUTE_AUDIT_2026_09_14.md)。旧空滚动触发器使 320×480、3.0 倍文字和八段长路径下的当前末段完全离开视口，根目录父级动作还由控制器弹出全局路由。`88c309be` 以路径快照、下一帧动画、代次栅栏和稳定范围校准保持末段可见，单段限制 240 px 并保留完整 Tooltip；根目录返回 `false`，非根目录返回 `true` 并读取父级。有效红灯 **0/1 PASS**，直接两文件 **65/65 PASS**、最终七文件 **84/84 PASS**，一次全库 analyze 无问题；未连接真实服务器、构建候选或操作设备。A1-05 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 WebDAV 配置表单已建立窄屏大字号滚动与动作合同**：[专项审计](WEBDAV_CONFIG_FORM_RESPONSIVE_AUDIT_2026_09_14.md)。旧编辑弹窗把完整长名称留在不滚动标题区，320×480、3.0 倍文字和四段重复名称稳定产生 3884 px 底部溢出。`998a635a` 让标题与四字段共享 `AlertDialog` 单一纵向滚动面，限制三行标题并保留完整 Tooltip，设置 16/20 边距、400 宽正文、动作向下溢出及 48×48 命中尺寸。有效红灯 **0/1 PASS**，修订后专项 **1/1 PASS**、直接两文件 **63/63 PASS**、最终七文件 **82/82 PASS**，一次全库 analyze 无问题；未连接真实服务器、构建候选或操作设备。A1-05 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-14 WebDAV 配置抽屉已建立长名称动作可达与精确路由合同**：[专项审计](WEBDAV_CONFIG_DRAWER_ROUTE_AND_LAYOUT_AUDIT_2026_09_14.md)。旧配置名称可无限增高，320×480、3.0 倍文字下四段重复长名称即可让删除动作失去可命中位置；选择/删除控制器还依赖全局 context 关闭路由。`1f327e0c` 将名称限制为两行省略并保留完整 Tooltip，补齐编辑/删除提示，以页面 context 创建配置和删除弹窗；控制器只提交状态，页面精确关闭抽屉或弹窗。直接两文件 **62/62 PASS**，最终七文件 **81/81 PASS**、一次全库 analyze 无问题；未连接真实服务器、构建候选或操作设备。A1-05 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 桌面退出弹窗与原生动作已建立可等待回滚事务**：[专项审计](DESKTOP_EXIT_DIALOG_AND_ACTION_TRANSACTION_AUDIT_2026_09_13.md)。旧空默认动作、冗长动作标签、先写偏好后异步执行和多关闭请求叠加缺少统一合同，320×480、3.0 倍英文文字稳定向下溢出 224 px。`9f463efb` 统一动作/备份归一化、single-flight 类型化路由、滚动弹窗与 48×48 动作，并在原生失败时恢复偏好、关闭拦截和原窗口可见状态。新专项 6/6，最终七文件 **40/40 PASS**、一次全库 analyze 无问题；未构建或操作设备。A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 共享选项弹窗已建立窄屏换行、整行命中与所属路由合同**：[专项审计](SHARED_OPTION_DIALOG_LAYOUT_AND_SELECTION_AUDIT_2026_09_13.md)。旧自然宽度行在 320×480、3.0 倍文字下逐项向右溢出 2362/2411 px 并向下溢出 80 px，1.0 倍英文项仍溢出 55 px。有效红灯 **0/2 PASS** 后，`74ba4778` 以滚动 `AlertDialog`、420 宽正文、可收缩换行文字、48 高整行选择和所属 context 统一选择语义；系统返回继续产生 `null`。最终五文件 **14/14 PASS**、一次全库 analyze 无问题；未构建或操作设备。A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 共享确认与消息弹窗已建立长内容、动作可达与所属路由合同**：[专项审计](SHARED_ALERT_DIALOG_LAYOUT_AND_ROUTE_AUDIT_2026_09_13.md)。旧确认/消息入口在 320×480、3.0 倍文字下分别产生 320 px 与 140 px 底部溢出，内置动作依赖全局 context；有效红灯为 **0/2 PASS**。`1edf8a67` 统一可滚动 `AlertDialog`、420 宽正文上限、16/20 边距、纵向动作溢出与 48×48 命中尺寸，并由所属路由返回。最终五文件 **45/45 PASS**、一次全库 analyze 无问题；未构建或操作设备。A2-01 保持 RUN，宏观仍为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 共享文本编辑弹窗已统一路由生命周期与响应式布局**：[专项审计](SHARED_EDIT_DIALOG_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_13.md)。旧静态方法在 `Get.dialog` 返回时立即释放输入控制器，但退出动画子树仍会继续访问它；固定编辑区也缺少窄屏大字号边界。有效红灯 **0/2 PASS** 后，`85ca7a73` 让弹窗子树持有控制器和路由 context，以有界滚动内容、纵向大字号动作和常规桌面紧凑布局覆盖两种形态。最终三文件 **14/14 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 更新与版本历史 Web 目标已统一归一化合同**：[专项审计](UPDATE_AND_RELEASE_WEB_TARGET_AUDIT_2026_09_13.md)。旧更新入口与版本历史各自维护不完整规则，会接受用户信息和越界端口；版本历史还会把通过修剪值校验的原始字符串交给剪贴板或下载器。有效红灯 **13 PASS / 3 FAIL** 后，`ce051c03` 统一共享结构化 HTTP(S) 解析、拒绝非空 userInfo，并让动作消费同一个规范 URI。直接 **16/16 PASS**，最终九文件 **47/47 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A1-05/A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 下载文件名已统一 UTF-8 字节边界并隔离长名称碰撞**：[专项审计](DOWNLOAD_FILENAME_UTF8_AND_COLLISION_AUDIT_2026_09_13.md)。旧逻辑按 160 UTF-16 code unit 截断，中文名称追加 `.part`/`.previous` 后可越过常见单目录项字节限制，emoji 还可能被切开；两个仅在末尾不同的长资产会得到同一目标名。稳定红灯 **8 PASS / 2 FAIL** 后，`83f38ecc` 使用 240 UTF-8 字节 basename 预算、完整 Unicode scalar 截断、最多 32 字节扩展名和 12 位 SHA-256 摘要，既有原子暂存/回滚流程继续复用结果。直接 **10/10 PASS**，最终八文件 **39/39 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A1-05/A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 HTTP(S) 目标识别与 IPTV 网络导入已统一完整 URI 合同**：[专项审计](HTTP_TARGET_VALIDATION_AND_IPTV_IMPORT_AUDIT_2026_09_13.md)。旧未锚定正则会拒绝 localhost、IPv6、长顶级域名和大写 scheme，同时把输入前后缀或本地路径里的 URL 片段判为有效；外部打开还会在分类后重新解析原始文本。稳定行为红灯 **0/3 PASS** 后，`e46ffbc4` 统一完整 HTTP/HTTPS URI、非空 host、1～65535 显式端口和内部无空白规则，校验与启动直接共享已验证 URI；IPTV 页面回归证明长顶级域名只提交一次，嵌入文本显示本地化错误且不创建请求。直接 **3/3 PASS**、页面集成 **45/45 PASS**，最终十文件 **128/128 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A1-05/A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 浏览器日志页已统一严格路由、安全响应和窄屏动作布局**：[专项审计](LOG_BROWSER_HTTP_AND_RESPONSIVE_UI_AUDIT_2026_09_13.md)。旧服务允许 GET 直接清空日志，任意路径返回诊断页；页面缺少禁缓存/嵌入等响应策略，标题和四个按钮在窄屏保持单行，清空没有确认，复制失败没有可访问反馈。`56c6b9f8` 仅允许 `GET /` 读取和带动作头的 `POST /clear` 提交清空，以 403/404/405 返回其他请求；统一安全响应头，并增加换行顶栏、移动端 44 px 动作、空状态、非内联事件和 `aria-live` 状态。实际回环 HTTP **15/15 PASS**，最终九文件 **37/37 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 本地日志已统一为可验证、可回滚的运行期事务**：[专项审计](LOCAL_LOGGING_TRANSACTION_AND_ENDPOINT_AUDIT_2026_09_13.md)。旧端点会持久化到下一进程，日志开关又以直接 Rx 写入和未等待观察器启停资源，快速相反操作可让旧启用迟到；HTTP 页面绑定全部 IPv4 地址并用“探测后重绑”选端口，设置注册前日志和 Release 浏览器缓冲也存在缺口。`bfe935bc` 统一 latest-target 单飞、按调用目标返回结果、成功后提交与失败回滚，端点只保留在当前运行期，HTTP 服务使用回环地址和系统原子端口；设置页增加双语忙碌/失败状态，早期日志与显式 Release 会话使用有界缓冲。最终八文件 **32/32 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 Windows 开机启动已统一为可验证、可回滚事务**：[专项审计](WINDOWS_STARTUP_TRANSACTION_AND_REGISTRY_COMMAND_AUDIT_2026_09_13.md)。旧设置页在注册表成功前直接改变 Hive/Rx，失败只写日志；启动检查只看 Run 值存在，便携目录移动后的旧命令也会被当成已启用。有效红灯后，`f24b8f11` 统一启动协调、用户点击和备份式响应写入，按实际状态读取、必要写入、回读验证后再提交；失败回滚并显示双语反馈，事务中禁用开关。Run 值使用动态 UTF-16 读取、类型检查和完整 FFI 清理，命令按当前可执行文件目标判断。最终八文件 **41/41 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 真实在线人数平台偏好已统一安全消费和持久化合同**：[专项审计](AUDIENCE_PLATFORM_PREFERENCE_PERSISTENCE_AUDIT_2026_09_13.md)。旧启动修复只比较归一化前后长度，`DOUYIN`、首尾空白等同长度值会留在 Hive，设置开关、房间卡片和列表则按规范小写键查询，产生启用状态与实际口径分裂。稳定红灯 **0/3 PASS** 后，`0744c7b3` 统一小写/去空白/去重/能力过滤，在首个消费者前修复 Hive，并覆盖运行时写入、当前/旧版备份共享解析、配置提取、导出和开关动作。首轮 **14/14 PASS**，最终十二文件 **87/87 PASS**、全库 analyze 无问题。未构建或操作设备；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 播放器显示模式与首选画质已统一安全消费和持久化合同**：[专项审计](PLAYER_DISPLAY_PREFERENCE_PERSISTENCE_AUDIT_2026_09_13.md)。显示模式底层虽已有最终钳制，但控制栏仍以原始索引读取说明；Wi-Fi/移动画质也会让已移除键进入设置页、单选框和 `indexOf == -1` 的自动选画质路径。有效红灯后，`9cf8d55e` 统一六种显示模式和五个稳定画质键，在首个消费者前修复 Hive，并覆盖运行时直接写入、当前/旧版备份共享解析、配置提取、导出、设置页和控制栏；重复显示模式列表同步移除。控制器 **15/15 PASS**、控制器与 Widget **19/19 PASS**，最终十文件全部通过、全库 analyze 无问题。未构建或操作设备；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 Windows 启动窗口尺寸、PiP 几何和设置事务已统一边界**：[专项审计](WINDOW_SIZE_PERSISTENCE_AND_DIALOG_TRANSACTION_AUDIT_2026_09_13.md)。持久宽高原先可把零、负数、非有限值或极端值带入桌面首帧和设置页，PiP 又把无穷宽高当成有效矩形；设置弹窗仅判断正数，先持久化再调用原生窗口，还在路由反向动画期间提前释放输入控制器。有效红灯和生命周期诊断后，`5710da2c` 建立默认 1280×720、最小 400×300、单边最大 16384 的共享合同，统一启动/运行时/备份/导出修复，清空损坏 PiP，并补齐仅数字输入、内联反馈、应用门禁和路由子树所有权。首轮 **27/27 PASS**，最终十三文件 **98/98 PASS**、全库 analyze 无问题。未构建或执行原生 Windows/设备操作；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 主题设置持久化、备份与首帧消费已统一安全合同**：[专项审计](THEME_SETTINGS_PERSISTENCE_AND_FIRST_FRAME_AUDIT_2026_09_13.md)。主题模式和语言原先通过非空断言读取，主题/加载颜色直接进入十六进制解析，Hive、备份和运行时写入还可保留已移除样式、异常颜色及负数/无穷/超大间距。有效红灯后，`6ebd3686` 建立支持项、RGB/ARGB 和 0～64 有限间距合同，在观察器前修复持久值，并统一当前/旧版备份、导出和全部首帧/UI 消费者。首轮 **4/4 PASS**，最终十四文件 **189/189 PASS**、全库 analyze 无问题。未构建或操作设备；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 单页数量设置已统一边界并修复管理弹窗退出竞态**：[专项审计](PAGE_SIZE_SETTINGS_BOUNDARY_AND_LIFECYCLE_AUDIT_2026_09_13.md)。持久化、备份和公开写入原先可保留零/负/重复/超上限或空候选，空列表还会流向 `options.first`；默认值可能脱离候选，保存会原地排序调用方列表，界面则静默忽略异常输入。有效红灯后，确认路径又稳定捕获输入控制器在路由反向动画结束前释放。`68a2a9cd` 建立 1～100 的唯一有序合同与自适应回落，在观察器前修复 Hive，并统一当前/旧版备份、导出、默认值、双语反馈和路由子树所有权。首轮 **11/11 PASS**，最终十一文件 **109/109 PASS**、全库 analyze 无问题。未构建或操作设备；A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 应用代理与播放器代理持久化/备份端点已统一合同**：[专项审计](PROXY_ENDPOINT_PERSISTENCE_AUDIT_2026_09_13.md)。界面已有端口输入保护，但 Hive、当前/旧版备份和导出仍可保留异常端口，畸形主机还会被宽松转为文本，解析默认值也在 7897/1080 之间分裂。有效红灯锁定共享合同缺口；`abc0d714` 统一严格主机类型、1～65535 端口与 7897 回落值，在观察器前修复持久端点，并让导出再次归一化。首轮五文件 **29/29 PASS**，最终十文件 **58/58 PASS**、全库 analyze 无问题。未执行生产网络探针、构建或设备操作；A2-01/A2-05 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 应用退出与 IPTV 自动同步计时设置已统一边界**：[专项审计](DEFERRED_TIMER_SETTINGS_AUDIT_2026_09_13.md)。源码原先允许持久化、备份和公开写入绕过退出分钟数/IPTV 同步小时数边界，一次退出计时动作还会被两个 500 ms 观察器再次重置。有效红灯锁定缺少归一化合同，并实证界面将 `525601` 从原值 15 直接提交；`d68db3d7` 统一 1～525600 分钟与 2～72 小时合同、启动修复、备份/导出和最终调度入口，同一显式动作现在只重启一次。首轮四文件 **25/25 PASS**，最终九文件 **79/79 PASS**、全库 analyze 无问题。未构建或操作设备；A1-05/A2-01 保持 RUN，宏观保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 DNS、HTTP 5xx 与播放端网络故障已进入类型化有界恢复**：[专项审计](NETWORK_FAILURE_RECOVERY_AUDIT_2026_09_13.md)。原分类器漏掉 Android/curl/POSIX/Windows 常见主机解析语法与 HTTP 5xx，且通用 input-open 文本会先于具体传输原因匹配。两轮有效红灯均为 **11 PASS / 2 FAIL**；`44b63210` 补齐跨平台标记、严格 5xx 模式和具体错误优先级，直接 **13/13 PASS**，最终分类器、播放器恢复、MediaKit/Fijk 缓冲、弹幕、录制与失败界面八文件 **186/186 PASS**，全库 analyze 无问题。未执行直播站点生产探针、构建或操作设备。A7-01 由 NR→RUN；宏观更新为 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 Windows PowerShell 5.1 质量/原生工具链已恢复跨代兼容**：[专项审计](POWERSHELL_5_TOOLCHAIN_COMPATIBILITY_AUDIT_2026_09_13.md)。有效红灯先后锁定无 BOM UTF-8 中文 UI 语义的 ANSI 误解码，以及 PowerShell 6+ 专用 `ConvertFrom-Json -AsHashtable`。`fd015458` 为全部 25 个含非 ASCII 的受跟踪 `.ps1` 保留 UTF-8 BOM，代理 journal 改用两代 PowerShell 共通的显式字典构造，构建策略新增全脚本防回归扫描。录制导航与 38 个代理事务场景均在两代 PowerShell 通过，Windows PowerShell 5.1 端到端 focused CI 和 Flutter 存储策略 **15/15 PASS**，真实 ADB 命令 0。本批未构建、操作设备或改变账本；宏观仍为 **20 PASS / 41 RUN / 1 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 录制目录、存储耗尽与自动恢复权限链已完成源码修订和确定性回归**：[专项审计](RECORDER_STORAGE_FAILURE_AUDIT_2026_09_13.md)。`723b4452` 将目录选择改为候选实际写入成功后再持久化，使用每次检查原子唯一的目录内探针，隔离启动初始化竞态并合并重复点击；开机自动恢复只静默探测权限，显式开始保留交互请求。FFmpeg 新增非重试型 `storageFull` 双语诊断，兼容续接路径也会阻断空间耗尽和本地输出写失败。初轮七文件 **79/79 PASS**；`f07d1861` 修复活动输出未计入缓存额度导致旧文件不回收，活动文件只计量、不进入删除候选，四文件 **71/71 PASS**；`afdcff04` 又让开启限制和调低已开启额度立即执行回收、刷新大小，并合并执行中的连续修改，有效红灯 **12 PASS / 3 FAIL** 后直接回归 **15/15 PASS**，最终四文件 **61/61 PASS**。三轮全库 analyze 均无问题；未构建、安装或操作设备。A7-02 由 NR→RUN；宏观更新为 **20 PASS / 41 RUN / 1 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 Android 外部分享接收已完成冷/热口令、混合附件、多附件、Provider 边界和真实外部发送方原生闭环**：[专项审计](ANDROID_INCOMING_SHARE_INTAKE_AUDIT_2026_09_13.md)。`269caa91`～`8f43f21b` 接通分享链并保证所有插件附件逐项释放；`98f5472a` 隔离单 URI 异常，并按 UTF-8 字节与完整 code point 清洗/截断显示名。此前联合回归 110/110、最终路径 15/15 和全库 analyze 已通过；本增量直接 11/11、Built-in Kotlin 审计、精确 Kotlin/Manifest 构建与原生门禁通过。288823157 B / `55F94C97…F2B3` arm64 Debug 已保留数据覆盖 K90；类型/查询异常没有抑制后续两份 M3U，查询异常按 URI basename 回退，中文/emoji/控制字符超长显示名安全化为 175 UTF-8 字节 basename，两份频道各精确一条。127835744 B / `4BF85571…6B82` R8 Release 测试包又通过公共分享链与三个 Debug 探针排除；独立 DocumentsUI/UID 10096 随后真实选中 M3U+XMLTV，经系统 chooser 将 `ACTION_SEND_MULTIPLE` 交给 Pure Live/UID 10946。两份 ExternalStorageProvider URI 均明确授权给目标包，播放列表和 EPG 各精确入库一次，17/17 检查通过。该包使用 Debug 证书并明确标记 `debug-signed`。三轮暂存树均为空且无 FATAL/ANR，IPTV 树与 Hive `91D6BAC5…6128F` 精确恢复，外部夹具精确删除，应用停止、首页/stay-awake 复原。A1-05/A2-01 保持 RUN，Windows 和最终正式签名候选继续；宏观仍为 **20 PASS / 40 RUN / 2 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 分享口令交接与导入弹窗已修订并完成 K90 系统面板验收**：[专项审计](SHARE_COMMAND_HANDOFF_AND_IMPORT_DIALOG_AUDIT_2026_09_13.md)。`5e1b9423` 将剪贴板处理改为消费者成功后提交、并发 single-flight 和默认 128 项 SHA-256 自分享历史；桌面/移动平台失败保持可重试并显示双语反馈，无效房间身份不进入平台通道。导入弹窗改由发起 State 持有路由，计时器可取消，320×480 / 3.0 倍英文长内容可滚动且 Cancel/Enter 返回明确结果。相邻七文件 **40/40 PASS**、全库 analyze 无问题；288832063 B / `5A8B6A08…3A23A` arm64 Debug 已保留数据覆盖 K90，真实 Bilibili 房间分享打开 `com.android.intentresolver/.ChooserActivity` 并显示口令预览/系统目标，测试未选择外部目标，系统返回后原房间动作仍可达。设备包哈希一致，Hive 精确恢复，应用停止、stay-awake 归零。A1-05/A2-01 保持 RUN；宏观仍为 **20 PASS / 40 RUN / 2 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 房间卡片长按、关注与标签分配已修订并完成 K90 原生专项**：[审计](ROOM_CARD_TAG_ASSIGNMENT_LAYOUT_AND_INTEGRITY_AUDIT_2026_09_13.md)。标签链 `c83ed5cc` 统一权威映射、有效 ID/旧键规则、持久化等待、响应式弹窗和新增标签边界；关注增量 `d499e41c` 移除一次性本地状态与全局 Navigator，改为观察规范关注集合、所属路由关闭、取消关注确认和单次事务。标签原有专项 **4/4 PASS**、相邻十文件 **131/131 PASS**；关注追加后同文件 **8/8 PASS**、相邻九文件 **73/73 PASS**，全库 analyze 无问题。最新干净 APK `288827674` B / `ABEEDA36…1726` 已覆盖 K90 且保留首次安装时间；真实 Bilibili 房间的直接关注关闭、取消关注提示/取消/确认、状态重开、再次关注、数字夹具创建/自动选择/确认/重开保持和无 FATAL/ANR 全部通过。Hive 哈希、uid/gid/mode/SELinux context 精确恢复，应用停止、stay-awake 归零。A1-05/A2-01 保持 RUN；宏观仍为 **20 PASS / 40 RUN / 2 NR，共 42 组未闭环**，Astra Light 使用 0 次。

- **09-13 GitHub Issue 已刷新到当前公开状态**：[增量审计](ISSUE_AUDIT_2026_09_13.md)。维护仓库 open 0、参考仓库 open 19；最新更新时间仍为 #860 的 `2026-09-11 14:10:04 UTC`，#859/#861 及其余条目均未越过现有专项读取窗口。本轮只读查询，没有同步上游或写入 Issue；宏观状态保持 **20 PASS / 40 RUN / 2 NR**、42 组未闭环，Astra Light 0 次。

- **09-13 Android 五种 MPV 音频输出已完成 K90 真实播放矩阵**：[专项审计](ANDROID_AUDIO_OUTPUT_BACKEND_AUDIT_2026_09_13.md)。`fec7eae9` 先把默认 OpenSL ES 单点改为 `audiotrack,aaudio,opensles,` 并补齐五项 Android 菜单、语义导航和即时/重启持久化；首轮逐后端播放据实暴露 `auto` 未解析为有效链、`null` 自动回退 Fijk 后仍创建 AudioTrack。`b303fffd` 统一 Android `auto` 有效链，并在初始化前把禁用音频意图传给自动回退内核；focused CI **189/189 PASS**、全库 analyze 无问题，Fijk 原生通道夹具 **8/8 PASS**。288826114 B arm64 Debug 已保留数据覆盖 K90，设备 APK 与 `539E8ACC…840E23` 一致；最终 `auto`、`audiotrack`、`aaudio`、`opensles`、`null` **5/5** 真实 Bilibili 播放通过，每项均有动态画面与相符的原生后端门禁，`null` 的三类后端信号和活跃 AudioFlinger 轨道均为 0。冷启动前台等待竞态由工具提交 `6f40be2c` 修订后完整重跑；设备 Hive 精确恢复到 `19F40EA9…D1F050`，应用停止、桌面与 stay-awake 复原。证据边界是一台 K90、一份 Debug 包和一个 Bilibili 房间；最终 MediaKit 稳定，Fijk 自动回退抑制由测试夹具覆盖。A7-04 保持 RUN，宏观保持 **20 PASS / 40 RUN / 2 NR**、42 组未闭环；Astra Light 0 次。

- **09-13 Android 50 次进退房与资源恢复已取得首轮完整原生证据**：[完整记录](ANDROID_ROOM_RESOURCE_RECOVERY_AUDIT_2026_09_13.md)。`61462573` 增加进程/内存/FD/线程/SurfaceFlinger 解析与循环工具；失败轮次先后暴露空诊断行、瞬态语义、应用内悬浮所有权、静态输入和中途证据丢失，最终 `1d29b9cb` 改为精确可点击动作与持久状态感知重试。K90 上绑定 `039f8ff3` 的 Debug APK 完成 50/50 次 Bilibili 视频→纯音频→退出，50 次均一次输入生效、悬浮会话关闭且进程稳定。每 5 轮的原生播放器/Codec 线程、FD、Socket、DMA-BUF、GPU FD、BLAST layer 无递增；空闲 52 秒后 FD 300→262、DMA-BUF 53→25，最终 PSS/RSS 相对预热首页 +16,684/+17,012 KB，无 FATAL/ANR。A7-04 由 NR→RUN；宏观为 **20 PASS / 40 RUN / 2 NR**、42 组未闭环。Release、多平台、视频恢复、全屏/PiP/后台和更长轮次继续，Astra Light 0 次。

- **09-12 Android 首页滚动已取得首轮 120 Hz SurfaceFlinger 量化**：[完整记录](ANDROID_HOME_SCROLL_FRAME_PACING_AUDIT_2026_09_12.md)。`09dce413` 新增目标 BLAST layer timestats、帧间隔百分位/阈值和主线程 schedstat 工具，并纳入固定本地门禁；精确提交相邻 **45/45 PASS**、全库 analyze 无问题。K90 上核对已安装 Debug APK SHA-256 为 `0F28A5F0…D4CD7F` 后执行热门网格 20 上+20 下、平台 20 左+20 右：竖向 2924 帧、P50/P90/P95/P99 为 8/8/16/24 ms、`>=16 ms` 5.472%、最大 102 ms；横向 2842 帧、8/8/8/16 ms、`>=16 ms` 2.322%、最大 42 ms；两组 dropped/lateAcquire/badDesiredPresent 均 0，页面、进程日志与清理断言通过。A1-06 由 NR→RUN；宏观为 **20 PASS / 39 RUN / 3 NR**、42 组未闭环。Release 对照、离群点 timeline、长列表与温升轮次继续，Astra Light 0 次。

- **09-12 视频几何仲裁与强制横屏返回已进入当前 Android 候选闭环**：[完整记录](VIDEO_GEOMETRY_ARBITRATION_AND_ORIENTATION_RESTORE_AUDIT_2026_09_12.md)。有效红灯 **35/37** 定位极端截图比例与最大面积异常候选；`01f7bfc6` 引入有限画布比例和严格多数紧凑簇。K90 上精确旧候选随后复现系统返回仍停在 `2608×1200`；`039f8ff3` 以一次性方向所有权按退出沉浸→竖屏→释放顺序恢复普通房间，并增强原生 UI 层级采集。精确最终提交 **197/197 PASS**、全库 analyze 无问题；288821628 B arm64 Debug 的 SHA-256 为 `0F28A5F0…D4CD7F`，保留数据覆盖安装且设备包哈希一致。竖屏完整链路后紧接普通流，两轮横屏返回、PiP、原房间存活、方向恢复与致命日志断言全部通过。A3-03 由 NR→RUN；宏观为 **20 PASS / 38 RUN / 4 NR**、42 组未闭环。真实内嵌黑边、长延迟几何、多次房间/重启与 Windows 客户端继续，Astra Light 0 次。

- **09-12 播放意外暂停与签名源刷新已纳入有界恢复**：[完整记录](PLAYBACK_CONTINUITY_RECOVERY_AUDIT_2026_09_12.md)。旧实现中卡住的原生 `play()` 或 source resolver 会长期占住恢复/生命周期队列；有效红灯 0/2 后，`8a4a417c` 分别复用意外暂停失败宽限并新增默认 12 秒源刷新上限，超时继续既有有限线路/内核回退且不改变用户暂停意图。恢复文件 **116/116**、九个相邻文件 **129/129**，最终 focused CI **245/245 PASS**、全库 analyze 无问题；精确 288815839 B arm64 Debug 已保留数据覆盖 K90，设备包 SHA-256 与 `DFA6C412…54E70442` 一致，正常播放/音频/PiP/退出 **16/16 PASS**。A3-06 由 NR→RUN；宏观为 **20 PASS / 37 RUN / 5 NR**、42 组未闭环。真实断流/EOF/签名到期注入、长测与 Windows 客户端继续，Astra Light 0 次。

- **09-12 弹幕列表与屏蔽管理已完成当前源码审计并补充 K90 候选证据**：[完整记录](DANMAKU_LIST_AND_FILTER_MANAGEMENT_AUDIT_2026_09_12.md)。有效红灯 13/19 定位到大小写重复存储、导入未归一化、完整关键词不可见、移除目标语义缺失、输入边界及开关/滑块交互语义；`d57e9b87` 统一启动/导入/新增归一化，补齐 40 字符上限、完整条目、精确移除、整行开关与格式化可调滑块。相邻 **88/88 PASS**、全库 analyze 无问题；同提交 288816635 B arm64 Debug 已保留数据覆盖 K90，设备 APK SHA-256 与 `2ACAEEAA…4FB44F9` 一致，过滤设置即时改变/隔离/恢复通过，应用、桌面和 stay-awake 复原。结合既有斗鱼首次冻结、新消息 3→10、一次追尾及冻结行长按屏蔽闭环，A4-02 由 NR→RUN；宏观为 **20 PASS / 36 RUN / 6 NR**、42 组未闭环。当前候选高频快速滚动、完整关键词原生闭环和 Windows 客户端继续，Astra Light 0 次。

- **09-12 主画面/小窗弹幕速度、FPS、密度、字体、描边与区域路径已完成源码审计**：[完整记录](DANMAKU_RENDERING_CONSISTENCY_AUDIT_2026_09_12.md)。基线实际小窗把全局可调描边宽度固定为 1.0，设置预览则无条件显示固定阴影且不画真实描边。`90d5d73b` 引入共享紧凑排版策略，实际 Overlay 和预览共同消费字重、字体族、描边开关与 0～4 宽度，预览按引擎相同透明度曲线先描边再填充。五文件 **37/37 PASS**、全库 analyze 无问题；精确提交 arm64 Debug 已覆盖 K90，设备包哈希一致，小窗状态双向重启/默认恢复通过，规范 Hive 精确恢复、应用停止、桌面/stay-awake 复原。A4-03 由 NR→RUN，宏观为 **20 PASS / 35 RUN / 7 NR**、42 组未闭环；真实系统 PiP 视觉、120 Hz Perfetto、长时高密度和 Windows 应用小窗继续，Astra Light 0 次。

- **09-12 Android 主弹幕模板与辅助语义已完成源码/原生往返**：[专项审计](ANDROID_DANMAKU_TEMPLATE_ACCESSIBILITY_NATIVE_AUDIT_2026_09_12.md)。`cc3ab5b2` 将主模板恢复改为完整验证后一次提交，保存纯文字与全部视觉字段；嵌入页恢复入口、整行开关、七类滑块、计数器及小窗颜色均具名。有效红灯复现后，精确 `9cc76caa` 七文件 **52/52 PASS**、全库 analyze 无问题。绑定 `cc3ab5b2` 的 arm64 Debug 已覆盖安装且设备 APK 哈希一致；小窗回归通过，真实 Bilibili 直播间中纯文字与顶部留白共同修改后一次恢复并跨进程保持。最终规范 Hive SHA-256 精确恢复、应用停止、桌面/stay-awake 复原。A2-04 保持 RUN，宏观保持 **20 PASS / 34 RUN / 8 NR**、42 组未闭环；Windows GUI、其余样式逐项输入、真实小窗完整视觉对照和长测继续，Astra Light 0 次。

- **09-12 Android 小窗弹幕设置路由、即时预览与重启持久化已补证**：[原生审计](ANDROID_PIP_DANMAKU_SETTINGS_NATIVE_AUDIT_2026_09_12.md)。旧 K90 小窗弹幕缓存点位于卡片空隙，序列还会把未换页误报为成功；`3627a936` 将整条路由改为双语实时语义并增加目标页 `assertSemantic`，双 PowerShell 回归 4/4、四 profile 校验通过。`3212c27b` 新增可恢复 smoke；当前候选实测开→关→重启→开→重启，预览禁用遮罩与 Switch 4→1→1→4→4 同步，两种状态均持久化。夹具首次选错 29 B 旧兼容 Hive 的失败已保留，随后恢复原始开启状态；最终改用 `443377` B 规范 Hive，恢复前后 SHA-256 均为 `701C666A…EA60C`，应用停止且设备状态恢复。A2-04 由 NR→RUN，宏观为 **20 PASS / 34 RUN / 8 NR**、42 组未闭环；Windows 双栏/逐项样式/默认模板/实际小窗/长测继续，Astra Light 0 次。

- **09-12 当前累计 Android 候选已覆盖安装并完成基础/呈现冒烟**：[完整审计](CURRENT_ANDROID_CANDIDATE_2026_09_12.md)。干净 `3e41e848` 构建/归档 arm64 Debug，288800843 B，SHA-256 `43ECD876…158D57`，签名、内容与 16 KB ELF 对齐通过；旧包与候选证书一致，安装前后 58 个状态文件逐路径/大小/SHA 完全一致，设备 `base.apk` 哈希与候选一致。当前 Bilibili 基础播放/10 条可见弹幕/音频往返/PiP/退出 **16/16 PASS**；Bilibili 标准流普通页→横屏→返回→PiP→回房 **7/7 PASS**，抖音竖屏普通页→竖屏沉浸→面板恢复→横屏→返回→PiP→回房 **9/9 PASS**。#858 首页软件注入音量增加使媒体流 0→10、铃声流保持 0，随后媒体流/静音、前台、进程及 stay-awake 全部恢复；实体按钮与播放中等场景继续。宏观仍为 **20 PASS / 33 RUN / 9 NR**、42 组未闭环；未改 Root/LSP/网络/ADB 端口或发布，Astra Light 使用 0 次。

- **09-12 Issue #859 已补齐 MPV/VideoToolbox 评论，并修订 iOS MPV 跨平台设置污染**：[Issue 审计](ISSUE_AUDIT_2026_09_10.md#859ios-抖音全屏播放闪退)。报告者确认 iPhone 12 / iOS 16.5.1 使用 MPV + VideoToolbox；源码另确认 Android 兼容输出、Windows 音频/硬解/RTX 或旧 `vo=gpu` 可经设置/备份进入 iOS。提交 `233efa57` 将 iOS 输出限制为 media_kit 纹理所需的 `libmpv`，保留 AudioUnit、VideoToolbox 与通用安全项，并在持久化、重置、设置 UI 和播放器创建处共同归一化。红测 **9/10**，首轮 analyze 导入错误如实保留；最终全库 analyze 无问题、六文件 **147/147 PASS**，精确提交再跑 **147/147 PASS**。相邻上游 media-kit #1361 仅作销毁竞态对照；缺少报告设备 crash/Jetsam 与原生复现，#859 保持 `community-platform / not-reproduced`，宏观仍为 **20 PASS / 33 RUN / 9 NR**、42 组未闭环；未操作手机、构建候选或发布，Astra Light 使用 0 次。

- **09-12 Issue #860 当前评论已复核，公共弹幕重复连接探针 30/30 通过**：[完整审计](ISSUE_860_REFRESH_DANMAKU_AUDIT_2026_09_11.md#后续增量公共直播弹幕重复连接探针)。新评论中的截图显示 IPv4 APN 配置及应用暂态重连提示，但仍缺平台/房间/时间戳、关闭码和原始日志。新增显式 opt-in 的生产适配器探针与资源守卫运行器；精确 `d77c6153` 在 Windows DIRECT 下对 Bilibili、Huya、Douyin 各循环 10 次，全部 ready、观察末尾保持连接，reconnect/terminal 均为 0。该结果不外推到 Android、报告网络、断网或长时稳定性；Issue 总体仍为 `not-reproduced`，A4-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，Astra Light 使用 0 次。

- **09-12 弹幕暂态重连与最终关闭已改为类型化事件并生成 Android 候选**：[Issue #860 增量](ISSUE_860_REFRESH_DANMAKU_AUDIT_2026_09_11.md#后续增量弹幕暂态重连与最终关闭事件类型化)。旧控制器依赖中文提示是否包含“正在尝试重连”决定保留或释放会话，措辞变化可让恢复后的 ready 被拒绝，最终错误文本也可能误留死会话。现由八个平台分别发布 `onReconnect` / `onClose`，普通直播间和多画面宿主不再解析文案。契约红灯精确落在旧接口；最终 13 文件 **72/72 PASS**、全库 analyze 通过。精确提交 `80c87c0e` 的 Android arm64 Debug 为 288798544 B，SHA-256 `DDACE9C909178E096E9DF8A2BC189476E6638F995AB3BF82BF730A3D673EAE68`，APK 内容与 16 KB ELF 对齐通过。完整 Issue 现象仍为 `not-reproduced`；未安装或操作手机，A4-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，Astra Light 使用 0 次。

- **09-12 Android 物理音量键媒体流路由已修订并生成定向候选**：[审计](ANDROID_HARDWARE_VOLUME_ROUTING_AUDIT_2026_09_12.md)。#858 的 OEM 物理按钮现象因缺少设备/日志/稳定时序继续保留 `not-reproduced`；源码可验证的第一处缺口是前台 Activity 从未建议硬件音量控件作用于媒体流。现于每次 `onResume` 绑定 `STREAM_MUSIC`，不拦截按键或直接修改系统流音量。宿主合同原始 0/1，最终同提交五文件 **71/71 PASS**、全库 analyze **No issues found**；`d8de9855` Android arm64 Debug 为 288805822 B，SHA-256 `5AFC1A42C8CFDC8D5671AD738297EEC2A9CAE6095B39A1A6DAB784968B099679`，APK 内容与 16 KB ELF 对齐通过。未安装或操作手机；A3-04 保持 RUN、A7-02 保持 NR，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，Astra Light 使用 0 次。

- **09-12 IPTV 频道 HTTP 请求头、持久化与媒体链路已修订**：[审计](IPTV_HTTP_HEADER_PLAYBACK_AND_RECORDING_AUDIT_2026_09_12.md)。旧解析会跳过 `#EXTVLCOPT` / `#EXTHTTP` / `#KODIPROP` 并把 URL `|...` 后缀留在媒体地址中，也没有频道字段可供播放器与录制使用。现统一解析头部/频道属性、VLC、EXTHTTP、adaptive stream/manifest headers 和 URL suffix，按确定性优先级规范化并经 schema 9 幂等迁移、稳定 ID 刷新及 `LiveRoom` 传递。主播放器、多画面、纯音频与 FFmpeg 录制共享结果，频道值覆盖全局 UA，畸形列表保留旧快照。直接六文件 **152/152 PASS**、多画面 **53/53 PASS**、最终 focused CI **426/426 PASS**，全库 analyze **No issues found**。真实受保护源/解码与 Android/Windows GUI 候选继续；A1-05/A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，未操作手机、构建或发布，Astra Light 使用 0 次。

- **09-12 IPTV 提供方回看元数据、归档窗口与 URL 策略已修订**：[审计](IPTV_PROVIDER_CATCHUP_METADATA_AND_WINDOW_AUDIT_2026_09_12.md)。旧导入会丢弃 `catchup`/source/days/correction，XMLTV `catchup-id` 未落库，所有历史节目又固定拼接 `playseek`。现将头部默认值和频道覆盖值贯通 parser、schema 8、幂等迁移、稳定 ID 刷新、`LiveRoom` 与播放器；归档窗口、禁用、缺失字段和未知模板在提交前得到明确结果。default/append/shift、Flussonic、Xtream Codes、VOD、时间/除数/格式化占位符及旧频道兼容路径均有纯策略回归。稳定红测 **32/33 PASS**，第一轮 **109/114 PASS**，修订后直接九文件 **226/226 PASS**，最终 focused CI **295/295 PASS**，全库 analyze **No issues found**。真实 IPTV 提供方/解码与 Android/Windows GUI 候选继续；A1-05/A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，未操作手机、构建或发布，Astra Light 使用 0 次。

- **09-12 IPTV 从回看返回直播、结果语义与大字号动作已修订**：[审计](IPTV_RETURN_TO_LIVE_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。旧直播节目分支只关闭节目单，播放器仍停留在回看源；回看 URL/区间没有显式清除路径，布尔结果又会把当前启动失败误标为旧请求被取代。现由当前节目和明确按钮共用返回直播事务，恢复原始直播地址并清除完整回看快照；三态结果、播放代次和 single-flight 隔离迟到任务，空原始地址保留节目单和播放器。返回动作在 EPG 加载/错误/空列表及 320×480 / 3.0 倍文字下持续可达。最终九个测试文件联合 **214/214 PASS**，全库 analyze **No issues found**。真实 IPTV 网络/解码与 Android/Windows GUI 候选继续；A1-05/A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，未操作手机、构建或发布，Astra Light 使用 0 次。

- **09-12 IPTV 直连播放器初始化、换房与回看 latest-wins 事务已修订**：[审计](IPTV_DIRECT_PLAYER_TRANSACTION_AUDIT_2026_09_12.md)。旧初始路径在 `setPlayer` 完成前返回并标记成功，直连源绕过播放请求栅栏；回看迟到成功/异常还可写入新请求并发布假提示。现统一等待 `VideoController.initialization`，以播放器 load epoch + IPTV playback epoch 隔离换房、退出和新回看；空身份/空地址不创建事务，被取代结果不更改当前页面。直接定向 **37/37 PASS**，九个测试文件联合 **205/205 PASS**，全库 analyze **No issues found**。真实 IPTV/解码、返回直播和 Android/Windows GUI 候选继续；A1-05/A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，未操作手机、构建或发布。

- **09-12 IPTV 节目单来源隔离、回看切换事务与大字号布局已修订**：[审计](IPTV_SCHEDULE_CATCHUP_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。旧读取可由较慢来源覆盖新来源或在退出后写入，停止边界的高亮与点击不一致；回看会折叠重复查询参数、把参数放到 fragment 后，连续点击又能重叠销毁/创建播放器并提前提示成功。旧固定节目行在 320×480 / 3.0 倍英文下复现 131/11 像素横向溢出，错误与空列表也不可区分。现统一来源/代次/销毁栅栏、半开时间区间、纯 URL 策略、single-flight 完整等待、明确状态、一次当前定位及响应式滚动布局。最终三文件 **37/37 PASS**，与相邻 IPTV 文件去重 **142/142 PASS**，全库 analyze **No issues found**。M3U 提供方回看元数据、真实 IPTV/解码和返回直播继续，A1-05/A3-04 保持 RUN；宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环，未操作手机、构建或发布。

- **09-12 直播间录制动作弹窗布局、任务复核与单次事务已修订**：[审计](ROOM_RECORD_ACTION_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_12.md)。旧五项固定 `Column` 在 320×480 / 3.0 倍英文下向底部溢出 **1819 像素**；弹窗快照可在任务变化后提交旧动作，标题入口在异步完成前可再次触发，停止/移除未等待，空添加结果也提示成功。现统一视口有界滚动、固定取消、自然高度标题按钮、提交瞬间任务复核、完整动作等待和反向动画后的录制中心导航。新增 **6/6 PASS**，六文件联合 **102/102 PASS**、全库 analyze **No issues found**。A3-04/A3-05/W2-04/W3-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实录制、构建或发布。

- **09-12 已知直播间直链/投屏选择器布局、阶段状态与退出生命周期已修订**：[审计](KNOWN_ROOM_LINK_SELECTOR_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。旧 `SimpleDialog` 将长选项与取消放在同一滚动内容中，320×480 / 3.0 倍英文、16 个选项时取消不能保持可达；滚到底部选择末项后，线路阶段还继承旧偏移，局部选择等待也没有统一退出完成者。现使用有界滚动主体、固定 SafeArea 操作区、阶段滚动归零及唯一取消回调。固定操作红测 **20/22 PASS**、阶段归零红测 **0/1 PASS**；修订后定向 **24/24 PASS**、六文件联合 **87/87 PASS**、全库 analyze **No issues found**。A1-05、A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实平台、构建或发布。

- **09-12 当前直播间音量事务、持久化边界与大字号布局已修订**：[审计](ROOM_VOLUME_DIALOG_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。旧百分比对 `NaN`/无穷调用 `toInt()` 会抛错，两个固定标题行在 320×480 / 3.0 倍英文下右溢出 818/903 像素，对话框另向底部溢出 224 像素；确认先写设置、未等待播放器便关闭。现统一自有草稿、平台目标、单次异步提交、提交期返回门禁、失败保留与内联重试；启动持久化、备份和房间值统一有限值与 `0..1` 边界，主体滚动且操作固定。原始红测 **2/4 PASS**，修订后新增 **9/9 PASS**，三文件联合 **44/44 PASS**、全库 analyze **No issues found**。A2-01、A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实声卡、构建或发布。

- **09-12 当前直播间定时器事务、生命周期与大字号布局已修订**：[审计](ROOM_PLAYBACK_TIMER_TRANSACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。旧开关直接启停真实计时，取消仍会改变会话；确认始终重新启用，活动计时在修改时长时还会连续重启两次。输入控制器早于退出动画释放，非滚动内容在 320×480 / 3.0 倍英文下向底部溢出 920 像素。现统一弹窗本地草稿、一次提交、停用优先、数字边界、内联错误、完整控制器所有权及固定操作区。有效红测 **0/5 PASS**，修订后新增 **5/5 PASS**，五文件联合 **30/30 PASS**、全库 analyze **No issues found**。A3-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实长时计时、构建或发布。

- **09-12 DLNA 发现、投屏事务与大字号布局已修订**：[审计](DLNA_DISCOVERY_CAST_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md)。搜索会话按代次独立持有订阅、计时器与资源释放，刷新隔离旧快照并移除已消失设备；投屏改为单一活动事务，严格串行暂停旧接收器、设置媒体地址和播放，关闭或设备移除后不再续发命令。地址校验、失败重试、当前接收器和窄屏 3.0 倍英文滚动状态同步补齐。新增 **12/12 PASS**，四文件联合 **41/41 PASS**、全库 analyze **No issues found**。A1-05 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 DLNA 接收器、构建或发布。

- **09-12 网页搜索生命周期、返回语义与状态布局已修订**：[审计](WEB_SEARCH_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md)。旧页强制读取路由参数，系统返回绕过浏览历史；加载错误未接线，关闭/返回重复销毁，确认期间新房间丢失，退出后迟到确认仍可能导航，发布版还暴露调试入口及完整 URL/响应头/控制台日志。现统一严格 HTTP(S) 请求、浏览器所有权、任务合并、房间确认队列、生命周期代次、进度/失败/重试和 `PopScope` 返回；窄屏 3.0 倍英文状态连续可达。新增 **13/13 PASS**，六文件联合 **100/100 PASS**、全库 analyze **No issues found**。A1-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实平台网页、构建或发布。

- **09-12 Firebase 初始化、认证会话与自动同步生命周期已修订**：[审计](FIREBASE_AUTH_CONTROLLER_SESSION_AUDIT_2026_09_12.md)。旧初始化依赖营销网站前置探测，初始用户需等待流回放才 ready；快照、流与登录页会重复同步，重试累积订阅，空 UID 保留旧身份，退出后迟到初始化仍继续。现以 SDK 结果、生命周期/身份代次、唯一订阅和同身份任务合并统一处理；权限/角色按当前用户快照提交，空云端配置静默结束，上传/下载核对身份，日志移除邮箱与 UID。有效红测 **0/6 PASS**，新增控制器/解析 **15/15 PASS**、邮箱与登录页 **9/9 PASS**，最终十文件联合回归 **127/127 PASS**、全库 analyze **No issues found**（352.2 秒）。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 Firebase、构建或发布。

- **09-12 Firebase 邮箱认证事务、反馈与大字号布局已修订**：[审计](FIREBASE_EMAIL_AUTH_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。旧密码重置只在 Android 显示，自定义元数据可覆盖规范身份字段；请求期间其余输入/切换仍可改动，密码首尾空格被静默裁剪，页面退出后迟到失败仍会回调，重置错误可能没有可见反馈。现统一可注入后端、保留字段、原样密码、单一活动事务、请求代次和可等待完成回调，并补齐双语通用错误、tooltip 与自然高度按钮。有效红测 **1/7 PASS**，修订后新增 **8/8 PASS**，最终九个测试文件联合回归 **111/111 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 Firebase/GitHub、构建或发布。

- **09-12 Firebase 云端配置详情解析、请求生命周期与注册元数据已修订**：[审计](FIREBASE_CONFIG_PREVIEW_AND_METADATA_AUDIT_2026_09_12.md)。旧详情页忽略 Map 配置，畸形标量/分区会阻断整页；缺失注册时间被伪造成当前时间，邮箱注册字段与读取字段分裂，每次上传又会重写注册时间。现统一容错快照、请求代次、空身份、通用错误与重试，并以 Firestore 事务保留或迁移 `created_at`；320×480 / 3.0 倍英文下元数据和原始 JSON 可滚动到达。有效红测 **0/8 PASS**，新增 **11/11 PASS**，最终八文件联合回归 **103/103 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 Firebase、构建或发布。

- **09-12 Firebase 个人中心动作事务与大字号布局已修订**：[审计](FIREBASE_PROFILE_ACTION_AND_LAYOUT_AUDIT_2026_09_12.md)。旧配置预览顶栏按钮在 320×480 / 3.0 倍英文下横向溢出 307 像素，空账号 ID 会触发断言；上传、下载与退出未等待也无进行中门禁，下载覆盖本机设置和退出登录均缺少确认。现将全部动作移入可滚动卡片，补齐方向说明、空身份保护、单一活动事务、进度/失败恢复、下载与退出确认，并让认证退出等待底层完成后安全返回。有效红测 **0/4 PASS**，修订后新增 **7/7 PASS**，最终六文件联合回归 **86/86 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 Firebase、构建或发布。

- **09-12 电视二维码设置同步输入、事务与相机生命周期已修订**：[审计](QR_SETTINGS_SYNC_LIFECYCLE_AND_INPUT_AUDIT_2026_09_12.md)。旧页会对空条码断言、从任意文本中抽取 URL、重复提交连续帧、让异常逃逸并在退出后更新旧 State；重试和路由退出还会遗留相机控制器，初始手电筒默认开启且自动闪光嵌套第二个按钮。现只接收规范 HTTP(S) origin，遍历整帧并合并同步事务，以代次隔离迟到结果，逐个释放控制器并增加重试门禁；相机提示/错误和结果页补齐双语、单一操作与大字号滚动。有效红测 **0/7 PASS**，修订后新增 **9/9 PASS**，最终八文件联合回归 **44/44 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实电视服务、构建或发布。

- **09-12 关注分区页签状态、可访问布局与空字段容错已修订**：[审计](FAVORITE_AREAS_STATE_AND_LAYOUT_AUDIT_2026_09_12.md)。旧页只有子页响应显示平台变化，长期控制器和顶栏仍保留旧数量，稳定触发页签长度异常；选择又只保留下标，重排时可切到另一平台。关注按钮在 320×480 / 3.0 倍英文下向下溢出 38 像素，空名称/类型还会触发断言。现以同一平台快照和 Widget 生命周期控制器按平台 ID 恢复选择，补齐瀑布流/卡片稳定键、自然高度按钮及双语字段回落。有效红测 **0/3 PASS**，修订后新增 **4/4 PASS**，五文件联合回归 **27/27 PASS**、全库 analyze **No issues found**；A1-03 保持既有 PASS，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、平台网络、构建或发布。

- **09-12 醒目留言空状态、卡片布局与平台输入容错已修订**：[审计](SUPER_CHAT_PRESENTATION_AUDIT_2026_09_12.md)。旧空页没有任何状态；畸形平台颜色会在构建卡片时抛异常，空头像仍发起失败请求；320×480 / 3.0 倍英文下长身份与金额出现横向溢出；无事件 ID 的重复快照又因重建时间不同而显示两次。现增加可滚动双语空状态、严格颜色回落和头像本地占位，卡片头按宽度/字号响应式排布，并统一复用消息模型事件身份与稳定卡片键。有效红测 **1/6 PASS**，修订后新增 **6/6 PASS**，最终十文件联合回归 **60/60 PASS**、全库 analyze **No issues found**。A4-05 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实付费事件、平台网络、构建或发布。

- **09-12 IPTV 订阅源管理布局与异步事务已修订**：[审计](IPTV_MANAGE_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。旧页在 320×480 / 3.0 倍中英文下多处横向溢出；初始读取失败直接逃逸，页面退出后迟到读取仍继续，删除完成会误关后来覆盖的路由，自动同步完成还会索引已删除项。现统一页面内加载/错误/空状态、请求代次、稳定资源身份、单项忙碌门禁和精确 `DialogRoute` 所有权，并将统计、卡片及操作改为响应式自然高度布局。有效红测 **0/6 PASS**，修订后新增 **7/7 PASS**，最终十文件联合回归 **195/195 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实订阅源、构建或发布。

- **09-12 工具箱路由所有权与选择器布局已修订**：[审计](TOOLBOX_ROUTE_AND_SELECTOR_LAYOUT_AUDIT_2026_09_12.md)。旧剪贴板检测无页面路由上下文，工具箱被新页面覆盖后，迟到结果仍会回填输入并显示提示；旧选择器又把选项和取消动作放在无明确高度边界的同一列表中，320×480 / 3.0 倍英文下两者都可能落到根视图之外。现由首帧页面上下文、`ModalRoute.isCurrent` 栅栏、有界滚动选项区和底部固定取消动作统一处理。有效红测 **23/26 PASS**，修订后定向 **26/26 PASS**，最终联合回归 **168/168 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实平台、构建或发布。

- **09-12 标签管理布局与数据完整性已修订**：[审计](TAG_MANAGEMENT_LAYOUT_AND_INTEGRITY_AUDIT_2026_09_12.md)。旧说明横幅与 116 像素固定卡片在 320×480 / 3.0 倍英文下使正文向下溢出 771 像素；详情/编辑弹窗不可滚动，描述框 IME 完成只关弹窗不提交。删除标签还残留房间映射，关注页继续选择旧 ID 后会显示空列表。现统一滚动面、响应式卡片、有状态可滚动弹窗、共享提交事务和按 ID 操作，并同步清理映射、让失效选择回到“全部”。有效红测 0/4 + 0/1，修订后新增 **5/5 PASS**，最终联合回归 **40/40 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实平台、构建或发布。

- **09-12 关于页与启动更新提示布局/生命周期已修订**：[审计](ABOUT_UPDATE_PROMPT_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)。关于页末项在 320×480 / 3.0 倍英文下曾向底部溢出 4 像素；旧提示按钮行向右溢出 333 像素、弹窗向底部溢出 44 像素，更新动作不可点击。现统一共享响应式 Tile、可滚动 AlertDialog 和可换行动作，并让自动提示成为根 Navigator 路由；系统返回先关闭提示，异步检查按挂载状态隔离迟到结果。新增 **4/4 PASS**，最终联合回归 **28/28 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未发起产品更新网络、操作手机、构建或发布。

- **09-11 Windows 多画面渲染目标已修订**：[审计](MULTIVIEW_RENDER_TARGET_AUDIT_2026_09_11.md)。旧每格纹理只在播放器创建时按布局均分，保留播放器切布局、窗口缩放或小格晋升后不会调用 `setSize`，导致大格上采样偏糊、降格后继续占用大纹理。现提取主播放器既有 viewport 协商器供两个入口共享；多画面按每格真实尺寸、DPR 和源宽高 180 ms 防抖更新，GlobalKey 搬移会交换大/小目标，identity、重挂和退出均有生命周期边界。新增 **5/5 PASS**，最终联合回归 **89/89 PASS**、全库 analyze **No issues found**。A3-08 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实多路、构建或发布。

- **09-11 Bilibili 二维码/Web 登录生命周期与大字号布局已修订**：[审计](BILIBILI_LOGIN_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_11.md)。旧二维码固定周期轮询会重入，刷新或退出后旧结果仍可覆盖新页面；WebView 完成地址的拦截与处理分裂，多次重定向/二维码切换会叠加事务。现改为完成后调度、有界退避、key/代次隔离和任务合并，HTTPS `m`/`www` 完成地址共用 Cookie 核验；二维码页与 Web 顶栏在 320×480 / 3.0 倍英文下保持状态和操作可达。新增 **13/13 PASS**，联合账号身份、账号导航、Cookie 编辑和翻译合同 **31/31 PASS**，全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实账号、网络、构建或发布。

- **09-11 账号身份刷新、退出事务与登录结果已修订**：[审计](ACCOUNT_IDENTITY_LIFECYCLE_AUDIT_2026_09_11.md)。Bilibili 旧服务延迟建立登录状态，重叠请求可由旧 Cookie 响应覆盖新账号，退出及浏览器清理也缺少合并边界；抖音昵称只在首次进入时读取，Cookie 修改后会残留旧名称。现统一即时核验状态、Cookie 快照/代次、同请求合并、退出本地同步清理和生命周期撤销；二维码/Web 登录只在身份核验成功后返回。新增 **6/6 PASS**，联合账号导航、Cookie 编辑、备份往返和翻译合同 **24/24 PASS**，全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实账号、网络、构建或发布。

- **09-11 第三方 Cookie 编辑状态、规范化与大字号布局已修订**：[审计](ACCOUNT_COOKIE_EDITOR_STATE_AND_LAYOUT_AUDIT_2026_09_11.md)。六个平台原先各自复制同一固定高度表单，粘贴内容原样进入 HTTP Cookie 配置，保存缺少明确结果，编辑后返回直接丢弃草稿；320×480 / 3.0 倍英文下长帮助会把输入与固定 44 高按钮推离当前视口。现统一共享滚动编辑页、控制字符与首尾空白清理、本机保存反馈、修改返回确认和自适应保存按钮；新增 **6/6 PASS**，联合账号入口、平台设置、备份往返和翻译合同 **21/21 PASS**，全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实账号、网络、构建或发布。

- **09-11 更新下载文件事务、打开流程和大字号弹窗已修订**：[审计](DOWNLOAD_LIFECYCLE_AND_DIALOG_AUDIT_2026_09_11.md)。旧 Android 流程下载完成后打开父目录；Windows/Linux 无论系统打开结果都会直接退出，便携 ZIP/历史附件同样受影响。旧文件名可携带路径片段，下载前还会删除目录内全部 APK 并直接写最终文件。现统一安全文件名、`.part`/`.previous` 可恢复提交、取消/失败清理、实际文件打开、桌面进程保持、打开失败原位重试和 Android APK 权限分流；弹窗在 320×480 / 3.0 倍英文下完整可滚动。新增 **10/10 PASS**，最终 8 文件 **38/38 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未发起真实下载、手机、构建或发布。

- **09-11 版本更新失败事务、资产身份和大字号布局已修订**：[审计](VERSION_UPDATE_STATE_AND_LAYOUT_AUDIT_2026_09_11.md)。旧检查异常会长期停在加载态并残留上一轮日志/地址，缺失版本或构建号仍可能拼出不存在的 Release 文件；320×480 / 3.0 倍英文下下载源及错误重试也缺少稳定可达布局。现统一成功状态、事务收尾、旧状态清理、控制器本机版本比较、严格资产身份与 HTTP(S) 链接合同，并让下载源、完整动作弹窗、复制、注入下载和重试可滚动到达。新增 **10/10 PASS**，最终 7 文件 **28/28 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未调用真实更新网络、下载器、手机、构建或发布。

- **09-11 版本历史维护源、刷新事务和双布局已修订**：[审计](VERSION_HISTORY_SOURCE_AND_LAYOUT_AUDIT_2026_09_11.md)。旧历史页写死上游仓库，与维护版版本检查/下载源分裂；外部 JSON 数字或畸形嵌套可中断整批解析，刷新又会暂时清空可见列表且失败静默。现统一 `VersionUtil.mirror`，归一化并局部隔离外部字段，刷新保留缓存和所选版本；移动详情整体可滚动，发布/复制/下载/关闭在 320×480 / 3.0 倍英文下连续可达，桌面双栏保持。有效红测 0/3 后新增 **10/10 PASS**，最终 5 文件 **18/18 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未调用真实更新网络、下载器、手机、构建或发布。

- **09-11 WebDAV 帮助页本地化、服务信息和大字号布局已修订**：[审计](WEBDAV_HELP_LOCALIZATION_AND_LAYOUT_AUDIT_2026_09_11.md)。旧页所有可见内容均硬编码中文，英文应用仍显示中文教程；“永久存储空间 3GB”与当前官方每月上传 1 GB、下载 3 GB口径不符，复制和图片预览也缺少一致的可访问操作。现补齐双语 42 个帮助键、当前 WebDAV 限制和官方入口，并让标题/参数行/长页在 320×480 / 3.0 倍英文下连续可达。新增 **5/5 PASS**，最终 10 文件 **99/99 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实账号、构建或发布。

- **09-11 WebDAV 状态布局与目录路径已修订**：[审计](WEBDAV_STATE_LAYOUT_AND_DIRECTORY_PATH_AUDIT_2026_09_11.md)。旧状态页在 320×480 / 3.0 倍文字下使“创建新配置”不可点击，长目录错误向底部溢出 2790 像素并隐藏“重试”；合法目录若只有服务路径而无名称又会触发空值断言。现以可扩展 Sliver 状态面保持五种状态及操作可滚动到达，目录优先使用规范化服务路径并隔离缺失字段。新增 5 项，WebDAV 页面/目录状态 **60/60 PASS**，最终 8 文件 **93/93 PASS**、全库 analyze **No issues found**。A1-05/A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 WebDAV、构建或发布。

- **09-11 本地互动平台覆盖与样式布局已修订**：[审计](LOCAL_INTERACTION_PLATFORM_AND_LAYOUT_AUDIT_2026_09_11.md)。旧实现只为 22 个支持平台中的 8 个定义资源包，其余会冒用哔哩哔哩身份，英文页还直接显示中文平台名；320×480 / 3.0 倍英文下样式分区标题最多向右溢出 521 像素，滑块标题和值另溢出 78 像素。现补齐全平台本地化身份、通用回落和 ID 归一化，并将标题/数值改为响应式布局。新增 7/7，最终 4 文件 **16/16 PASS**、全库 analyze **No issues found**。A2-01/A4-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实平台、构建或发布。

- **09-11 备份设置与本地配置预览已修订**：[审计](BACKUP_SETTINGS_AND_LOCAL_PREVIEW_LAYOUT_AUDIT_2026_09_11.md)。旧本地预览在 320×480 / 3.0 倍英文下向底部溢出 229 像素，云端标题被误用于本地数据，模块数还把备份元数据计入；备份页日志说明单行截断，开关/连接进度固定在长文本右侧。现由统一滚动长页、1/2/4 列自然高度摘要、已识别分区计数、独立本地文案和响应式控件修复。新增 7/7，最终 8 文件 **38/38 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实备份/云端服务、构建或发布。

- **09-11 平台显示、偏好与第三方认证入口已修订**：[审计](PLATFORM_SETTINGS_AND_AUTH_LAYOUT_AUDIT_2026_09_11.md)。旧页在 320×480 / 3.0 倍英文下把开关和拖动入口固定在长标题右侧，唯一/隐藏平台仍可拖动，且可隐藏最后一项；隐藏首选平台后偏好仍失效。抖音账号还跳到历史误命名路径，规范路由未注册，退出确认向底部溢出 32 像素。现由响应式控制行、可见顺序边界、唯一项保护、首选同步修复、完整滚动选择器和规范/兼容双路由统一处理。新增用例 8/8，最终 16 文件 **49/49 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 录制设置布局、选择器和配置边界已修订**：[审计](RECORD_SETTINGS_LAYOUT_AND_BOUNDS_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下，旧缓存标题向右溢出 802 像素，最大并发任务弹窗向下溢出 992 像素；英文页面还直接显示内部中文画质值，手动 `99`/`0` 会越过提示范围写入。现由响应式标题、整体滚动选择器、路由内数字编辑器和共享 `RecorderConfig` 边界统一布局、输入、启动与持久化修复。最终相关测试 **151/151 PASS**、全库 analyze **No issues found**。A2-01/A6-02 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实录制、构建或发布。

- **09-11 播放器内核设置布局、MPV 菜单和代理快捷编辑已修订**：[审计](PLAYER_KERNEL_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下，旧内核状态先触发 ListTile 全宽断言；初步堆叠后，MPV 音频输出摘要又向右溢出 680 像素。旧代理快捷弹窗还会保存 `65536` 等越界端口，并由路由外持有输入控制器。现由响应式状态/高级说明、整体滚动整行菜单和路由内 StatefulWidget 统一布局与 `1..65535` 校验。最终相关测试 **48/48 PASS**、全库 analyze **No issues found**。A2-01/A2-05 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实 MPV/代理链路、构建或发布。

- **09-11 刷新设置选择器布局与时间边界已修订**：[审计](REFRESH_SETTINGS_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下，旧刷新间隔弹窗向下溢出 548 像素；本地或备份中的 0/负数又会让自动刷新开关已启用但计时器不启动。现由整体滚动弹窗保持 12/20/8 个选项和三个末项连续可达，并在启动、当前备份及旧配置提取时统一归一化到 5～360 分钟。最终相关测试 **87/87 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实平台刷新、构建或发布。

- **09-11 缓存与数据页面的删除范围、并发状态和大字号布局已修订**：[审计](CACHE_DATA_SETTINGS_SCOPE_AUDIT_2026_09_11.md)。旧控制器把默认录制目录、字体/升级下载目录和 IPTV 数据库目录同时计入“缓存”并递归删除，失败后仍把大小写成 0；页面还混用录制目录标题与本地缓存说明。320×480 / 3.0 倍英文下，缓存大小尾部另会占满 256 像素卡片正文并触发 `ListTile` 断言。现由仅包含图片/表情临时文件的存储策略、清空后剩余大小复测、共享进行中任务、独立双语文案和响应式布局完整保留持久用户数据。最终相关测试 **37/37 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实应用数据、构建或发布。

- **09-11 主题设置长页、模式/语言选择和网格间距弹窗已修订**：[审计](THEME_SETTINGS_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下，旧页的加载样式尾部状态先触发 ListTile 全宽断言；旧间距弹窗再向右溢出 379 像素、向下溢出 1580 像素，语言两行向右溢出 180/34 像素，主题末项无可点击区域。现由窄屏状态堆叠、统一整体滚动选择器和路由内持有的间距编辑器保持末项与操作可达；间距只提交有限的 `0..64` 值。最终相关测试 **43/43 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 网络代理设置布局与端口编辑已修订**：[审计](NETWORK_PROXY_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)。旧页在 320 像素正文中仍把地址/端口固定拆成约 146/98 像素横排，3.0 倍英文标签与编辑宽度受限；清空应用层端口还会把最后有效值 `7897` 立刻覆盖成 `1080`，越界整数也直接写入。现由响应式纵排/横排、统一 `1..65535` 解析和双语错误提示保持两组端点可达，并保留最后有效配置。最终相关测试 **37/37 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、连接真实代理、构建或发布。

- **09-11 字体管理器布局、默认身份和字重选择已修订**：[审计](FONT_FAMILY_MANAGER_LAYOUT_AUDIT_2026_09_11.md)。基线在 320×480 / 3.0 倍英文下顶栏右溢出 182 像素；紧凑顶栏后的中间版本又暴露许可证 688 像素、下载动作 131 像素溢出。现由紧凑顶栏、惰性 Sliver 长页、响应式元数据/动作和整体滚动字重弹窗保持最后一项可达；Windows 卸载当前字体后也统一持久化 `Default`，大小写字体扩展名使用同一规则。最终相关测试 **30/30 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN、A2-07 保持 PASS，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、下载字体、构建或发布。

- **09-11 加载样式设置的固定标题区与大字号网格已修订**：[审计](LOADING_STYLE_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)。旧页在 320×480 / 3.0 倍英文下颜色行向底部溢出 234 像素；仅堆叠颜色行的中间版本又暴露外层固定 `Column` 造成的 702 像素溢出。现由统一惰性 `CustomScrollView`、响应式 1/2/3 列大字号网格、两行名称与 Tooltip 保持 85 个样式、末项选择和恢复默认可达。最终六文件 **20/20 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 底部导航显示、排序和大字号布局已修订**：[审计](NAVIGATION_SETTINGS_REORDER_AUDIT_2026_09_11.md)。旧页为隐藏项保留拖动把手，菜单仅剩一项时拖动隐藏的 Record 行会对单元素列表执行 `removeAt(3)` 并抛出 RangeError，空值/未知/重复 ID 也会原样进入主页；现统一归一化启动与导入数据，隐藏项及唯一页签不显示拖动入口，排序回调限制在可见边界，320×480 / 3.0 倍英文下控制行堆叠到标题下方。最终七文件 49/49、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 观看数据设置平台完整性、本地化与大字号布局已修订**：[审计](AUDIENCE_METRIC_SETTINGS_LAYOUT_AUDIT_2026_09_11.md)。旧页只列 14 个站点，漏掉 7 个当前已注册普通直播平台，且六个站名在英文页面仍为硬编码中文；现清单覆盖全部 21 个非 IPTV 直播站点，名称统一走本地化，新增七组双语口径说明，模式和平台行在 320×480 / 3.0 倍英文下纵向展开。修改前 1/2，最终九文件 44/44、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 竖屏直播设置摘要与枚举弹窗已修订**：[审计](PORTRAIT_SETTINGS_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下，四个当前值会占满 `ListTile` 宽度并触发布局/语义级联异常；纵向摘要修订后又暴露旧枚举弹窗向底部溢出 80 像素。现由窄屏堆叠摘要、整体可滚动弹窗和完整行选项保持四组设置可达，四个末项连续选择及一次呈现刷新均通过。修改前 0/2，最终五文件 60/60、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 视频设置 ASMR 定时弹窗布局与输入生命周期已修订**：[审计](VIDEO_SETTINGS_ASMR_TIMER_DIALOG_AUDIT_2026_09_11.md)。旧实现聚焦自定义输入保存时会在路由退场动画中过早释放控制器，并用复数通用键显示 `1 Hours` / `1 days`；现由有状态弹窗持有输入控制器、整体滚动布局和紧凑分钟/小时/天单位保持十个预设与自定义输入可达。修改前 1 PASS / 2 FAIL，最终五文件 17/17、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 视频设置清晰度选择与大字号布局已修订**：[审计](VIDEO_SETTINGS_RESOLUTION_DIALOG_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下，共用滑块标题向右溢出 946 像素，清晰度当前值向底部溢出 4 像素，五档内部中文值直接出现在英文界面；完整行选项的中间实现又暴露弹窗向底部溢出 248 像素。现由响应式滑块标题、窄屏堆叠摘要、稳定值与本地化标签分层、可滚动整行选项统一两个入口。最终六文件 13/13、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 通用设置倒计时弹窗布局与输入生命周期已修订**：[审计](GENERAL_SETTINGS_COUNTDOWN_DIALOG_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下旧弹窗向底部溢出 548 像素；补成滚动布局后又稳定暴露聚焦自定义输入保存时控制器被路由结果提前释放。现由有状态弹窗持有输入控制器，七个预设及自定义正整数分钟均可达，15 分钟预设和 7 分钟输入连续提交通过。修改前 2 PASS / 1 FAIL，最终三文件 17/17、全库 analyze 无问题。A2-01 保持 RUN、A2-03 保持 PASS，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 Windows 启动窗口尺寸弹窗布局与本地化已修订**：[布局审计](GENERAL_SETTINGS_WINDOW_SIZE_DIALOG_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下旧弹窗向底部溢出 512 像素，默认预设还混入硬编码中文；现由整体有界滚动和中英文动态默认标记保持五个预设、宽高输入及操作可达。修改前 1 PASS / 1 FAIL，最终四文件 22/22、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 通用设置刷新率弹窗窄屏大字号已修订**：[布局审计](GENERAL_SETTINGS_REFRESH_RATE_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。320×480 / 3.0 倍英文下三个固定横排标题分别右溢出 174/274/207 像素，旧弹窗另向底部溢出 248 像素且最高档不可达；现由有界滚动弹窗和可换行名称/耗电徽标保持三档完整可选。修改前 0/1，最终五文件 17/17、全库 analyze 无问题。A2-01 保持 RUN、A2-02 保持 PASS，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 页面尺寸编辑框窄屏/大字号布局已修订**：[布局审计](PAGE_SETTINGS_DIALOG_LAYOUT_AUDIT_2026_09_11.md)。320 像素正文宽度下固定标题行稳定右溢出 164 像素；现以可换行标题区和响应式横排/纵排输入区保持“自适应推荐”“添加”及确认动作可达。修改前 0 PASS / 2 FAIL（其中一项同时含夹具时序），最终四文件 45/45、全库 analyze 无问题。A2-01 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 设置首页窄屏大字号顶栏已修订**：[布局审计](SETTINGS_APP_BAR_LAYOUT_AUDIT_2026_09_11.md)。320×480 / 2.0 倍英文稳定复现顶栏横向溢出 119 像素且标题宽度归零；现按窗口与文字缩放切换带 Tooltip 的紧凑图标或宽屏文字按钮，并保持同一路由。修改前 1 PASS / 1 FAIL，最终六文件 51/51、全库 analyze 无问题，含窄屏滚动到“备份与恢复”。A2-01 由 NR 进入 RUN，当前宏观为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、构建或发布。

- **09-11 PiP 弹幕预览与实际小窗几何已统一**：[一致性审计](PIP_DANMAKU_PREVIEW_FIDELITY_AUDIT_2026_09_11.md)。自动缩放下实际小窗同时缩放字号和速度，旧预览只缩字号；实际引擎轨道分配/绘制与预览又各用不同高度。干净红灯为 3 PASS / 1 FAIL，现由共享指标统一字号、速度、轨道、表情和防重叠间距，五文件 26/26、全库 analyze 无问题。A2-04 的源码子项前进，真实 Android PiP / Windows 小窗、重启持久化和性能仍待最终候选，整项保持 NR；未操作手机、构建或发布，宏观 42 组保持。

- **09-11 收藏恢复/手动/变更刷新已合并为单一触发**：[Issue #860 收藏增量](ISSUE_860_REFRESH_DANMAKU_AUDIT_2026_09_11.md#后续增量收藏刷新触发器合并)。启动核验后的恢复计时器原会在下拉、收藏变更或在途全量刷新之后再执行；关闭恢复刷新配置也不撤销已排队任务。修改前 19 PASS / 3 FAIL，补充在途场景再得 22 PASS / 1 FAIL；现由触发器所有权和全量提交点共同撤销过时恢复任务，最终九文件 61/61 与两个修改 Dart 文件严格分析通过。完整随机变化报告仍为当前源码未复现；未操作手机、构建或发布，宏观 42 组保持。

- **09-11 WebSocket 停滞握手可中止并完成有界关闭**：[Issue #860 审计](ISSUE_860_REFRESH_DANMAKU_AUDIT_2026_09_11.md)。当前 3.1.8 源码相对报告所用 3.1.2 已包含多项收藏/弹幕变化，且报告无日志，因此宽泛现象仍为当前源码未复现；本批确定性复现并修订共享连接助手在 HTTP Upgrade 停滞时关闭也被阻塞的缺口。两轮修改前失败保留，最终 18 文件 102/102 与两个修改 Dart 文件严格分析通过，含真实本机 TCP 停滞 Upgrade。未操作手机、构建候选或发布，宏观 42 组保持。

- **09-11 Windows 桌面播放器内核状态错配已修订**：[Issue #861 审计](WINDOWS_PLAYER_ENGINE_ISSUE_861_AUDIT_2026_09_11.md)。当前源码的 Windows 运行时本已固定集成式 MPV，但旧设置/备份可残留 IJK 并在页面误报；现统一平台能力、初始化/导入/启动/回退与设置页，桌面显示固定 MPV 且不可点击，移动端多内核保持。修改前 7 PASS / 2 FAIL，最终六文件 144/144 与七个修改 Dart 文件严格分析通过；全库分析捕获的 Huya 录制探针签名/导入漂移同步修订。未操作手机、构建候选或发布，Issue #860 与原生双端验收继续，宏观 42 组保持。

- **09-11 缓存平台名即时语言切换、微博真实路由与四列断点已闭环**：[后续验证与失败链](WEIBO_APPLICATION_INTEGRATION_2026_09_11.md#后续缓存站名四列断点与真实路由闭环)。保留相同 `Site`/适配器身份，在绘制时解析当前语言；真实中文→英文切换覆盖全部 22 个适配器并保留自定义回退名。微博四组双语窄/宽屏搜索均点击实际卡片进入播放路由，1000 像素补齐四列 × 三档字号。最终 24 文件 257/257、三个修改 Dart 文件严格分析通过，累计新增 59 项；未操作手机、构建候选或发布，原生字体与完整双端验收继续，宏观 42 组保持。

- **09-11 微博已接入应用并修订热门页大字号布局**：[接入与失败/通过证据](WEIBO_APPLICATION_INTEGRATION_2026_09_11.md)。注册、有限目录、场次查询、分享、迁移 14、外部打开与新鲜源消费接通；实际卡片复现 200% 字号溢出 21 像素，修订为自然高度懒加载行。新增 55 项，去重 253 项定向闭环、24 文件严格分析通过，保留三轮失败及夹具修订记录。当前 21 直播站点 + IPTV、6 组参考平台未注册；仍非原生全功能验收，未构建/操作手机/发布，宏观 42 组保持。

- **09-11 微博分享文本修订已通过定向验证**：[复现与范围](WEIBO_SHARE_NORMALIZATION_2026_09_11.md)。三条红基线均复现后修订结构性点路径和紧接中文正文的预处理，新增 19 项，六文件 252/252 与两个修改文件严格分析通过。此前排队中的检查点已先同步 GitHub，现补同步实际验证结果；微博平台注册、双端验收和发布仍待完成。

- **09-11 录制音频时间锚点已修订并通过限定原生回归**：[PES 根因与证据](RECORDING_AUDIO_PES_CLOCK_2026_09_11.md)。修复 TS 音频聚合在分段时改变时间锚点的问题，显式保留前导偏移以避免负 DTS 包损失。3/3 Python、171/171 定向、四文件严格分析、11/11 实际 FFmpegKit 原生场景通过，包含微博、静音小包/时钟抖动、HEVC 8/10-bit、双音轨、TS 回绕与正常主动停止。六组新矩阵的生产单、多段全轨道时间线一致，旧失败和旧实现对照保留。仍非双端全功能/异常恢复验收；未构建 APK、操作手机或发布 3.2.0。

- **09-11 录制时钟扩展矩阵为 9 PASS / 1 FAIL**：[矩阵与失败证据](RECORDING_CLOCK_MATRIX_2026_09_11.md)。39/39 定向、四文件严格分析通过；原五组及 HEVC 8/10-bit、双音轨、真实 TS 回绕四组通过。微博视频旧阶跃消除且内容完整，但新多段音频相对单段仍有 123/44100 秒偏移范围，超过两采样点门槛，继续定位。仅探针/文档同步，生产代码基线 f46ebe56 不变；未构建 APK、操作手机或发布，不将该原生失败标为修复完成。

- **09-10 分段时钟已接入生产并完成限定场景原生回归**：[生产接入与证据](RECORDING_CLOCK_PRODUCTION_2026_09_10.md)。版本化 TS / CSV、严格时钟校验、旧格式兼容、取消/原片保留和字节跟踪已接通；167 项定向、15 文件严格分析、5 组实际 FFmpegKit 回归通过，含正常 HTTP FLV 主动停止。HEVC、多轨、其他输入、异常恢复、原微博样本新路径复验及双端完整验收继续；未构建 APK、操作手机或发布。下列“尚未修复”条目保留为本次接入前的定位历史。

- **09-10 录制拼接时钟缺陷已定位，尚未修复**：[同输入逐帧对照与离线候选](RECORDING_CONCAT_CLOCK_DRIFT_2026_09_10.md)。实际 FLV/TS/MP4 的 255 视频帧和 278 音频帧内容顺序一致，但生产拼接额外引入约 90 毫秒阶跃；离线候选已消除该样本阶跃，仍待项目原生内核、确定性多场景及生产接线验证。

- **09-10 微博适配器与录制证据续查**：[适配器源码检查点](WEIBO_ADAPTER_CHECKPOINT_2026_09_10.md)、[同输入诊断](WEIBO_RECORDING_INPUT_EVIDENCE_2026_09_10.md)。旧 MP4 完整解码通过，但两处视频时间间隙未归因；新增显式有界 FLV/TS 留存，87/87 定向通过。平台注册、双端应用验收及 3.2.0 发布仍待完成。

- **09-10 微博直播元数据层已验证**：[微博/一直播审计](WEIBO_METADATA_API_AUDIT_2026_09_10.md)。实际目录和在播详情接通；HLS 字段实为 FLV，保留访问门槛/回放/播放开关与身份校验，不猜画质。154/154 定向、67/67 含真实探针（去重 155，新增确定性 54）、四文件严格分析通过。公开媒体仅 FLV 前缀，完整播放/录制与应用注册仍待续；一直播 DNS/代理访问失败不判停运。20 直播站点 + IPTV、7 组未注册、42 组未闭环保持，未操作手机/构建/发布。

- **09-10 Windows 音量控件替换已修订**：[控件审计](VOLUME_WIDGET_LIFECYCLE_AUDIT_2026_09_10.md)。补齐重绘后的 6 项 Widget 基线全部失败；修订控制器订阅/迟到初值/悬停归属，避免移动端默认音量误写 Windows 当前房间。四文件 89/89、两文件严格分析通过（新增 12 项），非实际声卡或原生候选验收；48154d15 APK 不含近期音量修订，完整目标与待验收计数保持。

- **09-10 音量生命周期修订**：[音量审计](VOLUME_LIFECYCLE_AUDIT_2026_09_10.md)。实际控制器复现 4 项缺陷：退出后写入、初始快照覆盖偏好、显示 Rx 未更新、迟到 setter 发布；修订归属/代次及平台等待上限后，五文件 206/206、五文件严格分析通过（新增 16 项）。保留夹具两项错误断言记录；非 #858 物理按钮根因结论，未操作手机。48154d15 已归档 APK 不含该修订，后续候选须按新 SHA 验证。

- **09-10 累计 Android 候选已构建并核验**：[完整候选证据](ANDROID_CUMULATIVE_CANDIDATE_2026_09_10.md)。干净 48154d15：全库 analyze 无问题、4072/4072 Flutter、42/42 指定公开接口；arm64 Debug APK / 3.1.8+4121 / Manifest 6121 / 288640934 B，哈希 B33B83C8…DE782416。包内容、16 KB 对齐、签名与旧候选保留核验通过；78 项原生场景仍全部 not-run，未安装/操作手机/发布，继续代码审查及全范围验收。

- **09-10 全量失败已定位到旧夹具并完成定向修订**：[累计门禁续记](CUMULATIVE_QUALITY_AND_SOURCE_SYNC_2026_09_10.md#第二轮完整门禁及分页引擎夹具修订)。a2b539cb 全量为 4069 PASS / 3 FAIL；独立复现相同失败。CC 视口准备与默认引擎回退前置状态修订后，六文件 273/273、两文件严格分析通过；保留首轮 Widget/Dio 虚拟时钟等待的失败记录。业务不变，待新干净提交完整回归；尚无新 APK / 原生 PASS，源代码每批同步 GitHub。

- **09-10 Issue 增量审查**：[Issue / 音量链路记录](ISSUE_AUDIT_2026_09_10.md)。维护仓库 open 0、上游 18；新增 #858 Android 音量键、#859 iOS 抖音全屏闪退均待复现，#849 新评论无新增诊断附件。累计门禁在 a2b539cb 上实际为 analyze 无问题、Flutter 4069 通过 / 3 失败，公开接口与 APK 构建尚未到达；失败夹具修订及定向验证进行中。未改变原生验收与全平台 3.2.0 范围。

- **09-10 累计门禁与 GitHub 同步**：[门禁/同步审计](CUMULATIVE_QUALITY_AND_SOURCE_SYNC_2026_09_10.md)。337 个积压提交及持续同步规则已推送，源码同步与 3.2.0 发布分开。全库分析捕获一个测试夹具遗漏 hlsPrefetch 的签名错误，补齐后 11/11 与严格分析通过；首轮完整门禁仍记失败，完整套件/公开接口及累计 APK 待续。新计划 78 个 Android 场景全部 not-run；本轮仅核对手机身份，未安装/切前台。20 直播站点 + IPTV、7 组未注册和 42 组未闭环保持。

- **09-10 搜索取消与退出栅栏已修复**：[搜索审计](SEARCH_CANCELLATION_LIFECYCLE_AUDIT_2026_09_10.md)。修复空草稿换平台残留旧结果、Windows 检测退出后迟到弹窗；niconico 搜索接通独立传输 token，旧适配器停止等待并消费迟到错误。修改前两项 Widget 稳定失败；最终七文件 142/142（新增 15 项）、五文件严格分析通过，保留首次测试帧调度错误记录。仍有旧平台底层取消/游标归属、累计候选及双端原生验收待续；20 直播站点 + IPTV、7 组未注册、42 组未闭环保持，未操作手机/构建/发布。

- **09-10 多画面与录制发现归属已接通**：[归属审计](MULTIVIEW_RECORDER_DISCOVERY_OWNERS_AUDIT_2026_09_10.md)。每格、录制任务及预取独立取消并等待临时发现清理；缩容先取消所有移除格。另复现并修复格子重建复用 epoch 导致旧结果创建播放器的竞态。首轮 178/178，最终多画面 81/81、其余 98 项同业务输入复用，去重 179 项（新增 13）；九文件严格分析通过，保留分析与复现失败记录。搜索/其他传输取消、真实多路/长录及双端 GUI 待续；20 直播站点 + IPTV、7 组未注册、42 组未闭环保持，未操作手机/构建/发布。

- **09-10 主播放与工具箱画质发现已接通主动取消**：[请求归属审计](QUALITY_DISCOVERY_CANCELLATION_AUDIT_2026_09_10.md)。修改前两项确定性失败；新增可选取消合同，niconico 发现会话在退出/换请求/超时后取消并等待清理，保护新播放器不受旧销毁影响。最终八文件 148/148（新增 12 项）、六文件严格分析通过；保留编译失败记录。多画面每格、录制任务/预取及搜索取消仍待续，非真实网络/双端原生验收；20 直播站点 + IPTV、7 组未注册、42 组未闭环保持，未操作手机/构建/发布。

- **09-10 niconico 应用注册/分享/搜索/目录迁移已接通**：[接入审计](NICONICO_APPLICATION_INTEGRATION_AUDIT_2026_09_10.md)。迁移 13 保留顺序和隐藏选择，严格 watch 链接接入共用入口；新增 27 项，去重 306 项通过覆盖、22 文件严格分析通过，含双语窄/宽屏 200% 字号真实目录 Widget。两项旧迁移期望与一次测试时钟停滞均保留记录并复测；页面画质发现主动取消、真实多画面/长录和双端原生验收仍待续。当前 **20 直播站点 + IPTV，7 组未注册，42 组验收未闭环**；未操作手机/构建/发布。

- **09-10 niconico 原生分类目录与关键词搜索已适配**：[目录审计](NICONICO_DIRECTORY_AUDIT_2026_09_10.md)。依据实际官方脚本及响应区分每页 70 的 recent 和每页 40 的 search，接入七分类、公开卡片、取消和服务端分页；空搜索不冒充全站目录。127/127（含新增 35 项）、六文件严格分析及外部探针 2/2 通过，回放 13 响应/415 条，十次实际目录/搜索请求成功。尚待平台注册/搜索与分享入口/取消链/迁移及双端 GUI、长录；仍 42 组未闭环、8 组未注册，未操作手机/构建/发布。

- **09-10 niconico 元数据与实际画质适配已验证**：[站点适配审计](NICONICO_SITE_ADAPTER_AUDIT_2026_09_10.md)。临时发现会话返回前关闭，实际分辨率/码率生成公开配方；补齐动态封面、头像及访问提示。最终新增确定性 39 项与生产探针共 40/40，七文件严格分析通过，125 项相邻通过证据复用。真实节目返回三档画质，seat 清理且 Cookie 为 0；未注册目录/导航，未媒体解码或双端 GUI/长录。保持 42 组未闭环、8 组未注册；未操作手机/构建/发布。

- **09-10 多画面已接入每格独立的会话型输入**：[多画面审计](MULTIVIEW_OWNED_INPUT_AUDIT_2026_09_10.md)。公开配方穿过解析、状态、画质切换及实际 cell owner，每次原生打开独立创建；换源取消、迟到清理、过期会话主动恢复与移除后的状态隔离接通。修复本轮稳定复现的恢复覆盖新源竞态；最终七文件 111/111（含 19 项新增）、五文件严格分析通过。底层解码/seat 使用替身，真实多路解码、自动恢复、平台注册及双端长录/GUI 待续；未操作手机/构建/发布，42 组未闭环、8 组未注册保持。

- **09-10 会话型输入的直链/投屏能力处理已补齐**：[入口审计](OWNED_INPUT_EXPORT_AUDIT_2026_09_10.md)。共用 flow 改用统一解析结果，会话源给出应用内播放/录制提示，不导出旧回退 URL 或私有中继；普通 URL 行为保留。修改前两项确定性失败，最终五文件 78/78（含 14 项新增）及五 Dart 文件严格分析通过。多画面每格会话管理、niconico 导航/注册、真实长录和双端 GUI 待续；未操作手机/构建/发布，19 站点 + IPTV、8 组未注册、42 组未闭环保持。

- **09-10 录制器接通会话型输入并完成本机原生对照**：[录制归属审计](RECORDER_OWNED_INPUT_AUDIT_2026_09_10.md)。解析游标、实际 RecorderController/FFmpegManager/Service 保存公开配方，创建中停止与排空后清理有归属；新增 19 项，最终 17 项及 11 文件严格分析通过，150 项相邻证据复用。自有输入和普通 URL 两次原生探针均通过，共四份完整双轨文件，停止/合并/释放/重启通过。未做真实 niconico 网络长录或 Android/GUI 验收；42 组未闭环、8 组未注册保持，未操作手机/构建/发布。

- **09-10 站点配方接通页面播放与逻辑线路**：[接线审计](OWNED_INPUT_ROUTE_AUDIT_2026_09_10.md)。解析/恢复保存无 URL 配方，画质切换经过实际管理器回执，页面及悬浮状态保留来源；新增 18 项。集成 160 PASS / 5 FAIL 后修正五项测试夹具并复测 5/5，16 文件严格分析通过，前 160 项同业务输入复用。手机身份/Root 与 MT 26 工具只读核验正常，未安装/改配置。录制器、平台注册、双端 GUI/长录及 42 组验收继续，8 组未注册保持。

- **09-10 自有输入已接入实际播放器管理器**：[状态审计](PLAYER_OWNED_SOURCE_STATE_AUDIT_2026_09_10.md)。类型化来源穿过播放/重播、引擎和恢复事务、管理器悬浮快照；补齐创建中暂停及恢复，最终新增 15 项、相邻 170 项复用，六文件严格分析通过。实际管理器→桌面 FFmpeg 六秒双轨消费与清理通过，首次输入失败原样保留且根因未证实。尚待站点解析/页面状态/录制器接线与原生 GUI，42 组未闭环、8 组未注册保持。

- **09-10 播放器有归属输入事务与真实消费已验证**：[事务审计](PLAYBACK_OWNED_INPUT_AUDIT_2026_09_10.md)。新增 24 项，首轮 179 项通过；构造器整理后 64 项、六文件严格分析通过，相邻 115 项复用。真实生产配方经共享传输层取得六秒双轨（180V/281A），播放预取为 0，提交及退出清理通过。仍非应用播放器/Android 验收；类型化状态、录制消费者和平台注册待续，42 组未闭环、8 组未注册保持，未构建或操作手机。

- **09-10 niconico 生产输入的会话/中继收尾已接通**：[所有权审计](NICONICO_INPUT_OWNERSHIP_AUDIT_2026_09_10.md)。最终 183/183 与八文件严格分析通过，另 12 项连接/TLS 回归通过；旧节目下播及官方入口/画质差异的三份外部失败保留。修订官方 WebSocket 路径、同尺寸码率选择后，生产 owner 实际 800×450 双轨短录 1/1，180V/281A、严格解码及 Cookie/资源清理通过。尚未接入应用播放/录制消费者、平台注册或双端 GUI/长录；19 站点 + IPTV、8 组未注册、42 组未闭环及候选保持，未操作手机或发布。

- **09-10 明确选流后的 niconico 双轨短录已通过**：[选流/保留审计](HLS_MASTER_SELECTION_AUDIT_2026_09_10.md)。固定窗口对照验证源过期后仍保留 3892；不将视频子列表直接替代含外置音频的 master。联合 90/90（含真实 1/1）与五文件分析通过，补充循环边界后最终 92/92、四文件分析通过。真实 720p 视频 6.000 秒、音频 6.016 秒、双轨完整解码，退出清理通过；这是显式选流中继证据，不关闭未选流 ABR 的旧失败，也不代表应用消费者/平台注册或长录已完成。19 站点 + IPTV、8 组未注册、42 组未闭环保持；未构建或操作手机。

- **09-10 niconico 动态 Cookie 已接通生产中继，真实短录仍 FAIL**：[中继与双轨审计](NICONICO_RELAY_AUDIT_2026_09_10.md)。71 项生产定向、5 项合同回归与六文件分批严格分析通过；两份 MP4 均可解码，但首份双轨约三秒，第二份六秒视频仅约三秒音频。已定位音频 3892 被展示但未请求，后续 PTS 跳过约三秒；补上双轨包覆盖检查并用原文件复判，撤销仅凭容器六秒的完成认定。继续固定窗口/多变体复现及消费者接线；19 站点 + IPTV、8 组未注册、42 组未闭环保持。未构建、操作手机或发布。

- **09-10 niconico 会话保活和按路径 Cookie 已实现**：[会话审计](NICONICO_SESSION_AUDIT_2026_09_10.md)。会话 24/24 与七文件严格分析通过，复用同输入 84 项及录制 Cookie 兼容 3 项；生产探针 3/3（含两项探针回归）与单文件分析通过。真实会话跨过 30 秒 seat 周期，主/音视频列表、16 B 密钥及保活后主列表均 200，退出 Cookie 清空、清理通过。尚未媒体解码/实录或接入应用消费者，仍 8 组未注册、历史 42 组未闭环；未操作手机/构建/发布。

- **09-10 niconico 元数据及真实会话入口已验证**：[接入审计](NICONICO_METADATA_AUDIT_2026_09_10.md)。新增 Dart watch-page 合同，区分预告/直播/结束与地区/登录条件；53/53（含生产 HTTP 1/1）与五文件严格分析通过。额外匿名 socket 返回 seat/stream，主列表 200、三档画质；未解码/录制，持有会话与按路径 Cookie 的应用接线待续，仍未注册。未构建或操作手机，19 直播站点 + IPTV、8 组未注册、42 组验收未闭环保持。

- **09-10 Bigo 既有元数据层完成新响应复验**：[复验记录](BIGO_CONTRACT_AUDIT_2026_09_10.md)。撤回重复实现，生产 API 保持不变；追加 2 项夹具测试，含完整捕获回放 44/44 与三文件严格分析通过。三房间仍返回登录门槛，无媒体成功证据，平台尚未注册。设备身份及 MT MCP 26 工具清单只读核对成功，未安装/切前台；42 组验收及额外 8 组平台扩展保持待闭环。

- **09-10 用户管理双语文案与窄屏布局已修订**：[呈现审计](USER_MANAGEMENT_PRESENTATION_AUDIT_2026_09_10.md)。ece91a10 修复确认框操作名被邮箱替换，统计/徽章和按钮支持换行与字体缩放，短窗口保留可滚动头部和目录空间。新增 24 项、联合 151/151；滚动提示补齐后 49/49 与三文件严格分析通过，复用相邻 102 项；另查看 6 张渲染快照。未构建/实机，历史 42 组及额外 8 组平台扩展仍待闭环。

- **09-10 用户管理确认与写操作生命周期已修订**：[操作审计](USER_MANAGEMENT_ACTION_LIFECYCLE_AUDIT_2026_09_10.md)。9931b584 固定控制器归属，退出后隔离确认/写回，同行占用覆盖确认、写入及刷新，取消或失败释放。新增 25 项、联合 127/127；测试初始化修正后 25/25 与三文件严格分析通过，相邻 102 项同生产输入复用。仅本地替身测试，云端权限和原生呈现待验；未构建/实机，宏观 42 组保持。

- **09-10 用户目录游标与搜索生命周期已修订**：[云端目录审计](USER_DIRECTORY_LIFECYCLE_AUDIT_2026_09_10.md)。81ef2df8 在用户及权限完整读取成功后提交游标，搜索等待在途分页并丢弃过时意图，退出隔离统计/权限续发与搜索 Timer。新增 18 项、联合 135/135；测试分析整理后 18/18 与两文件分析通过，相邻 117 项同生产输入复用。未访问真实账号或变更权限，云端规则及管理页写操作待续；未构建/实机，宏观 42 组保持。

- **09-10 收藏独立刷新与延迟同步生命周期已修订**：[收藏刷新审计](FAVORITE_REFRESH_LIFECYCLE_AUDIT_2026_09_10.md)。a2b755d1 保护启动 finally 和关闭后操作，暴露含锁等待的活动任务供布局/页大小等待，取消收藏快照遗留 Timer；保留未知状态预览与当前标签/删除合并规则。新增 19 项，联合 148/148；移除测试冗余导入后 19/19 与三文件严格分析通过，相邻 129 项同生产输入复用。未构建/实机，宏观 42 组保持。

- **09-10 本地外部快照与 IPTV 刷新生命周期已修订**：[本地刷新审计](LOCAL_REFRESH_LIFECYCLE_AUDIT_2026_09_10.md)。d8e2b737 共享初始加载、串行合并后续刷新，提示由任务终态完成；关闭后隔离迟到结果，页大小/布局等待快照，保留 IPTV 原序。新增 25 项（含实际 400↔900 视口）、九文件 129/129、三文件严格分析通过。收藏独立刷新及管理页云端请求待续；未构建/实机，宏观 42 组保持。

- **09-10 布局断点现等待在途分页任务再提交**：[布局事务审计](LAYOUT_PAGING_TRANSACTION_AUDIT_2026_09_10.md)。4b80212d 推迟模式/尺寸提交，返回原布局取消意图，退出隔离旧等待者；四类网络分页接入当前任务，含远程补数及原生目录重分页。新增 47/47（含真实 BasePageView 400↔900 视口）、同输入相邻 197 项与六文件严格分析通过。独立本地外部刷新待续；未构建/实机，宏观 42 组保持。

- **09-10 页大小选择与远程补数已纳入串行事务**：[页大小审计](PAGE_SIZE_TRANSACTION_AUDIT_2026_09_10.md)。bdd027f5 保留最后选择、请求终态后提交尺寸，刷新重新检查活动任务，补数与普通加载共用句柄，连通性期间重复加载更多不再跳两页。新增 22 项，联合 106/106、三文件严格分析通过；布局断点与管理页云端请求待续。未构建/实机，Android 152cf151 / Windows 2fb471d3 尚未包含，宏观 42 组保持。

- **09-10 固定与远程分页退出后续发/发布已修订**：[退出审计](FIXED_REMOTE_LIFECYCLE_AUDIT_2026_09_10.md)。c14a3e3c 在批次、部分错误、连通性和远程补数返回处保护页面生命周期，四个直播派生类同步保护标签/登录/排序副作用。新增 48 项、联合 84/84，类型清理后 48/48 及五文件严格分析通过。页大小并发与用户管理云端请求待续；未构建/实机，Android 152cf151 / Windows 2fb471d3 尚未包含，宏观 42 组保持。

- **09-10 全量目录分页退出后的迟到结果已隔离**：[生命周期审计](SERVER_ALL_LIFECYCLE_AUDIT_2026_09_10.md)。dfab7d41 修订公共分页及三个派生类：页面关闭后不再发布行/状态、完成刷新提示或写分类图片缓存；底层 Future 仍被观察至终态。23 项新增、八文件 72/72、五文件严格分析通过。Fixed/Remote 派生副作用待续；Android 152cf151 / Windows 2fb471d3 尚未包含本批，未构建/实机，宏观 42 组与 8 组未注册平台保持。

- **09-10 分类与失败恢复累计 Android 候选已归档**：[新候选](CATEGORY_RECOVERY_ANDROID_CANDIDATE_2026_09_10.md)。干净 152cf151 构建 arm64 Debug，288493053 B，签名/16 KB/资源/独立 SHA 通过；含最近四批分类与恢复修订，61 场景全 not-run，未安装。手机身份和旧 APK 哈希已复核，前台仍为其他应用；本轮未读取应用数据或重取备份。Windows 仍 2fb471d3，宏观 42 组与 8 组未注册平台保持。

- **09-10 刷新中的分类点击意图与提示归属已修订**：[时序审计](AREA_REFRESH_INTENT_AUDIT_2026_09_10.md)。f242428e 立即提交明确点击，避免目录在动画中返回覆盖新选择；本地切片不再结束活动刷新，涵盖 loading 标志尚未置位的连通性阶段。新增 6 项，定向 34/34、四文件严格分析通过；目标删除按既有规则回退，未构建/实机，宏观 42 组与 8 组未注册平台保持。

- **09-10 空快照失败恢复与导航保留已修订**：[恢复审计](RETAINED_PAGE_RECOVERY_AUDIT_2026_09_10.md)。42dd533b 让已发布空快照的错误/登录提示保留在有界提示区，保留横向页、调用者动作和刷新所有权；首次失败仍完整状态页，实际重试等待期间补齐进度反馈。新增 15 项，联合 197/197、三文件严格分析通过；本批未构建/实机，宏观 42 组与 8 组未注册平台保持。

- **09-10 分类目录刷新与控制器归属已修订**：[目录归属审计](AREA_TAXONOMY_OWNERSHIP_AUDIT_2026_09_10.md)。be97c366 修复外部选中/等数量替换仍指向旧页、目录清空未解绑，并在旧页卸载后释放移除分类控制器；新增 8 项含双宽度、连续替换及关闭页面，联合 182/182、双文件严格分析通过。原先重排成功路径保持；未构建或操作手机，宏观 42 组与 8 组未注册平台保持。

- **09-10 分类空页导航与位置恢复已修订**：[分类页审计](AREA_TAB_NAVIGATION_AUDIT_2026_09_10.md)。42456bbd 保留空分类横向页面、补齐空内容垂直刷新承载及平台/分类独立位置存储键；实际手势复现后修复，联合 174/174、夹具清理后新增 2/2 复验和双文件严格分析通过。无本批构建/实机；Android f5aab636 / Windows 2fb471d3 尚未包含，宏观 42 组与 8 组未注册平台保持。

- **09-10 两批 UI 累计 Android 候选已核验**：[候选审计](SHARED_UI_ANDROID_CANDIDATE_2026_09_10.md)。干净 f5aab636 构建 arm64 Debug，288491573 B，签名/16 KB/内容/独立归档通过，未安装；当前旧 APK 哈希匹配已验签备份，仅两项核心数据哈希复核，完整状态快照仍需安装前重取。新交接计划清理旧计数及 APK 引用残留，57 项全 not-run；Windows 仍待更新，宏观 42 组与 8 组未注册平台保持。

- **09-10 共用列表提示、状态恢复与分页布局修订完成**：[共用页审计](BASE_PAGE_LAYOUT_AUDIT_2026_09_10.md)。cacf5611 限制提示区占高、保留完整错误与正文位置，修复状态页下拉刷新接线和窄窗口分页栏；新增 25 项 Widget、联合 172/172、四文件严格分析通过。真实拖动、按钮、页大小与页码输入有本机证据；无本批构建/实机，Android d4adcb77 / Windows 2fb471d3 仍未含两批 UI 修订，宏观 42 组与 8 组未注册平台保持。

- **09-10 搜索页小高度与能力动作修订完成**：[搜索布局审计](SEARCH_PAGE_LAYOUT_AUDIT_2026_09_10.md)。31abc302 统一正文滚动、结果卡片自然高度及网页/重试能力判断；新增 62 项 Widget、联合 103/103、三文件严格分析通过。含中英文四视口六状态、末项/按钮可达、筛选排序与分页所有权；尚无本批构建或实机证据，Android d4adcb77 / Windows 2fb471d3 均未包含修订，宏观 42 组与 8 组未注册平台保持。

- **09-10 小红书累计 Android 候选与当前备份已核验**：[候选审计](XIAOHONGSHU_ANDROID_CANDIDATE_2026_09_10.md)。干净 d4adcb77 构建 arm64 Debug，288486345 B，签名/16 KB/内容/双语与独立归档通过；未安装。当前旧 APK 哈希匹配已验签备份，新取得两份一致状态快照，227 文件/9 数据库核验通过，迁移输入未变。候选 51 场景全 not-run，手机只读且等待前台窗口；19 直播站点 + IPTV、8 组未注册、宏观 42 组未闭环保持。

- **09-10 小红书真实短链与分享别名已接入**：[分享审计](XIAOHONGSHU_SHARE_LINK_AUDIT_2026_09_10.md)。127c5781 接通短链、dynpath/hina/裸域名与搜索，修复终端点段经 URI/标点处理被误接受；有界跳转不读取主页、笔记、无关或本地目标。214 项通过、末次 82 项复验、六文件严格分析通过，另有真实分享/搜索 1/1。未构建或操作手机；19 直播站点 + IPTV、8 组未注册、宏观 42 组未闭环保持。

- **09-10 小红书真实控制器原生录制两轮通过**：[原生审计](XIAOHONGSHU_CONTROLLER_NATIVE_AUDIT_2026_09_10.md)。4f84013d 探针使用实际注册适配器与录制控制器，两轮自动合并 MP4、完整解码、指标回写和资源释放通过；原生 1/1，最终单文件严格分析通过。预取选项开启但两轮均未准入，按原 relay 路径验收，不代表源完整性或 GUI/Android/长时通过。当前 19 直播站点 + IPTV、8 组未注册、宏观 42 组未闭环；候选、版本和手机保持。

- **09-10 小红书已接入应用，原生验收待续**：[应用审计](XIAOHONGSHU_APPLICATION_INTEGRATION_AUDIT_2026_09_10.md)。69f6db99接通精确房间查询、分享/收藏、质量线路与播放/录制解析，目录迁移12保持用户隐藏选择；320项定向通过，观看值空态末次31项复验及24文件严格分析通过。注册适配器生产探针1/1，HLS 200/426B/3分片；未原生播放或实录。当前19直播站点+IPTV、8组参考平台未注册，宏观42组未闭环。手机只读、候选和版本保持。

- **09-10 小红书公开分享与真实媒体取得进展**：[分享合同](XIAOHONGSHU_SHARE_API_AUDIT_2026_09_10.md)。3abad7a4新增当前SSR解析，区分下播页推荐与目标房间，保留访问条件及四源/一质量；最终124/124定向、五文件严格分析通过，另有生产元数据1/1。完整2秒HLS分片1080p H.264+AAC严格解码通过，仅为外部媒体证据，尚未应用注册或双端原生验收；9组未注册、宏观42组未闭环和候选保持。手机仅只读身份/前台核对，无接管或修改。

- **09-10 战旗当前H5配置优先级与真实画质矩阵已接入**：[播放器合同](ZHANQI_PLAYER_CONTRACT_AUDIT_2026_09_10.md)。7569e40d优先h5Cdns/cdns，保留禁用列并归并同CDN/后缀身份；134/134（含真实元数据1/1）与四文件严格分析通过。当前样本仅索引2、四单元/一源身份；公开访客签名成功但FLV404、调度节点DNS/代理连接失败，无有效媒体或原生PASS。9组未注册与宏观42组未闭环保持，手机仅只读核对、候选不变。

- **09-10 战旗底层元数据合同已接入，媒体仍待验证**：[战旗审计](ZHANQI_METADATA_API_AUDIT_2026_09_10.md)。659e4715 保留目录页号/总数、三种身份、可空昵称和平台声明状态，最终140/140定向与四文件严格分析通过；真实生产元数据1/1通过。两间status=4样本的声明HLS均404，未注册可播入口；一直播仅取得DNS/TLS访问失败，未判停运。手机只读核对后保持其他应用前台；9组未注册、宏观42组未闭环，候选和版本不变。

- **09-10 累计Windows候选2fb471d3与有限GUI冒烟通过**：[候选与设置持久化](HLS_WINDOWS_CANDIDATE_2026_09_10.md)。仅定点刷新失效MSVC运行库路径缓存，保留原构建门禁；Debug ZIP 142623043 B，构建150.569秒。独立实例首页、录制中心、超时15→30秒及正常退出后持久化通过，恢复15秒并结束两次进程。未进行GUI实录或完整发布门禁；手机只读核对一致，未安装或接管前台。Android仍fb106ed6未安装，宏观42组未闭环。

- **09-10 累计Android候选fb106ed6已构建并独立归档**：[候选核验](HLS_ANDROID_CANDIDATE_2026_09_10.md)。TTing与HLS保留/实际录制入口进入arm64 Debug，288457197 B、版本3.1.8+4121/Manifest6121；16 KB/内容/同证书/双语资源和复制后SHA通过，构建75.542秒。复用定向证据，未重跑完整发布门禁；44组候选原生场景全not-run，未安装、无手机/模块/发布操作，Windows仍f3de664a、宏观42组未闭环。

- **09-10 实际控制器原生录制与自动合并已补证**：[原生闭环增量](HLS_CONTROLLER_PREFETCH_AUDIT_2026_09_10.md)。9b8f29a8探针连续两轮用户启动/停止/重启，经真实Manager与自动合并均通过：各180V/282A包、MP4全解码、临时698420B正确回写648853B，目录/调度/池释放。原生1/1，修订工具静态标注后单文件严格分析通过；不是GUI/Android/长时验收，W3-05仍RUN。下一步累计Android Debug候选；本轮无手机或发布。

- **09-10 用户实际录制入口已启用有界HLS保留**：[控制器接线](HLS_CONTROLLER_PREFETCH_AUDIT_2026_09_10.md)。a10327be修订公共录制尝试入口，四项未启用红测转绿，七文件103/103及四文件严格分析通过；首次、手动重启、断流续接保留源策略，FLV/离线任务与未准入清单保持原路径。底层默认false未变，但应用录制入口现显式true；实际控制器原生链路/累计候选UI待验，本轮无手机、构建或发布，宏观42组未闭环。

- **09-10 新录制合同的完整实录链路已通过**：[接线验收](HLS_CAPTURE_CONTRACT_AUDIT_2026_09_10.md)。干净9571295f一次Windows原生实录1/1 PASS：24视频/24音频分片全部交付，48.517333秒MP4包数守恒并完整严格解码，停止排空6.785秒，结束重型进程0。显式开启预取不等于应用默认或GUI验收；W3-05保持RUN，下一步接通真实录制控制器策略。未操作手机、构建、发布或合并上游。

- **09-10 HLS验收改为源交付与成品时间线核对，不靠固定40秒猜测**：[合同审计](HLS_CAPTURE_CONTRACT_AUDIT_2026_09_10.md)。0a84b309 的41/41定向、三文件严格分析及三历史样本的5项正反判定通过：44.18秒完整样本通过新合同，缺18440、漏首音频、少计原始TS仍失败，去掉警告也掩盖不了未交付分片。历史FAIL原样保留，生产/默认值不变；新探针完整外部流程待验，无重录/手机/构建/发布，宏观42组未闭环。

- **09-10 HLS 下载阶段已可观测，真实停止排空取得完整交付证据**：[阶段审计](HLS_DOWNLOAD_PHASE_AUDIT_2026_09_10.md)。ce592868 的69项定向及最终8项诊断复验、六文件严格分析通过；本次停止时6个已准入 ticket 分别处于 loader/正文阶段，约8.1秒内全部完成，21视频/22音频分片连续交付。MP4与五份原始TS均完整解码，包数守恒；总长44.181333仍触发旧40秒门禁，因此整体仍FAIL，上次单片超时未记修复。下一步建立源清单与成品的内容守恒验收，保留旧缺片负例；无手机/构建/发布，宏观42组未闭环。

- **09-10 录制包边界检测已补齐，联合实录仍在停止交付门禁失败**：[时间线审计](MEDIA_PACKET_TIMELINE_AUDIT_2026_09_10.md)。9b8e40f5 的 20/20 定向和四文件严格分析通过；保留文件验证区分末包 PTS、真实包结束与轨内空档。一次当前真实录制确认首片 A/V 差吻合源 PDT，但停止 20 秒排空后视频 18440 未交付，尾部标记=true，正确记 FAIL；五段完整解码通过不抵消缺失 2 秒。源 TS 保留、未合并，继续查单 ticket 停止前下载状态；无手机/构建/发布，宏观仍 42 组未闭环。

- **09-10 HLS shortest 候选已验证会裁掉有效尾部，未加入生产**：[边界审计](HLS_SHORTEST_BOUNDARY_AUDIT_2026_09_10.md)。a46bccea 的四场原生控制、两文件严格分析与四份全解码/payload 核对通过：音频尾部减少 93 包，音轨先结束时视频尾部减少 61 包，四场仍需手动停止。首次提前退出假设失败独立留账，不计生产 Bug 修复或完整 A/V 验收；下一步区分原始保全与对齐导出合同。默认预取关闭，无手机/构建/发布，宏观仍 42 组未闭环。

- **09-10 HLS 刷新周期累积缺口已复现并修复**：[周期审计](HLS_RELOAD_CADENCE_AUDIT_2026_09_10.md)。40a2bf8c 的两个有效红测转绿：同一慢响应三秒窗口由首序号 0→3→6→10 丢9，改为 0→3→5→8 连续；按正文变化选择整/半目标周期，并扣除实际加载耗时，保持每 feed 单请求。163 项定向、三场原生控制、三文件严格分析、三份全解码/payload 通过。测试路径错误及电脑重启中断单独留账，恢复物理仓库别名后续跑未完成阶段。真实后续缺口的完整根因与 A/V 停止边界仍待验收；默认预取关闭，无手机/构建/发布，宏观仍42项未闭环。

- **09-10 HLS 后台刷新失败的停止漏报已修复**：[覆盖证据审计](HLS_REFRESH_COVERAGE_AUDIT_2026_09_10.md)。270a71f4 通过 80/80 定向、最终 11/11（含三场原生控制）、六文件严格分析及六份保留文件全解码/payload 对比；活动期后台 sequence-gap/HTTP 失败现于停止前发出一次覆盖警告并锁存终态，停止取消保持零误报，已发布缓存继续排空。补齐两处旧测试替身参数，失败阶段留账。此改动仅修复覆盖证据漏报，真实后续缺片和共同 A/V 停止边界仍待续；默认预取关闭，无手机/构建/发布，宏观仍 42 项未闭环。

- **09-09 已准入 HLS 缓存的原生起点桥接已验证**：[起点桥接审计](HLS_SELECTED_START_AUDIT_2026_09_09.md)。db0ad486 的 98/98 定向、七文件严格分析、3/3 原生文件测试（七场控制）与七份全解码通过。自动选中路径恢复 94 个音频前缀包，与显式零索引逐包一致；未准入自动路径保持原默认，调用方参数保持优先。仍有约两秒音轨尾差，后续刷新缺口和真实录制待续；默认预取关闭，无手机/直播重录/构建/发布，宏观仍 42 项未闭环。

- **09-09 HLS 原生起点已取得因果对照，生产策略尚未改动**：[起点/边界审计](HLS_NATIVE_START_BOUNDARY_AUDIT_2026_09_09.md)。83157905 的 3/3（两统计 + 四场原生）、两文件严格分析、四份全解码及 payload 比较通过。独立序号/3V4A 窗口下默认音轨缺 94 包、晚起约 1.984 秒；实验显式起点 0 恢复前缀，起点差约 21 ms，原视频 payload 不变，但音轨尾部仍多约两秒。共用序号对照还证明默认路径可同时跳过 60 个视频包；首次错误假设独立留账。下一步仅为真正准入的缓存接通 native 起点，并单独处理共同停止边界，未改全局参数/默认预取或真实时长门槛。无手机/直播重录/构建/发布，宏观仍 42 项未闭环。

- **09-09 HLS 初始两路串行等待缺口已复现并修复**：[读取时序审计](HLS_PREFETCH_PREPARATION_AUDIT_2026_09_09.md)。9ba022b2 仅并发获取已选中的最多两份初始清单，继续整批准入、共同取消和等待终态；两项有效红测转绿，61/61 定向、两文件严格分析、1/1 原生对照通过。真实采集约 29 秒首字节、四段与 MP4 合并完成，仍因 42.917 秒超过旧 40 秒门槛为 0/1；独立检查全文件解码通过、内部无明显 DTS 空档，但音频晚起 1.248 秒/尾部多 2.912 秒，停止前还记录后续序号缺口。下一步做 native 初始选片/共同 A/V 边界控制实验，未放宽门槛或重录。默认预取关闭，无手机/构建/发布；宏观仍 42 项未闭环。

- **09-09 LL-HLS 完整父分片已准入，真实录制仍未通过**：[LL 录制审计](HLS_LL_RECORDING_AUDIT_2026_09_09.md)。718cad56 完成五类 LL 元数据的有界校验、未完成 PART 前缀与完整父分片转换，本地只发布完整媒体，不宣称 PART 拼接或阻塞刷新。157/157 定向、1/1 原生固定对照通过；当前 20 份媒体清单全部准入，随后真实 Manager 两次均 0/1。新增脱敏失败诊断的 35/35 回归及 13 文件严格分析通过，定位第二次视频刷新为 retention/sequence-gap，实际有 TS 仍因覆盖不完整失败。下一步复现初始两路串行读取与短窗口滚动时序，不放宽校验、不盲目重录。默认预取保持关闭，无手机、构建或发布；宏观仍 42 项未闭环。

- **09-09 HLS DATERANGE 已接入生产保留与发布**：[事件审计](HLS_DATERANGE_AUDIT_2026_09_09.md)。e7240740 完成跨清单同 ID 增量、冲突原子回滚、END-ON-NEXT 后继、事件退休与总预算；另补十进制时间下界防止舍入过早退休。127/127 七文件定向通过，最终六文件严格分析及 36/36 事件回归、1/1 原生对照通过；源站关闭后 462 个音视频包与直连相同、完整解码通过。当前 TTing 24 份清单复验中，20 份媒体可解析，未处理标签由六类降至五类，仍未准入或真实录制 PASS。默认预取仍关闭，无手机、构建或发布；宏观仍 42 项未闭环。

- **09-09 TTing 真实预取未准入的原因已核实**：[准入诊断](TTING_PREFETCH_ADMISSION_AUDIT_2026_09_09.md)。5f71f3c4 的 3/3 定向、1/1 真实清单探针及三文件严格分析通过。24 份当前清单中，三档明确质量 root 可选两路，自动档多变体未准入；20 份媒体清单均因 DATERANGE/PART/PART-INF/PRELOAD-HINT/RENDITION-REPORT/SERVER-CONTROL 六类标签未进入保留路径。未下载媒体或重跑长录制；还确认当前竖屏源需要修订旧 height=720 验收假设。后续补协议合同与真实录制，宏观仍 42 项未闭环。

- **09-09 生产 BYTERANGE 输入原生对照通过**：[范围审计](HLS_BYTERANGE_NATIVE_AUDIT_2026_09_09.md)。82550a7f 单文件严格分析、1/1 原生探针通过；非零 MAP、同文件三片与隐式偏移正确，关闭源站后两轮缓存读取的 180 视频/282 音频包与直连一致，完整解码通过。此范围未发现生产缺陷，没有放宽校验或改默认值。真实 TTing/LL-HLS 与更广合同待续；无手机、构建、发布，宏观仍 42 项未闭环。

- **09-09 HLS 已发布预取分片的停止排空已修复**：[排空审计](HLS_PUBLISHED_DRAIN_AUDIT_2026_09_09.md)。56b139f3 的 240/240 定向、3/3 原生文件测试、两份全量解码及五文件严格分析通过；两个 HTTP 410 红测转绿。相同慢源两场景视频由 0–13 补齐至 0–17、音视频约 36 秒，尾部包时间差 1.633 ms、尾部丢弃=false；代价为停止约 8.2–8.5 秒，预算有限且完成即结束。仍未默认启用，真实 TTing/LL-HLS 与范围合同待续；没有手机、构建或发布，宏观仍 42 项未闭环。

- **09-09 HLS 预取已直接接入生产 relay，保持显式关闭默认值**：[生产接入审计](HLS_PRODUCTION_PREFETCH_AUDIT_2026_09_09.md)。5688d18c 的 234/234 定向、3/3 原生文件测试、两份全量解码和九文件严格分析通过；修复并发根清单覆盖，补初始 65 片保全、HEAD/精确范围及停止后缓存读取。真实 Manager 直连预取保持连续 0–13、约 28 秒视频，关闭后池零占用；音频约 36/34 秒，尾部偏差仍待处理，未记完整 A/V 或真实 TTing PASS。没有手机、构建或发布，宏观仍 42 项未闭环。

- **09-09 HLS 音视频原子准入已接通原生实验**：[准入审计](HLS_PREFETCH_PLAN_AUDIT_2026_09_09.md)。c2758d3a 的 113/113 定向、3/3 原生文件测试、两份全量解码及五文件严格分析通过。唯一明确组合从实际 master 解析，两份 snapshot 全体验证后才启动下载；第二路不支持时零选中/零下载，多变体不猜测质量。原生仍连续 0–13、约 28 秒视频，尾部丢弃未闭环。下一步接现有生产 relay，默认应用尚未启用；无手机、构建或发布，宏观仍 42 项未闭环。

- **09-09 HLS 停止冻结的两个时序缺陷已修复**：[冻结审计](HLS_PREFETCH_FREEZE_AUDIT_2026_09_09.md)。4e7a63d1 的 95/95 定向、3/3 原生文件测试、两份全量解码及三文件严格分析通过。未准入读取在冻结后及时返回，停止发布固定最后已提供的清单与 URI，未发布的新预取退休；两项有效红测转绿。原生仍连续 0–13、约 28 秒视频，但尾部丢弃/两层截止仍待协调，未记完整 A/V 验收。生产默认尚未接入，无手机、构建、发布，宏观仍 42 项未闭环。

- **09-09 HLS 独立预取已取得连续原生交付，默认生产接入待续**：[调度审计](HLS_PREFETCH_SCHEDULER_AUDIT_2026_09_09.md)。fc0fa50e 的 184/184 定向、3/3 原生文件测试、两份 TS 全量解码和九文件严格分析通过。同一 12 秒慢视频/6 秒窗口，body 与 headers 两场景均从旧基线 0→6 改善为连续 0–13、约 28 秒视频，关闭后池零占用；同时修复共享传输重定向 body 取消回归。实验适配层尚非默认生产接线，停止尾部仍丢弃且音频多约两秒，未记真实 TTing 或完整 A/V 验收 PASS。没有手机、构建或发布操作，宏观仍 42 项未闭环。

- **09-09 HLS 生产失败请求所有权已修复，预取共用传输已验证**：[传输审计](HLS_UPSTREAM_TRANSPORT_AUDIT_2026_09_09.md)。3a1647de 的 130/130 定向、3/3 滚动控制及 1/1 缓存原生、八文件严格分析通过。畸形请求头导致上游 TCP 遗留的红测转绿；日志不再输出头值异常全文，新增精确范围/压缩长度准入与单 ticket 取消。生产慢源仍序号 0→6，仅约四秒媒体；动态预取调度待接线。未操作手机、构建或发布，宏观仍 42 项未闭环。

- **09-09 HLS 保留清单已接通缓存原生读取验证，生产调度仍待接入**：[发布审计](HLS_RETAINED_PUBLICATION_AUDIT_2026_09_09.md)。16593295 的 70/70 定向、1/1 独立原生探针与四文件严格分析通过；关闭测试源站后，从八条完整缓存读取的视频 180 包、音频 189 包分别与直连参考一致。新增保留清单渲染，保持范围/MAP/密钥/断点；不计为慢源持续录制或 A/V 同步通过。没有手机、构建、发布操作，宏观仍 42 项未闭环。

- **09-09 HLS 未读响应取消已修复，预取所有权池已实现但尚未接线**：[取消/预取池审计](HLS_PREFETCH_POOL_AUDIT_2026_09_09.md)。109d5fb2 / 0eef1043 最终 69/69 定向、3/3 原生控制及七文件严格分析通过；第九个被拒响应的真实 TCP 红测转绿，其余八个请求保持。新池统一限额、完整后发布、读取租约及期限/取消，修订首轮迟到流泄漏。慢源仍只保留约 4 秒内容，继续清单/下载接线；无手机、候选或发布操作，宏观仍 42 项未闭环。

- **09-09 HLS 有界清单保留元数据层已实现，尚未接入下载**：[保留层审计](HLS_RETAINED_WINDOW_AUDIT_2026_09_09.md)。89879fc6 的 49/49（三文件）及两文件严格分析通过，覆盖滑动历史、双预算、范围/MAP/密钥归属、PDT/断点与失败刷新原子性；开发中的格式和 lint 失败独立留账。仅新基础组件，LL-HLS 标签合同、下载调度、缓存租约及 native 清单发布仍待接线，真实缺片未修复。无手机/构建/发布操作，宏观仍 42 项未闭环。

- **09-09 HLS 预取串行化已取得独立原生对照**：[响应头/预取审计](HLS_NATIVE_PREFETCH_AUDIT_2026_09_09.md)。22934f8f 的 3/3（两项统计 + 四场景原生实验）、单文件严格分析通过。直连早响应头可重叠请求，晚响应头和生产完整暂存均串行；强制开启 http_multiple 也未解决。直连仍跳片且取消有封装收尾错误，因此保留保护，下一步实现有界预取/清单保留。仅新增诊断，未操作手机、修改生产行为、构建或发布，宏观仍 42 项未闭环。

- **09-09 HLS 总预算与本地完整发布等待已协调**：[预算审计](HLS_BUDGET_COORDINATION_AUDIT_2026_09_09.md)。41b3bf8b / d9e1b613 最终 51/51 定向、2/2 原生控制及四文件严格分析通过；10 秒慢交付控制由零输出转为启动，四场景正常排空。真实 TTing 仍 0/1：首数据约 88 秒，两段共 5,224,144 B，虽解码通过，第一段音视频仍有空档、第二段无音频包。失败与夹具修订均保留；继续吞吐/预取及窗口协调，未记稳定录制 PASS。未操作手机、重建候选或发布，宏观仍 42 项未闭环。

- **09-09 HLS 上游响应体挂起已修订**：[空闲超时审计](HLS_BODY_IDLE_AUDIT_2026_09_09.md)。0664b540 对媒体暂存和清单按输入读超时检测真正空闲，两个有效失败转绿；44/44 定向、2/2 原生控制与两文件严格分析通过，真实 TCP 断开和 spool 清理验证。原生零输出场景本次触发约 7 秒强制取消兜底，差异单独留账；持续慢交付/本地预算仍待协调，未记稳定录制 PASS。未操作手机、重建候选或发布，宏观剩余不变。

- **09-09 活动录制缺片现已独立保存并提示**：[缺片审计](HLS_INPUT_COVERAGE_AUDIT_2026_09_09.md)。0c2fe8f4 的 147/147 定向与 2/2 原生控制、13 文件严格分析通过；三个慢场景各一次真实缺片事件，正常控制无误报，状态跨日志裁剪、终态、重连及 JSON 恢复保留，中英文大字号操作可达。旧测试接口遗漏已修订，中断的分析经进程确认结束后续接。实际慢采集仍缺内容，下一步继续读取预算/暂存协调；未操作手机、重建候选或发布，宏观剩余不变。

- **09-09 慢交付/短窗口已形成可重复原生控制**：[滚动 HLS 审计](HLS_ROLLING_DELIVERY_AUDIT_2026_09_09.md)。4d58ef49 的统计回归与四场景原生控制共 2/2、单文件严格分析通过。持续 12 秒交付的 2 秒分片在 10 秒预算下零录制；15 秒可启动，但 34 秒采集中只留约 4 秒内容且 video sequence 从 0 跳到 6。排除“扩大超时即完整录制”的结论；首次空 410 被计入媒体的汇总错误已单独修正。下一步补活动录制输入缺口的持久化和结果提示，并继续协调预算/暂存；未改生产逻辑、候选或发布状态，宏观剩余不变。

- **09-09 TTing 新增有界时序诊断，真实取证指向慢交付/短窗口与读取预算组合**：[交付审计](TTING_HLS_DELIVERY_AUDIT_2026_09_09.md)。最终 48 项定向通过，原生三场景对照保持原包数/时间线；真实短录仍 0/1、零录制文件，但完整保留 27 请求。2 秒视频分片完整交付耗时 10.251–17.544 秒，超过 6 秒清单窗口；native 约 10.14 秒后刷新，先于旧分片完整交付。本探针预算为 10 秒，应用默认为 15 秒，后续按真实设置做受控复现，不直接改时间戳或盲目延长。宏观剩余、候选和发布状态不变，未操作手机。

- **09-09 TTing 时间缺口已定位到合并前，真实采集根因继续追踪**：[逐包/受控审计](TTING_CMAF_TIMELINE_AUDIT_2026_09_09.md)。原始 TS 已有约 10.18 秒的视频晚起点、音频 5.97 秒及视频 4.26 秒内部空档，MP4 包数与两段总数一致。df4dbefe 的一个原生测试覆盖三种 CMAF 场景并通过，单文件严格分析通过：仅延迟响应保持约 21 ms 起点差，视频清单少前 10 秒才出现约 10 秒差。首次夹具 EOF 断言修订独立保留，未改生产逻辑。下一步补真实清单范围和交付时序，不硬改时间戳；宏观剩余、候选与发布状态不变，未操作手机。

- **09-09 TTing Windows 原生短录暴露待修问题**：[原生审计](TTING_NATIVE_RECORDING_AUDIT_2026_09_09.md)。50b06c8e 两次在线采集目标均 0/1：复验首个非零文件采样约 75 秒，进度滞后，停止后才形成两段。保留 TS 的生产合并和完整解码 1/1、最终单文件严格分析通过，但 MP4 视频晚起约 10.18 秒、末尾音频覆盖不足，未记完整录制 PASS。下一步对照逐包时间线与受控 HLS；不再盲目延长或重录。[Bigo/浪 Live 访问补查](BIGO_LANGLIVE_ACCESS_AUDIT_2026_09_09.md)另记。仍为 18 直播站点 + IPTV、9 组未注册、42 大项未闭环；未操作手机、重建候选或发布。

- **09-09 Bigo 目录与登录状态底层 API 已验证，仍未注册**：[元数据审计](BIGO_METADATA_API_AUDIT_2026_09_09.md)。cf704d5f 修订真实目录可空封面，保留身份与登录要求，不把 gated alive=0 误报下播；最终 78/78（含生产 Dio 探针 1/1）、三文件严格分析通过。实时目录 20 房间、所选 owner 匹配，尚无有效媒体/原生播放或录制证据。当前仍 18 直播站点 + IPTV、9 组未注册、42 大项未闭环；没有构建、安装或操作手机，候选不变。下一步补媒体合同与后续应用接线。

- **09-09 TTing/FLEX 真实生产链路已补证**：[生产 relay 审计](TTING_PRODUCTION_RELAY_AUDIT_2026_09_09.md)。34833223 opt-in 探针以注册适配器和真实 Dio 经 Clash 运行，目录 7 房间、当前 ncp_llh 四档共 24 份主/子列表成功，录制解析/recovery/分享/刷新匹配，1/1 通过；最终单文件严格分析无问题。初次分析两项提示与后续纯静态修订独立记录，没有重复网络验证。未读取媒体分片、未原生解码或录制成品，候选与历史 42 大项不变；README、能力表和差距表已同步当前 18 直播站点 + IPTV、9 组未注册及不同候选 SHA。下一步继续剩余平台和原生验收，整体验收未完成。

- **09-09 TTing/FLEX 应用入口已接通，原生验收待续**：[应用审计](TTING_APPLICATION_INTEGRATION_AUDIT_2026_09_09.md)。452fadaa 注册有限公开目录、精确频道查询、收藏分享、源策略/续签和录制解析；23 文件 201/201、24 个改动 Dart 文件 fatal-infos 分析无问题。两项首轮录制夹具参数错误独立保留，未改变生产排序规则。当前 **18 个直播站点 + IPTV、9 组参考平台未注册**；历史 42 大项未闭环。手机型号/代号一致，本机 MT 转发恢复、26 工具 schema 已读，未打开或修改 APK、切换前台或安装。候选仍 bee143e2 / f3de664a，不包含本批；下一步补生产适配器在线探针和累计原生验收。下方数量及待办为各批历史快照。

- **09-09 录制源策略元数据接线已完成**：[接线审计](RECORD_SOURCE_QUERY_METADATA_AUDIT_2026_09_09.md)。a82f6d37 将精确 URL 策略沿公共正常/recovery 解析、录制筛选/cursor/续租、控制器和 FFmpeg manager/service 传至 relay；八文件 105/105、八文件 fatal-infos 分析无问题。两次夹具错误独立保留，没有改动平台资格检查。没有原生解码/录制成品、手机或构建操作；播放器/多画面源所有权接线及 TTing 注册仍待继续，候选与历史 42 大项不变。

- **09-09 HLS 单源参数传递能力已加入**：[源级策略审计](HLS_SOURCE_QUERY_POLICY_AUDIT_2026_09_09.md)。b68a0f10 为后续 TTing/FLEX 接入增加显式同源目录 token 策略，保留普通 HLS 行为；策略与真实 loopback 链路、停止、Cookie 相邻回归 67/67。两项分析提示经纯语法/导入修订后，四文件 fatal-infos 分析无问题。应用播放/恢复/多画面/录制元数据接线与 TTing 注册尚待完成，平台数量、候选和历史 42 大项不变，无设备操作。

- **09-09 屏蔽管理布局与删除身份已修订**：[管理页审计](SHIELD_MANAGEMENT_AUDIT_2026_09_09.md)。3937b252 修订长词/滑条标题溢出和旧索引误删三类上游遗留根因，9 个有效红项转绿，四文件 44/44、四文件 analyze 通过。扩展夹具的懒构建查找错误独立记录；无手机、构建或发布操作。现有候选不含本批，历史 42 大项与 A4-02 原生状态不提升，下一累计候选补界面验收。

- **09-09 弹幕长按动作与关键词弹窗已修订**：[动作审计](DANMAKU_ACTIONS_AUDIT_2026_09_09.md)。ffd16158 修订提前释放、长消息菜单不可达和旧行 context 失效三处上游遗留；5 个有效红项转绿，五文件 32/32、两文件 analyze 通过，含复制/取消/屏蔽/真实文件重开/双语键盘布局。首轮夹具 I/O 超时独立保存，不计产品缺陷。未构建或操作手机，现有候选不含本批，A4-02 与历史 42 大项不提升；继续屏蔽管理与累计原生验收。

- **09-09 TTingLive / FLEX TV 公开链路已补证**：[合同审计](TTING_PUBLIC_CONTRACT_AUDIT_2026_09_09.md)。Clash 下主目录、频道/主播/广播身份、新旧 API 样本、三档 HLS 及 64 KiB TS 前缀取得一致证据；依据官方 NCP 播放器补齐 token 后，原子列表 403 转为 200。只有公开取证，没有生产适配器、原生解码或录制 PASS；仍为 17 直播站点 + IPTV、10 组未注册。弹幕测试进程继续，夹具超时单独处理。

- **09-09 Issue 增量已只读核对**：[增量审计](ISSUE_AUDIT_2026_09_09.md)。open 筛选仍为维护仓库 0、上游 16，编号无新增；#849 多出两条运行库讨论，但没有当前维护候选的故障复验或另一报告者恢复确认，继续区分环境建议和完成证据。未修改 Issue、系统运行库或设备；弹幕动作测试沿原进程等待资源，不新增原生 PASS。

- **09-09 弹幕恢复按钮本地化越界已作源码修订**：[布局审计](DANMAKU_RESUME_LAYOUT_AUDIT_2026_09_09.md)。f35e605 的四组有效布局红项转绿，四文件 19/19 和两文件 analyze 通过；保留大字号、完整计数、冻结偏移及一次点击追平，短桌面按钮不拉满。上游遗留布局问题，未同步上游。未构建或操作手机，bee143e2 候选不含本批；A4-02 和历史 42 大项未提升，下一次累计候选补原生布局验收。

- **09-09 OPENREC / Picarto 累计 Android 候选已核验归档，未安装**：[候选审计](OPENREC_PICARTO_ANDROID_CANDIDATE_2026_09_09.md)。干净 bee143e2 完成 2492/2492 完整测试、42/42 公共接口（9 个既有平台）及全量分析；288,245,662 B arm64 Debug 的内容、16 KB、签名、完整双语资源和归档哈希通过，旧 1d318bba 保留。38 组绑定新包的原生场景全部待验，覆盖安装前重查当前证书及一致备份。源码仍为 17 个直播站点 + IPTV、10 组未注册，历史 42 大项未闭环；Windows 仍 f3de664a，无手机操作或发布。下方候选与数量为各批历史快照。

- **09-09 Picarto 请求收尾与总时限已修订**：[生命周期审计](PICARTO_RESPONSE_LIFECYCLE_AUDIT_2026_09_09.md)。cd1e3126 以独立运输令牌修复 HTTP 错误/超限的上游遗留、连续小块越过总预算，并统一取消优先级及 UTF-8 字节预算。7 项有效失败转绿，九文件 267/267、两文件 analyze 通过；没有操作手机或增加原生 PASS。下一步将 OPENREC 接入与本修订纳入一次累计 Android 候选门禁/构建，仍为 17 个直播站点 + IPTV、10 组未注册、42 大项待闭环。

- **09-09 OPENREC / mellow-fan 源码已注册，在线整链仍待验**：[应用审计](OPENREC_APPLICATION_INTEGRATION_AUDIT_2026_09_09.md)。实现 70a78805，接通复合身份收藏/分享、真实 HLS 画质、共享播放器/FFmpeg 请求头及配置迁移。24 文件 291/291 回归、27 文件及最终探针分析通过；DIRECT 诊断目录 200 但无可选卡片，Clash 目录 403，两条注册适配器生产探针均 0/1，未伪报为通过。当前 **17 个直播站点 + IPTV，10 组参考平台未注册**；历史矩阵仍 42 大项未闭环。未构建、安装或操作手机，无原生 PASS 增量。下方数量为各批历史快照。

- **09-09 OPENREC / mellow-fan 底层 API 已验证，应用接入待续**：[合同审计](OPENREC_API_AUDIT_2026_09_09.md)。实现 37bdd9c9；按公开频道 ID 与数字身份核对当前广播，保留三种 HLS 源族及必要请求头。真实响应暴露 limit 不保证页长，已改为明确空页才结束。最终 30 项定向 + 1 项直连生产探针通过、三文件分析无问题；Clash 目录生产探针仍为 access 失败，媒体列表 200 不等于完整代理链路通过。仍为 16 个直播站点 + IPTV、11 组未注册，无构建、设备操作或原生 PASS 增量。

- **手机升级前备份及真实数据本地迁移已核验，尚未安装**：[备份演练审计](ANDROID_SCHEMA7_BACKUP_REHEARSAL_2026_09_08.md)。身份匹配，实际安装 APK 哈希对应 80b7431c，与候选 1d318bba 同证书；227 个文件两份快照一致、9 库完整性通过。真实 schema 6 的 143 频道/13,421 节目/42 映射在生产代码本地升至 7 后整表校验和重开通过（1/1、单文件 analyze 通过）。手机前台为哔哩哔哩，未唤醒/输入/安装，待确认切换窗口；32 组原生场景与历史大项状态未提升。

- **花椒与响应收尾累计 Android 候选已归档，未安装**：[候选审计](HUAJIAO_ANDROID_CANDIDATE_2026_09_08.md)。干净 1d318bba 通过 2418/2418 完整测试、42/42 公共接口和全量分析；288,202,501 B arm64 Debug 的内容、16 KB、签名、双语资源和归档哈希通过。Android 最新候选更新为 1d318bba，Windows 仍 f3de664a；32 组候选原生场景待验，覆盖安装前仍需一致 DB 备份。未操作手机、未发布、无原生 PASS 增量；下方各批候选和数量是历史快照。

- **花椒应用入口与游标接入已完成，原生验收继续**：[应用审计](HUAJIAO_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)。按目录/刷新缓冲隔离原生游标，接通 UID 收藏、主播/广播分享、配置迁移与播放/录制恢复。18 文件累计 287 项闭环，最终两文件 34/34、改动 Dart 分阶段分析通过；真实注册适配器探针结果见审计。当前源码 **16 个直播站点 + IPTV、11 组参考平台未注册**；未构建、操作手机或新增原生 PASS。下面各批数量保留为历史快照。

- **五平台响应收尾已统一，四平台源泄漏与持续读取期限已修订**：[生命周期审计](PLATFORM_RESPONSE_LIFECYCLE_AUDIT_2026_09_08.md)。a482e576 以独立请求令牌修订映客/克拉克拉/猫耳/TwitCasting 的错误、超限及期限退出，花椒复用同一作用域；调用方和并行请求保留。9 项有效红测转绿，六文件 195/195、七文件 analyze 通过。未构建或操作手机；旧候选不含修订，下一步恢复花椒应用接入，无原生 PASS 或发布增量。

- **花椒公开合同与底层 API 已验证，应用接入待续**：[花椒审计](HUAJIAO_API_AUDIT_2026_09_08.md)。真实响应复现并修订地理 point 误过滤、空标题和缺广播哨兵；真实 Dio 适配器回归补齐请求级取消收尾。34/34 定向、三文件 analyze、生产 API 1/1 通过；两页原生游标和 UID→当前广播→HLS/FLV 匹配已验。尚未平台注册、构建或原生验收，仍 15 直播站点 + IPTV、12 组未注册。下一步核验相邻 API 的同类流收尾，再接入花椒导航/收藏/播放录制。

本页用于回答剩余范围，避免从大量历史增量日志推测完成度。详细过程仍在 [验收入口](ACCEPTANCE_3_2_0.md)。**全目标未完成，正式版本未发布。**

## 当前可证明的状态

以下表格为本次核对的当前状态；后续阶段记录按各自日期解读，不再把其中的“最新”作为当前候选指针。

| 项目 | 当前证据 |
| --- | --- |
| Android 最新本机构建/原生输入 | `52e25b82` 的 R8 Release 测试包，3.1.8+4121 / Manifest 6121，127835744 B，SHA-256 `4BF85571…6B82`；使用 Debug 证书并标记 `debug-signed`，已覆盖安装并完成公共分享及 DocumentsUI 外部发送验收，尚未发布 |
| Android 当前编号账本 | 46 行：16 PASS / 30 RUN / 0 NR；每行仍含多个动作和平台组合，旧包证据不自动覆盖当前源码 |
| Windows 最新归档 | `2fb471d3` Debug；尚未纳入之后的小红书、搜索/共用页、分类及分享修订 |
| 手机快照 | 2026-09-13 08:32 +08:00，25102RKBEC / myron；顶层 `com.miui.home`，Pure Live 已停止，stay-awake 为 0 |
| 当前安装 APK | 版本 3.1.8 / 6121，设备 `base.apk` SHA-256 精确等于 `4BF85571…6B82` Release 测试包；正式签名候选仍待生成 |
| 数据恢复条件 | 最新 DocumentsUI 轮次先备份规范 Hive 与完整 IPTV 树，结束后按元数据/逐文件 SHA 精确恢复；外部夹具精确删除，首次安装时间保持 `2026-07-21 18:07:53` |
| 总体范围 | 当前 **21 个直播站点 + IPTV，6 组未注册**；历史大组 20 PASS / 42 RUN / 0 NR |

### 以下为历史阶段记录

- **含六批 IPTV/EPG 数据修复的 Android 候选已归档，未安装**：[数据链路候选](IPTV_DATA_ANDROID_CANDIDATE_2026_09_08.md)。干净 c97a61aa 完成 2313/2313 测试、42/42 接口与全量 analyze；288,174,752 B arm64 Debug 的内容/16 KB/签名/全文案/归档哈希核验通过。Android 最新输入更新为 c97a61aa，Windows 仍 f3de664a；25 组候选场景待验，安装前需一致 DB 备份，schema 7 实机迁移未执行。版本仍 3.1.8+4121，无原生 PASS 或发布增量。下方未构建描述保留为历史阶段。

- **M3U 元数据、损坏列表及旧频道身份已修订**：[解析审计](M3U_PARSER_AUDIT_2026_09_08.md)。e48e552d 保留末属性、带逗号的频道名和 EXTGRP 分组，有解析错误时保留原列表；解析升级后的唯一流地址匹配保留旧频道 ID/收藏，TVG 冲突和歧义不猜配。32 项 parser + 7 项真实导入新增回归，十二文件 226/226、五文件分析无问题。当前未构建上机；下一步累计 Android 候选完整门禁和构建，原生仍 42 个大项待闭环。

- **IPTV 覆盖导入、持久身份与缓存归属已修订**：[覆盖审计](IPTV_REPLACEMENT_AUDIT_2026_09_08.md)。443b0d1e 保留来源设置、可明确匹配频道的收藏和引用，SQL 失败保留旧数据，真实同步等待精确来源快照；共享文件 URI/分隔符误删也已补红测修复。46 项新回归、十一文件 187/187；完整分析单条 info 修订后四文件分析无问题。未打包上机；下方覆盖导入待修描述为历史状态，剩余 M3U 解析边界和累计 Android 候选继续，宏观仍 42 项待闭环。

- **IPTV 自动 EPG 映射保留与事务已修订**：[映射审计](IPTV_MAPPING_TRANSACTION_AUDIT_2026_09_08.md)。14082d5b 保留锁定/非自动映射，空输入不删除，失败或过期来源工作回滚；唯一匹配避免空名和歧义误配。8 项有效红测转绿，26 专项、十文件 141/141 和完整 analyze 通过。未构建上机；覆盖导入的来源/频道重建和缓存覆盖是独立待修风险，没有记为完整导入通过。

- **EPG 跨来源频道身份和旧库迁移已修订**：[身份审计](EPG_SOURCE_IDENTITY_AUDIT_2026_09_08.md)。25b11759 隔离同 raw ID 的频道/节目，房间与播放器按所选来源解析；schema 7 事务迁移保留设置、映射与预约字段。六项有效红测转绿，九文件 115/115；单项测试 lint 修正后 24/24 与七文件分析通过。未打包上机，安装前待一致数据库备份；下一步 IPTV 真正覆盖导入/文件归属，不增加原生 PASS。

- **EPG真实导入的事务、编码与网络收尾已修订**：[本批审计](EPG_IMPORT_TRANSACTION_AUDIT_2026_09_08.md)。c6c2495b修复UTF-8乱码、覆盖时重置开关、迟发写入失败留下半批数据、查询参数格式识别和下载残留；实际同名确认/返回也已验证。38项直接HTTP/SQLite/Widget、最终七文件88/88及全量analyze通过；手机/原生PASS无增量，现有APK不含本批。下一步跨来源频道ID和IPTV覆盖导入，不重复构建。

- **IPTV初始化失败反馈与离页保护已修订**：[初始化审计](IPTV_INITIALIZATION_AUDIT_2026_09_08.md)。a14aa84e接住读库/默认导入异常，默认来源未就绪提供重试，离页不发起后续页面查询；显式重试互斥、等待中新选择和手动导入恢复均有回归。41项页面加相邻48/48、全量analyze通过；b68c81d1 APK不含本批，下一步真实导入器的临时DB/HTTP核验，无手机或PASS增量。

- **含三批IPTV修复的新Android候选已归档，未安装**：[候选审计](IPTV_ANDROID_CANDIDATE_AUDIT_2026_09_08.md)。干净b68c81d1完成2129/2129测试、42/42接口及全量analyze；288,144,953 B arm64 Debug的内容/16 KB/签名/新增文案/归档SHA通过。最新Android输入取代96673538，Windows仍f3de664a；19组候选专项待验，无原生PASS增量，版本3.1.8+4121、未发布。下方未构建描述属于历史阶段，以本项为最新。

- **EPG来源选择生命周期与窄屏修复**：[选择审计](IPTV_EPG_SELECTION_AUDIT_2026_09_08.md)。98528ae1把加载/失败/空结果分开，取消或离页后的旧查询不再打开窗口，重复打开/重试各只读一次，标题64像素溢出消除；中英文大字体20项实际滚动选择通过。31项页面与相邻共38/38，全量analyze无问题；三批IPTV修订待累计构建，原生/真实导入与全平台3.2.0继续。

- **IPTV网络导入弹窗与提交已修订**：[异步导入审计](IPTV_NETWORK_DIALOG_AUDIT_2026_09_08.md)。9e2ad351/ad72f8d6修复输入关闭提前释放、重复提交及迟到结果关闭错误路由；关闭在途窗口会明确提示导入继续，同页阻止重复，失败保留草稿，刷新失败不误报导入失败。21项真实页面、相邻共28/28通过；全量分析单条unused import已清理，两文件复查无问题。未打包/上机，EPG来源选择及真实导入链路继续。

- **IPTV设置弹窗修复，尚未打包**：[页面审计](IPTV_SETTINGS_DIALOG_AUDIT_2026_09_08.md)。75978897修复UA弹窗提前释放、保存副标题不刷新及UA/同步间隔大字体溢出，补EPG导入双语文案；12项真实页面加相邻合同共19/19、全量analyze通过。现有Android96673538/Windowsf3de664a不含修订；下一批继续网络导入/来源选择的异步与交互验证，无原生PASS或发布增量。

- **包含录制修复的 Android 候选已归档，未安装**：[累计候选](AVC_STOP_ANDROID_CANDIDATE_2026_09_08.md)。干净96673538完成2098/2098测试、42/42接口及全量analyze；288,139,348 B arm64 Debug APK的内容、16 KB、签名与归档SHA均通过。包含26de4378/1abbff9a，取代ae5232b2作为最新Android输入；16组累计原生场景待验，手机/UI/PASS无增量，版本仍3.1.8+4121。以下历史阶段描述以本项为最新状态。

- **FLV AVC 尾部边界已修订，双协议原生短录复测通过**：[边界审计](FLV_AVC_STOP_BOUNDARY_AUDIT_2026_09_08.md)。52 项定向、五文件 analyze、正常/补帧/停滞/EOF 四原生对照通过；不改写媒体字节，沿原 3 秒预算完成画面或保留坏源。真实克拉克拉 HLS 32.872 秒、FLV 28.933333 秒均全解码退出 0、错误为空。1abbff9a 尚未新构建；ae5232b2 不含本批修复，下一步更新累计候选，没有手机操作、GUI 大项 PASS 或发布增量。

- **克拉克拉 FLV 实测发现尾部缺帧，源分片误删保护已修订**：[原生与边界审计](KILAKILA_NATIVE_TAIL_AUDIT_2026_09_08.md)。HLS 同一成品以保留时基全解码通过；FLV 的 picture+SEI 完整标签尾部可离线复现缺帧。65/65 定向、三文件 analyze、真实原生正常/坏源保留对照通过；修复的是错误识别与源保留，不是 FLV 媒体质量。26de4378 未新构建，ae5232b2 不含本修订；没有手机操作、UI PASS 或发布，下一步修复访问单元尾部。

- **修复后的 Android 候选已全量验证并归档，未安装**：[新候选审计](KILAKILA_FIXED_ANDROID_CANDIDATE_2026_09_08.md)。干净 ae5232b2 完整 2087/2087 测试、42/42 接口、全量 analyze 通过；288,134,508 B 的 arm64 Debug APK 已核对 16 KB/资源实际文案/签名/归档 SHA，包含萌星目录修复。旧 8ea62ac6 继续保留为暂缓安装的历史包；此包现为历史输入，最新 Android 候选见本页首项，Windows 仍 f3de664a。15 组累计原生场景待验，没有手机操作或 PASS 增量，版本仍 3.1.8+4121，未发布。

- **克拉克拉萌星目录真实遗漏已修订，旧候选暂缓安装**：[修订与候选审计](KILAKILA_RISING_STAR_AUDIT_2026_09_08.md)。现网 107 分类各页实际有 10 个 dataType=2 在播房间，旧过滤把它们变成空目录；4 个有效红项随 224 项回归转绿，三文件 analyze 和真实 10 条萌星卡片探针通过。原 8ea62ac6 已完成 2081 项完整门禁及 arm64 APK 构建/归档，但不含修订，明确标记暂缓安装；下一步从修订后的源码重建。没有手机操作、原生 PASS 或发布增量，平台数量仍 15 个直播站点 + IPTV、12 组未注册。

- **克拉克拉已完成应用注册，原生验收继续**：[应用审计](KILAKILA_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)。热门/新人原生分页、UID 收藏、分享、目录迁移、共享请求头与播放/录制恢复接通；369/369 定向回归通过，测试/探针两处 lint 修订后 46/46、20 文件 analyze 和真实注册适配器探针 1/1 通过。源码为 **15 个直播站点 + IPTV，12 组参考平台未注册**。未新构建、操作手机或增加原生 PASS；下面各阶段的平台数量与未注册描述保留为当时快照，以本项和文末为准。

- **克拉克拉公开分享解析及 UID 衔接已实现**：[分享审计](KILAKILA_SHARE_LINK_AUDIT_2026_09_08.md)。121/121 定向回归、四文件 analyze、真实官网 302 分享→广播→主播探针通过；独立 .NET 夹具和新旧编码参数验证，首次路径规范化反例已修订。仅新增 PointyCastle 4.0.0，无其他依赖升级。尚未平台注册、构建或原生验收，未注册分组仍 13；下一步进入应用接入。

- **克拉克拉 UID 定位链路已补齐，应用接入继续**：[身份审计](KILAKILA_OWNER_IDENTITY_AUDIT_2026_09_08.md)。官网主播主页与当前广播分别解析，每次重新定位并核对房间/主播，空卡片与失败分开；62/62 定向回归、最终三文件 analyze 和生产 API 探针 1/1 通过。新版分享的一条独立解码/签名证据已取得，应用解析尚待实现。未平台注册、构建或操作手机，未注册分组仍 13，原生计数不变。

- **累计 Android 候选已通过完整门禁并归档，未安装**：[候选审计](CUMULATIVE_ANDROID_CANDIDATE_2026_09_08.md)。干净 `3a7716b0` 全量 1943/1943 测试、42/42 接口探针、全量 analyze 和 APK 16 KB/资源/签名/SHA 核验通过；APK 287,151,530 B，版本仍 3.1.8+4121。纳入近期目录刷新、映客、YY、CC 等累计源码修订。三处门禁问题与失败记录已保留；接口探针不代表新总目录或浏览器原生验收。Android 最新候选更新为本项，Windows 仍 f3de664a；没有手机操作或原生 PASS 增量。下方“未构建”等描述保留为各批当时状态。

- **CC 总目录已完成源码接入，候选实测待补**：[总目录审计](CC_CATALOG_INTEGRATION_AUDIT_2026_09_08.md)。读取官方配置得到 20 分类 + 3 房间/专题入口，保留数字收藏 ID；网页入口明确标注浏览器动作，错误不再变成四空页，刷新保留最新标签选择。62/62 定向回归、八文件最终 analyze 通过；测试路由夹具和一处冗余 import 已分别修订记录。未新构建、操作手机或发布，原生验收数量不变。

- **CC 分类界面漏房间已修订**：[控制器审计](CC_CATEGORY_CONTROLLER_AUDIT_2026_09_08.md)。实际页面绑定复现 30 条响应只显示 20 条后跳过尾部，3 个红项随 85 项定向回归转绿；分类专用原生分页复用有界缓冲，支持两端切页/改数量、失败刷新与重试。四文件 analyze 通过；未改推荐页、总目录或设备，历史验收计数不变。

- **CC 分类房间分页已修订，总目录迁移继续**：[本批审计](CC_MIGRATION_AUDIT_2026_09_08.md)。旧实现每页重复 SSR 首屏；现按真实分类 API 的 start/size 获取，旧收藏数字 ID 不变，错误结构不当空页、视频不冒充直播。10 个红项转绿，20/20 回归、三文件 analyze 及真实 API 探针通过。官方 23 项入口和旧目录 JSON 内嵌 HTML 已取证，尚未完整接入新分类/专题导航；没有构建、设备操作或发布。

- **YY 外部打开及相邻启动异常已源码修订**：[本批审计](ROOM_EXTERNAL_OPEN_AUDIT_2026_09_08.md)。真实菜单方法的空 URL、抖音/虎牙缺少弹幕元数据和浏览器二次异常共 9 个红项转绿；五文件 79/79 回归通过，覆盖 14 站点网页、Android 深链处理、重复输入和房间替换归属。原生菜单→浏览器仍待验，当前 Android/Windows 候选未包含本批；CC 分类迁移保持待处理，历史验收数量不变。

- **最新 Issue 增量已核对**：[09-08 审计](ISSUE_AUDIT_2026_09_08.md)。open 筛选返回维护仓库 0、上游 16，新增 #857 YY 外部打开和 #855 CC 入口迁移；YY 当前源码遗漏对应分支，CC 分类返回迁移后的 HTML 而部分后台仍响应，均待处理。#849 新增一位报告者修复 VC++ 后恢复的证据，不代表其他报告者或全部启动问题关闭。没有新增原生验收、发布或手机操作。

- **克拉克拉底层 API 已实现，尚未应用注册**：[API 审计](KILAKILA_API_AUDIT_2026_09_08.md)。33/33 确定性回归通过，首轮两个花括号 lint 修订后最终三文件 analyze 无诊断；真实生产 API 探针 1/1 通过，两页各10房间、推荐1条、FLV/HLS解析与同房间重新请求成功。广播/主播身份、分页、元数据/媒体和错误分类分开；尚未原生解码。下面“尚无应用实现”是此前输入取证阶段的历史快照，未注册分组仍为 13。

- **下一参考平台克拉克拉已取得独立公开输入证据**：[合同审计](KILAKILA_PUBLIC_CONTRACT_AUDIT_2026_09_08.md)。目录两页各12条、显式 isLastPage、匹配免费房间详情、新旧主机及 HLS/FLV 有界采样已核对；历史回放业务错误与当前下播分开，分享跳转尚待解析/渲染验证。尚无应用实现或原生解码，未注册分组仍13；没有新增构建或设备操作。

- **映客已应用注册，原生验收继续**：[应用审计](INKE_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)。热门/分类有限精选说明、配置迁移、分享、播放请求头、严格录制地址与恢复已接入；147/147 首批回归、19 文件 analyze、真实公开生产解析探针通过，配置落盘重开、官网链接和实际搜索补测首轮发现一处遗漏，修订后 14/14 及五文件 analyze 通过。当前源码 **14 个直播站点 + IPTV，13 组参考平台未注册**。没有新候选或手机操作；下方平台数量为各阶段历史快照，最新计数以本项和文末为准。

- **映客底层公开 API 已有源码与实测证据，尚未平台注册**：[接口审计](INKE_PUBLIC_CONTRACT_AUDIT_2026_09_08.md)。确认参考的布尔状态/详情媒体结构与现网不同；新 API 区分在线元数据、有限官网精选和媒体缺失，按 UID+广播 ID 配对公开 FLV，不伪造画质或观众数。26/26 确定性测试通过，补两处括号 lint 后复用；三文件 analyze 无诊断、真实生产 API 探针 1/1 通过，另有 64 KiB AVC/AAC FLV 前缀。尚未接入导航、设置迁移、播放/录制解析或原生验收，未构建；13 直播站点 + IPTV、14 未注册参考分组的口径不变。

- **原生目录刷新快照已作源码事务化修订**：[本批审计](DIRECTORY_REFRESH_TRANSACTION_AUDIT_2026_09_08.md)。第三页刷新挂起/失败时，旧卡片、页码、总数及缓存保持一致；新目录单独构建，成功或合法空页才替换，失败重试继续新游标，显式回看/改条数仍使用旧目录。5 个有效红项转绿，七文件 114/114（含目录 48 项）与两文件 analyze 通过，覆盖实际桌面刷新/重试按钮、离线、容量及在途取消。尚未新构建或原生验收；Android 最新候选仍 58546f51、Windows 仍 f3de664a，均不含本批修订，未发布。

- **原生目录恢复与网络回调归属已进入 Android 累计候选**：[本批审计](DIRECTORY_RECOVERY_AUDIT_2026_09_08.md)。真实错误按钮不再从第一页重复消耗空页预算，失败桌面跳页保留目标，缓存上限在回看/改条数后保持可见并提供刷新入口；迟到网络回调按目录代次隔离。32/32 直接回归、66 个同源码相邻用例分阶段通过，五文件 analyze 无诊断；320 宽/双倍字体及实际按钮补证。干净 58546f51 Android Debug 已构建归档，287,116,779 B、16 KB/内容/复制后 SHA 通过，版本仍 3.1.8+4121；包含此前分区及图标修订。只读确认 Android 在线且身份匹配，未安装、未切手机前台；待明确测试窗口再做累计原生验收。

- **猫耳图标帧与通用封面缓存已作源码修订**：[图像资源审计](AREA_ARTWORK_AUDIT_2026_09_08.md)。官方移动/web 资源的彩色帧位置相反，已精确区分；分类/收藏卡片及关注头像共用规则，旧/新状态图退出跨平台通用封面缓存。八文件 87/87 回归通过，含实际 Widget 像素；冗余测试导入修订后五文件 analyze 无诊断。只读确认手机身份/Root/转发及 MT 的 26 个工具，没有 APK 打开、修改、安装或手机前台输入。此源码批当时未构建，现已纳入上方 58546f51 Android 候选；Windows 和原生视觉验收继续。历史 42 个未闭环大项和 14 个未注册平台组口径不变。

- **分区原生异常已复现、修订并在新 Windows 候选复验**：[所有权与 UI 审计](AREA_CATEGORY_OWNERSHIP_AUDIT_2026_09_08.md)。修订平台列表别名、普通 List 追加重复以及切换分类后页数上限沿用旧分类；6 个红测失败转绿，77/77 定向及 3 文件 analyze 通过。干净 f3de664a Debug 已构建归档，猫耳分类初次/刷新、音乐收藏与搜索能力说明实际补证；UI HLS 录制 115.008 秒 MP4 全段严格解码通过，大小与卡片一致，实例正常退出。图标多状态资源、完整播放/长录与 Android 继续，未发布；下方 f92aa1a7 为旧 Windows 候选。

- **Windows 累计 Debug 候选 f92aa1a7 已构建归档**：[候选及 MT 检查](MISSEVAN_WINDOWS_CANDIDATE_2026_09_08.md)。141,375,456 B，439.706 秒，输出/归档 SHA 一致；包含猫耳、收藏身份与 TLS 修订，尚未启动新候选做可见 UI 验收。按用户补充只读核对手机身份、Root、既有转发及 MT initialize/tools/list 成功，没有安装、切前台或模块操作。下面旧 Windows 状态保留历史口径，以本项为最新 Debug 构建证据。

- **猫耳与收藏修订已进入 Android Debug 候选 7aaecb8e，未安装**：[候选审计](MISSEVAN_ANDROID_CANDIDATE_2026_09_08.md)。287,112,756 B，版本仍 3.1.8+4121，16 KB/内容核验通过；构建 297.849 秒，归档与 SHA 再核对一致。没有手机操作或正式发布；下方应用接入批次的“没有 APK”保留为当时状态，以本候选为最新构建证据。

- **猫耳 FM 已源码注册并通过双协议原生短录**：[应用接入审计](MISSEVAN_APPLICATION_INTEGRATION_AUDIT_2026_09_08.md)。目录、配置迁移、链接、共享请求头和生产录制解析已接入；搜索/弹幕明确标记未接入。201/201 定向、19 文件 analyze、真实公开接口 1/1、Windows HLS/FLV 短录各 1/1 通过，MP4 全段严格解码退出 0。当前源码 13 个直播站点 + IPTV，参考分组剩余 14 组未注册；尚无包含本批的新 APK，原生 UI、代理/relay、纯音轨和长期验收继续。下方历史批次的平台数量保留发生时的快照，以本项及文末当前范围为准。

- **分类收藏身份与过期列表快照已修订**：[本批审计](FAVORITE_AREA_IDENTITY_AUDIT_2026_09_08.md)。跨平台同号分类独立，猫耳 catalog/tag 分命名空间，旧父分类缺失兼容，取消收藏不再按裸 ID 误删；已挂载收藏页读取实际 observable。38/38 定向测试与 6 文件 analyze 通过，包含真实按钮和文件 Hive 往返；未构建、安装或操作手机。猫耳平台注册等接入仍待完成，参考平台未注册数仍 15。

- **猫耳原生分页已进入热门/分类路由的可选能力路径**：[分页衔接审计](MISSEVAN_DIRECTORY_UI_AUDIT_2026_09_08.md)。完整响应保留后再分UI页，使用服务器hasMore、保留尾部/空后页/失败重试游标，刷新与在途改页大小隔离旧目录响应。55/55定向回归通过，包含BasePageView内容保留及卸载检查。既有平台路线不变；平台注册、配置与播放/录制集成尚待完成，未注册数仍15，没有新APK或手机操作。详细测试及剩余分类收藏身份问题见审计。

- **猫耳 FM 进入暂存适配阶段，尚未开放入口**：[公开合同审计](MISSEVAN_STAGED_ADAPTER_AUDIT_2026_09_08.md)。新增匿名API、保留原生分页元数据与额外推荐条目、热度语义、严格错误分类、HLS/FLV同协议刷新和签名失效元数据。HTTP/外部FFprobe已验证一个公开房间为AAC加16×16 H.264，不强制全平台纯音频。本批没有手机操作或新APK；59/59定向及真实API探针1/1通过，剩余接入门禁见审计。站点注册与原生验收尚待完成，未注册数仍15。

- **TLS修订已进入新Android候选b5f39c2b，未安装**：[09-08构建审计](RECORDING_TLS_ANDROID_CANDIDATE_2026_09_08.md)。干净源码、arm64 Debug、287,074,474 B，16KB/内容核验通过，耗时411.089秒，版本仍3.1.8+4121。候选归档与SHA再次核对，复用56项定向/原生四状态/最终analyze证据，未执行完整发布门禁。手机切换窗口仍待确认，本轮无ADB或其他设备操作。

- **TLS握手停止已有源码修订与本机闭环证据**：[连接所有权审计](RECORDING_TLS_OWNERSHIP_AUDIT_2026_09_07.md)。原红测保留全部断言转入日常测试，56/56定向回归通过；直接/CONNECT握手取消、错误证书/主机名拒绝、两次3MiB+17B逐字节响应、会话隔离及清理通过。原生四个HTTP上游停止场景严格解码/输出SHA保持，暂停场景仍标记尾片舍弃。增加的TLS网络侧桥尚待Android及长期代理/功耗验收；现已纳入上方b5f39c2b候选，尚未操作手机。

- **上一 Android Debug 候选 c442380c 已构建，尚未安装**：[候选与守卫审计](RECORDING_STAGED_ANDROID_CANDIDATE_2026_09_07.md)。287,067,886 B，16 KB/内容校验通过，耗时294.532秒，版本仍3.1.8+4121。设备型号/代号一致，但前台是哔哩哔哩，停在只读预检并询问切换窗口；无唤醒、安装、输入或模块操作。录制刷新/暂存/尾片提示已进该包，但手机最近一次已验证安装仍80b7431c；TLS红项保留。另修订本机唤醒身份核验和常亮原值恢复，9/9守卫与8/8包装器离线测试通过，尚待原生工具复验。

- **历史TLS红项诊断（后续修订见上项）**：[连接停止审计](RECORDING_TLS_STOP_AUDIT_2026_09_07.md)。当时ClientHello后停止超过3秒，关闭单relay的HttpClient尝试也失败并撤回。独立Dart观察显示HttpClient.close既未断开对端也未结束Future；保留RawSocket后可断网，但握手Future仍悬而未决。该诊断批保留了显式启用的红测、业务源码保持f0554973，无APK或手机操作；本批已用网络侧所有权接续修订，没有改SDK或重用那次无效补丁。

- **大响应暂存已有真实文件I/O边界证据**：[容量审计](RECORDING_STAGING_LIMITS_AUDIT_2026_09_07.md)。3MiB逐字节一致、8路占满/第9路拒绝、128MiB+1上限、分配中close和存储分配异常共5个新增场景通过；4文件35/35回归、2文件analyze通过，原生默认路径四场景严格解码及输出SHA与前批一致。尚未覆盖永久磁盘I/O停滞、实际写盘失败、连接建立阶段停止和手机存储性能；本轮没有APK或手机操作。

- **尾片舍弃已进入原生终止字段和录制卡片提示**：[提示审计](RECORDING_TAIL_WARNING_AUDIT_2026_09_07.md)。126/126定向测试通过；原生完整响应标记false、三种暂停响应true，四场景严格解码通过且输出SHA与上一批相同。任务持久化/重连保持提示，新用户录制重置；独立于数据包损坏，不阻止健康分段使用。中英文320px/2倍文字布局与按钮测试通过，手机UI与容量/性能尚待验收，无新APK。

- **HLS完整响应暂存已通过本机四场景对照，手机仍未部署**：[本批审计](RECORDING_HLS_STAGING_AUDIT_2026_09_07.md)。77/77定向回归、7文件analyze通过；完整/25%/50%/90%暂停输入均约2秒结束，无会话强制取消，严格A/V解码通过。三个暂停场景只保留前三片，原生日志仍有410、尾片跳过及解复用I/O错误；inputDrained不等于纯EOF或零丢失。相邻合并停止重复应答已锁存。剩余为尾片结果语义、容量/磁盘/连接建立边界、性能及Android复验；本轮没有APK、ADB、MT、LSP或发布操作，Android仍80b7431c。以下保留历史批次证据，不应把旧候选状态当作当前源码状态。

- **输出缓冲截断已有源码修订，完整录制验收仍未通过**：[缓冲审计](RECORDING_OUTPUT_FLUSH_AUDIT_2026_09_07.md)。核对固定FFmpegKit源码后，录制内部TS启用逐包刷新；66/66定向测试、三文件analyze及生产原生四场景严格A/V解码通过，文件不再停在非完整TS包前缀。但暂停输入仍触发强制取消和输入损坏标记，保留源规则未放宽；下一步是完整输入边界停止与高码率/长录性能验证。本轮未构建、部署或操作手机，Android候选仍80b7431c。

- **在途 HLS 停止已取得本机确定性失败对照，尚未修复应用**：[复现与工具审计](RECORDING_HLS_PARTIAL_STOP_AUDIT_2026_09_07.md)。完整响应的 TS 严格解码通过；25%/50%/90% 暂停响应均触发约 6 秒强制取消，三个坏 TS 恰好是健康文件的同一 524288 B 前缀，停在非完整 TS 包边界。下一步核对原生输出缓冲/trailer，而非直接延时或裁剪。测试器旧监控预检和失败收尾已增加所有权保护，76 项新增断言、既有73场景、38代理事务与平台合同通过；真实设备保护路径尚未验证。本轮没有手机、APK或应用源码变更，整体录制仍 FAIL。

- **Cookie修复候选80b7431c已覆盖安装，但严格解码仍失败**：[Android复验](TWITCASTING_COOKIE_ANDROID_RETEST_2026_09_07.md)。主Hive覆盖安装前后字节一致，APK哈希匹配；low档出现实际画面，首段401解除，实际生成19.733秒MP4。原生脚本返回0，但完整A/V严格解码发现尾部附近H.264损坏，整体录制保持FAIL；6秒停止预算触发强制取消，另见4秒/8秒样本时长延展，根因继续用本机确定性源区分。两个代理session、reverse、监控、进程/唤醒锁/常亮均完成清理。下一轮实机前还需修订预检旧监控及失败收尾的所有权保护；不把文件非空或metadata通过当作内容通过。

- **TwitCasting实机短录缺陷已定位并完成源码修复，原生仍待复验**：[原生与会话审计](TWITCASTING_ANDROID_NATIVE_AUDIT_2026_09_07.md)。Android 1a18f353保留数据覆盖安装成功，房间/画质状态可操作，但视频区黑色且首段401，整轮FAIL；测试监控、代理、reverse、进程/唤醒锁/常亮已清理。匿名HTTP对照证明播放列表会话Cookie丢失；现修复限额、单会话、origin隔离的Cookie传递与重定向，57/57定向回归、修订范围分析及生产转发HTTP探针1/1通过。原测试频道下播后另选公开直播，init/media均200；不是实机播放/录制文件证据。手机仍为修复前APK，下一步新候选构建、覆盖安装和原生复验。

- **新增 TwitCasting 源码适配与真实HTTP核验通过**：[接入审计](TWITCASTING_ADAPTER_AUDIT_2026_09_07.md)。公开目录/顶栏分类、频道身份、三档HLS、严格录制输入、同档恢复及第5代配置迁移已实现；热门/分类复用60条窗口再本地分页。首轮81/81与最终53/53定向回归通过（有重叠），风格修订范围分析无诊断，生产代理探针1/1通过：55条公开房间、18分类、3档及444 B媒体列表。不是原生播放/录制或已安装证据。当前源码12直播站点加IPTV，另15组参考平台未注册；OPENREC实测403，保留未实现。该批当时尚无TwitCasting候选；后续Android 1a18f353已覆盖安装，但首段401导致短录FAIL，见[原生与会话审计](TWITCASTING_ANDROID_NATIVE_AUDIT_2026_09_07.md)。Windows候选仍未包含；未发布。

- **浮窗遮挡下的代理自动收尾已实机通过**：[遮挡审计](ANDROID_PROXY_OCCLUSION_AUDIT_2026_09_07.md)。38个代理事务场景通过；复用1aa6886f，实际未遮挡点进入代理页并恢复两个开关，整轮短录与自动清理退出0，23.633秒文件严格完整解码无错误。前两次失败及明确恢复均保留；未实现远程弹幕的报告已从条件PASS修正为SKIP。没有新APK或发布。

- **前批 Android 候选1aa6886f已保留数据覆盖安装**：[诊断实机审计](RECORDING_DIAGNOSTIC_ANDROID_AUDIT_2026_09_07.md)。主Hive安装前后首次启动前字节一致，设备APK哈希匹配。Picarto本次25.054秒短录严格完整解码退出0且日志为空，停止快照显示799ms正常收尾、未强制取消/未报告损坏。自动代理恢复仍失败，整轮FAIL；明确恢复及进程/reverse/唤醒锁/常亮清理均完成。下一步修订浮动播放器遮挡下的代理导航，不反复构建同一应用。

- **停止诊断已补齐并通过原生对照**：[终止证据审计](RECORDING_STOP_EVIDENCE_AUDIT_2026_09_07.md)。停止原因、耗时、输入收尾与损坏判定共用不可变快照，85/85 定向测试及 analyze 通过；本机真实 FFmpeg 的2个输入场景、3个HLS停止场景通过。下一步构建包含源保留与诊断的 Android Debug 候选，不代表原手机尾部损坏已修复。

- **已知损坏的录制源段保护与 Picarto 标签已修订**：[输入完整性审计](PICARTO_INPUT_INTEGRITY_AUDIT_2026_09_07.md)。原生旧录像错误定位到尾部，采集日志已报损坏包但原 TS 被删除；现将明确损坏按 attempt 持久化，阻止随后 stream-copy 返回 0 掩盖问题并删除源段，普通停止 I/O 提示不误报。126/126 定向回归通过，应用源码 analyze 无诊断；新增本机原生完整/截断输入2个场景及HLS停止3个场景均通过。未构建或安装，原手机录像损坏原因及Android原生复验继续。

- **新 Android 候选 2006c044 已覆盖安装**：[原生审计](PICARTO_ANDROID_NATIVE_AUDIT_2026_09_07.md)。安装前后、首次启动前主 Hive 字节一致，设备 APK 与候选 SHA 一致；首页与新增平台进入成功。Picarto 实际播放画面及 22.082 秒 H.264 720p30/AAC 文件已取得，但完整解码发现损坏，代理自动收尾也失败，**整轮保持 FAIL**。单选画质/线路切换为 SKIP，未证明长录、后台或全部播放模式。随后两个代理开关和临时 reverse 均恢复，监控取消、进程/唤醒锁/常亮已清理。

- **代理往返通过，原生入口/嵌套滚动问题已定位**：[原生工具复验](PICARTO_ANDROID_NATIVE_AUDIT_2026_09_07.md)。先独立完成代理开启/恢复，再经过两次未开始录制的入口失败；现按实际“返回”导航并在停止进程前恢复代理。73 个录制守卫场景、6 个包装器测试通过；第三轮发现嵌套滚动歧义，新增真实 XML 回归后 25 个代理事务场景通过。嵌套滚动修订尚未完整上机复验，录像损坏来源继续定位。此前[代理事务](ANDROID_PROXY_TRANSACTION_AUDIT_2026_09_07.md)与[目标守卫](ANDROID_RECORDING_GUARD_AUDIT_2026_09_07.md)保留各批边界记录。

- **候选构建/质量证据未扩写**：[构建审计](PICARTO_ANDROID_CANDIDATE_AUDIT_2026_09_07.md)。完整测试首次 1581/1，修正期望列表后相关 2/2，全库 analyze 无诊断，接口 42/42。APK 287,023,145 B、Manifest 6121、16 个原生库及 16 KB 对齐通过；本次未重构建。不是一次完整全绿，也未正式签名发布。

- **新增Picarto源码适配**：[接入与验证](PICARTO_ADAPTER_AUDIT_2026_09_07.md)。公开目录、详情、HLS画质、严格录制输入、重新取流和第4代配置迁移已实现；11文件定向回归115/115，风格修正后30个相关用例加1个生产代理探针31/31，范围分析无诊断。真实HTTP取得目录10条、声明720p30的画质和285B媒体列表；不是原生播放/录制文件证据。当前源码11个直播站点加IPTV；原17个扩展候选中Picarto进入实现、另16组仍未注册，Picarto完整分类/原生搜索/弹幕与原生验收继续。该接入批当时没有构建、设备输入或发布；最新候选已包含源码，见上项。

- **Issue与平台总账已刷新**：[09-07 Issue核验](ISSUE_AUDIT_2026_09_07.md)确认维护仓库open 0、上游open 14；#849新评论没有补充故障日志，#854关闭不等于iOS问题已修复。[参考平台差距](PLATFORM_EXPANSION_AUDIT_2026_09_07.md)核对真实注册入口，实施前盘点为17个未注册候选分组；Picarto最初经本机Clash取得目录/详情/HLS 200，此后源码接入进展见上项。修订兼容性文档的快手弹幕、AcFun与11适配器口径；未改应用、设备或发布。

- **前批源码：录制卡片窄屏布局修复**：[页面审计](RECORDER_PAGE_LAYOUT_AUDIT_2026_09_07.md)。真实页面在320宽度、中英文1/2倍文字下稳定复现4个溢出场景；封面/详情和底部动作现按约束换行。28项页面操作加相邻录制生命周期共 **90/90通过，analyze无诊断**。保留处理中启动等待旧封装的既有意图合同，不重写状态机。已纳入上方2006c044 Android候选，已上机取得录制中心截图；完整布局/动作矩阵继续，下方旧候选不含此新布局。

- **Release长录制已补证**：[虎牙长录审计](WINDOWS_LONG_RECORD_AUDIT_2026_09_07.md)。复用2d8e4e0c，实际持续录制706秒墙钟，最终711.806秒H.264 720p60+AAC完整解码退出0、错误日志0 B，三段TS合并MP4；168.92 MB与177,121,160 B一致。十分钟61/61响应，离页内存/句柄/线程回落并正常退出；列表CPU仍约2.5%，签名预取/续接次数没有独立证据，W3-05保持RUN。没有重构建、发布或操作手机前台。

- **CPU归因取得消息级证据**：[进程内仪表](WINDOWS_CPU_CONTEXT_AUDIT_2026_09_07.md)。无业务模板可见时每秒约293–419次WM_GETOBJECT同步无障碍查询，最小化后为0；约60次/秒的Flutter定时消息并未同步消失，高CPU也不是持续排队WM_NULL洪流。发起进程及产品额外负载仍待确认，未屏蔽无障碍功能或修改正式应用；两套仪表进程均已退出。等待可选的无轮询桌面协调期间，继续复用当前Release完成播放/录制功能验收。

- **新增产品Release候选与CPU复验**：[Windows Release审计](WINDOWS_RELEASE_CPU_AUDIT_2026_09_07.md)。干净2d8e4e0c、3.1.8+4121 unsigned便携ZIP构建成功（74,603,787 B），独立实例实际加载随包VC++运行库。空关注页可见/最小化/恢复CPU约1.208%/0.0166%/1.330%，三段各13/13响应并正常退出，现象在Release仍存在。WPR启动遇0xc5585011、未取得热栈且未留下录制；下一步用隔离runner进程内仪表，不更改系统策略或猜测性修补。该候选可复用后续原生验收；未重新全测、生成安装器或发布。

- **新增CPU最小程序对照**：[窗口可见性与观察条件](WINDOWS_CPU_CONTEXT_AUDIT_2026_09_07.md)。相同SDK、空插件清单的静态模板串行Debug/Release构建成功；可见/最小化/恢复分别约0.243%/0.013%/0.288%及0.306%/0.0067%/0.308%。两种模式都有可见性差异，尚未解释Pure Live空关注页约0.958%与热门页约2.3%的额外负载。下一步核验Pure Live自身Release候选，必要时再做隔离原生消息/热栈定位；不是产品性能PASS，没有凭猜测加延时或修改业务代码。

- **最新播放/录制补证**：[Windows 虎牙原生审计](WINDOWS_PLAY_RECORD_AUDIT_2026_09_07.md)。复用 fadd5bdb 完成实际 20M→8M、线路1→2、直链画质/线路取消与持续录制；207.61 秒 H.264 1080p60 + AAC 完整解码无错误，最终卡片 32.26 MB 与 33,832,167 B 对账一致，关闭旧临时字节沿用缺陷的原生复验子项。离页资源回落，但列表 CPU 约2.3%仍待定位；签名续接/长录/多平台未由此完成。

- **新增 Windows 累计候选 fadd5bdb**：[原生审计](WINDOWS_AUXILIARY_NATIVE_AUDIT_2026_09_07.md)。Debug 构建成功并在独立实例完成空链接、无效跳转草稿、折叠恢复、历史空状态、新数量标签和取消的实际观察，正常退出。复用前批完整门禁与标签批 43/43，不是本提交重新全测。Android 第二次补证仍遇前台争用，守卫在输入前停止；平台选择器、复制、DLNA、长录和性能继续。

- Android 增量：[辅助页面原生补证](AUXILIARY_NATIVE_AUDIT_2026_09_07.md)。已安装 af88a032 完成历史列表、数量草稿取消、清空取消、下拉刷新及工具箱入口五个场景；下一次点击前因其他应用进入前台而停止，工具箱输入/选择器继续待验。原生发现的历史「尺寸」误用已修订中英文数量标签，**43/43 定向回归通过，analyze 无诊断**；新文案已进入 Windows 候选，尚未更新 Android。

- **当前累计候选 af88a032**：[候选审计](CUMULATIVE_CANDIDATE_AUDIT_2026_09_07.md)。干净提交 **1522/1522 测试、42/42 接口探针通过，analyze 无诊断（79 秒）**；Android arm64 Debug 已构建并保留数据覆盖安装。主 Hive 字节与安装包哈希分别核对一致；首页竖屏、横屏与左侧导航滚动已做原生补证，旋转/常亮恢复、应用停止。其余累计原生动作继续。

- 最新源码批次：[播放器已知房间取流/投屏](KNOWN_ROOM_LINK_ACTION_AUDIT_2026_09_07.md)，**160/160 定向回归通过，analyze 无诊断**。菜单和控制栏共用单动作门禁，离页/房间变化隔离迟到结果，复制等待确认，投屏转交选定 URL 并管理自己的子路由。已纳入当前累计 Android 候选；物理 DLNA 接收器及这些选择器的原生完整交互仍待验。

以下历史微批记录各自完成时的状态；其源码现均包含在当前 af88a032 候选中，具体功能的原生缺口仍按各组保留。

- 历史源码批次：[工具箱动作与直链流程](TOOLBOX_ACTION_AUDIT_2026_09_07.md)，**174/174 定向测试通过，analyze 无诊断**。两个动作互斥，取消/编辑/离页隔离迟到结果，画质/线路选择有路由所有权，复制等待平台确认；包含实际 Widget 与中英文窄屏交互。未构建或上机；真实平台条件、播放器菜单相邻取流/投屏入口及累计原生证据继续。

- 历史源码批次：[短链接请求边界](LIVE_SHORT_LINK_AUDIT_2026_09_07.md)，**138/138 定向测试通过，analyze 无诊断**。统一跳转状态、相对 Location、8 次请求上限、12 秒总期限及专属客户端释放，含真实本机 HTTP 往返。没有真实平台短链或新候选原生证据；工具箱动作生命周期、画质/线路/复制与平台条件继续。

- 历史源码批次：[工具箱直接链接解析](LIVE_LINK_PARSER_AUDIT_2026_09_07.md)，**94/94 定向测试通过，analyze 无诊断**。共用 HTTP URI 提取与主机/路径校验，修复错误 ID、空路径异常和首个无关链接遮蔽；补齐 AcFun 说明。未构建/上机，短链请求边界、抖音真实 ID 映射、动作状态与原生验收继续。

- 历史源码批次：[工具箱自动填充与页面入口](TOOLBOX_CLIPBOARD_AUDIT_2026_09_07.md)，**65/65 定向测试通过，analyze 无诊断**；用户编辑/关闭隔离、一次性读取、主机识别和英文窄屏标题已修订。未构建或安装，手动解析/跳转/直链与原生动作仍待闭环。

- 历史源码批次：[历史记录与辅助页面审查](AUXILIARY_PAGES_AUDIT_2026_09_07.md)。历史刷新冲突、弹窗释放及清空确认已修订；公共刷新提示保留字体缩放并适配局部宽度，**44/44 定向回归通过，analyze 无诊断**；未构建或上机，不覆盖下列已安装候选证据。
- 手机上已安装的历史 APK：**286,998,845 B**，SHA-256 **EFD5A76AE8B4A8823B95FC50087EEBC5999690C7E796E39F9A41FFFF82C130E8**，版本仍 3.1.8+4121 / Manifest 6121。质量记录 `20260907T015733844Z-quality-full.json`；构建记录 `20260907T020239405Z-build-androidarm64-debug.json`（含完整质量共 628.651 秒，Gradle 275.3 秒）。Windows 最新 Release 候选为上述2d8e4e0c；没有正式发布。

### 下列为此前候选的历史证据，不替代当前状态

- 应用修复 `11264976`：首页短高度轨道整体独立滚动。基础设施修复 `67612cc9`：显式 Android transport 贯穿唤醒、正文、清理，7/7 离线包装器夹具通过。
- 干净 `67612cc950f447c041acba70d29ecb30fced0aa9` 完整门禁 **1300/1300 单元/Widget、42/42 接口**；analyze 无诊断，141.4 秒。质量记录 `20260906T214320095Z-quality-full.json`，463.123 秒，结束活跃重型进程 1。
- Android arm64 Debug 构建通过：`20260906T214818970Z-build-androidarm64-debug.json`，全流程 785.376 秒，Gradle 222.6 秒，结束活跃重型进程 0。版本仍 3.1.8+4121，Manifest code 6121，16 个原生库、16 KB 对齐核验通过。
- APK **286,952,838 B**，SHA-256 **DC9EFE0AE2721A9304E7E9218C99720694093EF298D3ACD3D33E1F8FB865CA7D**。旧包归档路径 `local-artifacts/candidate-archive/67612cc9/PureLive-3.1.8-4121-android-arm64-v8a-debug.apk`；不是正式签名发布包。原 Firebase KGP 未来兼容警告保留。
- K90 Pro Max 的型号、代号、Android 版本已按明确 `-s 192.168.1.2:5555` 核对。覆盖安装前后 Hive 文件字节一致，设备 base.apk 哈希与候选一致，竖屏首页启动截图成功。未清除数据、导入测试配置或操作其他应用。
- **横屏修复的原生复验仍未完成**：旋转前前台为 Pure Live，之后观察守卫发现已非目标；随后活动记录显示哔哩哔哩前台。没有继续发出坐标输入，原旋转设置恢复为 `accelerometer_rotation=1 / user_rotation=0`，Pure Live force-stop 命令成功，包装器常亮清理成功。前台变化来源未确认，不据此认定应用崩溃，也不据此声称修复已上机通过。
- 证据目录 `local-artifacts/home-rail-native-20260907/`，含安装、截图和清理记录。配置副本只留本地忽略目录。旧 `f867f799` Android 候选已归档并核对哈希；Windows 仍是旧 `f867f799` Debug 候选，没有本批新 Windows GUI 证据。

## 剩余数量：历史账本口径，不等同当前缺陷数

**42不是整个目标的全部剩余量。** [参考平台扩展表](PLATFORM_EXPANSION_AUDIT_2026_09_07.md)列出实施前17个平台候选分组；Picarto、TwitCasting、猫耳、映客、克拉克拉、花椒、OPENREC、TTingLive、小红书、niconico 与微博已源码注册，当前 **21 个直播站点 + IPTV，6 组未注册**（YouTube、Bigo Live、战旗、一直播、企鹅电竞、浪 Live），另有各平台完整能力/原生验收、域名兼容、弹幕与通用解析缺口。TwitCasting 已有实际短录，但严格解码失败后的修订仍待当前候选手机复验；当前 Android 本机构建输入为 `52e25b82` 的 `4BF85571…6B82` Release 测试包，Windows 仍为 `2fb471d3` Debug，二者与之后的源码修订分列；旧候选原生证据不覆盖新源码。原先“数个工作日”的估计仅能作为现有验收组的粗略量级，也不覆盖全部平台扩展；需按逐平台可达性、接口与实现证据重新估算。

对 [历史执行账本](ACCEPTANCE_MATRIX_3_1_0.md) 的 A/W 编号行逐行统计（只读状态列，不统计证据正文中的 PASS）：

| 范围 | 总大项 | PASS | RUN：部分完成 | NR：未执行 |
| --- | ---: | ---: | ---: | ---: |
| Android | 46 | 16 | 30 | 0 |
| Windows | 16 | 4 | 12 | 0 |
| 合计 | 62 | 20 | 42 | 0 |

当前账本已有 20 项 PASS、42 项 RUN、0 项 NR，共 **42 个历史大项尚未闭环**。一行通常含多个动作或平台组合；此外还有单独的平台能力表、长时验证及发布门禁。部分 PASS 属于旧版本/旧手机，RUN 也可能只覆盖其中一个子场景。由此既不推导“当前还有 42 个 Bug”，也不推导完成百分比或最终候选已有 20 项通过。

## 接下来按工作组收口

1. **账本对齐与 Issue**：把新证据映射到 62 个编号行，记录候选 SHA、设备、实际覆盖动作；已解决的历史失败关闭，证据不覆盖的子项保留。按当前版本核对 Issue，保持不合并上游。
2. **首页、设置与数据**：首页横屏轨道已完成新包启动/滚动补证，其余动作继续；累计 WebDAV 表单/选择/上传/恢复/删除的 Android、Windows 原生补证；逐项完成历史、标签、工具箱、IPTV、关于/更新与设置重启持久化。
3. **播放、线路与互动**：用最终候选完成普通/横竖屏/小窗/PiP/音频/后台组合，核对画质、线路、失效续接和弹幕实际更新；旧单次成功不覆盖所有组合。
4. **平台与录制**：保留各平台已有短录证据，补充长时运行、下播/断流/恢复、文件完整性和资源回落。AcFun 弹幕未接入等能力缺口与产品故障分列；参考项目能力比较继续按原目标完成。
5. **性能与故障**：Android/Windows 各自保留空闲、播放、录制、退出后的 CPU/内存/帧证据。Windows 空闲约 2.3% 的归因尚未闭合；不以 Debug 开销代替 Release 性能结论。故障注入遵守用户设备边界，不通过切换 Wi-Fi 或重启设备测试。
6. **最终发布**：实际完成上述范围后，再固定最终提交、完整门禁、各平台串行构建/签名/安装与产物校验，整理 README、详细更新日志、限制和回滚说明，发布 3.2.0。缺少某平台证据时保持明确缺口，不借用旧包或其他平台结果。

整体完成时间尚无可靠估计；历史“数个工作日”不覆盖尚余 6 个参考平台组，总工期取决于各平台实现、真实缺口与验证条件。优先完成可验收的功能组，不通过无限细分源码小改动代替整体收口。
- **09-11 精细字号设置布局、数值边界与重置已修订**：[审计](FONT_SIZE_SETTINGS_LAYOUT_AND_BOUNDS_AUDIT_2026_09_11.md)。旧页未呈现已有的五项用途说明，控制器启动及备份解析也让越界/非有限值进入主题和滑块；单击顶栏重置会立即改写全部五项。现由统一默认值/范围、启动与导入归一化、严格非有限值事务、可换行说明、720 像素宽屏正文和可滚动重置确认闭合源码路径。新增 **6/6 PASS**，最终联合回归 **44/44 PASS**、全库 analyze **No issues found**。A2-01 保持 RUN、A2-07 保持 PASS，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未操作手机、真实配置、构建或发布。
- **09-11 搜索分页重叠与有界停滞已修订**：[审计](SEARCH_PAGINATION_STAGNATION_AUDIT_2026_09_11.md)。旧控制器把任一非新增页立即视为平台结束，接口若重复相邻页边界会隐藏后续新结果；无条件继续又会让固定响应无限追加。现按平台记录连续停滞，允许一次完整重叠页，第二次停滞有界结束；新增结果归零，空页/失败独立结束，换词与换平台清空预算。新增 **3/3 PASS**，最终联合回归 **129/129 PASS**、全库 analyze **No issues found**。A1-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未访问真实平台、操作手机、构建或发布。
- **09-11 搜索重复提交事务已修订**：[审计](SEARCH_SUBMIT_TRANSACTION_AUDIT_2026_09_11.md)。旧控制器会让连续回车/按钮点击取消并重发完全相同的首屏请求，聚合搜索即使已有快平台结果、仅剩慢平台也会整体重启。现由“平台下标 + 去空白关键词”合并未完成首屏事务；同键共享 Future，不取消 transport、不重复扇出，异词/切平台保持 latest-wins，完成后同词仍可刷新。新增 **3/3 PASS**，最终联合回归 **132/132 PASS**、全库 analyze **No issues found**。A1-04 保持 RUN，宏观仍为 20 PASS / 33 RUN / 9 NR，共 42 组未闭环；未访问真实平台、操作手机、构建或发布。
- **09-12 Android 小窗弹幕辅助语义与恢复默认已修订并覆盖安装**：[专项审计](ANDROID_PIP_DANMAKU_ACCESSIBILITY_RESET_AUDIT_2026_09_12.md)。旧开启态 Switch 均为空名称 NAF 节点，滑块只读数值，恢复确认文案也少列实际会重置的类别；`63597cf1` 统一整行可点击的具名 toggle、七类滑块格式化语义、单一自动 FPS 默认常量和完整双语确认。六文件 43/43、全库 analyze 通过；`D52040A3…DF8977` arm64 Debug 保留数据覆盖安装后，设备 APK 哈希一致。K90 原生四个 Switch 及字号/字重滑块均具名，取消保留自定义关闭，确认恢复默认开启并跨进程保持；规范 Hive 精确恢复、应用停止、stay-awake 恢复。A2-04 保持 RUN，宏观仍为 **20 PASS / 34 RUN / 8 NR**、42 组未闭环，Astra Light 0 次。
