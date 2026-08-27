# 上游同步审查：9b1c0a6e

- 上游冻结点：`9b1c0a6ee0c469e1363fbb214ad7abf26f775a27`
- 维护分支审查点：`403772f15e1f7511fc486320bb8ba37d1ca5640b`
- merge base：`e696bb79e28c5c09f1e6e03264ededce69b9266e`
- 入站提交：7；入站文件：6；全部属于播放器、依赖锁或发布元数据高风险路径。
- 结论：记录真实上游祖先关系，但不把这批回滚值覆盖到维护分支。

## file_review

| file | upstream change | disposition | 说明 |
|---|---|---|---|
| `lib/player/adapters/media_kit_adapter.dart` | 恢复 `force-seekable` 与 2 秒探测；其余差异为行尾重写 | accept ancestry | 两个有效属性已在维护分支存在；不再次覆盖已经完成的源事件、音频模式与生命周期修复。 |
| `pubspec.yaml` | 将 FFmpegKit 从精确 `0.5.13` 降到 `0.5.7` | drop | `0.5.7` 对应 builder `0.10.3`；维护分支 `0.5.13` 对应 `0.10.5`，仍为 FFmpeg 8.1.2 系列并包含后续构建修正。 |
| `pubspec.lock` | 锁文件仍写 `0.6.0`，与上游 YAML 的 `0.5.7` 不一致 | drop | 该树在严格 `--enforce-lockfile` 下不自洽，不进入候选发布树。 |
| `plugins/flame_barrage/pubspec.lock` | 独立插件锁文件批量漂移 | drop | 与本次播放器/录制根因无关，由维护分支目标工具链单独解析。 |
| `assets/releases.json` | 重写 v3.0.6 Release 索引 | drop | 保留本仓库更新源、签名产物和 Release 索引。 |
| `assets/version.json` | 从 3.0.6/4094 回滚到 3.0.5/4093 | drop | 版本回退会破坏升级顺序和产物一致性。 |

## semantic_change_ledger

| commit / module | upstream intent | implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
|---|---|---|---|---|---|---|
| `5834cb21466ec91f130c1f81c2017431710d025a` FFmpeg | 尝试回退录制依赖 | YAML 改为 `0.5.3`，锁文件却保持 `0.6.0` | 依赖图不一致，未给出原生库身份或录制证据 | 会令本地严格构建失败，并丢失后续 FFmpeg 8 构建修正 | drop | 锁文件一致性、原生库版本、HTTP-FLV/HLS 实录 |
| `fa4ec2a5ec17eab9aa1326e482e7aa55ebf705bf` FFmpeg | 把回退点改为 `0.5.7` | 仅改单行 YAML | builder `0.10.3` 早于 FFmpeg 8.1.2/CVE 修正点 `0.10.4` | 录制行为与供应链都倒退 | drop | 同上 |
| `7de0fe0b11c878f7e920305a2017de1d023c2ca4` merge | 合并历史 | 无独立语义 | 只接受祖先关系 | 无运行时内容 | accept | 合并后全仓审计 |
| `870e1cf3d950bdd335f1ac4bb0814bdb08243ca9` MediaKit | 缩短首帧并强制直播流可 seek | 添加 `force-seekable=yes`、`demuxer-lavf-analyzeduration=2` | 有效行已存在；全文件行尾重写不应覆盖维护分支状态机 | 原样覆盖会丢失播放器会话修复 | accept ancestry | 播放/暂停、音频切回、源切换、解码失败恢复 |
| `9fffef35356beb89d9bae6dc32accfa45d0a8302` Release | 更新 v3.0.6 索引 | 改发布资产 JSON | 与维护分支资产和签名不匹配 | 错误更新源 | drop | Release URL、哈希、源码提交一致性 |
| `5bf2979e66a671b3a4259c3c0003f71a1938084f` Release | 再次更新 v3.0.6 索引 | 改发布资产 JSON | 同上 | 同上 | drop | 同上 |
| `9b1c0a6ee0c469e1363fbb214ad7abf26f775a27` Version | 回滚至 3.0.5 | 仅回退版本 JSON | 没有配套源码、锁文件和产物事务 | 会让新安装包版本倒退 | drop | 版本号、build number、APK 元数据一致性 |

## issue_and_bug_mapping

- 录制失败：`present`。这批上游提交仅尝试依赖降级，未形成 URL、请求头、FFmpeg 原生身份和输出文件的端到端证据；维护分支继续按录制源合同修复。
- 自动暂停、竖屏比例、Surface 恢复：`already-fixed-in-fork`。上游本批没有新的根因修复；维护分支保留生命周期、源事件、Surface 和几何事务提交。
- 版本回滚：`upstream-only`。这是上游发布状态变化，不作为维护分支运行时代码修复。

## fork_feature_impact

维护分支保留本地弹幕、音频模式、竖屏/横屏/PiP/应用小窗统一几何、播放器会话隔离、录制诊断和本地发布流程。上游本批没有可独立移植的新功能；直接采用其树会覆盖这些修复并造成 FFmpeg YAML/lock 不一致。

## quality_assessment

上游 MediaKit 的两行属性已经存在于维护分支。依赖回退缺少一致锁文件和实录证据，且回退到了早于 FFmpeg 8.1.2 安全修正的 builder。Release 与版本提交只改变元数据。最佳组合是保留祖先关系、保持维护分支文件，并继续用可验证的源合同和原生库身份解决录制问题。

## disposition

- `accept`：合并提交祖先关系；MediaKit 两行已存在的语义。
- `drop`：FFmpeg 依赖/锁文件回退、插件锁漂移、上游 Release 索引和版本回滚。
- `rewrite`：录制失败继续在维护分支以流地址合同、原生 FFmpeg 身份、重试状态机和产物验证完成。

## conflict_resolution

使用 `git merge -s ours --no-ff upstream/master` 建立真实上游祖先关系。候选树保持维护分支全部文件，因此不会让上游版本、发布索引、依赖回退或整文件行尾重写进入运行树。

## regression_plan

- 播放器：普通页、横屏、竖屏、系统 PiP、应用小窗、音频切回、后台恢复。
- 录制：各平台 HTTP-FLV/HLS，签名 URL 刷新，请求头，失败分类，重试及非零文件验证。
- 依赖：`pub get --enforce-lockfile`、FFmpeg AAR/ZIP SHA 与原生版本标记。
- 发布：版本、ABI、原生库、签名、Release 资产与源码提交一致。

## verification_plan

1. 审查脚本高风险批准门禁。
2. ours merge 后执行全仓审计与 `git diff --check`。
3. 播放器/Surface 定向测试已通过；录制修复后运行录制和平台解析定向测试。
4. 全部代码完成后只执行一次 analyze；正式交付再执行完整回归和目标平台构建。
