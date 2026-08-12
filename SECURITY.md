# Security Policy

## Reporting

请优先使用 GitHub 仓库的 **Security → Report a vulnerability** 私下提交漏洞。报告中请包含受影响版本、复现步骤、影响范围和建议修复方式；请勿在公开 Issue 中附带 Cookie、令牌、签名文件或个人直播源。

## Secrets and signing material

- Android JKS、`key.properties`、Windows PFX/私钥和 WebDAV/Cookie 配置均不得提交。
- 发布密钥应保存在仓库外，并通过本机安全目录或 GitHub Actions Secrets 注入。
- 若密钥曾进入 Git 历史，应立即轮换；仅删除当前分支文件不会清除历史对象。
- 曾经提交到历史中的测试签名材料均视为已退役。发布 Android 版本前应核验 APK 证书指纹，并确认其与当前受控的发布密钥一致。
- `.gitleaks.toml` 仅排除构建产物和 Firebase 官方定义为客户端公开配置的两个固定文件；提交前仍应运行 Gitleaks 检查工作树和 Git 历史。

## Supported versions

仅最新 GitHub Release 和 `master` 当前版本接受安全修复。
