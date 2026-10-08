# third_party

放**上游源码的本仓副本与补丁**:这些包由上游维护,本仓只为兼容本地构建打最小补丁,不参与 v2 的质量门禁(`analysis_options.yaml` 已排除)。

| 目录 | 来源与用途 |
|---|---|
| `built_in_kotlin/` | AGP 9 / Built-in Kotlin 兼容补丁过的 Flutter 插件 Android 子包(`flutter_inappwebview_android`、`share_handler_android`、`mobile_scanner`、`flutter_exit_app`、`flutter_js`),由根 `pubspec.yaml` 的 `dependency_overrides` 与应用 `pubspec.yaml` 的 `path:` 引用 |
| `media_kit/`、`media_kit_video/`、`fvp/` | Predidit 系 media-kit fork(播放内核);当前以 pub 依赖 + 覆盖引入,目录为后续 vendoring 预留 |

规则:

- 上游代码只打**必要补丁**,补丁文件在提交信息里说明原因;不做风格重排。
- 新增 vendored 包必须同时给出:上游 URL + commit、打补丁的文件清单、以及"为什么不能直接用 pub 版本"。
- 这里的代码不算本仓的公共 API,业务包禁止直接 import;需要能力时走 `packages/integrations/`。
