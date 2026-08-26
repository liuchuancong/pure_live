# v3.0.0 build 4088 全仓审查

## 冻结范围

- 维护分支：`liuchuancong/pure_live:master`
- 上游：`liuchuancong/pure_live@e808dcaef14627413d5b1f634d8c7e8f6eb6103c`
- merge base：`e808dcaef14627413d5b1f634d8c7e8f6eb6103c`
- 入站上游提交：0；上游冻结点已经包含在维护分支中，没有用远端树覆盖本地修复。
- 审查覆盖：全部 Git 已跟踪文件以及提交前非忽略新增文件；机器清单按直播/播放器、平台接口、设置持久化、导航、五个平台原生层、依赖、工作流、测试、资源和文档分类。

机器证据由以下命令生成，JSON 位于不提交的 `local-artifacts`：

```powershell
PowerShell -File tool/review_upstream_update.ps1 -BaseRef HEAD -UpstreamRef upstream/master -ReportOnly
python tool/audit_repository.py --output local-artifacts/repository-audits/build-4088.json
```

仓库新增手动只读工作流 `Audit Upstream Update`，执行同一冻结、逐提交/逐文件盘点和全仓扫描，只上传证据，不合并、不构建、不发布。真正合并仍须提交含 `file_review`、`conflict_resolution`、`verification_plan` 的审查文档并通过显式批准门禁。

## 阻断级发现与修复

### P0 — Android 直播页系统侧滑返回失效

根因不是播放器画面，而是返回模型冲突：直播控制器注册全局 `back_button_interceptor_plus`，Manifest 又关闭 Android 预测性返回；正常返回分支在路由确认退出前执行 `clearListener()`。Flutter 3.47 / targetSdk 37 下，全局拦截、系统边缘手势、弹窗 Navigator 和直播路由会竞争，产生“侧滑无响应”、第一次手势被吞或页面未退出但播放器监听已拆除。

修复：

- 删除全局拦截依赖和控制器注册/注销代码，启用 `enableOnBackInvokedCallback=true`。
- 直播页改为路由局部 `PopScope`。普通竖屏允许系统直接 pop；横屏/全屏拦截一次并恢复普通模式；弹窗和底部面板继续由顶部路由优先关闭。
- 返回手势不再提前清理播放器监听，控制器只在真实路由销毁后执行资源释放。
- 新增三组 Widget 回归：普通返回、全屏两段返回、弹窗优先返回。

### P1 — 可变供应链与不可复现 Windows 打包

- `flutter_inappwebview` 使用可移动分支名，远端分支变化会让相同源码解析出不同依赖；已固定到实际锁定的 40 位提交 `3e6c4c4a25340cd363af9d38891d88498b90be26`。
- Windows 工作流同时克隆 Fastforge 可移动分支、激活未指定版本的 Fastforge/Melos，且 Chocolatey Inno Setup 未锁版本；现统一固定 `fastforge 0.6.0` 与 `Inno Setup 6.7.1`，删除冗余源码克隆。
- 旧全平台工作流仍会并发启动多个 runner；现按 Android → Windows → Linux → Apple 串行，并在每阶段验证此前明确选择的平台成功。
- 全平台工作流全部使用 `flutter pub get --enforce-lockfile`；审计器阻止可变 Action/Git 引用、无版本全局 Dart 激活、可变 Git clone、未锁 Chocolatey 包和未锁 Pub 解析重新进入。

### P1 — Windows 165 Hz 弹幕策略入口缺失

Windows 原生层已经正确发布当前显示器的当前/最大刷新率，并在跨显示器与模式变化后更新；缺陷在设置页只向 Android 暴露“省电/均衡/最高”档位，因此 Windows 自动弹幕总是读取新安装默认的省电档，最高只能 60 FPS。现在 Windows 同样显示档位选择，变更通过既有响应式订阅立即更新直播和小窗弹幕；系统显示模式信息仍保留独立刷新入口。

### P1 — MSIX 日志目录按钮指向和错误反馈

日志写入实际目录是 `LOGS/log`，旧 UI 只验证父级 `LOGS` 后打开拼接的子路径且不等待结果；子目录不存在或 shell 打开失败时会落到“文档”或静默结束。现在日志写入器与 UI 共用唯一目录解析，检查并打开实际目录，Windows Explorer 使用参数化 detached 启动，macOS/Linux 校验进程退出码，失败显示明确反馈。

### P1 — Windows MSIX build number 漂移

应用版本提升后 `windows/packaging/msix/make_config.yaml` 仍保留旧 build number，会造成 Release 文件名、应用包版本与更新源不一致。现改为 `3.0.0.4088`，静态构建策略校验把 MSIX 版本与 `pubspec.yaml`、`assets/version.json` 绑定。

## 风险路径复核

- **直播/播放器/弹幕**：房间控制器所有权、普通/横屏/全屏/PiP 表达切换、弹幕恢复、音频模式串行队列、画质事务和资源释放均进入测试门禁；返回修复不销毁仍在使用的播放器会话。
- **导航/启动**：路由局部返回、弹窗优先级、Windows 单实例早期互斥、启动刷新和多窗口参数路径分开检查。
- **持久化/升级**：新增 build 不更换应用 ID；Hive 键、备份恢复、历史容量、关注去重、Windows 旧目录迁移保持兼容。
- **平台接口**：公开接口探针覆盖 Bilibili、Douyu、Huya、Douyin、Kuaishou、CC、Twitch、SOOP 和 YY 的分类、搜索、房间、弹幕/播放节点与关键字段合同。
- **原生与发布**：Android 预测性返回、ABI/签名；Windows 版本/窗口/路径；Linux/macOS/iOS 产物结构；Release 源码 SHA、版本、校验和与资产完整性分别验证。
- **生命周期库存**：全仓扫描列出 `Timer.periodic`、Stream `.listen` 和空 catch；高频控制器逐一核对取消/关闭路径。空 catch 只保留在可选系统/注册表/兼容探测等允许失败的边界，不作为业务成功信号。

## 近期上游 Issue

- #800/#802 的普通直播页与竖屏比例回归已由 build 4087 的布局恢复及确定性几何测试覆盖，build 4088 保留该修复。
- #801 的 Windows 高刷新率档位和 MSIX 日志目录在本 build 补齐。
- #793、#767、#708 的单实例、viewport 纹理/高 DPI 和工作区全屏路径保留既有修复与回归。
- #792、#779 是功能请求，不伪装为本次稳定性缺陷。

详细 Issue 结论见 `ISSUE_AUDIT_2026_08_25.md`。

## 交付判定

只有以下条件全部成立才原位替换 `v3.0.0`：静态策略和全仓审计零错误、格式化无差异、Flutter Analyze 通过、完整 Flutter 测试通过、公开接口探针通过、目标平台 Release 构建/签名/结构/校验和通过，并且旧 Release 资产先全部删除后再上传同一 build 4088 资产。任一阶段失败时保持 Release 为草稿，不发布混合资产。
