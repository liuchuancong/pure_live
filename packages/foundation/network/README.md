# pure_live_network

> 职责:dio 封装:超时、重试、代理与网络错误分类

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包 + L0 叶子(utils、logging)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_network.dart`;内部实现放 `lib/src/` |

## 内容

四个 app、每个站点适配器、插件宿主和更新检查都需要同样的传输规则;v1 的代价是三十份各自写的重试逻辑,其中没有一份读过 `Retry-After`。

- `settings.dart` —— `NetworkSettings`:三类超时、响应/请求体上限、重定向策略、`maxConcurrent`、`hostMinSpacing`、`refuseOriginChange`、`acceptsGzip`;`headersFor` 合并 UA/默认头/单次请求头
- `retry_policy.dart` —— `RetryPolicy`(次数 / 指数曲线 / 上限 / 是否服从服务器)与 `parseRetryAfter`、`parseHttpDate`。**429 带 `Retry-After: 30` 就等 30 秒**,而不是继续按曲线锤它;超过 `retryAfterCeiling` 的提示视为"别再来了",不再排队等待
- `classification.dart` —— 状态→kind 的表(`kindForStatus` / `isRetryableStatus` / `failureForStatus` / `classifyDioException` / `retryAfterOf` / `oversizeFailure`)。401/403→forbidden、404→notFound、408/504→timeout、429/425→rateLimited、5xx→server;501/505 不重试(再怎么问答案都一样)
- `failure.dart` —— `NetworkFailure`(`code` 对齐 platform-models §14),新增 `retryAfter` 与 `actualUri`:重定向换了主机只有从响应侧才看得见
- `headers.dart` —— `HttpHeaderBag`:大小写不敏感、同名多值保留(Set-Cookie 不能被压成一行),`redacted()` 把凭据类头换成 `[redacted]`
- `url_reference.dart` —— `resolveReference`(绝对 / `//host` / `/x` / `../x` 四种写法都按**实际应答的 url** 解析)、`withQuery`、`sameOrigin`、`redact`(签名 token 就在 query 里)、`urlHostOf`、`isHttpScheme`
- `request_body.dart` —— `RequestBody.json|form|text|raw|multipart|asIs`。编码与它必须的 content-type 绑在一起:`form` 显式做 UTF-8 percent-encoding,不交给 transformer 猜(中文表单字段变 mojibake 就是这么来的)
- `limiter.dart` —— `ConcurrencyLimiter`(并发上限,**队列也有上限**:无限队列只是把"慢"推迟成内存问题)与 `HostThrottle`(同host最小间隔,槽位在请求时就预定,否则同一秒的两个请求只隔开第一对)
- `responses.dart` —— `HttpResponse` 基类(`uri` 应答地址 + `requestedUri` 请求地址 + `leftOrigin` + `redactedHeaders` + `elapsed`)、`TextResponse`、`RawResponse`、`HeadResponse`、`DownloadResult`(`isPartial` / `isComplete`:把截断的下载当完整文件写进缓存是永久污染)、`decodeJsonObject` / `decodeJsonList`
- `client.dart` —— `NetworkClient`:两层门面坐在同一条发送路径上。Dio 形的 `get` / `getJson` / `post` / `sendBytes` 保留给既有 provider;包 own 的 `getText` / `requestJson` / `requestJsonArray` / `submitJson` / `postForm` / `postJson` / `put` / `patch` / `delete` / `head` / `requestBytes` / `download` 是新写的入口。`download` 用 `ResponseType.stream` **边读边拦**:chunked 响应不声明长度,乱报 content-length 的 CDN 也不少见。一个并发槽位覆盖整段重试(重试四次仍是一个逻辑请求)

## 依赖

- `dio ^5.9.0` —— 传输。`package:dio/dio.dart` 的类型(`CancelToken`、`Response`)仍出现在旧门面签名里,这是保留 provider 兼容的代价。
- `pure_live_utils`(retryAsync / Clock / requireNonBlank 等)、`pure_live_logging`。

## 平台矩阵

纯 Dart + dio,不含 `dart:io`,Android / iOS / Windows / Linux / macOS / Android TV / web 可用。`download` 走 `ResponseType.stream`,该路径在 dio 的浏览器适配器(XHR)上**未跑过真机**。

## 验证

- 分析:`dart analyze packages/foundation/network packages/foundation/utils packages/ecosystem/extension`(2026-10-11:`No issues found!`)
- 测试:`dart test` network 18/18、extension 53/53、utils 38/38 通过。新增的 limiter / 边读边拦的 download / Retry-After 路径**没有对应测试**,只是编译与既有测试没被打破。

## 未验证(2026-10-11)

- **代理与证书固定**:pubspec 描述仍写着"代理",实际没有暴露 —— dio 的 `DefaultHttpClientAdapter` 代理设置需要 `dart:io`,会把 web 排除掉。要么按平台分支注入 adapter,要么改描述,当前先记为缺口。
- 真机 429/503 的 `Retry-After` 行为(含服务器时钟偏差)未在设备上观测;HTTP-date 分支是照 RFC 9110 §5.6.7、§10.2.3 写的。
- `refuseOriginChange` 只在 `sameOrigin` 的单测层面成立;真实重定向链(多跳、跳完再跳回)未验证。
- `ConcurrencyLimiter` 与 `HostThrottle` 在真实并发下的表现(队列打满、close() 与在途请求交错)未压测。
