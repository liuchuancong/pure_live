# pure_live_files

> 职责:跨平台文件与路径访问,含导入导出与下载目录

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_files.dart`;内部实现放 `lib/src/` |

## 内容

- `file_names.dart` —— `sanitizeFileName`(非法字符 / 控制字符 / 前后缀空白 / Windows 保留名 / 只截词干保住扩展名)、`disambiguateName`(`a (1).mp4` 式让位)、`resolveWithin`(**目录逃逸守卫**:拒绝绝对 key 与 `..` 逃出的结果)
- `paths.dart` —— `DirectoryPolicy`(应用绑 path_provider)、`writeTextAtomically`(临时文件 + rename,崩溃不会留下半截设置)、`mimeTypeFor`

名字来自站点或导入的播放列表,就是攻击者可控文本;`resolveWithin` 集中做一次归一化,好过每个调用者各自记得防 `../`。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
