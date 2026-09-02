# 上游同步审查：e696bb79

- 原始上游冻结点：`e696bb79e28c5c09f1e6e03264ededce69b9266e`
- 审查净化点：`05db8871c8840aef3c65bbcf622a387c946eb43a`
- 维护分支审查起点：`3ee3fd13b3613e3fe61601229db04879b7d0657f`
- merge base：`f77123d21548ece1e5786fe493da80255f8432fd`
- 入站提交：54 个上游提交 + 1 个工作流净化提交；入站文件：139。
- 来源分类：播放器/比例/录制为 `integration-conflict` 与 `fork-regression` 混合；部分平台接口为 `external-drift`；工作流与版本覆盖为产品不变量冲突。

## file_review

原始上游包含全平台构建默认开启、非固定工作流引用和尾随空格。净化提交恢复维护分支工作流，保留完整上游祖先关系。版本、更新源、Release 索引、签名、平台默认值均在真实 merge 中保留维护分支值。删除的播放器回归测试全部保留。

## semantic_change_ledger

| 模块 | upstream intent | implementation / quality_assessment | fork_feature_impact | disposition | regression_plan |
|---|---|---|---|---|---|
| Android Surface | 修复竖屏/横屏源切换后的纹理比例 | `VideoOutput.java` 刷新 Surface 引用的方向正确；现有实现仍缺源会话标签、零尺寸过滤和释放屏障 | 直接合并会与本仓库竖屏几何和播放器恢复层产生竞态 | rewrite | 原生尺寸代次、横竖屏连续切换、旧尺寸晚到 |
| 播放生命周期 | 优化后台/音频与返回 | 页面 Widget、Activity、全局播放器存在多控制者；短暂 pause 被当成后台 | 会触发自动暂停、小窗恢复停播 | rewrite | 生命周期状态机、用户暂停、音频、PiP、方向切换 |
| 播放源恢复 | 加强 session 校验和解码恢复 | 上游包含维护分支补丁，但事件在回调时读取当前代次，旧源仍可冒充新源 | 继续使用会污染 playing、videoParams、error | rewrite | 旧源延迟事件、重定向、同 URL 重开、失败回滚 |
| 全屏/PiP/竖屏 | 根据源方向更新全屏与小窗 | 上游删除大量本仓库竖屏策略和测试，原生 Surface 修复与 Dart 几何未形成单一合同 | 普通、全屏、小窗比例会互相覆盖 | adapt | 9:16、16:9、4:3、1:1、竖屏内容封装在横屏画布 |
| 播放器内核切换 | 使用默认内核并增加恢复 | 新内核提交前缺少当前源首帧事务 | 会出现黑屏和切回后继续故障 | rewrite | MediaKit/Fijk/VideoPlayer 候选打开、成功提交、失败回滚 |
| 平台解析与画质 | 统一画质标签并增强各站解析 | 标签归一意图可接受；URL、画质、线路仍要用稳定 ID 绑定 | 影响播放和录制的实际画质准确性 | adapt | Bilibili/Douyu/Huya/Douyin/Kuaishou/CC/YY/Twitch/SOOP |
| 录制输入 | 强化 URL、请求头、重试和 FFmpeg 参数 | 多轮 FFmpeg 重构互相覆盖；地址、请求头、时效与协议仍未封装为同一合同 | 继续产生通用“输入地址错误”和错误画质 | rewrite | HTTP-FLV、HLS、重定向、403 刷新、音频源、首包验证 |
| 录制状态/UI | 增加诊断、持久化与任务展示 | 高频统计写回整个 RxList；状态阶段、列表成员和呈现耦合 | 卡片跳动、状态提前、错误信息含糊 | rewrite | 独立任务流、节流、稳定排序、恢复、桌面响应式 |
| 返回与路由 | 引入 Android predictive back 和直播页 Shell | 原始上游曾破坏普通直播页；本仓库已恢复布局不变量 | 直接覆盖会再次隐藏普通页 UI | adapt | 普通页返回、全屏先退、弹窗先关、侧滑退出 |
| 设置/备份 | 新增竖屏、窗口与历史设置 | 必须保留旧安装默认值、备份和恢复迁移 | 缺失键默认错误会导致升级后功能消失 | adapt | 缺失键、旧备份、重复导入、范围裁剪 |
| 依赖/构建/发布 | 更新依赖和上游 v3.0.6 发布配置 | 上游默认全平台构建并覆盖仓库、版本和更新源，违反维护策略 | 会触发高额 Actions 与错误更新地址 | drop | 工作流静态审计、版本与资产一致性 |

### 入站提交逐项处置

| commit | subject | disposition | 说明 |
|---|---|---|---|
| `8e4006adc8e4391cb4358f8243db7d64bc57d5ef` | refactor: update desktop detection logic to exclude mobile platforms | accept | 低耦合变更，合并后由对应定向测试验证。 |
| `fdd472ef44f505b0f0eafade98caee457367b6be` | fix(fijk_helper): disable audio focus request in FijkPlayer options | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `5c6cd453c83dd45a141abc6e6c4f092ca3bc5164` | refactor(live_audio_handler): reorganize imports and improve code readability | accept | 低耦合变更，合并后由对应定向测试验证。 |
| `83bb72b97b9b9acb86003e926df9938c9a95abd4` | refactor(yy_site): streamline getLiveStreamObj by consolidating request parameters | accept | 低耦合变更，合并后由对应定向测试验证。 |
| `844420ba1406728102da0f89561121c26fd53d8b` | Merge remote-tracking branch 'liuchuancong/master' | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `a41898c1785d6ca4307327250d3fac6e2070ede7` | 修复全屏返回 | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `8f5312935f9733c596fe1000fd6433a33cc46fd0` | Merge remote-tracking branch 'liuchuancong/master' | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `59643f4c0b693debb9670a087fe4457ee955ef63` | 优化房间切换界面布局，调整组件间距和尺寸，增强用户体验 | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `48f907ab819038dee28e1f9078a504f01adfa330` | 优化房间切换功能，重构历史观看时间格式化逻辑，新增兼容性布局选项 | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `f5dd66b0f7ca6fc767cf93c5f65783f52191d38d` | fix(视频播放比例) | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `9dbeef7266bef106b9895671482b376538b4e9fe` | Update repository references from liuchuancong to liuchuancong across documentation and codebase | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `4fcc53f5d2b962f5f41d172dfeb21675b3b4c9d3` | 优化构建配置，默认启用所有平台构建选项，简化包管理命令 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `5d57cb0ccfd79fe1df95822c21c85c453696c1ae` | chore: update releases.json for v3.0.4 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `b14f289ddd579067277cf2bc37e9317db31d6502` | Update version from 3.0.4 to 2.9.8 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `d722541d06e84834f7717e425a3731e00fbe996e` | 修复视频比例 | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `84388b39017b3b4f6845d00d21fc03f02c8257f8` | 优化视频全屏处理逻辑，添加对移动设备的屏幕方向判断 | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `4c433e18a0be252c46b1e73945f4344b930083a4` | 优化播放器初始化逻辑，使用传入的默认引擎并更新日志信息 | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `451dc4b69767f1e4520d0c12f9360ddd498c312c` | 更新版本号从2.9.8到3.0.4 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `f2468a46c92985b6145761c0426a9bda0280af8f` | chore: update releases.json for v3.0.4 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `2d3820978869e6897782877b58e5601bdeb92fe3` | chore: update releases.json for v3.0.4 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `74543f68194f8c8bc504bbb627c1c622cd568142` | chore: update releases.json for v3.0.4 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `213cbbf449293350342e3b520c7a521ffa5d3a44` | 修复: 更新exportAllSettings方法的includeSensitiveData默认值为true | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `5a158989e20b310b1ec58231ea32bcd7be4cc39e` | feat: 增强画中画功能，支持竖屏模式下的窗口几何更新 | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `7626dc9d91ac25ff04e2a5f330771610998abb4f` | feat: 根据设置条件动态显示多视图选项 | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `b315109f88c7489bb3b10438c5f8fa4c8297c342` | fix: 更新版本号至3.0.5，修复相关描述和下载链接 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `31929bdb826c595f4cb7a69d1a2375b99428b052` | fix: 更新版本号至3.0.5 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `2136a2e24005bd7ee9251d79e5803a57a499d76c` | fix(recorder): harden streams and quality selection | rewrite | 录制意图成立，改用源合同、协议能力与状态机实现。 |
| `7910d2125972cb0bfb81a730ddc4ff3dc3eeaaf7` | chore: update releases.json for v3.0.5 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `d35fee6530a84f658c85aa87fd30f8953929b173` | fix(font): 更新按钮颜色以适应主题容器，增强可读性 fix(ffmpeg): 添加Android平台的TLS验证选项 | rewrite | 录制意图成立，改用源合同、协议能力与状态机实现。 |
| `63ae94ad2d9e6cfa7b91bbf0a8d394549ca15d23` | Merge branch 'master' of https://github.com/liuchuancong/pure_live | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `f0c0fbf021b158f73a32e588adebaefdab3d2ee7` | feat(live_play): 添加 showPanel 属性以控制面板显示 | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `a22160e99189d98b1f9bb8107c667ed72917ef10` | fix(media_kit): 增加 demuxer-lavf-analyzeduration 属性值以优化直播流解析 | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `a2d34d6005abba85d480c1c088ead6afce771ca1` | chore: 更新版本号至 3.0.6，调整相关配置文件以匹配新版本 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `f0401db7b488e1624c113a7de2de42a6d3aa9388` | fix(version): 更新版本描述格式，添加版本号和更新信息 | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `59d6ecb196ad909857d5080ceed87437b7e2c192` | fix(recorder): harden all platform capture startup | rewrite | 录制意图成立，改用源合同、协议能力与状态机实现。 |
| `63e43634bdf7328d387977c03e20f35fbfad13eb` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `a724764fd15a1c6506cf5ad24de22f190cc0b356` | Implement code changes to enhance functionality and improve performance | adapt | 保留意图，按维护分支状态合同与回归门禁适配。 |
| `db55c1b45a30dfcc48921df88c2e50f8df9209e5` | Merge branch 'master' of https://github.com/liuchuancong/pure_live | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `c6a4c735f3046c7bba3103f1fc7c7681544acd35` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `01358dc65b6c2d4a9350afae8a5cb92922cfb305` | fix(media_kit_adapter): remove unnecessary property for live stream analysis | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `536737231632dfb9c87b719ec1f8a616f87571d0` | Merge branch 'master' of https://github.com/liuchuancong/pure_live | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `6584fa659a5061e61ffdbc948f721c2adea35ff2` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `200beb88b90bb376e5510f68db625314a8e1de21` | refactor(ffmpeg_command_builder): simplify command building and improve argument handling | rewrite | 录制意图成立，改用源合同、协议能力与状态机实现。 |
| `81fa899413d1512c73eafea88ec3e45b855ca67d` | Merge branch 'master' of https://github.com/liuchuancong/pure_live | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `97c665621784fa90baad0f7f6531068f014888d1` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `a6a57153d4670d7662d6aefd2c68daac2a3ea167` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `430fcdbecc58ec7bc90dd61b1a475d84e4b3cf39` | refactor(ffmpeg_command_builder): streamline header handling and improve argument formatting | rewrite | 录制意图成立，改用源合同、协议能力与状态机实现。 |
| `8fd0a4506cb6c2658bbe7dc52305015f136b23e4` | Merge branch 'master' of https://github.com/liuchuancong/pure_live | accept | 仅接受祖先关系；冲突以逐文件台账处置。 |
| `6bdf38e11b42481497b0a3a93c3ec4739adec5c0` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `2e1fcd31ef1f764ea01deba9486b5fabd5c20948` | fix(player): harden source and decoder recovery | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `8b7a001c1a76f43faeb039e8b7d0d0c34802e100` | fix(player): improve session validation for current player | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `5d73fbdacb6c6821fd4d08b517ec59bbe57fb527` | fix(ffmpeg_command_builder): enhance audio stream command and argument handling | rewrite | 录制意图成立，改用源合同、协议能力与状态机实现。 |
| `a218922bf837b22a6075db54c296912fa60b2584` | fix(media_kit_adapter): remove unnecessary properties for live stream handling | rewrite | 并入播放器会话、Surface 和呈现事务，不直接复用补丁式实现。 |
| `e696bb79e28c5c09f1e6e03264ededce69b9266e` | chore: update releases.json for v3.0.6 [skip ci] | drop | 保留维护分支版本、更新源、签名和按需串行构建策略。 |
| `05db8871c8840aef3c65bbcf622a387c946eb43a` | chore(upstream): sanitize release workflow policy | accept | 恢复全部工作流默认关闭、固定引用和维护分支发布边界，消除原始入站阻断项。 |

### 入站文件逐项处置

| file | category | disposition | 处置理由/验证 |
|---|---|---|---|
| `.github/workflows/sign-staged-android.yml` | workflows_and_release | accept | 审查净化提交带入维护分支正式签名工作流；保留固定引用、Secrets 短时签名和目标产物校验。 |
| `.env` | repository_metadata | drop | 保留 liuchuancong 更新源和维护分支环境元数据。 |
| `.env.dev` | repository_metadata | drop | 保留 liuchuancong 更新源和维护分支环境元数据。 |
| `.env.prod` | repository_metadata | drop | 保留 liuchuancong 更新源和维护分支环境元数据。 |
| `.github/ISSUE_TEMPLATE/config.yml` | repository_governance | adapt | 保留维护范围说明和本仓库 Issue/链接。 |
| `.github/workflows/build_pure_live_release.yml` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `.github/workflows/feature-build.yml` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `.github/workflows/publish-staged-release.yml` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `.github/workflows/stage-hosted-artifacts.yml` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `MAINTENANCE_POLICY.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `README.md` | repository_governance | adapt | 保留维护范围说明和本仓库 Issue/链接。 |
| `RELEASE_NOTES.md` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `android/app/build.gradle.kts` | android_native | adapt | 逐项合并返回、Surface、后台与权限；保留包名、签名和平台通道。 |
| `android/app/src/main/AndroidManifest.xml` | android_native | adapt | 逐项合并返回、Surface、后台与权限；保留包名、签名和平台通道。 |
| `android/app/src/main/kotlin/com/mystyle/pure_live/MainActivity.kt` | android_native | adapt | 逐项合并返回、Surface、后台与权限；保留包名、签名和平台通道。 |
| `android/build.gradle.kts` | android_native | adapt | 逐项合并返回、Surface、后台与权限；保留包名、签名和平台通道。 |
| `assets/releases.json` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `assets/translations/en.json` | translations_and_assets | adapt | 合并新键并保持中英文调用键一致。 |
| `assets/translations/zh.json` | translations_and_assets | adapt | 合并新键并保持中英文调用键一致。 |
| `assets/version.json` | workflows_and_release | drop | 保留维护分支版本、Release 索引、签名与按需串行工作流。 |
| `docs/BUILD_AND_RELEASE.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/PLAYER_RECOVERY_AUDIT_3_0_14.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/RECORDING_AUDIT_3_0_13.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/REPOSITORY_AUDIT_3_0_0_BUILD_4088.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_5_0.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_6_0.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_7_0.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_8_0.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_9_0.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_9_4.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_9_5.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_9_6.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_2_9_7.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_3_0_0.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_3_0_13.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/STAGE_UPDATE_3_0_14.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `docs/UPSTREAM_AUDIT_E808DCAE.md` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `lib/common/base/base_page_scroll_bone.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/base/base_page_view.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/base/local_reactive_page_controller.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/global/initialized.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/global/platform/desktop_manager.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/models/release_model.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/services/settings/backup_controller.dart` | persisted_settings | adapt | 补齐旧键默认、备份恢复和幂等迁移。 |
| `lib/common/services/settings/player_settings_controller.dart` | persisted_settings | adapt | 补齐旧键默认、备份恢复和幂等迁移。 |
| `lib/common/services/settings/window_size_controller.dart` | persisted_settings | adapt | 补齐旧键默认、备份恢复和幂等迁移。 |
| `lib/common/utils/version_util.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/common/widgets/common_appbar_actions.dart` | common_runtime | adapt | 按初始化、响应式和资源释放不变量审查。 |
| `lib/core/interface/live_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/bilibili/bilibili_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/cc/cc_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/douyin/douyin_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/douyu/douyu_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/huya/huya_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/iptv/iptv_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/kuaishou/kuaishou_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/soop/soop_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/twitch/twitch_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/site/yy/yy_site.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/core/utils/live_quality_label.dart` | platform_interfaces | adapt | 接受解析/画质意图，以稳定 ID、类型容错及平台测试适配。 |
| `lib/gen/env.g.dart` | other_application_source | adapt | 保留维护分支身份并核对调用方。 |
| `lib/modules/about/version_history.dart` | app_modules | adapt | 保留维护分支 UI 与设置同步逻辑。 |
| `lib/modules/live_play/dialogs/play_other.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/services/android_predictive_back_service.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/button/record_action_button.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/layout/live_play_back_scope.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/layout/live_play_content.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/layout/live_play_shell.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/layout/live_play_video.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/video_player/video_controller.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/live_play/widgets/video_player/video_controller_panel.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/modules/settings/pages/font_family_manager_page.dart` | app_modules | adapt | 保留维护分支 UI 与设置同步逻辑。 |
| `lib/modules/settings/pages/navigation_settings_page.dart` | app_modules | adapt | 保留维护分支 UI 与设置同步逻辑。 |
| `lib/modules/settings/pages/portrait_live_settings_page.dart` | app_modules | adapt | 保留维护分支 UI 与设置同步逻辑。 |
| `lib/modules/settings/pages/video_settings_page.dart` | app_modules | adapt | 保留维护分支 UI 与设置同步逻辑。 |
| `lib/player/adapters/fijk_adapter.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/adapters/media_kit_adapter.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/adapters/video_player_adapter.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/core/audio_stream_loader.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/core/engine_fallback_manager.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/core/live_audio_handler.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/core/playback_header_resolver.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/core/player_manager.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/core/portrait_stream_support.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/global_player_service.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/interface/unified_player_interface.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/models/player_exception.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/utils/fijk_helper.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/player/utils/window_helper.dart` | live_playback | rewrite | 纳入生命周期、源会话、Surface 与呈现四层重构。 |
| `lib/recorder/ffmpeg/ffmpeg_command_builder.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/ffmpeg/ffmpeg_manager.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/ffmpeg/ffmpeg_scheduler.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/models/live_record_task.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/pages/recorder/recorder_controller.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/pages/recorder/recorder_page.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/services/cache_service.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/services/ffmpeg_service.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/services/recorder_continuation_policy.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/services/recorder_diagnostics.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/services/stream_resolver_service.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/recorder/services/video_processor_service.dart` | recording_and_storage | rewrite | 纳入录制源合同、协议探测、任务状态机和 UI 重构。 |
| `lib/routes/android_native_page_transition.dart` | navigation_and_startup | adapt | 只在直播路由局部接入 predictive back。 |
| `plugins/flame_barrage/pubspec.lock` | dependencies_and_vendored | adapt | 锁文件按最终 pubspec 生成；VideoOutput 使用审查后的原生重写。 |
| `pubspec.lock` | dependencies_and_vendored | adapt | 锁文件按最终 pubspec 生成；VideoOutput 使用审查后的原生重写。 |
| `pubspec.yaml` | dependencies_and_vendored | adapt | 锁文件按最终 pubspec 生成；VideoOutput 使用审查后的原生重写。 |
| `test/app_initializer_recorder_policy_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/cc_quality_parser_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/douyin_playback_parser_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/douyu_playback_parser_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/engine_fallback_manager_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/ffmpeg_failure_classifier_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/ffmpeg_record_command_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/ffmpeg_scheduler_cancel_token_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/huya_play_url_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/live_play_normal_layout_test.dart` | tests | drop | 拒绝删除维护分支播放器/布局回归测试。 |
| `test/live_quality_label_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/live_record_task_persistence_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/media_kit_video_geometry_test.dart` | tests | drop | 拒绝删除维护分支播放器/布局回归测试。 |
| `test/mobile_video_frame_test.dart` | tests | drop | 拒绝删除维护分支播放器/布局回归测试。 |
| `test/playback_header_resolver_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/player_audio_mode_transition_test.dart` | tests | drop | 拒绝删除维护分支播放器/布局回归测试。 |
| `test/portrait_stream_support_test.dart` | tests | drop | 拒绝删除维护分支播放器/布局回归测试。 |
| `test/recorder_continuation_policy_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/recorder_storage_policy_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/recorder_stream_resolver_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/recording_platform_contract_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/release_asset_urls_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/soop_platform_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/twitch_playback_parser_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `test/video_processor_manifest_test.dart` | tests | accept | 保留新增覆盖，合并后修正为新状态合同。 |
| `third_party/media_kit_video/android/src/main/java/com/alexmercerind/media_kit_video/VideoOutput.java` | dependencies_and_vendored | adapt | 锁文件按最终 pubspec 生成；VideoOutput 使用审查后的原生重写。 |
| `tool/prefetch_android_native.ps1` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `tool/publish_local_release.ps1` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `tool/update_actions_sha.py` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `tool/update_releases.py` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `tool/validate_build_policy.ps1` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `tool/verify_actions_sha.py` | tooling_and_policy | adapt | 审计文档可引用；策略和发布工具保留维护分支不变量。 |
| `windows/packaging/exe/local_release.iss` | windows_native | drop | 保留维护分支安装目录、便携数据和版本配置。 |
| `windows/packaging/exe/make_config.yaml` | windows_native | drop | 保留维护分支安装目录、便携数据和版本配置。 |
| `windows/packaging/msix/make_config.yaml` | windows_native | drop | 保留维护分支安装目录、便携数据和版本配置。 |

## issue_and_bug_mapping

- #802 / #797 / #790：Android Surface 与横竖屏比例，维护分支标记 `present`，采用原生 Surface 会话化重写。
- #808 / #805：播放器内核切换与解码恢复，维护分支标记 `present`，采用候选播放器事务与事件源标签。
- #791 / #804：Android 与抖音录制失败，维护分支标记 `present`，采用平台录制源合同和 FFmpeg 实际能力探测。
- #806：抖音画质标签重复，维护分支标记 `present`，采用稳定质量 ID 与显示标签分离。
- 自动暂停：`fork-regression`，第一错误状态来自页面 Widget 将短暂 lifecycle pause 写入全局播放器。

## fork_feature_impact

- 保留普通直播页顶部栏、视频、画质/线路入口、弹幕列表同时可见。
- 保留本地弹幕、小窗弹幕、音频模式、后台播放、录制中心及 Windows 数据目录定制。
- 画质/线路以新源首帧成功为提交点；失败保留旧源和旧选择。
- 普通、全屏、系统画中画和应用小窗只改变呈现，不销毁播放/弹幕会话。

## quality_assessment

上游包含正确的原生 Surface 修复方向、平台解析增强和若干维护分支回流提交；同时存在工作流违规、版本覆盖、删除关键回归测试、播放器/录制多轮互相覆盖和状态合同缺失。结论为选择性接受与核心子系统重写，原始上游树不作为发布树。

## disposition

- accept：低耦合解析、辅助工具和新增有效测试。
- adapt：设置、路由、平台接口、Android 原生入口、翻译。
- rewrite：播放器生命周期、源会话、Surface、几何呈现、录制输入和录制 UI。
- drop：上游版本、更新源、Release 索引、全平台默认开启、删除维护分支回归测试。
- defer：未具备设备或协议证据的平台运行结论，保留源码兼容。

## conflict_resolution

使用审查净化分支 `05db8871c8840aef3c65bbcf622a387c946eb43a` 做真实 merge。文本冲突按上述逐文件 disposition 解决；合并后运行全仓审计。播放器和录制冲突先保留维护分支，再以独立可回滚提交重写；原生 VideoOutput 单独适配。

## regression_plan

- 生命周期：前台、短暂 pause、后台、系统 PiP、应用小窗、音频模式、用户主动暂停。
- 源会话：旧事件晚到、重定向、同 URL 重开、画质/线路失败回滚、内核切换。
- 几何：9:16、16:9、4:3、1:1、竖屏内容封装在横屏画布；普通/全屏/PiP/小窗。
- 录制：各平台 URL/请求头/时效/画质/线路、HTTP-FLV/HLS、403 刷新、断网重连、文件验证。
- UI：录制状态阶段、稳定排序、统计节流、错误详情和 Windows 响应式布局。

## verification_plan

1. 合并后 `python tool/audit_repository.py`、`git diff --check`。
2. 修改完成后一次 Flutter Analyze。
3. 先运行播放器、比例、平台解析、FFmpeg、录制模型和布局定向测试。
4. 正式 Android 交付前执行完整质量门禁、接口探针、arm64 Release 内容核验。
5. 本轮设备证据保持独立；当前任务未包含手机操作。
