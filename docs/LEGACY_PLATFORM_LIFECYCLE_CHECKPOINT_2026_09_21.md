# 历史平台生命周期检查点（2026-09-21）

## 结论

- **一直播**：历史官方域名 `yizhibo.com` 当前返回 DNS NXDOMAIN/委派失败；旧版
  `get_basic_live_info` 合同保留为历史证据。`yizhibo.net` 尚无官方迁移证据，因此不替换
  站点身份，也不注册一个仅有旧合同的应用入口。
- **企鹅电竞**：腾讯已公告于 2022-06-07 停止运营，服务器关闭。源码库中的旧适配器和
  支持列表仅作为历史资料，不计入当前可用平台数量。
- **继续实施**：浪 Live 仍有当前官网、WebView 和 2026 年更新的官方客户端，进入媒体
  合同与应用适配阶段；战旗继续等待一条通过前缀字节校验的生产媒体样本。

这样处理后，原“四个平台”审计组拆为 **2 个当前实施项 + 2 个生命周期归档项**，避免把
旧代码存在误报为平台仍可用。

## 一直播证据

历史参考实现使用：

```text
www.yizhibo.com/live/h5api/get_basic_live_info?scid=ROOM_ID
```

并从房间页面读取 `play_url`。2026-09-21 复核结果：

- `yizhibo.com` 的 A 记录返回 NXDOMAIN；
- `www.yizhibo.com` 的权威委派链返回失败；
- 搜索结果中的 `yizhibo.net` 未取得原品牌、主体或官方公告的迁移证明。

恢复条件：官方主体发布新域名/迁移公告，且房间身份、状态、媒体与请求头合同均能从当前
入口重新验证。

## 企鹅电竞证据

腾讯公告的停止运营节点：

- 2022-04-07 停止新用户注册、新主播及新公会入驻并关闭充值；
- 2022-06-07 停止所有功能与服务，服务器关闭；
- 社区项目随后删除企鹅电竞支持，并把平台关闭写入变更记录。

恢复条件：腾讯发布同一产品的正式恢复运营公告，并出现可验证的当前直播入口与媒体合同。

## 当前实施队列

1. 浪 Live：核验当前 API/页面合同，完成精确房间号和官方链接、状态、媒体、播放/录制刷新。
2. 战旗直播：保留已完成的内部 LiveSite；发现新开播样本后运行有界媒体探测，通过后注册。
3. 第二批中的 WinkTV、PandaTV、PopkonTV 已完成生命周期或源码接入，下一项转入 Shopee Live。

## 来源

- 一直播历史实现：<https://github.com/bililive-go/bililive-go/blob/ef71711a7c573b013d82fec01ee8d0609ee36aca/src/live/yizhibo/yizhibo.go>
- 企鹅电竞停止运营公告转载：<https://www.thepaper.cn/newsDetail_forward_17500128>
- JustLive-Web 变更记录：<https://github.com/guyijie1211/JustLive-Web>
- 浪 Live 官方客户端：<https://play.google.com/store/apps/details?id=com.lang.lang>
- 浪 Live 官方 WebView：<https://webview.lang.live/>
