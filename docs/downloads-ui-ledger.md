# 下载面改造台账（music / 红果 / B站 + 预览页）

**用途**：这条队列是「直播录制 = 录像库」那条线在三个下载模块上的续集。每轮自动任务从这里取**第一个未勾项**做完并勾选；改前先 `git status --porcelain` 比对，
若下面这些文件已有未提交改动，说明另一条线正在写：本轮**只做只读复核**，在末尾「状态」里记一行，不要动这些文件。

**验收门（每一轮都必须过）**：`dart analyze lib` 无问题；只对本轮真正编辑过的**单个文件路径**跑 `dart format --line-length 120`，绝不传目录；按 pathspec 提交自己改的文件，**不 push**（推送留给人工确认）。
**禁区**：不碰直播模块（modules/live）与设置导航结构；不删他人文件；`music_songlists_view.dart`、三个 plugin registrant、`pubspec.yaml`/`pubspec.lock` 属其它车道，永远不进提交。

## 已完成
- [x] D1 字节/速率格式化收成一个来源（`shared/widgets/download_format.dart`），修掉音乐只到 MB；`formatRecordingBytes` 转调它。
- [x] D2a B站删视频时连弹幕旁挂一起删（`deleteDanmakuSidecars`，与 writer 同命名规则，在 `shared/danmaku/danmaku_files.dart`）。
- [x] D2b vod / 红果进预览页传 `onDeleted`，播放器里删文件会回写任务；`previewDeleteBody` 文案同步改成真话（zh+en）。
- [x] D3a 预览页顶栏补「用系统播放器打开 / 所在目录 / 删除」，文件已不存在时只留目录；新增 `common.previewOpenFile`。
- [x] D3b vod / 红果的预览项传 `groupPath`/`groupLabel`，右侧列表按剧/分集成组而不是流水号。

## 待做（按顺序）
- [x] D2c **存在性标记**（已落地：`shared/widgets/download_workspace.dart` 的 `downloadFilePresent`，一行一次 `existsSync`、不扫目录、下载中的行不判缺失；三页与详情复用，缺文件时行内说「文件已删除」并给移除动作）
- ~~旧描述~~ ：三张队列的行与详情要能说出「盘上还有没有这个文件」。外部移走/删除后，done 行仍指向死路径。做法：行内一次 `File(...).existsSync()` 即可（不要在 build 循环里扫目录），状态文案复用 `recorder.stateFileDeleted` / `common.previewFileMissing`，并给一个「从列表移除」的动作。涉及 `modules/vod/pages/vod_downloads_page.dart`、`modules/hongguo/pages/hongguo_downloads_page.dart`、`modules/music/pages/music_downloads_view.dart`。
- [ ] D5（**上一轮做到一半停在这里**：三页仍是 `ListView`+`DsListRow`，没有任何 `DsTable`；公共件里只多了 `downloadFilePresent`。降级与摘要行仍未收进 `download_workspace.dart`。）
  D5 原描述 **三页升级到录像库同款表格**：`DsTable` + 列排序 + 搜索 + 筛选面板（`DsPanel`，条件与「只看可播放」收进去）+ 多选与批量删除 + 刷新/错误态，窄窗自动降级为行卡。同时把三家各抄一份的窄窗降级与摘要行（数量·速度·字节·目录 + 打开目录/全暂停/全恢复/清已完成）收进 `shared/widgets/download_workspace.dart`。参照实现：`modules/live/recorder/pages/recorder_library_pane.dart`。**注意**：三页各有一份设置面 pane 也画队列，见 D4，先做 D4 再动表格，避免同一处改两遍。
- [x] D4 **去掉设置面重复队列**（已落地：`settings_navigation.dart` 新增 `openModuleItem`，vod/红果设置面只留摘要 + 跳到模块页，列表只在模块页存在）
- ~~旧描述~~ ：vod 与红果在设置 pane 和模块导航页各画一遍同一件事，摘要与动作还不一致（设置面没有速度、没有组动作）。设置里留一行入口（数量摘要 + 跳到模块页），列表只在模块页存在。检查 `features/settings/surface/settings_search.dart` 与导航偏好/备份键是否因此变动。
- [ ] D3c **预览页音乐音频态**：舞台现在只有 `WallpaperVideoPlayer` + 弹幕层，音乐进来会落进黑底视频框。要给 `MediaPreviewItem` 加歌词/时长一类的音频事实，舞台按项目类型分支：封面 + 滚动歌词 + 播放条；音乐下载页的「播放」由此可走预览页（保留用模块播放器的入口则按「同项只留一个入口」处理）。
- [ ] D6a **目录分家**：红果现在和 B站挤同一个 `appPaths.videos`。给红果自己的下载目录（`AppPaths` + `StorageFolder` 的一项 + 设置可改），**旧行的绝对路径仍可播放、不做静默搬家**；提供与录像库 `mergeTitle` 同款的「把其他目录的文件并进来」显式动作，并写清迁移失败不删源。
- [ ] D6b **下载完进本地曲库**：音乐下载目录不会自动进本地库（`modules/music/controller/music_local.dart` 只扫用户手动加的根）。让下载目录成为一个自动登记的根（或给下载完成一条入库事件），并确保「本地」与「下载」两页不重复显示同一首歌（一行只说一次）。

## 状态（每轮追加一行）
- 2026-11-02 18:11 UTC（下载面轮）：**本轮未改任何代码**（避让协议第 1 条命中）。第一条未勾项已是 D5，而 D5 点名的文件全部被主会话占住且正处在提交的中间态：`vod_downloads_page.dart`、`hongguo_downloads_page.dart`、`music_downloads_view.dart`、`download_workspace.dart`、`download_details.dart`、`widgets.dart` 在 18:09 时是「未暂存的在途改动」（三页 mtime 01:56/02:00/02:04、公共件 02:05，我进场 02:09，分钟级热改），18:11 复查时已变成 `M ` 已暂存而未提交——HEAD 仍是 8cd7b1807，说明一个跨模块的大提交正在进行；连本台账自己都是 `A`（已暂存、等那次提交带上），并且在我读它的第一行与第二行之间就被改写过一次（D2c/D4 被勾、状态段插进一条我没见过的行），所以我写的东西随时会被覆盖。此情此状下改三张页必然对撞，故只登记。
  我准备做的 D5 落法（下一轮，前提：`git status --porcelain` 里这三张页 + `download_workspace.dart` 已干净且热改已过 40 分钟）：一次只换一家，先 B站（`vod_downloads_page.dart`，行最密、窄窗降级已有一份可抄），把 `ListView`+`DsListRow` 换成 `DsTable` + 列排序，搜索与筛选（阶段、是否只看可播放）收进页头入口后的 `DsPanel`，多选与批量删除走表头勾选，刷新/错误态与「文件已删除」沿用 D2c 的 `downloadFilePresent`；三页各抄的窄窗降级与摘要行（数量·速度·字节·目录 + 打开目录/全暂停/全恢复/清已完成）折进 `download_workspace.dart` 一处，第二、三家只接参数不复制版式。参照 `modules/live/recorder/pages/recorder_library_pane.dart`（禁区，只读）。
- 2026-11-03（第二条 lane 前的主会话）：D2c、D4 已落地并核过（三页 0 处 DsTable ⇒ D5 确未开始；预览页 0 处 lyric ⇒ D3c 未开始）。`dart analyze lib` = No issues found。本轮把「壁纸预览页 + 录像库 + 直播/IPTV 分家 + 下载 D1-D3b、D2c、D4」一并提交；**只 commit 未 push 前的状态已由本次推送解决**。待做顺序不变：D5 → D3c → D6a → D6b。
- 2026-11-03：D1、D2a/b、D3a/b 完成，`dart analyze lib` 无问题；未 build、未真机验收。D2c 起为后续轮次。
