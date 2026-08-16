# Changelog

## 1.0.1 - 2025-11-15

### Fixed
- Fixed `unnecessary_null_comparison` warnings in `fijkview.dart` and `fijkvol.dart`
- Removed placeholder GitHub URLs from pubspec.yaml
- Improved code quality and reduced analyzer warnings

### Changed
- iOS configuration now uses CocoaPods dependency (BIJKPlayer) instead of local framework
- Cleaned up unused plugin template files
- Updated homepage URL in pubspec.yaml

## 1.0.0 - 2025-01-13

### Initial Release

This is the first release of `flv_lzc`, a fixed and improved version of fijkplayer 0.11.0.

### Fixed
- Removed deprecated `mRegistrar` usage in Android plugin (FijkPlugin.java)
- Updated to use modern Flutter plugin API
- Fixed compatibility issues with Flutter 3.x and above
- Resolved compilation errors in modern Flutter environments

### Features
- Full FLV stream support with H.265 codec
- Low latency live streaming optimization
- Cross-platform support (iOS & Android)
- All original fijkplayer features maintained
- Based on ijkplayer for powerful media playback

### Migration from fijkplayer

To migrate from fijkplayer to flv_lzc:

1. Update your `pubspec.yaml`:
```yaml
dependencies:
  # fijkplayer: ^0.11.0  # Remove this
  flv_lzc: ^1.0.0        # Add this
```

2. Update your imports:
```dart
// Old
import 'package:fijkplayer/fijkplayer.dart';

// New
import 'package:flv_lzc/fijkplayer.dart';
```

3. Run `flutter pub get` and rebuild your app

All APIs remain the same, so no code changes are needed beyond the import statement.

---

# Previous fijkplayer Change Log

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

---
## [0.11.0](https://github.com/befovy/fijkplayer/compare/v0.10.1...v0.11.0) (2023-07-23)
* migrate to sdk: ">=2.14.0 <4.0.0"

---
## [0.10.1](https://github.com/befovy/fijkplayer/compare/v0.10.0...v0.10.1) (2021-11-30)

* fix fix mov seek null pointer crash (https://github.com/befovy/ijkplayer/pull/71) (https://github.com/befovy/FFmpeg/commit/72cfdff6)

---
## [0.10.0](https://github.com/befovy/fijkplayer/compare/v0.9.0...v0.10.0) (2021-07-11)

* download android symbols from github release.

---
## [0.9.0](https://github.com/befovy/fijkplayer/compare/v0.8.8...v0.9.0) (2021-05-29)

* null safety support
---
## [0.8.8](https://github.com/befovy/fijkplayer/compare/v0.8.7...v0.8.8) (2021-05-15)

* fix ios setLoop never return ([2476a3a](https://github.com/befovy/fijkplayer/commit/2476a3ac3d4ed94e315b11061dbfb646fa406046)), closes [#396](https://github.com/befovy/fijkplayer/issues/396) and [#366](https://github.com/befovy/fijkplayer/issues/366)

* upgrade iOS pod dependency, resue github release, fix jcenter unavaiable ([86deb1f](https://github.com/befovy/fijkplayer/commit/86deb1f77716ff54cd9df514b292dc9c1e2de5c5))

---
## [0.8.7](https://github.com/befovy/fijkplayer/compare/v0.8.6...v0.8.7) (2020-07-11)

* upgrade iOS pod dependency, speed up pod install

---
## [0.8.6](https://github.com/befovy/fijkplayer/compare/v0.8.5...v0.8.6) (2020-07-06)

* fix android context null pointer error ([4cdf670](https://github.com/befovy/fijkplayer/commit/4cdf6705a1c49eb075f3b195c4052d2281de6877)), closes [#272](https://github.com/befovy/fijkplayer/issues/272)

---

## [0.8.5](https://github.com/befovy/fijkplayer/compare/v0.8.4...v0.8.5) (2020-07-04)

* fix slider pos after seek and fullscreen toggle ([354b436](https://github.com/befovy/fijkplayer/commit/354b436fe5f3c4e73b93e985822cacfb1633b159)), closes [#261](https://github.com/befovy/fijkplayer/issues/261)
* enable iOS bitcode ([a0f1ad2](https://github.com/befovy/fijkplayer/commit/a0f1ad2e2e10a2bdb39d63bfabe4175793ccebc7))

---
## [0.8.4](https://github.com/befovy/fijkplayer/compare/v0.8.3...v0.8.4) (2020-05-16)

* fix initial volume in iOS device is zero ([fc6a60d](https://github.com/befovy/fijkplayer/commit/fc6a60d68f59730390fa7668933f28e270fc1389))
* fix pos update roll back when seeking ([064f062](https://github.com/befovy/fijkplayer/commit/064f062ab42dfd8c1831507861ff5973fca39ad3))

* add fsFit in demo and docs ([4608acb](https://github.com/befovy/fijkplayer/commit/4608acbc295ce78425cec98d65849140e1a390f6))
* lazy load android native libriries, fixes [#234](https://github.com/befovy/fijkplayer/issues/234) ([3788cfe](https://github.com/befovy/fijkplayer/commit/3788cfec1f33e590d20aff5801633185e529044d))
* fix spell error go package name ([40446af](https://github.com/befovy/fijkplayer/commit/40446afa25aefb0f9bed293ee77784277d2a3cae))

---
## [0.8.3](https://github.com/befovy/fijkplayer/compare/v0.8.2...v0.8.3) (2020-05-10)

* update ijkplayer android 0.7.4, iOS 0.7.3
* fix #226 #225 #212

---
## [0.8.2](https://github.com/befovy/fijkplayer/compare/v0.8.1...v0.8.2) (2020-05-05)

* (desktop) add global init for go-flutter, remove path_provider in demo ([7040f25](https://github.com/befovy/fijkplayer/commit/7040f25c3b4bea0de881a54f79f09cd4502fcd80))
* (android) fix color error upgrade android ijkplayer to 0.7.2 ([ae9590e](https://github.com/befovy/fijkplayer/commit/ae9590ebf7ec30141c27529fb68dd0ef8d4a8d7a))

---
## [0.8.1](https://github.com/befovy/fijkplayer/compare/v0.8.0...v0.8.1) (2020-05-04)

* Uint8List not fount ([54481ef](https://github.com/befovy/fijkplayer/commit/54481efd2167a9ac94036a0b6d7a52ee704d8296))

---

## [0.8.0](https://github.com/befovy/fijkplayer/compare/v0.7.3...v0.8.0) (2020-05-04)

* add takeSnapShot api ([c4e37eb](https://github.com/befovy/fijkplayer/commit/c4e37ebf078938e8d4b2514db87a9969e0291948))
* fix demo github action checks ([588d943](https://github.com/befovy/fijkplayer/commit/588d94355e2be0740ce0e17f912059dd64833c50))

---

## [0.7.3](https://github.com/befovy/fijkplayer/compare/v0.7.2...v0.7.3) (2020-05-01)

* don't require audio session when load plugin ([839ac6a](https://github.com/befovy/fijkplayer/commit/839ac6a74448edd31458fffcd02502f423597fae)), closes [#219](https://github.com/befovy/fijkplayer/issues/219)

---

## [0.7.2](https://github.com/befovy/fijkplayer/compare/v0.7.1...v0.7.2) (2020-04-19)


* iOS orientation changed after enter and then leave background ([d57f514](https://github.com/befovy/fijkplayer/commit/d57f5148c633bef887c8197258fc94da1f7bc2f0)), closes [#209](https://github.com/befovy/fijkplayer/issues/209)

---

## [0.7.1](https://github.com/befovy/fijkplayer/compare/v0.7.0...v0.7.1) (2020-04-11)

* update ijkplayer to 0.6.0

---
## [0.7.0](https://github.com/befovy/fijkplayer/compare/v0.6.3...v0.7.0) (2020-03-22)

* feat: migrate to flutter 1.12 android new API ([ee02c09](https://github.com/befovy/fijkplayer/commit/ee02c0912910403afc46ded9e780cd05456f60cd))
* fix: api changed, build failed using flutter beta version ([0aa1e9f](https://github.com/befovy/fijkplayer/commit/0aa1e9ffbaa18c96c285a49f55890f05343c7e24))

---
## [0.6.3](https://github.com/befovy/fijkplayer/compare/v0.6.1...v0.6.3) (2020-03-21)

* change pod library name, solve name conflict

## [0.6.2](https://github.com/befovy/fijkplayer/compare/v0.6.1...v0.6.2) (2020-03-08)

* fix error int not double  ([#195](https://github.com/befovy/fijkplayer/issues/195)) ([643a3c2](https://github.com/befovy/fijkplayer/commit/643a3c2848a9f6694a367c6db2ba78c527c607a7))

## [0.6.1](https://github.com/befovy/fijkplayer/compare/v0.6.0...v0.6.1) (2020-03-08)

* docs: add fijkPanel2Builder docs

## [0.6.0](https://github.com/befovy/fijkplayer/compare/v0.5.2...v0.6.0) (2020-03-08)

* add fijkview onDispose ([74d17ce](https://github.com/befovy/fijkplayer/commit/74d17cec1203718df5541e441d6c234514eb984a))
* add screen brightness API for Android and iOS ([0879d95](https://github.com/befovy/fijkplayer/commit/0879d95e8ae3dc4ae7213272d54cdc2248571a4f))
* panel2 , vertical drag set brightness and volume ([#184](https://github.com/befovy/fijkplayer/issues/184)) ([7a7219a](https://github.com/befovy/fijkplayer/commit/7a7219a0ebc3b66e29c64ba7c1eafa49437cf986)), closes [#140](https://github.com/befovy/fijkplayer/issues/140) [#159](https://github.com/befovy/fijkplayer/issues/159)
* failed to play url with file scheme. fix [#189](https://github.com/befovy/fijkplayer/issues/189) ([e3567aa](https://github.com/befovy/fijkplayer/commit/e3567aac13bcdf97df32283304fe214749e82ac4))

#### ⚠ BREAKING CHANGES

* FijkPanelWidgetBuilder add new prarmeter, FijkData

---
## [0.5.2](https://github.com/befovy/fijkplayer/compare/v0.5.1...v0.5.2) (2020-02-21)

* fix error log after call setVol. missing break.  fix [#180](https://github.com/befovy/fijkplayer/issues/180) ([cee1741](https://github.com/befovy/fijkplayer/commit/cee174181d590fe36d35f12f31c4747f48e7d710))

---
## [0.5.1](https://github.com/befovy/fijkplayer/compare/v0.5.0...v0.5.1) (2020-02-21)

* upgrade aar to 0.5.1, use consumerProguardFiles fix [#178](https://github.com/befovy/fijkplayer/issues/178) ([f56de4e](https://github.com/befovy/fijkplayer/commit/f56de4e91b8b89af69f0338af2703c7aaa03cafa))
---

---
## [0.5.0](https://github.com/befovy/fijkplayer/compare/v0.4.2...v0.5.0) (2020-01-06)

* show cover after prepared ([#162](https://github.com/befovy/fijkplayer/issues/162)) ([9cacfe9](https://github.com/befovy/fijkplayer/commit/9cacfe90a13e84e205b91cb7f2645abb2f2bf2e4)), closes [#118](https://github.com/befovy/fijkplayer/issues/118)

---
## [0.4.2](https://github.com/befovy/fijkplayer/compare/v0.4.1...v0.4.2) (2020-01-03)

* add FijkSlider and duration support ([#158](https://github.com/befovy/fijkplayer/issues/158)) ([eae19e9](https://github.com/befovy/fijkplayer/commit/eae19e9ad07134106c8e35fa361f9d4e7692874c))

---
## [0.4.1](https://github.com/befovy/fijkplayer/compare/v0.4.0...v0.4.1) (2020-01-01)

* activity null, use context instead ([#155](https://github.com/befovy/fijkplayer/issues/155)) ([7f722e1](https://github.com/befovy/fijkplayer/commit/7f722e1a0bba50f08218539aa1d36b102c1c595c)), closes [#154](https://github.com/befovy/fijkplayer/issues/154)

---
## [0.4.0](https://github.com/befovy/fijkplayer/compare/v0.3.0...v0.4.0) (2019-12-30)

* api and host-option for keep screen on ([#153](https://github.com/befovy/fijkplayer/issues/153)) ([12d1df0](https://github.com/befovy/fijkplayer/commit/12d1df08243d13bbf28f99407a26721ff2daac06))
* remove opaque in FijkValue ([34ecb83](https://github.com/befovy/fijkplayer/commit/34ecb8390cc08ad389afd44ff740af83e5928e21))

---
## [0.3.0](https://github.com/befovy/fijkplayer/compare/v0.2.3...v0.3.0) (2019-12-23)

* fullscreen update, add fs parameter, check width > height when orientation ([#125](https://github.com/befovy/fijkplayer/issues/125)) ([74779fe](https://github.com/befovy/fijkplayer/commit/74779fe0a125643d5ff4a0605f18dcad793c9bed))
* add userdata opaque in FijkValue ([cdd8014](https://github.com/befovy/fijkplayer/commit/cdd8014b2a31d21f4d9f3931dc6c3f041c30592d))
* add fs parameter for FijkView ([e9bddc9](https://github.com/befovy/fijkplayer/commit/e9bddc96cec4ea5448f8e928e954a5a3e74346b7))
* lazy init surface after prepared ([#148](https://github.com/befovy/fijkplayer/issues/148)) ([2889371](https://github.com/befovy/fijkplayer/commit/28893712f9510abc27feaf84ccf5412f2707623e))
* **example:** add ListView demo ([1062282](https://github.com/befovy/fijkplayer/commit/10622822270927c5f21f1b773f0788d693b0ec16)), closes [#117](https://github.com/befovy/fijkplayer/issues/117) ([#124](https://github.com/befovy/fijkplayer/issues/124)) ([4e9e306](https://github.com/befovy/fijkplayer/commit/4e9e3065ea405a9fbb8e4a1267f03af19d5cdaf9))  ([#149](https://github.com/befovy/fijkplayer/issues/149)) ([d6a40ca](https://github.com/befovy/fijkplayer/commit/d6a40ca3961aa83b9a64a258a2b1c4e03ac4fbd9))


* fix java cycle reference [#126](https://github.com/befovy/fijkplayer/issues/126) ([3e1176f](https://github.com/befovy/fijkplayer/commit/3e1176f7d92549a00ee15e8ab602b2c44932838a))
* fix null width and height event ([#147](https://github.com/befovy/fijkplayer/issues/147)) ([3bcae22](https://github.com/befovy/fijkplayer/commit/3bcae22306d959367bfbb60037c909c588f53bff)), closes [#145](https://github.com/befovy/fijkplayer/issues/145)
---


## [0.2.3](https://github.com/befovy/fijkplayer/compare/v0.2.2...v0.2.3) (2019-11-28)
--------------------------------

* asset URL scheme for go-flutter ([#116](https://github.com/befovy/fijkplayer/issues/116)) ([6c72711](https://github.com/befovy/fijkplayer/commit/6c727118b1281c547a74fd25b0dd6931eda721eb))
* new volume panel ([#119](https://github.com/befovy/fijkplayer/issues/119)) ([948ef8b](https://github.com/befovy/fijkplayer/commit/948ef8b6a3913d509dfaab757acc2d22777690fb)), closes [#109](https://github.com/befovy/fijkplayer/issues/109)
* rotate video which has metadata rotation ([#120](https://github.com/befovy/fijkplayer/issues/120)) ([b12699b](https://github.com/befovy/fijkplayer/commit/b12699bc8a6fd2b4cfdb58afbd3b66f220526708)), closes [#81](https://github.com/befovy/fijkplayer/issues/81)

## [0.2.2](https://github.com/befovy/fijkplayer/compare/v0.2.1...v0.2.2) (2019-11-22)
--------------------------------

* add Android audiofocus request and releasse.  closes [#89](https://github.com/befovy/fijkplayer/issues/89)
* add hostOptions for iOS and Android ([#114](https://github.com/befovy/fijkplayer/issues/114)) ([9bb344a](https://github.com/befovy/fijkplayer/commit/9bb344adcdf9069e189bf38eae9ee27ccafec12a)), closes [#113](https://github.com/befovy/fijkplayer/issues/113)
* buffer percent, notify current position from msg queue ([#111](https://github.com/befovy/fijkplayer/issues/111)) ([86357fe](https://github.com/befovy/fijkplayer/commit/86357fef191f72065ad64dc6078c684beca2214d))
* example: enable-accurate-seek option, fix [#113](https://github.com/befovy/fijkplayer/issues/113) ([7b72f77](https://github.com/befovy/fijkplayer/commit/7b72f7751716048c90dd3b2940c8114888f8a1f4))

## [0.2.1](https://github.com/befovy/fijkplayer/compare/v0.2.0...v0.2.1) (2019-11-16)
--------------------------------

* fix: wrong screen orientation after exit full screen mode on Android ([#108](https://github.com/befovy/fijkplayer/issues/108)) ([d0fea2c](https://github.com/befovy/fijkplayer/commit/d0fea2c11117dd4b12bdcd386a4d29cfdce40bf4)), closes [#73](https://github.com/befovy/fijkplayer/issues/73)

## [0.2.0](https://github.com/befovy/fijkplayer/compare/v0.1.10...v0.2.0) (2019-11-15)
--------------------------------

* go-flutter desktop version support ([#107](https://github.com/befovy/fijkplayer/issues/107)) ([966caef](https://github.com/befovy/fijkplayer/commit/966caef0251aecca14aa3d36c822316bb0fb0fe0))
* fix restart timer when touch slider  ([#104](https://github.com/befovy/fijkplayer/issues/104)) ([765e2e6](https://github.com/befovy/fijkplayer/commit/765e2e61fd95d94ae4fed44e2b7e700e6c57920e))


## [0.1.10](https://github.com/befovy/fijkplayer/compare/v0.1.9...v0.1.10) (2019-11-15)
--------------------------------

* new API, FijkVolume.getVol() ([#100](https://github.com/befovy/fijkplayer/issues/100)) ([dd57cea](https://github.com/befovy/fijkplayer/commit/dd57cea4870a909cbbec71a4cc127fdbefe9cf1f))
* set datasource member variable when setDataSource ([20f94de](https://github.com/befovy/fijkplayer/commit/20f94deb0bb561e4fc0127eb615200e26b46f6c1))
* proguard for android class ([1f85f28](https://github.com/befovy/fijkplayer/commit/1f85f28728cb89e48576b9791909860728160751)), closes [#98](https://github.com/befovy/fijkplayer/issues/98)
* update doc error method name. FijkVolume.setUIMode ([#102](https://github.com/befovy/fijkplayer/issues/102)) ([c33cc11](https://github.com/befovy/fijkplayer/commit/c33cc11d5676fb6b411f9b7be7f14850ea662ecc))

## 0.1.9
--------------------------------
- FijkView: fix fullscreen no state, no refresh when state change #77
- panel: fix error CircularProgressIndicator when autoPlay is false #76

## 0.1.8
--------------------------------
- FijkView: add fsFit argument, controls full screen FijkFit mode

## 0.1.7
--------------------------------
- fijkplayer: fix android volume double float cast error
- fijkplayer: fix error pause state after seeking #65

## 0.1.6
--------------------------------
- fijkplayer: update FijkVolume API, break change

## 0.1.5
--------------------------------
- ios: fix NSUrl parse error
- fijkplayer: add FijkLog with levels
- docs: english translation
- fijkplayer: new feature fijkvolume, system volume API
- ijkplayer: set default option `start-on-prepated` to 0
- iOS: fix CocoaPods use_frameworks! error

## 0.1.3
--------------------------------
- ffmpeg: enable concat and crypto protocol
- fijkplayer: add static method all() to get all fijkplayer instance
- fix: issue #31, pixelbuffer crash on iOS

## 0.1.2
--------------------------------
- fijkvalue: add video / audio render started
- fijkplayer: remove setIntOption API, use setOption instead

## 0.1.1
--------------------------------
- fix fijkpanel slider value out of range
- android: add androidx support

## 0.1.0
- update ijkplauer to f0.3.5
- fijkplayer err state and FijkException
- support playing flutter asset file
- unit test and widget test
- pass fijkoption arguments and set player's option

## 0.0.9
--------------------------------
- update ijkplayer to f0.3.4
- add RTSP support
- decrease libary binary size

## 0.0.8
--------------------------------
- update ijkplayer to f0.3.3
- fix reset bug, #26
- Add doc website, https://fijkplayer.befovy.com
- Add diagram about FijkState, update FijkState document

## 0.0.7
--------------------------------
- Update FijkView widget tree, add FijkFit (scaling mode)
- fix pixelbuffer leak on iOS

## 0.0.6
--------------------------------
- FijkSourceType as a option argument

## 0.0.5
--------------------------------
- add FijkPanel (UI controller of video)

## 0.0.3
--------------------------------
- add more comment and update README

## 0.0.2
--------------------------------
- make iOS CocoaPods `FIJKPlayer` available

## 0.0.1
--------------------------------
- A usable music player plugin
- Draw the video frame through surface for android
## 1.0.4+purelive.1

* Defer Android SurfaceTexture creation until a real player requests it. This
  fixes an intermittent Flutter engine cold-start abort during plugin attach.
