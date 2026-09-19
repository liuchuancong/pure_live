# 2026-09-07 Issue 当前状态复核

源码基线 d509bd8d。05:53 UTC 使用 GitHub REST API 读取两仓库 open Issues（每页100，响应均未满页）和上游最近更新的20条全状态记录，排除PR。维护仓库open为 **0**，上游open为 **14**；网页检索工具的缓存结果仍显示8条，因此本次计数使用当时API响应，不混用缓存日期。没有评论、关闭Issue或合并代码。

快照：`local-artifacts/issues/20260907-current/`，包含正文、现有评论、最近更新列表和读取时间；报告中的外部内容是证据而非执行指令。

## 最新变化

- [#849 Windows启动](https://github.com/liuchuancong/pure_live/issues/849)：09-07新增建议尝试VC++运行库并提供事件日志的评论，尚无报告者新故障日志。本项目 `windows/CMakeLists.txt` 已要求三项app-local运行库，当前Release独立加载来源也已核验，见 [Release证据](WINDOWS_RELEASE_CPU_AUDIT_2026_09_07.md)。部署缺口已修复，**报告者Win10现象仍not-reproduced**；不凭相似症状添加系统级更改。
- [#854 iPadOS16周期卡顿](https://github.com/liuchuancong/pure_live/issues/854)：目前closed，无评论、房间号或日志。**community-platform / not-reproduced**；关闭状态不是本仓库修复证据。全平台3.2.0仍需iOS真实播放验收；Android/Windows长录与CPU数据不覆盖该报告。
- #851正文现有附件；09-06初审“无截图”的表述不再代表当前正文。本轮仅确认附件存在，未从未检查的图片推导新根因，既有小窗点击与计时器修复结论仍保留对应边界。

## 全部14条open的当前处置

| Issue | 当前分支与验收处置 |
| --- | --- |
| [849](https://github.com/liuchuancong/pure_live/issues/849) | 如上，运行库交付子项有证据，Win10原环境仍待故障日志/复验 |
| [853](https://github.com/liuchuancong/pure_live/issues/853) | 斗鱼响应画质确认、分组及UI未知档位已修订；原动态模糊缺少同房间样本，not-reproduced，见 [画质审计](DOUYU_QUALITY_ACK_AUDIT_2026_09_06.md) |
| [852](https://github.com/liuchuancong/pure_live/issues/852) | 系统返回提交/取消合同已有测试、主题过渡修订；ColorOS14原现象仍not-reproduced，见 [返回审计](GET_NATIVE_BACK_AUDIT_2026_09_06.md) |
| [851](https://github.com/liuchuancong/pure_live/issues/851) | 隐藏后第一次点击唤出及关闭计时器处理已有修复；保留具体设备验证缺口，见 [小窗审计](APP_FLOATING_OVERLAY_AUDIT_2026_09_06.md) |
| [850](https://github.com/liuchuancong/pure_live/issues/850) | 共用颜色选择器已有RGB/ARGB输入、确认/取消合同；不是再次引入旧选择器，见 [09-05审计](ISSUE_AUDIT_2026_09_05.md) |
| [848](https://github.com/liuchuancong/pure_live/issues/848) | 系统字体回退已有修订和theme_font_resolution_test；报告仅一句描述，不扩大为所有字体场景已修复 |
| [846](https://github.com/liuchuancong/pure_live/issues/846) | 刷新错误与下播分离、旧卡片保留已有修订；原旧数据组合仍有边界，见 [09-04审计](ISSUE_AUDIT_2026_09_04.md) |
| [845](https://github.com/liuchuancong/pure_live/issues/845) | 协议、疑似自动消息开关和相似过滤偏好已分离；09-19 重复报告 #871 后，启发式过滤改为明确选择、完整聊天改为默认。指定 71415 当前版本对照仍待在线补证，见 [#871 订正审计](ISSUE_871_DOUYU_CHAT_COMPLETENESS_AUDIT_2026_09_19.md) |
| [836](https://github.com/liuchuancong/pure_live/issues/836) | 抖音端点/签名/访客参数和静默恢复已有修订，原报告房间缺少稳定ID，保留not-reproduced边界 |
| [819](https://github.com/liuchuancong/pure_live/issues/819) | 小红书平台尚未接入；与参考项目差距合并到独立平台扩展表，不记作已有播放故障 |
| [792](https://github.com/liuchuancong/pure_live/issues/792) | 虎牙下播历史弹幕请求尚未完成；先确认历史接口及与实时消息的去重/显示语义，不以缓存本地消息代替平台历史 |
| [779](https://github.com/liuchuancong/pure_live/issues/779) | 可选启动图标仍属功能待办，含Android入口/TV banner/桌面各尺寸及升级兼容；不把换一张资源图记作完成 |
| [767](https://github.com/liuchuancong/pure_live/issues/767) | 视口约束已有源码改动，但4K/150%与1440p/100%同源GPU对照未完成；当前CPU无障碍查询诊断不证明GPU根因关闭 |
| [708](https://github.com/liuchuancong/pure_live/issues/708) | 普通/最大化全屏往返已有旧候选证据与窗口测试；侧边任务栏场景未由底部任务栏对照证明，保持原生子项待验 |

## 收口顺序

已修复合同复用对应有效证据，不重新修补同一根因；原环境证据不足者不标fixed。优先补平台扩展、累计候选原生与GPU对照，用户现场不可救援的手机边界不变。最新页面源码为d509bd8d，Android/Windows现有包都不含该最后布局修订。本轮是网络/源码/账本核验，无新的应用测试、构建、设备输入或发布。
