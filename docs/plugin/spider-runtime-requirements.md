# Spider 运行时需求分析(TVBox / drpy / lx-music 兼容层)

> 目的:在写任何兼容层代码之前,把真实生态的宿主接口逐项摸清。来源为参考项目源码本体的逐行盘点,
> 不是猜测。结论决定 fjs 桥接的设计约束。

## 1. webtv-main quickjs JS 宿主(全局桥接面)

来源:`quickjs/src/main/java/com/fongmi/quickjs/method/Global.java` 与 `Local.java`
(@JSMethod 注解方法即 JS 可直接调用的全局函数)。

| 全局函数 | 签名 | 语义 | PureLive 对应 |
|---|---|---|---|
| `req(url, options)` | 同步返回响应对象 | HTTP 请求(**同步**),http.js 在其上包 async 版 | PluginNetwork(异步)——见 §4 同步约束 |
| `_http(url, options)` | 同步 | req 的底层 | 同上 |
| `joinUrl(parent, child)` | 同步字符串 | 相对 URL 拼接 | 纯 Dart 可复刻 |
| `md5X(text)` | 同步字符串 | md5 hex | crypto 包 |
| `aesX(mode, encrypt, input, inBase64, key, iv, outBase64)` | 同步字符串 | AES-CBC/ECB 双向,输入输出编码可选 | pointycastle |
| `rsaX(mode, pub, encrypt, input, inBase64, key, outBase64)` | 同步字符串 | RSA(含 no-padding 变体) | pointycastle |
| `s2t(text)` / `t2s(text)` | 同步字符串 | 简繁转换 | 需字表(延迟项) |
| `getPort()` / `getProxy(local)` | 同步 | 本地代理端口(嗅探/本地代理回调) | 需要**本地 HTTP 代理服务**(未建) |
| `js2Proxy(dynamic, siteType, siteKey, url, headers)` | 同步 | 生成走本地代理的回调 URL | 同上 |
| `setTimeout(func, delay)` | — | 定时器 | fjs 内建 timers ✓ |
| `local.get/set/delete(rule, key)` | 同步 | 每站点持久 kv | KeyValueStore ✓ |

### JS 库资产(随宿主分发,spider 直接 import)

| 文件 | 行数 | 作用 | 处置 |
|---|---:|---|---|
| http.js | 16 | req 的 async 包装 | 薄,可自带 |
| crypto-js.js | 6190 | CryptoJS 全套 | **vendoring 决策** |
| cheerio.min.js | 1(压缩,~200KB+) | HTML 解析 | **vendoring 决策** |
| gbk.js | 64 | GBK 编解码 | 可按需自带 |
| similarity.js | 0(空) | 相似度 | 跳过 |
| cat.js | 1(压缩) | underscore 类工具 | **vendoring 决策** |

### spider 模块形态

`import * as spider from '<file>'` 后取 `__jsEvalReturn()`(drpy0)或 `default`;方法集
init/home/categoryContent/detailContent/searchContent/playerContent/liveContent —— 与已实现的
JsDrpySpiderHandle 对齐 ✓。

## 2. webtv-main Python 宿主(spider.py 基类)

chaquo 基类方法: init/homeContent/homeVideoContent/categoryContent(tid, pg, filter, extend)/
detailContent(ids)/searchContent(key, quick, pg)/playerContent(flag, id, vipFlags)/liveContent(url)/
localProxy(param)/destroy。基类给脚本注入: fetch/post(requests 封装)、html(lxml)、cache(走本地代理)、
log、regStr/removeHtmlTags/cleanText、str2json/json2str、getProxyUrl。

关键点:**py spider 的 fetch 是同步 requests**;嵌入解释器跑在专用线程上,同步阻塞可接受 ——
我们的 serious_python worker 模式(专用线程轮询网关)天然满足 ✓。

## 3. lx-music user-api(preload.js)

`lx.request(url, {method,timeout,headers,body,form,formData}, callback(err,resp,body))`(异步回调式)、
`lx.send/on`(inited/request/updateAlert)、`utils.crypto{md5,aesEncrypt,rsaEncrypt,randomBytes}`、
`utils.buffer{from,bufToString}`、`utils.zlib{inflate,deflate}`、`currentScriptInfo`、`version:'2.0.0'`、
`env:'desktop'`。已实现于 MusicSourceScriptHost ✓(缺:proxy 支持、storage 持久化——lx 桌面端脚本
另有 localStorage 等价物时需补)。

## 4. 关键架构约束:同步 HTTP

drpy/quickjs 系 spider 的 `req()` 是**同步**调用——页面解析逻辑层层依赖同步返回。webtv 的 quickjs
包装器允许原生方法阻塞 JS 线程(JS 跑在专用线程),因此可行。

fjs 的 `fjs.bridge_call` 返回 **Promise**(异步)。这意味着:

1. **异步型 spider**(init/home/... 声明为 async 函数、或内部全部 await req)可直接跑 ✓
   —— 我们的 JsDrpySpiderHandle dispatch 本身返回 Promise,await 即得。
2. **同步型 drpy spider**(绝大多数存量)在 fjs 上无法直接跑:`req` 返回 Promise,同步代码拿到的是
   Promise 而非响应。可选路径:
   - a) 调研 fjs 是否支持同步桥(bridge_call 同步返回;FRB 的 sync 模式);
   - b) QuickJS job 循环重入(在 req 处挂起栈、驱动 job、恢复——需 fjs 暴露该能力);
   - c) 预执行转换(把同步源自动包成 async——不可行,无法静态改写任意代码);
   - d) 支持子集:仅适配"顶层 async"的新式 spider,存量同步源放弃。

**结论(需求记录,未实现)**:路径 a/b 需对 fjs 的 FRB 桥做一次能力确认(读 fjs 源码 FRB 生成层);
若均不可行,W8 铺量的存量同步源需要自研 quickjs 包装器(whl.quickjs 同类,工程量大)或引导源作者
改 async。此项为 **W8 的第一阻塞项**,已在本文件记录。

## 5. 各域功能需求清单(工业级口径)

### TVBox 域
- [x] 单仓/多仓/urls/storeHouse 解析
- [x] lives 组/频道解析
- [x] M3U(EXTVLCOPT 头)
- [x] XMLTV EPG
- [x] JS spider 宿主(plain + drpy 模块形态)
- [x] Python spider 宿主(serious_python + 本地网关)
- [ ] 本地 HTTP 代理服务(js2Proxy/localProxy/callback 类 spider 的硬需求)
- [ ] 同步 req 约束解法(§4)
- [ ] spider jar(zip)解包:jar 内 js/py 的发现与装载
- [ ] cheereio/crypto-js/gbk 库 vendoring 决策
- [ ] 直播仓库 lives 的 type/api 变体(订阅式 lives)
- [ ] playerContent parse=1 的网页嗅探播放(webview)

### lx-music 域
- [x] user-api 宿主(request/send/on/crypto/buffer/zlib)
- [ ] 脚本 localStorage 持久化(若脚本使用;需对真实音源脚本盘点)
- [ ] 代理设置透传(lx.request options 里的 agent)
- [ ] 音源脚本管理面(导入/启停/源切换)的设置项接线

### Bilibili 视频域(newBV 参照)
- [x] WBI 签名
- [x] popular/view/playurl(游客 try_look)
- [ ] 登录(QR 扫码 + Cookie 导入)→ 大会员画质/收藏/历史上报
- [ ] pgc(番剧)playurl
- [ ] 弹幕(seg.so protobuf + websocket)
- [ ] 字幕(aisubtitle api)
- [ ] 搜索筛选条件(filter 表)

### 直播域(dart_simple_live 参照)
- [x] huya 协议(v1 行迁移已完成并验证)
- [ ] bilibili live(getInfoByRoom/getRoomPlayInfo/getDanmuInfo 已盘点,web 直播流未含登录态)
- [ ] douyu(getEncryption 签名链)/douyin(webid+签名)/kuaishou/yy/cc 等站协议迁移
- [ ] 每站弹幕 websocket(v1 已有 35+ 站实现可迁)
