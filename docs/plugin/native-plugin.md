# Native Plugin

> Dart 编译的官方/高性能插件,进程内以契约接口暴露。

## 1. 适用

- 核心直播源(Bilibili/Douyu/Huya/Douyin…)
- 高性能需求:protobuf 弹幕、复杂签名
- 系统级能力提供方

## 2. 结构(以 bilibili 为例)

```text
plugins/bilibili/
├── manifest.yaml            # capabilities: live,vod,search,feed,auth,danmaku,subtitle
├── lib/
│   ├── bilibili.dart        # barrel:导出 Provider 工厂 + Manifest
│   └── src/
│       ├── live/            # LiveCapabilityProvider
│       ├── vod/             # VodCapabilityProvider(协议词典:pure_live_TV modules/vod)
│       ├── auth/            # AuthCapabilityProvider(扫码/Cookie)
│       ├── danmaku/         # DanmakuCapabilityProvider(protobuf)
│       └── models/          # freezed 模型
├── test/
│   ├── contract/            # 能力契约测试(与 JS 源同一套断言)
│   └── fixtures/            # 真实响应录制
└── security policy          # 域名白名单/权限声明
```

## 3. 规则

- 只依赖 L0 + plugin_api;不得依赖其他插件、media adapter、UI。
- 网络经统一 network 底座;凭据经 auth 保险箱;不落盘明文凭据。
- 全部能力必须通过契约测试 + fixtures 快照(见 [../development/testing.md](../development/testing.md))。
