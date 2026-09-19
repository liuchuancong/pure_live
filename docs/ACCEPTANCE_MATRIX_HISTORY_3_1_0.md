# v3.1.0 Android / Windows 验收矩阵历史增量

此文件保存从当前编号表移出的阶段性增量说明。62 个编号行及其当前状态仍只在 [`ACCEPTANCE_MATRIX_3_1_0.md`](ACCEPTANCE_MATRIX_3_1_0.md) 维护。

---

> 2026-09-19 Issue #872 Bilibili 登录弹幕增量：3.1.4 到修订前认证包缺少 `support_ack`、queue UUID 与 room 场景，也未处理 `p_is_ack` 消息。`52db99fb` / `9b4eb33b` 增加当前认证字段、operation 24 ACK 和同 Cookie `DedeUserID` 身份绑定。有效红灯 7 PASS / 3 FAIL；七文件 57/57，最终协议 11/11 与 analyze 通过；最终 DIRECT 严格探针在 45 秒内解析 1 条聊天且无重连/最终关闭。游客实连不替代报告者登录态 Windows 复验，详见 `docs/ISSUE_872_BILIBILI_LOGGED_IN_DANMAKU_AUDIT_2026_09_19.md`。A4-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；未构建候选、启动 GUI 或操作设备，Astra Light 0 次。

> 2026-09-19 Issue #869 Android 进房音量增量：3.1.4 与冻结的 3.1.2 都在设备当前媒体音量非 0 时把单房间保存值写回共享系统媒体流，因而旧房间静音值会覆盖用户在外部更新后的设备值。`789f03cc` 改为普通进入只采纳设备当前值、不执行房间恢复写入；明确全局静音仍是唯一初始化写入例外，既有生命周期和事件代次保护保留。有效红灯 35 PASS / 1 FAIL，直接 36/36，最终八文件 253/253 与 analyze 通过，见 `docs/ISSUE_869_ANDROID_ROOM_VOLUME_RESTORE_AUDIT_2026_09_19.md`；代码已推送至 `origin` 并精确核对。A3-04 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；未构建候选、操作设备或启动 GUI，Astra Light 0 次。

> 2026-09-19 Issue #867 房间卡片简洁布局增量：3.1.4 的简洁预设只隐藏字段，真实卡片与固定网格仍保留 16:9 封面；历史 `8169dafa` 明确使用 `showAsListTile: true`。`bc083310` 已补齐持久化布局维度、无封面紧凑行、固定/自然网格共享几何、3.1.2/3.1.4 迁移和手动布局选择器。有效红灯锁定控制器、设置页与热门卡片三类缺口，第一轮 25/25，最终八文件 82/82 与最终 analyze 通过，见 `docs/ISSUE_867_ROOM_CARD_COMPACT_LAYOUT_AUDIT_2026_09_19.md`；代码提交已推送至 `origin` 并精确核对。A1-02/A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；未构建候选、启动 GUI 或操作设备，Astra Light 0 次。

> 2026-09-16 Issue #852 ColorOS 14 系统手势返回增量：普通路由原先让 Flutter 共享元素预测返回持有手势；Flutter P2 #153577 仍记录视觉完成后输入被继续阻塞。`6fbc1685` 集中亮/暗主题页面转场并让 Android 普通路由使用 `FadeForwards`，保留 Manifest 系统回调、commit 标准 Navigator pop、cancel 语义和直播页自有返回仲裁。有效红灯 3 PASS / 3 FAIL，直接 6/6，最终四文件 21/21 与本批一次 analyze 通过，见 `docs/ISSUE_852_COLOROS_SYSTEM_BACK_AUDIT_2026_09_16.md`；代码提交已推送至 `origin` 并精确核对。ColorOS 14 实机仍待复验；A1-04/A1-05/A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；未构建候选、启动 GUI 或操作设备，Astra Light 0 次。

> 2026-09-15 Issue #865 WebDAV 仅恢复关注列表增量：旧入口只能全量覆盖；`a36ee8fa` 增加“恢复全部设置”和“仅恢复关注列表”，后者只导入 `favoriteRooms` / `favoriteAreas`，保留屏蔽项、平台选择及所有其他本机设置。版本化和旧版平铺备份均受支持，目标结构先于变更校验，目标外损坏 section 不阻断选择性导入，全量/仅关注共享单次持久化事务。320×480 / 3.0 倍文字入口与确认可达，最终六文件 104/104、本批一次 analyze 通过，见 `docs/ISSUE_865_WEBDAV_FAVORITES_ONLY_RESTORE_AUDIT_2026_09_15.md`；`origin/master` 已精确同步该提交。未构建候选、启动 GUI 或操作设备；A1-05/A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 Issue #866 抖音多画面选源增量：报告版本 3.1.3 会保留 `origin / md / ao`，而小格最低档路径取列表末项，独立历史夹具实际 0 PASS / 1 FAIL；`56cd4d97` 已排除 `ao` 与 `only_audio` rendition，`09a716e6` 证明严格详情解析后的最低档仍为视频 URL，并携带 User-Agent / Origin / Referer / Cookie。当前抖音解析器与多画面联合 59/59、本批一次 analyze 通过，见 `docs/ISSUE_866_DOUYIN_MULTIVIEW_AUDIT_2026_09_15.md`。历史 K90 cycle 46 只证明普通页/录制的纯音频项隔离，不替代当前多画面、平板横屏或 Windows 卡顿复验；A3-06/A3-08/W3-03 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；本批未构建候选、启动 GUI 或操作设备，Astra Light 0 次。

> 2026-09-15 标签编辑冲突与所有权增量：旧编辑器提交时只按 ID 搜索当前列表，同 ID 新对象会继承旧草稿，原对象被其他状态发布更新时也会被静默覆盖；弹窗持有的旧控制器实例同样没有换代检查。`af19b610` 捕获对象身份及初始名称/说明，提交前核对当前注册控制器、精确对象和字段快照；重新排序仍可编辑，对象替换、字段更新或控制器换代则保留当前状态和草稿，显示双语 live-region 冲突提示、释放焦点并禁用确认。有效红灯 15 PASS / 2 FAIL，页面专项 17/17，最终六文件 66/66 与最终 analyze 通过，见 `docs/TAG_EDITOR_CONFLICT_AND_OWNERSHIP_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签删除确认与身份增量：旧弹窗在 Dart 中拼接通用句首、标签名和标点，英文形成不自然句式；两个普通文字动作也没有明确的破坏性层级。确认回调又按可复用 ID 搜索当前列表，确认期间恢复/导入的同 ID 新对象会继承旧确认并被删除。`0af360f2` 将完整句移入双语资源，使用 420 px 滚动正文、48 px 取消动作和错误色填充删除动作；弹窗只返回类型化结果，页面随后核对生命周期、控制器实例和精确对象身份。同 ID 替换保留新标签与映射，原对象确认才删除并清理映射。有效红灯 14 PASS / 1 FAIL，页面专项 15/15，最终六文件 64/64 与本批唯一一次 analyze 通过，见 `docs/TAG_DELETE_CONFIRMATION_AND_IDENTITY_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签置顶状态与拖拽所有权增量：旧首项仍显示并暴露“移到顶部”的可点击动作，但控制器收到索引 0 后只返回；动作图标还额外包裹核心 `ReorderableDragStartListener`，与实际持有整卡长按的 `ReorderableBuilder` 重叠。`2b039c00` 让首项显示填充图钉和双语“已位于顶部”，保留按钮角色但移除点击动作；其他项保留具名置顶，完成后连续化 `order` 并立即切换新首项状态，同时移除多余拖拽监听器。有效红灯 13 PASS / 1 FAIL，最终四文件 51/51 与本批唯一一次 analyze 通过，见 `docs/TAG_TOP_STATE_AND_DRAG_OWNERSHIP_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签编辑器校验与布局增量：旧标签管理和房间新增入口对空名称/重名只发全局 Toast，错误不与名称字段关联；清除图标没有目标名称，房间入口在 320×480、3.0 倍英文下又出现 773 px 空状态与 220 px 表单溢出。`dd6fcb6f` 以共享类型化校验统一新增/编辑，把空名称与重名放进字段内并在修改时清除；四个清除动作补齐双语名称、按钮语义、稳定 Key 与 48 px 命中，空状态/表单改为有界滚动。房间路由显式返回并派发 Future，结束后集中释放文本、滚动和焦点对象。有效红灯 21 PASS / 2 FAIL，窄屏布局红灯 10 PASS / 1 FAIL，房间专项 11/11，最终六文件 62/62 与本批唯一一次 analyze 通过，见 `docs/TAG_EDITOR_VALIDATION_ACCESSIBILITY_AND_LAYOUT_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签房间映射完整性增量：旧迁移对平台键使用 `putIfAbsent`，已有平台分配时不会合并旧房间号中的其他标签，随后仍删除旧键；新平台又原样复制重复与孤儿 ID。启动和备份导入也直接发布空白键、重复/空标签身份及失效映射。`4d8ed292` 统一标签列表与映射规范化：trim、稳定去重、当前身份过滤、规范键碰撞合并；旧键与既有平台分配无损合并并扇出到每个匹配平台，导入在发布前修复身份，仅标签替换同步清理孤儿映射，保存/导出使用深拷贝快照。有效红灯 23 PASS / 3 FAIL，三个直接专项 27/27，最终六文件 59/59 与本批唯一一次 analyze 通过，见 `docs/TAG_ROOM_MAPPING_MIGRATION_AND_IMPORT_INTEGRITY_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签身份与改名完整性增量：旧新增直接使用毫秒时间戳，确定性红灯中 256 个标签只得到 21 个不同 ID；旧加载继续保留碰撞，卡片 Key、房间映射及按 ID 编辑/删除因此失去唯一目标。旧改名也把当前项纳入不区分大小写的重复搜索，`Travel` → `travel` 被自身阻断。`79266c7e` 改用单调微秒分配并扫描现有集合；加载时保留旧 ID 第一项、重建空/重复身份、连续化顺序并写回，改名查重排除当前索引。有效红灯 7 PASS / 2 FAIL，补入旧数据迁移后直接红灯 7 PASS / 3 FAIL，页面专项 11/11，最终六文件 50/50 与本批唯一一次 analyze 通过，见 `docs/TAG_MANAGEMENT_IDENTITY_AND_RENAME_INTEGRITY_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签卡片动作增量：旧置顶、编辑和删除图标只有通用 Tooltip，多卡片列表无法从语义确认目标，`InkWell` 也没有明确按钮与点击合同。`267c56ab` 用共享组件为每项建立独立 `Semantics`，以中英文“置顶/编辑/删除 + 标签名”同时作为完整 Tooltip 与可访问名称，并统一按钮角色、点击动作、48 px 高度和弹窗等待期禁用。有效红灯 6 PASS / 1 FAIL，页面 7/7，最终五文件 22/22 与最后一次 analyze 通过，见 `docs/TAG_MANAGEMENT_CARD_ACTION_ACCESSIBILITY_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 标签管理详情增量：旧标签名称只是文字大小的 `GestureDetector`，没有 Tooltip、可访问名称、按钮/点击语义或 48 px 命中高度；新增、详情、编辑和删除也没有共享页面门禁，快速重复输入可叠加路由，卡片高度未计入应用内可调字号。`2daabafe` 增加具名 `Semantics` 容器与 `InkWell`，统一触摸、鼠标、键盘和辅助功能激活；四类弹窗共享同步 single-flight、根 Navigator 与 `finally` 重试，并按实际样式行高计算卡片尺寸。有效红灯 4 PASS / 2 FAIL，页面 6/6，最终五文件 21/21 与最后一次 analyze 通过，见 `docs/TAG_MANAGEMENT_DETAIL_ACCESSIBILITY_AND_ROUTE_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 桌面托盘菜单增量：旧实现同时在右键按下和释放时弹出菜单，一次物理手势可形成两次请求；释放路径还会额外聚焦窗口并以无异常边界的 `.then` 再次弹出，连续右键会让刷新、聚焦与弹出交错。`cd9fed8d` 以右键按下为唯一入口、释放为空回调；新增协调器将“刷新菜单 → 弹出菜单”组成 single-flight，重复请求共享 Future，异常后释放门禁并由外围收口，所有托盘 void 回调显式派发 Future。有效红灯 0 PASS / 1 FAIL，新专项 3/3，最终七文件 35/35 与最后一次 analyze 通过，见 `docs/DESKTOP_TRAY_CONTEXT_MENU_EVENT_AND_TRANSACTION_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 Windows 标题栏项目链接增量：旧应用名区域是无名称 `InkWell`，以 `canLaunchUrl` 加默认模式 `launchUrl` 分两次调用，false/异常没有反馈，快速重复输入可并发启动浏览器；32 px 标题栏也未收束长名称、大字号与尺寸文本。`a21492bf` 抽出具名链接，用 Tooltip、Tab 焦点、Enter/Space、可见焦点与等待期禁用统一输入；项目 URI 只调用一次外部应用打开，false/异常显示既有双语反馈并恢复重试，`FittedBox.scaleDown` 让 120×32 / 64 px 长文本夹具不溢出。有效红灯 0 PASS / 1 FAIL，新专项 5/5，最终八文件 45/45 与最后一次 analyze 通过，见 `docs/WINDOWS_TITLE_BAR_PROJECT_LINK_TRANSACTION_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-15 Windows 标题栏控制增量：旧三个系统按钮只有图标和鼠标手势，没有 Tooltip、可访问名称、键盘焦点或焦点指示；同步 `VoidCallback` 也不持有原生 Future，快速重复输入可并发派发动作，异常没有界面反馈。`0e654db8` 增加双语语义与 Tooltip，以 Material `InkWell` 提供 Tab 焦点、Enter/Space 激活和可见焦点边框，并在 `_runAction` 内等待单次动作、等待期禁用、收口异常、显示本地化 SnackBar 后恢复重试。有效红灯 0 PASS / 1 FAIL，新专项 5/5，最终十文件 62/62 与最后一次 analyze 通过，见 `docs/WINDOWS_TITLE_BAR_CONTROL_ACCESSIBILITY_AUDIT_2026_09_15.md`。未构建候选、启动 GUI 或操作设备；W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-14 Windows 窗口几何增量：旧桌面事件在队列外按旧模式分流，普通分支直接异步读取并保存尺寸；读数期间进入/退出 PiP 会污染下次启动大小，最小化、最大化和真全屏尺寸也未隔离，被动 Future 异常另会泄漏。`30c2e4cf` 将 Windows 普通尺寸与 PiP 矩形统一串入宿主队列，执行时按最终模式提交；普通尺寸在读取前后两次核对三种非普通呈现，失败后的队列可重试，桌面事件统一记录异常，非 Windows 路径保持。有效红灯 7 PASS / 1 FAIL，宿主专项 13/13，最终十文件 121/121 与最后一次 analyze 通过，见 `docs/WINDOWS_WINDOW_GEOMETRY_CAPTURE_OWNERSHIP_AUDIT_2026_09_14.md`。未构建候选、启动 GUI 或操作设备；W1-01/W2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-14 Windows 小窗呈现增量：旧 `WindowService` 在退出全屏后若宿主进入异常不会恢复呈现，重试会覆盖原始快照；退出又在全屏/宽屏恢复前先清快照，恢复异常会让原生宿主、播放器和全局 PiP 状态分离。`b08a33f3` 增加呈现 seam、进出 single-flight 和原始快照所有权：进入失败恢复原呈现；退出呈现失败则恢复 PiP 呈现并重新进入宿主，宿主回滚也异常时以类型化结果让 `PlayerManager` 采用真实的普通窗口状态；全局 PiP 状态保留唯一发布者。有效红灯 2 PASS / 3 FAIL，最终七文件 97/97 与最后一次 analyze 通过，见 `docs/WINDOWS_PIP_PRESENTATION_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选、启动 GUI 或操作设备；W2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环；Astra Light 0 次。

> 2026-09-14 Windows 小窗宿主增量：旧 `WindowHelper` 在宿主调用前先改逻辑模式，进出任一步失败都会留下错误模式和部分窗口状态；重复直接调用可并发写窗口，进入未完成时还能保存混合几何，退出又把应用最小尺寸从统一的 400×300 扩大为 800×600。`57ea9a85` 将进出、置顶更新和几何捕获串入同一宿主队列，只在完整成功后提交模式；失败逐项恢复进入前窗口并允许重试，重复进出共享 Future，退出恢复统一最小尺寸。有效红灯 0 PASS / 5 FAIL，加强专项 7/7，最终六文件 80/80 与最后一次 analyze 通过，见 `docs/WINDOWS_PIP_HOST_TRANSACTION_AND_ROLLBACK_AUDIT_2026_09_14.md`。未构建候选或启动 GUI；W2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 Windows 小窗进出增量：旧控制栏以未等待回调进入小窗，Windows 进出没有转换门禁；重复点击会并发调用宿主，原生失败没有反馈，关闭期间迟到完成的进入及已激活小窗关闭/销毁也不会可靠恢复主窗口。`c069dcf2` 以修订号、会话 ID 和播放器身份串行进出，只在宿主成功且仍持有事务时提交状态；等待期间禁用入口，失败保留旧状态并允许重试，关闭/销毁补齐主窗口恢复及关闭后重入栅栏。两轮有效红灯为 42 PASS / 1 FAIL、43 PASS / 1 FAIL，播放器专项 46/46，最终六文件 81/81 与最后一次 analyze 通过，见 `docs/WINDOWS_PIP_TRANSITION_OWNERSHIP_AUDIT_2026_09_14.md`。未构建候选或启动 GUI；W2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 Windows 小窗置顶开关增量：旧共享开关会在原生窗口操作前立即写偏好，同一旧回调可并发派发多次请求，异常后当前层级、显示值和持久值可能分离。`0c38ec34` 改为页面 single-flight，原生成功后才提交；等待期间禁用，失败保持旧值、尽力恢复旧层级、显示双语长文本并允许重试。有效红灯 13 PASS / 1 FAIL，最终五文件 38/38 与最后一次 analyze 通过，见 `docs/WINDOWS_PIP_ALWAYS_ON_TOP_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或启动 GUI；A2-01/W2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 视频设置后台播放开关增量：旧共享开关会在权限/服务结果前立即写偏好，等待期间可重复触发，服务异常保留新值且没有反馈。`cbac24f4` 改为页面 single-flight，按尚未持久化的目标值同步保活，兼容助眠/纯音频会话，并在权限和服务成功后才提交；失败保留旧值、显示双语长文本并允许重试。有效红灯 12 PASS / 1 FAIL，最终六文件 30/30 与最后一次 analyze 通过，见 `docs/VIDEO_SETTINGS_BACKGROUND_PLAYBACK_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 视频设置 ASMR 模式开关增量：共享开关旧实现会在业务回调前立即写 `RxBool` 且始终可点，ASMR 开启会先显示开启再等待权限，关闭也会先落盘再等待定时服务；重复触发可并发工作，异常没有反馈。`d842cb05` 增加默认兼容的禁用/延迟提交合同，并由页面 single-flight、当前路由/控制器栅栏只在权限或服务成功后提交；失败保留旧值、显示双语长文本并允许重试。有效红灯 10 PASS / 1 FAIL，最终五文件 28/28 与最后一次 analyze 通过，见 `docs/VIDEO_SETTINGS_ASMR_MODE_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 视频设置 ASMR 定时增量：旧入口连续触发会叠加弹窗，保存又先写偏好再等待定时服务，失败时留下已变更值且没有可重试反馈。`1ac4919b` 以页面 single-flight、当前路由/生命周期栅栏和根 Navigator 持有弹窗；非法输入改为行内错误，服务等待期间输入、预设、取消、保存和系统返回均停止重复工作，成功后才持久化，失败保留旧值与草稿并允许重试。有效红灯 8 PASS / 1 FAIL，最终四文件 23/23 与最后一次 analyze 通过，见 `docs/VIDEO_SETTINGS_ASMR_TIMER_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 视频设置清晰度路由增量：旧 Wi-Fi/移动网络入口通过全局 `Get.context` 各自创建弹窗，连续触发会叠加两条路由；页面销毁后旧回调抛错，被新页面覆盖后又会把弹窗盖到当前路由。`89bfb10c` 改由页面共享 single-flight，以页面/当前路由/控制器栅栏和类型化结果延迟提交精确目标；滚动内容、16/20 边距、420 px 上限及 48×48 取消动作覆盖 320×480 / 3.0 倍文字。主红灯 5 PASS / 2 FAIL，当前路由红灯 7 PASS / 1 FAIL，最终两文件 23/23 与最后一次 analyze 通过，见 `docs/VIDEO_SETTINGS_RESOLUTION_ROUTE_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 Windows 小窗几何增量：旧运行时捕获/导出把 `displayId` 写到归一化器不读取的层级，尺寸与坐标保留但显示器身份稳定丢失；旧设置回调连续触发还会叠加两个确认路由，并在 320×480 / 3.0 倍英文下各溢出 704 px。`b13d8dea` 统一规范嵌套快照，以页面单次门禁、根 Navigator、滚动正文、48×48 红色动作和生命周期栅栏完成五字段清空。四轮有效红灯依次为 4 PASS / 1 FAIL、4 PASS / 1 FAIL、4 PASS / 1 FAIL、9 PASS / 1 FAIL，最终五文件 31/31 与最后一次 analyze 通过，见 `docs/WINDOWS_PIP_GEOMETRY_CAPTURE_AND_RESET_AUDIT_2026_09_14.md`。未构建候选或操作设备；W1-01/W2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 精细字号恢复默认增量：旧弹窗已具备五项字号说明和滚动正文，但同一 AppBar 回调连续触发会叠加两个确认路由。`2f7df9ef` 让页面在路由前同步持有恢复事务，取消、遮罩、系统返回、确认或页面销毁后统一释放；入口在事务期间置灰，并在提交前核对页面及控制器生命周期。根 Navigator、16/20 边距、420 px 正文与 48×48 红色 Filled 动作覆盖 320×480 / 3.0 倍文字。有效红灯 6 PASS / 1 FAIL，最终页面 7/7 与最后一次 analyze 通过，见 `docs/FONT_SETTINGS_RESET_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 观看记录单项删除增量：旧卡片使用 28×28 裸 `GestureDetector`，没有 Tooltip、键盘按钮语义和取消机会。`a85becfc` 保留小圆形视觉并把入口扩为具名 48×48 `IconButton`；页面以完整直播间标题显示响应式危险确认，与清空共用单次历史变更门禁，并按对象身份只删除确认时捕获的实例。确认期间重新观看同一房间的新对象仍保留。有效红灯 24 PASS / 3 FAIL，最终四测试文件 46/46 与最后一次 analyze 通过，见 `docs/HISTORY_ENTRY_DELETE_ACCESSIBILITY_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A1-05/A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 观看记录清空确认增量：旧页面使用通用确认和普通文本动作，连续触发会叠加弹窗；确认期间新增、重新观看或由刷新/恢复替换的记录也会被最终清空。`db3ef116` 在路由前捕获对象快照并持有页面门禁，以 `Set.identity()` 只移除确认时拥有的实例；同房间后续观看仍保留。弹窗补齐双语数量、滚动正文、16/20 边距、420 px 正文与 48×48 红色 Filled 动作。旧实现专项门禁退出失败，最终三文件 34/34 与最后一次 analyze 通过，见 `docs/HISTORY_CLEAR_CONFIRMATION_AND_SNAPSHOT_AUDIT_2026_09_14.md`。未构建候选或操作设备；A1-05/A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 本地缓存清理确认增量：旧页面在确认阶段没有忙碌门禁，连续触发会叠加两个弹窗；清理动作也缺少明确的破坏性层级和 48×48 命中合同。`6bcbcb8b` 从确认前到 `clearCache()` 完成持有页面事务，与底层清理合并形成两层门禁，并补齐根 Navigator、滚动正文、16/20 边距、420 px 正文和红色 Filled 动作。有效红灯 1 PASS / 2 FAIL，最终两文件 10/10 与最后一次 analyze 通过，见 `docs/CACHE_CLEAR_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 账号退出确认增量：旧确认没有目标平台，同一账号行连续触发会叠加两个弹窗，Bilibili 页面侧事务也没有覆盖浏览器 Cookie 清理。`86939e0d` 让七个平台共用具名的响应式退出确认，并由账号控制器从弹窗到清理完成持有单次任务；320×480 / 3.0 倍中英文下平台名、取消和退出均可达。有效红灯 4 PASS / 2 FAIL，最终三文件 16/16 与最后一次 analyze 通过，见 `docs/ACCOUNT_LOGOUT_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 版本历史下载确认增量：旧确认没有目标文件名；同一下载动作连续触发会叠加两个弹窗，下载回调执行期间也缺少重复工作门禁。`cdc18971` 以规范 URI、捕获文件身份和页面级忙碌状态串行确认与平台下载，文件名缺失时回退 URL 路径或本地化占位；滚动弹窗、16/20 边距、420 px 正文和 48×48 动作覆盖 320×480 / 3.0 倍文字。有效红灯 3 PASS / 2 FAIL，最终四文件 19/19 与本批唯一一次 analyze 通过，见 `docs/VERSION_HISTORY_DOWNLOAD_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md`。未启动真实下载、构建候选或操作设备；A1-05/A2-01/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 WebView2 缺失提示增量：旧水平标题在 320×480 / 3.0 倍文字下中文向右溢出 240 px、英文溢出 1536 px，动作仍是通用确认；启动探测与搜索动作连续触发还会叠加两个弹窗。`5eea37ec` 以同步门禁、类型化弹窗结果和控制器退出栅栏串行路由与外部启动，使用可滚动弹窗、可换行标题、48×48 动作及明确的双语“打开下载页”，下载目标改为微软官方语言中立入口。有效红灯 0 PASS / 3 FAIL，最终六文件 101/101 与本批唯一一次 analyze 通过，见 `docs/WEBVIEW2_MISSING_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A1-04/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 录制中心取消监控增量：旧通用确认没有目标任务和文件保留说明，在 320×480 / 3.0 倍英文下向下溢出 320 px，平台标签另向右溢出 61 px；同一按钮回调连续触发会叠加两个路由。`b85217f4` 以任务捕获、页面 Navigator、同步忙碌门禁和等待式 `unRecorder` 建立单次事务，确认正文显示完整标题并明确保留既有文件，滚动弹窗与可换行标签覆盖大字号。有效红灯 38 PASS / 4 FAIL，最终两文件 43/43 与本批唯一一次 analyze 通过，见 `docs/RECORDER_MONITOR_REMOVAL_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；AND-REC-06/A6-02/W3-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 关注分区取消关注增量：旧确认弹窗在 320×480 / 3.0 倍英文长名称下稳定向下溢出 128 px，同一点击回调连续触发两次还会叠加两个确认路由。`ff57bcbd` 以同步忙碌门禁、捕获目标身份、页面 Navigator 和弹窗自身 context 建立单次事务，并使用统一滚动面、16/20 边距及至少 48×48 的动作尺寸。有效红灯 4 PASS / 2 FAIL，最终三文件 24/24 与本批唯一一次 analyze 通过，见 `docs/FAVORITE_AREA_UNFOLLOW_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md`。未构建候选或操作设备；A1-03 保留 PASS、W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 观看记录保留数量增量：旧弹窗在 320×480 / 3.0 倍英文文字下稳定向下溢出 260 px，“Apply”命中点落在窗口外；空白、非数字或负数还会静默返回。`0272de8a` 统一标题/正文滚动边界、纵向全宽 48 px 应用动作和可换行底部动作，并以弹窗 State 提供双语行内错误、继续编辑清错、键盘完成与点击共用校验。有效红灯 19 PASS / 2 FAIL，最终三文件 30/30 与本批唯一一次 analyze 通过，见 `docs/HISTORY_RETENTION_DIALOG_LAYOUT_AND_VALIDATION_AUDIT_2026_09_14.md`。未构建候选或操作设备；AND-HISTORY-01/A1-05/W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 Windows 视频输出 fit 尺寸增量：旧 viewport / DPR 策略始终按 `contain` 的最小轴分配原生纹理，1920×1080 源在 500×500 视口选择 `cover` / `fitHeight` 时仍只分配 500×282，再由 Flutter 放大到约 889×500。`7715e0fa` 将有效 `BoxFit` 传到尺寸策略和尺寸器，按主导轴分配、保持源宽高比与源尺寸上限，并在显示模式变化时重新发布 `setSize`。有效红灯为缺少 `fit` 合同，最终四文件 26/26 与本批唯一一次 analyze 通过；Windows x64 Debug ZIP 142,778,353 B / `8B823AC8…5B43` 构建成功，见 `docs/WINDOWS_VIDEO_OUTPUT_FIT_SIZING_AUDIT_2026_09_14.md`。未启动 GUI 或采集 GPU；W3-03/#767 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 Windows 副屏亮度增量：Issue #863 的稳定写入链来自仍被生成注册器加载的 `screen_brightness_windows`。该插件注册后监听窗口大小/激活/关闭消息，通过 DDC/CI 把捕获值写到窗口当前所在的物理显示器；旧 `6cf42712` 的 CMake 变量没有被生成逻辑或插件消费。`a0bbe074` 改为平台接口与 Android/iOS 直接实现，Windows/macOS 注册器、锁文件和新 ZIP 均移除桌面亮度插件，移动端实现保留。有效红灯 1/4，最终 13 文件 245/245 与本批唯一一次 analyze 通过；Windows x64 Debug 构建成功，日志/安装清单/1,301 项 ZIP 均 0 命中，EXE 依赖表也不含亮度 DLL，见 `docs/WINDOWS_SECONDARY_MONITOR_BRIGHTNESS_OWNERSHIP_AUDIT_2026_09_14.md`。未启动 GUI 或写亮度；W1-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 房间卡片设置入口与字段增量：本地标签对照确认 `upstream-v3.1.2` 到 `upstream-v3.1.3` 删除设置目录九个文件、共 6,736 行，主题入口随之消失，与 Issue #864 的稳定版现象一致。`230ad13d` 按当前卡片架构恢复移动/桌面独立配置、三种预设身份、真实预览、可见字段、有限圆角、旧四键和备份合同；后续 #867 证明简洁预设的无封面拓扑当时仍缺失，并已由 `bc083310` 补齐。原批 14 个受影响测试文件 154/154、最后一次 Dart 编辑后的最终 analyze 均通过，见 `docs/ROOM_CARD_SETTINGS_REGRESSION_AND_RESTORATION_AUDIT_2026_09_14.md` 与 `docs/ISSUE_867_ROOM_CARD_COMPACT_LAYOUT_AUDIT_2026_09_19.md`。A1-02/A2-01 保持 RUN。

> 2026-09-14 WebDAV 恢复增量：`79d8965f` 在远端读取和本机设置变更前显示包含完整文件名与覆盖说明的响应式确认弹窗；控制器等待页面结果，并在确认后、读取后及本地恢复后核对服务代次与目录路径，取消、系统返回、服务替换和目录变化均保持零旧状态提交。旧源码有效红灯 0/1，页面 27/27、目录状态 44/44、最终七文件 90/90 与一次全库 analyze 均已留档，见 `docs/WEBDAV_RESTORE_CONFIRMATION_AND_TRANSACTION_AUDIT_2026_09_14.md`。A1-05 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 WebDAV 文件行增量：`0684adb8` 将文件/目录名称限制为两行省略并保留完整 Tooltip，时间限制为一行，以路径末段补齐空白名称；删除确认由页面创建响应式危险弹窗并明确显示目标名，控制器只保留单次忙碌、服务/目录身份与远端删除事务。旧实现在 320×480、3.0 倍文字和五段重复名称下把动作菜单中心推到纵坐标 1844 px；有效红灯 0/1、页面 26/26、最终七文件 85/85 与一次全库 analyze 均已留档，见 `docs/WEBDAV_FILE_ROW_AND_DELETE_DIALOG_AUDIT_2026_09_14.md`。A1-05 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 WebDAV 面包屑增量：`88c309be` 用路径快照、下一帧动画、代次栅栏和稳定范围校准保持深层路径的当前末段可见；单段限制为 240 px 单行省略并保留完整 Tooltip。根目录父级请求改为返回 `false`，非根目录返回 `true` 并读取父级，控制器不再弹出全局路由。旧实现在 320×480、3.0 倍文字和八段长路径下当前末段完全离开视口；有效红灯 0/1、直接两文件 65/65、最终七文件 84/84 与一次全库 analyze 均已留档，见 `docs/WEBDAV_BREADCRUMB_VISIBILITY_AND_ROUTE_AUDIT_2026_09_14.md`。A1-05 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 WebDAV 配置表单增量：`998a635a` 将标题与四个字段统一纳入 `AlertDialog` 单一纵向滚动面，长编辑标题限制三行并保留完整 Tooltip；弹窗使用 16/20 边距、400 宽正文、向下动作溢出和 48×48 命中尺寸。旧实现在 320×480、3.0 倍文字与四段重复名称下稳定向下溢出 3884 px；有效红灯 0/1、修订后专项 1/1、直接两文件 63/63、最终七文件 82/82 与一次全库 analyze 均已留档，见 `docs/WEBDAV_CONFIG_FORM_RESPONSIVE_AUDIT_2026_09_14.md`。A1-05 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-14 WebDAV 配置抽屉增量：`1f327e0c` 将配置名称限制为两行省略并保留完整 Tooltip，为编辑/删除动作补齐提示；配置表单和删除确认由页面 context 创建，选择/删除控制器不再关闭全局路由，页面分别拥有抽屉与弹窗关闭时机。旧实现在 320×480、3.0 倍文字下四段重复长名称即可让删除图标失去可命中位置；直接两文件 62/62、最终七文件 81/81 与一次全库 analyze 均已留档，见 `docs/WEBDAV_CONFIG_DRAWER_ROUTE_AND_LAYOUT_AUDIT_2026_09_14.md`。A1-05 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 桌面退出增量：`9f463efb` 将 `exit`/`minimize` 统一为启动、运行时与当前/旧版备份共享的动作合同，默认值固定为退出；关闭确认改为 single-flight 类型化路由、可滚动窄屏布局和 48×48 动作，原生操作完成后才返回成功，失败恢复偏好、关闭拦截及原窗口可见状态。旧 320×480、3.0 倍英文文字下稳定向下溢出 224 px；新专项 6/6、最终七文件 40/40 与一次全库 analyze 均已留档，见 `docs/DESKTOP_EXIT_DIALOG_AND_ACTION_TRANSACTION_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 共享选项弹窗增量：`74ba4778` 将自然宽度 Radio/文字行改为标题与选项共同滚动的 `AlertDialog`，正文限制 420 宽，文字可收缩换行，整行至少 48 高并共享所属路由选择回调；当前值、行尾命中和系统返回 `null` 均有确定性覆盖。旧实现在 320×480、3.0 倍文字下逐项向右溢出 2362/2411 px、向下溢出 80 px，1.0 倍英文项仍向右溢出 55 px；有效红灯 0/2、最终五文件 14/14 与一次全库 analyze 均已留档，见 `docs/SHARED_OPTION_DIALOG_LAYOUT_AND_SELECTION_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 共享确认与消息弹窗增量：`1edf8a67` 将确认与单动作消息统一为可滚动 `AlertDialog`，正文限制 420 宽并保留 16/20 窗口边距；动作横向空间不足时向下排列，内置命中尺寸至少 48×48，并使用弹窗所属 context 返回。旧实现在 320×480、3.0 倍文字下分别溢出 320 px 与 140 px；有效红灯 0/2、最终五文件 45/45 与一次全库 analyze 均已留档，见 `docs/SHARED_ALERT_DIALOG_LAYOUT_AND_ROUTE_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 共享文本编辑弹窗增量：`85ca7a73` 将控制器所有权从静态方法移到弹窗路由子树，确认/取消使用所属 context 返回；内容使用有界滚动视口，窄屏或大字号动作改为纵向全宽，常规桌面仍保持紧凑布局。有效红灯 0/2、最终三文件 14/14 与一次全库 analyze 均已留档，见 `docs/SHARED_EDIT_DIALOG_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 更新与版本历史 Web 目标增量：`ce051c03` 将更新下载和版本历史统一到完整结构化 HTTP(S) URI 合同，拒绝非空 userInfo 与 1～65535 之外的显式端口；复制和下载动作各自只解析一次，并消费同一个规范 `Uri.toString()`，避免校验值与实际传递值分离。稳定红灯 13 PASS / 3 FAIL、直接 16/16 和最终九文件 47/47 均已留档，全库 analyze 无问题，见 `docs/UPDATE_AND_RELEASE_WEB_TARGET_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 下载文件名增量：`83f38ecc` 把更新页、版本历史与下载弹窗共用的安全文件名从 160 UTF-16 code unit 改为 240 UTF-8 字节 basename，给 `.part`/`.previous` 预留单目录项预算；截断按完整 Unicode scalar 执行，扩展名最多保留 32 字节，超长名称加入 12 位 SHA-256 摘要以隔离共享前缀碰撞。稳定红灯 8 PASS / 2 FAIL、直接 10/10 和最终八文件 39/39 均已留档，全库 analyze 无问题，见 `docs/DOWNLOAD_FILENAME_UTF8_AND_COLLISION_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 HTTP(S) 目标校验与 IPTV 网络导入增量：`e46ffbc4` 用完整结构化 URI 替换未锚定且限制顶级域名长度的正则，统一 HTTP/HTTPS scheme、非空 host、1～65535 显式端口和内部无空白合同；localhost、IPv4/IPv6、长顶级域名与编码组件保持有效，嵌入文本、无 scheme、非 HTTP 协议和越界端口被拒绝。校验、外部打开和 IPTV 网络导入共享决策。稳定行为红灯 0/3、直接 3/3、页面集成 45/45 和最终十文件 128/128 均已留档，全库 analyze 无问题，见 `docs/HTTP_TARGET_VALIDATION_AND_IPTV_IMPORT_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 浏览器日志页增量：`56c6b9f8` 将读取限制为 `GET /`，将清空限制为带动作头的 `POST /clear`，其他请求按 403/404/405 返回；全部响应增加禁缓存/嗅探/嵌入、同来源资源、无引用来源与 CSP。页面同步增加窄屏换行、44 px 动作、键盘焦点、空状态、清空确认和 `aria-live` 反馈，并移除内联点击处理。有效红灯、实际回环 HTTP 15/15 和最终九文件 37/37 均已留档，全库 analyze 无问题，见 `docs/LOG_BROWSER_HTTP_AND_RESPONSIVE_UI_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 本地日志增量：`bfe935bc` 将开关改为 latest-target 单飞事务，只在文件写入器和 HTTP 服务启停成功后提交状态，失败回滚并显示双语反馈；快速相反请求按各自目标返回结果。浏览器端点只保留在当前运行期，服务使用回环地址和系统原子端口；设置注册前的早期日志保持诊断路径，Release 在显式开启的会话内提供有界浏览器缓冲。多轮有效红灯、分层回归和最终八文件 **32/32 PASS** 均已留档，全库 analyze 无问题，见 `docs/LOCAL_LOGGING_TRANSACTION_AND_ENDPOINT_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 Windows 开机启动增量：`f24b8f11` 将应用初始化、设置点击和备份式响应写入统一为注册表实际状态读取、必要写入、回读验证后提交的单飞事务；失败按实际状态回滚并显示双语反馈，事务期间禁用开关。Run 值改为动态 UTF-16 读取和完整 FFI 清理，并按当前可执行文件目标识别便携目录移动后的旧路径。有效红灯、首轮三文件门禁、备份响应 4/4 和最终八文件 41/41 回归均已留档，全库 analyze 无问题，见 `docs/WINDOWS_STARTUP_TRANSACTION_AND_REGISTRY_COMMAND_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 真实在线平台偏好增量：`0744c7b3` 修复启动只按列表长度判断归一化变化的问题，将小写、去空白、去重和并发在线能力过滤统一到 Hive、运行时、当前/旧版备份共享解析、配置提取、导出与设置开关。稳定红灯 0/3、首轮 14/14 和最终十二文件 87/87 回归均已留档，全库 analyze 无问题，见 `docs/AUDIENCE_PLATFORM_PREFERENCE_PERSISTENCE_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 播放器显示偏好增量：`9cf8d55e` 将六种显示模式索引和 Wi-Fi/移动网络五个稳定画质键统一为启动、运行时、当前/旧版备份共享解析、配置提取、导出和 UI 消费合同；越界显示模式回落到默认 contain，未知画质回落到原画，重复的显示模式列表已移除。有效红灯、15/15 控制器回归、19/19 控制器与 Widget 回归及最终十文件门禁均已留档，全库 analyze 无问题，见 `docs/PLAYER_DISPLAY_PREFERENCE_PERSISTENCE_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 Windows 窗口尺寸增量：`5710da2c` 将启动宽高统一为默认 1280×720、最小 400×300、单边最大 16384 的 Hive/窗口事件/备份/导出/首帧合同；PiP 增加完整有限矩形检查，设置弹窗增加范围反馈、原生应用门禁及路由子树输入控制器所有权。有效红灯、生命周期诊断、27/27 首轮和十三文件 98/98 最终回归均已留档，全库 analyze 无问题，见 `docs/WINDOW_SIZE_PERSISTENCE_AND_DIALOG_TRANSACTION_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 主题设置增量：`6ebd3686` 为模式、语言、RGB/ARGB 颜色、加载样式和 0～64 有限间距建立共享合同，在观察器前修复 Hive，并统一运行时写入、当前/旧版备份、导出及首帧/UI 消费路径。有效红灯、4/4 首轮与十四文件 189/189 最终回归均已留档，全库 analyze 无问题，见 `docs/THEME_SETTINGS_PERSISTENCE_AND_FIRST_FRAME_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 单页数量设置增量：`68a2a9cd` 将 Hive、运行时写入、当前/旧版备份和导出统一为 1～100 的唯一有序合同与自适应回落，并保证默认值始终属于候选；保存不再修改调用方列表。管理弹窗补齐范围/重复反馈，输入控制器由路由子树持有，确认退出不再抢先释放。有效红灯与生命周期回归均已留档；首轮 11/11、最终十一文件 109/109 与全库 analyze 通过，见 `docs/PAGE_SIZE_SETTINGS_BOUNDARY_AND_LIFECYCLE_AUDIT_2026_09_13.md`。A2-01 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-13 代理端点增量：`abc0d714` 将应用代理与播放器代理的 Hive、当前/旧版备份和导出统一为严格主机类型、1～65535 端口与 7897 回落值，并在观察器安装前修复持久端点。有效红灯锁定共享合同缺失；首轮五文件 29/29、最终十文件 58/58 与全库 analyze 通过，见 `docs/PROXY_ENDPOINT_PERSISTENCE_AUDIT_2026_09_13.md`。A2-01/A2-05 保持 RUN，账本仍为 20 PASS / 42 RUN / 0 NR，共 42 组未闭环。

> 2026-09-12 当前累计候选：精确 `3e41e848` arm64 Debug 已完成同签名覆盖安装，安装前后 58 个状态文件逐路径/大小/SHA 一致，设备 APK 哈希匹配候选。当前 Bilibili 冷启动、刷新、播放、10 条可见弹幕、音频模式往返、PiP 恢复、致命日志与退出清理 16/16 通过；标准流呈现 7/7、抖音竖屏呈现 9/9 通过。它刷新 A0/A3 当前候选证据，不新增宏观 PASS；详见 `docs/CURRENT_ANDROID_CANDIDATE_2026_09_12.md`。

> 2026-09-12 增量：网页搜索已补齐严格 HTTP(S) 启动参数、WebView 唯一所有权、加载进度/错误/重试、浏览历史优先的系统返回、最新房间确认队列及退出栅栏；发布版隐藏调试入口并收敛完整 URL/响应头/控制台日志。新增 13/13、相关六文件 100/100，见 `docs/WEB_SEARCH_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md`。A1-04 保持 `RUN`，真实平台、代理与 Android/Windows WebView 候选继续。

> 2026-09-12 增量：DLNA 发现按搜索代次管理订阅、超时、快照和释放；刷新隔离旧会话，投屏以单一事务严格串行暂停旧设备、设置地址和播放，并在退出后停止续发命令。新增 12/12、相关四文件 41/41，见 `docs/DLNA_DISCOVERY_CAST_LIFECYCLE_AND_LAYOUT_AUDIT_2026_09_12.md`。A1-05 保持 `RUN`，真实接收器、多网卡与 Android/Windows 候选继续，宏观计数不变。

> 2026-09-12 增量：已知直播间获取直链/投屏的清晰度与线路选择器改为有界滚动主体和固定取消动作，阶段切换归零滚动；系统返回、路由移除和销毁会完成当前选择并释放单次动作门禁。定向 24/24、相关六文件 87/87，见 `docs/KNOWN_ROOM_LINK_SELECTOR_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md`。A1-05 与 A3-04 保持 `RUN`，真实平台、接收器与双端候选继续，宏观计数不变。

> 2026-09-12 增量：Firebase 个人中心的配置预览、上传、下载和退出已统一为页面所有的单一活动事务；下载覆盖本机设置与退出增加确认，空账号 ID、动作异常和安全返回均有确定性回归。320×480 / 3.0 倍英文下全部入口可滚动到达，见 `docs/FIREBASE_PROFILE_ACTION_AND_LAYOUT_AUDIT_2026_09_12.md`。A1-05 与 A2-01 保持 `RUN`，真实 Firebase 与双端候选操作继续。

> 2026-09-13 增量：房间卡片长按与标签分配已统一权威映射、有效 ID/旧键写入规则和响应式弹窗；新增标签复用 15/40 边界、IME 并自动选中。关注按钮另统一规范集合观察、所属 Navigator、取消关注确认和 single-flight。标签原有专项 4/4、相邻十文件 131/131；关注追加后同文件 8/8、相邻九文件 73/73，全库 analyze 通过。K90 最新覆盖安装后完成真实 Bilibili 直接关注关闭、取消提示/取消/确认、状态重开、再次关注、创建标签、确认及重开保持，设置精确恢复且无 FATAL/ANR。见 `docs/ROOM_CARD_TAG_ASSIGNMENT_LAYOUT_AND_INTEGRITY_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 `RUN`，Windows 右键、Release、其余平台和大量标签原生滚动继续，宏观计数不变。

> 2026-09-13 增量：分享口令改为消费者成功后才提交已处理状态，合并并发剪贴板检查，以有界 SHA-256 历史抑制自分享，并在桌面/移动交接失败时保留重试和双语反馈；导入弹窗由发起路由持有，在 320×480 / 3.0 倍英文下可滚动操作。相邻七文件 40/40、全库 analyze 通过。精确 arm64 Debug 保留数据覆盖 K90 后，真实 Bilibili 分享动作打开 `com.android.intentresolver/.ChooserActivity`，口令预览与系统目标可见；不选外部目标直接返回后原房间动作仍可达，Hive 精确恢复且无 FATAL/ANR。见 `docs/SHARE_COMMAND_HANDOFF_AND_IMPORT_DIALOG_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 `RUN`，Windows 原生剪贴板导入、双实例、Release 和异常平台通道继续，宏观计数不变。

> 2026-09-13 增量：Android 已实际消费冷启动和运行中 `ACTION_SEND` 口令，并按内容 URI 复制后导入 M3U。原生轮次据实暴露并修订 AlertDialog intrinsic、Android 17 外部路径 EACCES 和暂存根错误；随后再隔离单 URI 异常，并以 UTF-8 字节和完整 code point 清洗/截断显示名。此前分享联合回归 110/110、最终路径 15/15 和全库 analyze 已通过，本边界增量直接 11/11、Kotlin 审计、精确构建与 K90 门禁通过。除冷/热/重复口令、混合附件、单 M3U 和真实 M3U+XMLTV 多附件外，Debug-only Provider 还验证类型/查询异常不会抑制后续两份 M3U，查询异常按 URI basename 回退，中文/emoji/控制字符超长名安全化为 175 UTF-8 字节 basename；频道各精确一条、暂存树为空、无 FATAL/ANR。同源码 R8 Release 测试包继续通过公共分享链和 Debug 探针排除；独立 DocumentsUI 又真实选中 M3U+XMLTV，经系统 chooser 将 `ACTION_SEND_MULTIPLE` 交给 Pure Live。两份 ExternalStorageProvider URI 明确授权给目标包，播放列表与 EPG 各精确入库一次，17/17 原生检查通过。该包使用 Debug 证书并标记 `debug-signed`。三轮 IPTV 树和 Hive 均精确恢复、外部夹具精确删除、应用停止。见 `docs/ANDROID_INCOMING_SHARE_INTAKE_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 `RUN`，Windows 和最终正式签名候选继续，宏观计数不变。

> 2026-09-13 增量：应用退出分钟数与 IPTV 自动同步小时数已统一持久化、当前/旧版备份、公开写入、UI 和最终调度边界；退出计时同一显式动作不再被两个延迟观察器二次重置。`d68db3d7` 的首轮四文件 25/25、最终九文件 79/79 与全库 analyze 通过，见 `docs/DEFERRED_TIMER_SETTINGS_AUDIT_2026_09_13.md`。A1-05/A2-01 保持 `RUN`，真实双端倒计时退出、重启和 IPTV 服务端同步继续，宏观计数不变。

> 2026-09-12 增量：Android 前台 Activity 现于每次 `onResume` 将硬件音量控件建议流恢复为 `STREAM_MUSIC`，不拦截按键或直接写系统音量；宿主合同原始 0/1，最终同提交 71/71、全库 analyze 及 `d8de9855` arm64 Debug 构建/完整性/16 KB ELF 对齐通过。后续 `3e41e848` 累计候选已覆盖安装：首页软件注入音量增加使媒体流 0→10、铃声流保持 0，随后恢复媒体流 0/muted、桌面、进程与 stay-awake。实体按钮、播放中、弹窗、全屏、PiP、外部 Activity、前后台和其他输出路由仍按 `AND-PLAY-16` 复验；A3-04/A7-02 与宏观计数不变，见 `docs/ANDROID_HARDWARE_VOLUME_ROUTING_AUDIT_2026_09_12.md`、`docs/CURRENT_ANDROID_CANDIDATE_2026_09_12.md`。

> 2026-09-12 增量：直播画面中的房间方向和竖屏全屏显示模式选择器改为有界滚动内容与固定取消。“记住房间方向”只保存在路由草稿，选择方向后与方向一次提交；取消和系统返回不写设置。320×480 / 3.0 倍中英文新增 5/5、相关七文件 58/58，见 `docs/PORTRAIT_PLAYBACK_PICKER_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_12.md`。AND-SET-07、A3-03/A3-04/A3-07 及宏观计数不变，真实竖屏与 Android 候选继续。

> 2026-09-12 增量：直播间标题栏录制动作改为单一等待事务，提交前按房间重新读取任务，空添加结果不提示成功；录制中心导航等待对话框反向动画结束。五项动作使用有界滚动主体和固定取消，320×480 / 3.0 倍中英文下连续可达。新增 6/6、相关六文件 102/102，见 `docs/ROOM_RECORD_ACTION_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_12.md`。A3-04、A3-05、W2-04 与 W3-01 保持 `RUN`，真实录制和双端候选继续，宏观计数不变。

> 2026-09-13 增量：`fec7eae9` 将 Android 普通 MPV 音频输出改为

> `audiotrack,aaudio,opensles,` 有序回退，并把设置页限制为当前 Android 包实际包含的驱动。

> 同提交 K90 Debug 候选保留数据覆盖后完成 5/5 次同类循环，14/14 门禁通过；新 PID 日志尾窗

> 中 AudioTrack 相关 152 行，OpenSL ES、unknown-key 与 `setVolume -19` 均为 0。Binder

> death-recipient 告警仍单列跟踪；测试器的瞬态 TID 退出竞态由 `da8c15b1` 修订并重跑通过。

> 后续 `09315462` 的 Android 五项音频菜单 Widget 与 `3bfda37b` 的双语语义设置路由通过，

> 同一 K90 APK 的原生菜单 6/6 检查完成且规范 Hive 已恢复。

> 本增量不改变 A7-04 的 `RUN` 状态，详见

> `docs/ANDROID_AUDIO_OUTPUT_BACKEND_AUDIT_2026_09_13.md`。
