# Fork note (Pure Live)

Vendored copy of `yaru_window_manager` 0.1.3 (MPL-2.0, upstream
<https://github.com/ubuntu/yaru_window.dart>) with one change: it drives
`window_frame_kit` instead of `window_manager`, which is a verbatim port of the
same facade, so the only source edit is the import in
`lib/src/window_manager.dart`. The package's own test suite is not carried: it
mocks `window_manager`, and as a non-member path dependency its dev
dependencies are not resolved here anyway.

---

# Yaru Window Manager

[![pub](https://img.shields.io/pub/v/yaru_window_manager.svg)](https://pub.dev/packages/yaru_window_manager)

A [`window_manager`](https://pub.dev/packages/window_manager) -based implementation
of [`yaru_window`](https://pub.dev/packages/yaru_window) for macOS and Windows.
