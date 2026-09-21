# 淘宝直播合同检查点（2026-09-21）

## 结论

淘宝直播已按当前公开网页合同接入应用注册表。首阶段覆盖精确场次、主播账号、官方房间链接与 `m.tb.cn` 分享短链；公开门户尚未暴露经核验的消费者直播目录，因此目录保持空结果并在界面持续说明范围。

## 生产证据

- 官网入口：<https://live.taobao.com/>；当前网页资源使用 `live-portal` 前端包。
- 详情接口：`mtop.mediaplatform.live.livedetail` v4.0，网页 `appKey=12574478`。
- 匿名首个请求返回短时 `_m_h5_tk` / `_m_h5_tk_enc`；客户端使用 `MD5(token&t&appKey&data)` 生成签名后，第二个请求取得详情。账号 Cookie 为可选增强项，不写入播放请求头或日志。
- 生产主播账号 `1759494485` 在探测时解析到直播场次 `2554133391311487`，`streamStatus=1`、`roomStatus=1`，返回五个 `lld`～`ud` 定义行。部分定义共享同一物理媒体，适配器按 HLS/FLV 对去重并保留较高定义身份。
- 当前样本 HLS 返回 HTTP 200、标准 `#EXTM3U` 与带独立 `auth_key` 的 TS 子资源；FLV 返回 HTTP 200，前缀为标准 `FLV`。
- `viewCount` 记录场次累计观看，`broadCaster.fansNum` 记录主播粉丝；两者分列，不标记为当前并发人数。

## 源码合同

- 稳定身份：`live:<ID>` 表示精确场次，`creator:<ID>` 表示主播及其当前场次；裸数字按精确场次解析。
- 链接：支持 `h5.m.taobao.com/taolive/video.html`、`tbzb.taobao.com/live`、`huodong.m.taobao.com/act/talent/live.html`，以及有界解析的 `m.tb.cn/h.*` 分享短链。
- 状态：直播、未开播、回放、受限、未知分别保留；回放与受限状态不伪装成未开播。
- 媒体：仅接受淘宝 CDN 的 `liveplatform` / `mediaplatform` HLS、FLV，要求 `auth_key`，并校验 HLS 子资源同主机、同流标识。
- 生命周期：房间进入与录制入口校验 HLS；收藏刷新省略媒体清单请求；恢复重新查询原身份；`auth_key` 到期前五分钟触发续期。
- 账号：设置页提供可选淘宝 Cookie 编辑器；配置参与备份、恢复和全部账号清理。

## 证据边界

本检查点记录公开接口与媒体字节验证。Android/Windows 原生画面、线路切换、恢复和短录并入全部功能收敛后的集中验收，不以 HTTP 200 或单元夹具替代。
