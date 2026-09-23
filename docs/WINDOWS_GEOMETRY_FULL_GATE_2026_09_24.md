# Windows 当前源码完整门禁诊断（2026-09-24）

`6f26c19f` 的 Windows x64 Debug 构建先执行 FullRegression：仓库审计 0 error、Flutter Analyze 无问题；Flutter 测试 **5329 通过、2 失败**，记录 `local-artifacts/build-records/20260923T222905685Z-quality-full.json`。失败项均在 `test/player_error_recovery_test.dart`：PiP 返回后的竖屏几何保持，以及旧竖屏采样不得污染新横屏源。构建在质量门禁终止，记录 `20260923T222906005Z-build-windowsx64-debug.json`，**没有产生新 Windows ZIP**。

同一源码下将整个测试文件单独运行，**118/118** 通过（`20260923T223151369Z-quality-focused.json`）。这说明失败依赖完整并发运行条件，尚不证明生产逻辑或测试本身哪一方有问题。检查后发现第一项用固定 1.12 秒等待两个异步几何计时器完成，第二项稳定横屏等待上限仅 2 秒；两处均在完整并发负载下存在时序余量不足的风险。本批仅把第一项改为等待当前源确实达到稳定竖屏、把第二项稳定横屏等待上限增至 5 秒，仍保留几何状态、比例和旧源隔离断言。修订后的文件定向回归 **118/118**（`20260923T223550382Z-quality-focused.json`）。

下一步对修订后干净提交重新执行一次 FullRegression，再进入 Windows Debug 编译/打包；若完整门禁仍出现同项失败，保留准确断言及并发条件，继续追生产异步链路。旧完整门禁的失败不得当作新包通过证据。
