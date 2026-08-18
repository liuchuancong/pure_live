# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## 0.0.4

- Added optional pointer event handling for `FlameBarrageWidget`.
- Added `enablePointerEvents` property to control whether the barrage widget responds to mouse and touch events.
- Improved barrage rendering isolation and prevented unnecessary pointer event processing when interaction is disabled.
- Fixed potential rendering artifacts caused by pointer events.

## 0.0.3

- New demo page for multiple screens sharing single BarrageController, support mutual exclusive switch between full screen and small window
- New BarrageItem independent style test demo to verify per-danmaku custom style override
- Add `fontFamily` property to BarrageConfig, BarrageEngine, MixedLayout and BarrageItem, support global and single danmaku custom font configuration
- Complete pause & resume freeze mechanism for barrage engine

## 0.0.2

- Added GitHub Pages online demo.
- Added English / Chinese README navigation.
- Improved documentation.
- Updated project branding and logo.

## 0.0.1

* Initial public release.
* High-performance barrage rendering engine powered by Flame.
* Batch rendering pipeline for reduced Widget Tree overhead.
* Dual-pass text rendering with independent outline and fill passes.
* Zero-allocation object pooling system (`BarragePool`).
* Dynamic runtime configuration updates.
* Native emoji rendering support.
* Sprite atlas animation support.
* Precise barrage interaction callbacks.
* Extensible Fragment architecture for custom rendering components.
* MIT License.
