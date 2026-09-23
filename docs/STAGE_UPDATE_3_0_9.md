# v3.0.9 Android 竖屏渲染内核修复

- 版本：`3.0.9+4097`
- 目标：Android `arm64-v8a` Release APK
- 冻结基线：`liuchuancong/pure_live@3f80262b`
- 来源分类：`fork-regression`
- 上游：本轮不合并上游，只修复维护仓库播放器几何链
- 设备操作：代码审查、官方文档/GitHub 对照、实时流探测、自动化测试和本机构建，不操作手机

## 真实流证据

2026-08-26 对当前抖音匿名推荐流做了同一时刻的接口、`ffprobe` 与首帧检查：

- 竖屏样本为 HEVC `1088×1920`，编码宽高与显示宽高一致，首帧本身就是完整竖屏画面；
- 横屏对照为 `1920×1080`、SAR `1:1`、DAR `16:9`；
- 当前样本中各清晰度的流级分辨率与实际画面方向一致。

因此截图中的超窄竖条不是抖音把正常画面塞进了异常比例，而是应用渲染阶段再次缩放了已经正确的
原生竖屏纹理。

## 根因与第一个错误状态

来源归类为 `fork-regression`。`git log -S buildUnifiedMobileVideoFrame` 和逐行归因确认，第一个错误状态
由维护分支提交 `6f50a445` 引入；此前 v3.0.2 已移除过相同类型的双重缩放。前几版虽然拆分了
平台提示、解码画布、有效内容和呈现窗口，但渲染末端仍同时存在两个尺寸所有者：

1. `PlayerManager` 先按自己的快照建立外层 `FittedBox`；
2. media-kit/FijkPlayer/BetterPlayer 内部又按原生纹理尺寸执行一次 fit；
3. 选中流提示与晚到解码事件方向不一致时，代码还会把比例差直接解释为对称黑边并生成临时裁边。

当外层还使用 16:9、内层已经收到 9:16 纹理时，两个 contain/fill 状态在不同帧更新，竖屏宽度会被
再次压缩。这个错误状态随后进入普通竖屏页、横屏全屏、应用小窗和系统 PiP，所以四处一起异常。
旧 Widget 测试只用无固有尺寸的 `ColoredBox`，没有模拟 media-kit 自带的 `FittedBox`，因而漏掉了该链。
[media-kit 的 `Video` 实现](https://github.com/media-kit/media-kit/blob/main/media_kit_video/lib/src/video/video_texture.dart)
也明确在原生纹理外部自带一个 `FittedBox`，因此应用层再包一层不是“统一缩放”，而是第二次缩放。

## 抖音官方模型

抖音开放平台的实时播放器把三件事明确分开：

- `orientation=vertical/horizontal` 表示画面朝向；
- `object-fit=contain/fillCrop` 表示容器内缩放/裁剪；
- 全屏 `direction=0/90/-90` 表示屏幕方向。

官方故障文档还要求在视频与容器比例不同的时候使用 `contain`，并把分辨率变化作为独立状态事件
处理。当前实现据此把“识别、缩放、全屏方向”拆为三个状态，不再用方向提示推导裁边。

对应官方资料：

- [`live-player`](https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/component/media-component/live-player/)：`orientation`、`object-fit` 和状态码 `2009`；
- [`LivePlayerContext.requestFullScreen`](https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/api/media/video/live-player-context/live-player-context-request-full-screen)：`direction=0/90/-90`；
- [视频组件常见问题](https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/tutorial/basic-ability/video-component)：容器比例与视频比例不同时 `fill` 会造成画面变形，应使用 `contain`，并单独检查 SAR。

## 修复设计

### 唯一缩放所有者

- 普通帧直接把用户选择的 `BoxFit` 传给当前播放器原生 Video Widget；
- 删除普通路径的外层宽高 `FittedBox`，原生 `rect/dw/dh` 决定纹理固有比例；
- 只有两次一致的真实帧检测确认黑边后，才建立一次“原生 fill → 测量裁边 → 最终 fit”视口；
- 回归测试新增带固有纹理比例和内部 `FittedBox` 的 media-kit 等价组件，覆盖“管理器仍为 16:9、
  原生纹理已为 9:16”的真实时序。

### 证据优先级

1. 选中 URL 对应的流级分辨率只用于首帧前的 provisional 方向；
2. 首个合理的 `dw/dh + rotation` 成为原生纹理事实来源；
3. 平台提示只修复超出合理范围的 SAR/尺寸异常；
4. 两次一致的帧像素观察才有裁边权限；
5. 房间手动方向覆盖只改变呈现策略，不改变纹理像素。

### 三套呈现落实

- **普通竖屏页**：竖屏视频占满可用宽度/高度，弹幕与画质区域使用三档底部面板，保留独立横屏入口；
- **横屏全屏**：9:16 纹理居中 contain，两侧显示低成本暗化模糊封面，控件覆盖整屏；
- **应用小窗 / Android PiP**：窗口外框持续跟随同一内容比例，Android 请求比例与
  `sourceRectHint` 使用同一可视视频矩形，普通横屏继续 16:9。

四种入口统一读取不可变 `VideoPresentationGeometry`，不再各自重新解释方向或画布。Android PiP
继续遵循[官方 PiP 指南](https://developer.android.com/develop/ui/views/picture-in-picture)：比例变化后更新参数，
`sourceRectHint` 使用布局完成后的实际可见视频矩形。

## 验证

- 定向渲染、识别、流提示、普通页布局与播放器生命周期：72 项通过；
- `flutter analyze`：0 issue；完整 Flutter 回归：462 项通过；
- 全仓审计：3814 个已跟踪文件、0 error；唯一 warning 为 30 处既有空 `catch` 的库存提示；
- 公开接口首轮 37/42：Bilibili、斗鱼、虎牙、快手、CC、抖音、SOOP 与 YY 通过，5 个 Twitch
  探测均因当前主机到 `gql.twitch.tv` 的 TLS 握手超时而失败；独立 `curl -4` 同样超时，归类为
  外部网络证据缺口，不改变本轮播放器源码结论；
- Android arm64 APK 内容、签名、哈希与 GitHub Release：待正式交付记录；
- 实机运行由用户安装正式 APK 后补充，不作为源码定位的前置条件。
