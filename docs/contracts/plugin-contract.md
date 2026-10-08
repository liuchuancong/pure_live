# 插件契约(Plugin Contract)

> Plugin 声明"我是谁、能做什么、需要什么权限";详细机制见 [../plugin/](../plugin/)。

## 1. 契约构成

```text
Plugin
├── Manifest      身份/版本/apiVersion/capabilities/permissions(静态声明,不可动态扩权)
├── Metadata      名称/作者/图标/描述/来源
├── Capabilities  实现的能力集合(见 capability-contract.md)
├── Permissions   所需权限(最小化,I8)
├── Providers     能力的具体实现(LiveProvider/VodProvider/…)
└── Runtime       运行形态:native(Dart 编译)/ js(沙箱脚本)/ data(无代码数据)
```

## 2. 基本规则

- 插件与宿主之间**只通过 Capability Contract 通信**(I5),禁止绕过。
- 插件崩溃、超时不得影响主 App(隔离边界见 [../security/plugin-sandbox.md](../security/plugin-sandbox.md))。
- `apiVersion` 版本化,Runtime 按 min/max 兼容区间判定(见 [../architecture/evolution.md](../architecture/evolution.md))。
- 安装管线:Download → Verify → Manifest Parse → API Compatibility → Permission Review → Sandbox → Install → Enable(见 [../security/security-model.md](../security/security-model.md))。

## 3. 来源

Builtin / Local File / URL / Repository / Marketplace(未来)。
