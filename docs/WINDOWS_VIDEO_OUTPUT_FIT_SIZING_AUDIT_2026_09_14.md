# Windows 视频输出 fit 尺寸所有权审计（2026-09-14）

## 范围与结论

本批复核上游 Issue #767 所在的 Windows 高 DPI 视频纹理链，基线为 `cf98dfc89edf1c15ee6e5206a4635ef451be96b7`，代码修订为 `7715e0fa864dd5f06657ade4a521a2b304b8d5f2`。结论是：已有 viewport / DPR 限幅只按 `BoxFit.contain` 的最小轴计算原生纹理，主播放器实际选择 `cover`、`fill`、`fitHeight` 等模式时仍会由 Flutter 放大一张偏小纹理。

现由同一个可见视口尺寸器接收播放器的有效 `BoxFit`，按显示模式选择主导轴，同时保持纹理为视频源宽高比、保持 180 ms 防抖并以源尺寸为上限。该修订关闭稳定的源码尺寸缺口，但不把源码回归或构建成功扩大为物理 4K 显示器的 GPU 结论，也不据此确认 Issue #853 的动态画面观感问题。

## 首个错误状态

`media_kit_video` 的 `Video` 在 `Texture` 外层使用 `FittedBox(fit: ...)`。旧 `calculateVideoOutputSize` 不接收 `fit`，始终使用：

```text
min(viewportWidth / sourceWidth, viewportHeight / sourceHeight)
```

以 1920×1080 视频、500×500 物理视口为例：

| 显示模式 | 旧原生纹理 | Flutter 最终目标 | 结果 |
| --- | ---: | ---: | --- |
| `contain` | 500×282 | 约 500×281 | 与视口匹配 |
| `cover` | 500×282 | 约 889×500 后裁切 | 纹理先被放大约 1.78 倍 |
| `fitHeight` | 500×282 | 约 889×500 | 同样放大 |

因此，旧策略虽然降低了原生纹理像素数，却在非 `contain` 模式重新引入合成层放大；显示模式切换也不会触发 `setSize`，因为尺寸器没有观察 `fit`。

## 修订合同

| 模式 | 原生纹理缩放轴 | 边界 |
| --- | --- | --- |
| `contain` / `scaleDown` | 宽高比例的较小值 | 完整画面、源尺寸封顶 |
| `cover` / `fill` | 宽高比例的较大值 | 两个视口轴都不依赖低分辨率纹理放大 |
| `fitWidth` | 宽度比例 | 宽度与物理视口匹配 |
| `fitHeight` | 高度比例 | 高度与物理视口匹配 |
| `none` | 1:1 源尺寸 | 不改变裁切语义 |

共同约束：

1. 原生纹理始终保持源视频宽高比，Flutter 继续单独拥有拟合、裁切和拉伸语义。
2. 所有比例最大为 1.0，不创建超过解码源尺寸的纹理。
3. 输出维持偶数像素；源尺寸尚未发布时继续使用有界 1080p 临时源。
4. `VideoOutputViewportSizer` 观察 `fit`；同一播放器从 `contain` 切到 `cover` 时发布非强制的新尺寸请求。
5. 主播放器传递当前 `effectiveFit`；多画面显式传递其既有 `BoxFit.contain`，不改变多画面显示语义。

## 回归与构建证据

### 有效红灯

- 记录：`local-artifacts/build-records/20260913T203327517Z-quality-focused.json`
- 新合同以 `fit: BoxFit.cover / fitHeight / fitWidth` 调用尺寸策略，旧实现因不存在 `fit` 参数而在测试加载阶段失败。
- 该红灯证明旧 API 没有表达显示模式，未以无关测试失败替代产品边界。

### 最终质量门禁

- 记录：`local-artifacts/build-records/20260913T203831811Z-quality-focused.json`
- 命令覆盖尺寸策略、viewport 尺寸器及 media_kit 相邻状态/几何测试，共 **26/26 PASS**。
- 新增确定性断言：同一 1920×1080 源与 500×500 视口下，`contain` 为 500×282，`cover` / `fitHeight` 为 890×500，`fitWidth` 为 500×282；同一输出身份切换 `contain → cover` 会发布第二次 `force=false` 调整。
- 本批最后一次 Dart 编辑后的唯一一次 analyze：`No issues found`。
- 仓库完整性审计：0 error；依赖清单未变化，锁定依赖解析按规则复用现有配置。

### Windows 构建

- 记录：`local-artifacts/build-records/20260913T204326094Z-build-windowsx64-debug.json`
- `WindowsX64 / Debug / SkipQuality` 构建成功，耗时 261.586 秒。
- ZIP：`local-artifacts/3.1.8-4121/PureLive-3.1.8-4121-windows-x64-debug.zip`
- 大小：142,778,353 B
- SHA-256：`8B823AC8DEBCD367A1926F8D2CBC326EAA2227311333522FA72A90037D0D5B43`
- 构建发生在提交前的已验证工作树，记录内 `source_commit` 因此仍显示父提交 `cf98dfc8`；该工作树随后原样提交为 `7715e0fa`，推送后本地与 `origin/master` 已核对一致。

## 验收边界与下一步

- W3-03 与 Issue #767 保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批没有启动 Windows GUI、播放真实直播、采集 GPU 3D / Video Decode、操作手机或发布 3.2.0；Astra Light 使用 0 次。
- 后续 Windows GUI 批次在物理 4K / 150% 与 1440p / 100% 上对照 `contain`、`cover`、`fill`、`fitWidth`、`fitHeight`，记录纹理矩形、GPU 3D、Video Decode、CPU、工作集、窗口缩放与退出回落。GUI 批次开始时只创建并持续复用一个 Astra Light 任务。
