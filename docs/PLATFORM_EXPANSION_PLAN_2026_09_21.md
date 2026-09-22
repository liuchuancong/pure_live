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
| A | 已注册 45 个直播站点 + IPTV | 应用入口、能力表与设置目录已覆盖 | 补齐各平台双端原生与录制证据 |
| A | Shopee Live（Indonesia） | 有限目录、搜索、分享链接、浏览器动态会话、FLV、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实播放与短录 |
| B | 战旗直播 | 内部适配器与媒体域名前缀识别已完成 | 取得当前真实直播字节证据后注册 |
| B | 浪 Live | 内部精确账号/链接与 FLV/HLS 解析已完成 | 取得公开目录合同与当前媒体样本后注册 |
| C | VK Video Live | 公开分类、在线目录、原生频道搜索、HLS 画质/双线路、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实播放与短录 |
| C | NimoTV | 官网有限推荐快照、快照关键词搜索、精确频道/别名、官方链接、直播状态、当前观看人数、五档签名 FLV、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、播放与短录 |
| C | Dailymotion | 官网公开 API 原生直播目录/搜索/精确视频与频道当前直播、官方链接回流、浏览器动态主清单、多档 HLS、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、播放与短录 |
| C | Rumble | 官网公开直播分页、目录内搜索、精确直播页/频道链接、当前/累计观看分列、浏览器动态 HLS、多档画质与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、播放与短录 |
| C | GoodGame | 官网 API v4 原生分页、精确频道/播放器链接、目录内搜索、当前观看、四档短时 HLS 与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、播放与短录 |
| C | FC2 Live | 官网普通目录、分类、精确频道与链接、当前/累计观看、控制 WebSocket、owned HLS 播放/录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实播放、停止、恢复与短录 |
| C | Steam Broadcasts | 官网热门社区直播原生分页、精确 SteamID64/观看链接、当前观看、账号状态、自适应 HLS 与录制恢复已接入 | 集中验收阶段使用 Clash 执行 Android/Windows 真实播放、恢复与短录 |
| C | 京东直播 | 官网精选原生分页、场次/官方链接、状态、累计观看、HLS/FLV 与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、线路切换、恢复与短录 |
| C | 淘宝直播 | 精确场次/主播身份、官方链接/分享短链、匿名 MTop 动态签名、状态、累计观看、五档 HLS/FLV、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实搜索、线路切换、恢复与短录 |
| C | 酷狗直播 | 官网动态分类、推荐/分类原生分页、主播搜索（含未开播）、精确房间、当前观看/热度/粉丝分列、签名 HTTPS FLV、续期与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、搜索、播放恢复与短录；远端聊天继续核验 |
| C | 百度直播 | 官网推荐/七分类原生会话分页、精确房间与官方链接、开播状态、当前观看/粉丝分列、HTTPS FLV/HLS、多档画质与录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、分类、播放恢复与短录；昵称搜索与远端聊天继续核验 |
| C | 六间房直播 | 官网大厅 411 条当前直播快照、六分类本地分页、官网昵称搜索（含未开播主播）、精确房间与官方链接、状态、平台热度/粉丝分列、HTTPS FLV 与播放/录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、搜索、播放恢复与短录；远端聊天继续核验 |
| C | LOOK 直播 | 官网视频/语音推荐原生分页、精确房间与官方链接、当前推荐页关键词筛选、状态、当前观看/热度分列、HTTPS HLS/FLV、客户端专用房型提示与播放/录制恢复已接入 | 集中验收阶段执行 Android/Windows 真实目录、搜索、音频/视频播放恢复与短录；远端聊天继续核验 |
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
- Dailymotion 官方视频字段：<https://developers.dailymotion.com/v0/reference/video-fields>
- Dailymotion 官方视频筛选器：<https://developers.dailymotion.com/me/v0/reference/video-filters>
- Streamlink 当前 Dailymotion 实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/dailymotion.py>
- Rumble 公开直播目录：<https://rumble.com/browse/live>
- yt-dlp 当前 Rumble 实现：<https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/rumble.py>
- GoodGame 官网：<https://goodgame.ru/>
- Streamlink 当前 GoodGame 实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/goodgame.py>
- FC2 Live 官网：<https://live.fc2.com/>
- yt-dlp 当前 FC2 Live 实现：<https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/fc2.py>
- Steam Community Broadcasts：<https://steamcommunity.com/?subsection=broadcasts>
- Streamlink 当前 Steam 实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/steam.py>
- 京东直播官网：<https://lives.jd.com/>
- DouyinLiveRecorder 当前京东实现：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
- 淘宝直播官网：<https://live.taobao.com/>
- DouyinLiveRecorder 当前淘宝实现：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
- 酷狗直播官网：<https://fanxing.kugou.com/>
- DouyinLiveRecorder 当前酷狗实现：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
- 百度直播官网：<https://live.baidu.com/>
- DouyinLiveRecorder 当前百度实现：<https://github.com/ihmily/DouyinLiveRecorder/blob/main/src/spider.py>
- 六间房直播官网：<https://v.6.cn/>
- StreamGet 当前六间房实现：<https://github.com/ihmily/streamget/blob/master/streamget/platforms/sixroom/live_stream.py>
- LOOK 直播官网：<https://look.163.com/hot>
- StreamGet 当前 LOOK 实现：<https://github.com/ihmily/streamget/blob/master/streamget/platforms/look/live_stream.py>
- 2026 年插件变更记录：<https://github.com/streamlink/streamlink/releases>
