# 45 个直播站点外部打开覆盖与待注册平台复核（2026-09-23）

## 用户可见缺口

注册表有 45 个直播站点和 IPTV；`RoomExternalOpener` 原先只覆盖 31 个直播站点。Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播、淘宝直播、酷狗直播、百度直播、六间房直播及 LOOK 直播的房间卡片虽已接入，外部打开却统一返回 `unavailable`。新增 14 个官网 URL 动作回归，旧实现均红灯。

现在为 14 站分别从经过校验的稳定房间 ID 构造官网链接，不直接转发卡片中的任意 `link` 字符串。Shopee 与淘宝的复合 ID、Nimo 数字频道、GoodGame `id:` 播放器、JD hash 路由等保留各自原生身份；无效 ID 返回空目标，IPTV 仍不发布外部官方房间页。源码 `Sites.supportedSiteIds` 与外部打开分支核对为 **46 个注册适配器，45 个直播站点目标，唯一无远端目标为 IPTV**。

## 验证

先新增 14 站动作红灯；最终外部打开与 14 站适配器共 **15 文件 125/125**，两文件定向 Analyze 无诊断。测试覆盖官方 URL、启动次数、恶意旧 `link` 不被使用、复合身份与无效 ID；实际外部浏览器和 Android 客户端跳转仍需候选原生验收。

同轮只读复核未注册平台：指定本机 Clash 7897 请求浪 Live 公开房间详情仍为 HTTP 403 / CloudFront；战旗公开目录 HTTP 200、`code=0`、五张 `status=4` 卡片。此次没有取得新的媒体前缀，生产可播证据门槛保持；未操作手机、更新模块或切换系统网络。原始响应只保存在忽略目录 `local-artifacts/reference/`，仓库仅保留脱敏摘要。
