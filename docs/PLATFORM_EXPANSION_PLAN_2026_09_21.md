# 平台扩展任务清单（2026-09-21）

## 执行顺序

每个平台按同一条最短闭环推进，减少重复审查与重复构建：

1. 核对官网入口、当前目录/搜索/房间/媒体合同与 GitHub 活跃参考实现；
2. 固化稳定房间身份、状态、观看指标口径、图片与媒体域名白名单；
3. 实现目录、搜索、官方链接回流、详情、画质/线路、播放与录制恢复；
4. 写契约夹具、目录迁移与链接识别回归，形成独立源码提交并同步远端；
5. 所有计划源码收敛后统一执行 Analyze、完整测试、Android/Windows 原生播放及短录验收。

## 当前清单

| 批次 | 平台 | 源码状态 | 下一步 |
| --- | --- | --- | --- |
| A | 已注册 33 个直播站点 + IPTV | 应用入口、能力表与设置目录已覆盖 | 补齐各平台双端原生与录制证据 |
| A | Shopee Live（Indonesia） | 有限目录、搜索、分享链接、浏览器动态会话、FLV、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实播放与短录 |
| B | 战旗直播 | 内部适配器与媒体域名前缀识别已完成 | 取得当前真实直播字节证据后注册 |
| B | 浪 Live | 内部精确账号/链接与 FLV/HLS 解析已完成 | 取得公开目录合同与当前媒体样本后注册 |
| C | VK Video Live | 公开分类、在线目录、原生频道搜索、HLS 画质/双线路、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实播放与短录 |
| C | NimoTV | 当前 Streamlink 仍保留插件，仅先做地区可达性与生命周期核验 | 有当前公开直播样本后进入适配 |
| 生命周期 | Trovo | 2026 年 Streamlink 已移除插件 | 先核对官网服务状态，再决定归档或恢复研究 |
| 生命周期 | DLive | 2026-09-21 官网已显示服务停止页面；旧 Streamlink 插件仅保留历史参考 | 不注册失效入口，保留生命周期证据 |
| 生命周期 | 一直播、企鹅电竞 | 已归档现行生命周期证据 | 保留历史解析，不进入应用注册 |

## 已覆盖的用户列举平台

YY Live、AcFun、Picarto、TwitCasting、猫耳 FM、映客、克拉克拉、花椒、
OPENREC / mellow-fan、TTingLive / FLEX TV、小红书、niconico、微博直播与 IPTV
均已存在源码适配器。后续工作聚焦各自明确缺口，而不是重复创建第二套平台实现。

## 参考基线

- Streamlink 当前插件清单：<https://github.com/streamlink/streamlink/blob/master/docs/plugins.rst>
- Streamlink 当前 DLive 实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/dlive.py>
- Streamlink 当前 VK Video Live 实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/vkvideolive.py>
- Streamlink 当前 NimoTV 实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/nimotv.py>
- 2026 年插件变更记录：<https://github.com/streamlink/streamlink/releases>
