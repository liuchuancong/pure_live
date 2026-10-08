# Bilibili(第一参考插件)

> W4 的参考实现:同时覆盖 Live / VOD / Search / Feed / Danmaku / Subtitle / Auth,是验证完整生态链的最佳样本。

## 1. 包形态

Native 插件 `plugins/bilibili/`,capability 拆分:

```text
live(直播 + protobuf 弹幕)   vod(ugc/pgg/番剧)
search / feed / auth(扫码+Cookie)/ danmaku / subtitle
```

## 2. 协议词典

endpoint、参数、签名、WBI、protobuf 弹幕协议 —— 以 **pure_live_TV `lib/modules/vod`**(bilibili_api_client / ugc_api / pgc_api / danmaku_api / music_api / lyric_api)与 v1 `lib/shared/platforms/bilibili` 为准,重写不复製。

## 3. 关键业务点

- 播放地址 TTL 与分段(dash);清晰度受登录态影响(大会员画质)→ 未登录优雅降级。
- 历史上报(可选):站点侧历史与本地历史并存,本地为准。
- 弹幕:segment 索引 + protobuf 解码(danmaku capability)。

## 4. 验收

全部 capability 契约测试绿;fixtures 齐全;真机:直播可播、视频可播、搜索/Feed 出内容、扫码登录成功、弹幕渲染。
