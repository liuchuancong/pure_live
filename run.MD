# 构建与发布

项目使用 Flutter `3.44.9`（Dart 3.11+）。推荐先安装 FVM，并在仓库根目录执行：

```shell
fvm install
fvm flutter pub get
fvm flutter analyze --no-fatal-infos --no-fatal-warnings
fvm flutter test test/danmaku_settings_controller_test.dart
```

## 本地构建

### Windows 便携版

```shell
fvm flutter config --enable-windows-desktop
fvm flutter build windows --release
```

产物目录：`build/windows/x64/runner/Release/`。

### Windows MSIX

```shell
fvm dart run msix:create --signtool-options "/td SHA256"
```

### Android 通用

```shell
fvm flutter build apk --release
```

### Android 分包

```shell
fvm flutter build apk --release --split-per-abi
```

### macOS 打包

```shell
fvm flutter build macos --release
```

如果想打包 dmg，则需要运行以下命令：

```shell
python3 -m venv .venv

# Windows
.venv\Scripts\activate
# Unix/Linux/MacOS
source .venv/bin/activate

pip install dmgbuild
fvm dart run dmg --no-sign --no-notarization
```

> 参考链接：https://pub.dev/packages/dmg

## GitHub Actions

`.github/workflows/feature-build.yml` 提供以下自动化流程：

1. 功能分支 `agent/**` 推送或 Pull Request：运行格式检查、静态分析、专项测试、Android 分架构 APK 和 Windows 便携版构建。
2. 推送 `v*` 标签：完成同一套质量门禁和构建后，自动创建 GitHub Release。
3. Release 同时上传三个 Android APK、Windows ZIP 与 `SHA256SUMS.txt`。

Android 正式发布使用以下 GitHub Actions Secrets：

- `PURELIVE_KEYSTORE_BASE64`
- `PURELIVE_STORE_PASSWORD`
- `PURELIVE_KEY_PASSWORD`
- `PURELIVE_KEY_ALIAS`

普通分支在 Secrets 缺失时会生成临时测试签名；标签发布会校验正式发布签名配置。

旧的 `.github/workflows/release.yml` 保留为手动的多平台签名发布流程，不响应标签推送，避免同一标签重复创建 Release。

## 发布新版本

1. 同步 `pubspec.yaml`、`assets/version.json` 和 `RELEASE_NOTES.md` 的版本与更新内容。
2. 确认 `master` 已包含待发布提交，并已推送到远端。
3. 创建并推送标签，例如：

```shell
git tag -a v2.0.23 -m "Pure Live v2.0.23"
git push origin v2.0.23
```

4. 在 Actions 页面确认 `build-and-release` 的质量、Android、Windows 和 Release 四个任务全部通过。
5. 在 [Releases](https://github.com/wzgrx/pure_live/releases) 核对附件与 SHA256 校验文件。
