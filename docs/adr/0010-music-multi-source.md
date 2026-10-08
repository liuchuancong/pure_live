# ADR 0010:音乐多源(Music Multi-Source)

- 状态:已接受(2026-10-08)

## 背景

单音源不可靠(VIP/地区/失效);lx-music 证明了多源+自定义源生态的价值。

## 决策

MusicCapability + **MusicResolver**(跨源解析)+ **MusicIdentity**(ISRC/元数据模糊匹配的逻辑身份,区别于 SourceSongId);内置源起步,自定义源走 JS 插件;lx user-api 音源脚本兼容为远期评估(接口预留不承诺)。见 [../sources/music/](../sources/music/)。

## 后果

- 正:换源播放/歌单跨源;生态可复用 lx 既有脚本资产(若兼容落地)。
- 负:身份匹配有误判风险(置信度阈值 + 用户确认一次记忆)。
