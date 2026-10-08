# JS Plugin

> 第三方生态插件:JS 脚本跑在 flutter_js 沙箱(仓库 `plugins/built_in_kotlin/flutter_js` 已含 AGP9 兼容补丁)。

## 1. 适用

网站解析、API 适配、搜索源、影视源、音乐源、小型数据适配器。远期目标:**兼容 lx-music 的 user-api 音源脚本**(脚本本就是 JS,宿主实现其 API 面 shim 即可,见 [../sources/music/music-resolver.md](../sources/music/music-resolver.md))。

## 2. 运行模型

```text
JS 脚本
 ↓ Sandbox API(受限注入:fetch/http / kv / log / crypto / Contents)
 ↓ PluginNetwork(域名白名单、超时、大小上限)
 ↓ Network Core(统一 dio,带日志与代理)
```

禁止:`JS → 任意 Dart HTTP / 文件系统 / 原生通道`。异常必须捕获在沙箱内(见 [plugin-security.md](plugin-security.md))。

## 3. 脚本结构

```js
PureLive.registerPlugin({
  manifest: { id, name, version, apiVersion, capabilities, permissions },
  // 按 capabilities 实现:
  live: { browse, detail, resolve, refresh },
  search: { search },
});
```

`apiVersion` 决定可用 API 面;宿主按版本注入兼容层。

## 4. 性能与稳定

- 脚本执行有超时;超时/异常 → 插件 degraded,连续失败自动禁用。
- 重计算(解析大 JSON)分片,避免阻塞 UI 线程 isolate。
- 每插件独立 JS Runtime 实例,全局状态不共享。

## 5. 开发与调试

模板仓库 + 本地导入(文件/URL);配合 Telescope 式运行时检查器(观察名单)与 talker 日志调试;详见 [plugin-development.md](plugin-development.md)。
