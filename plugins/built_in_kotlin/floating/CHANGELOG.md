## 6.0.0

* Fix builds on Flutter 3.29+
 
Thanks [@deckerst](https://github.com/deckerst)!

## 5.0.1

* Avoid excessive `hasSystemFeature` calls
 
Thanks [@yoer](https://github.com/yoer)!

## 5.0.0

* *BREAKING* Switch to declarative Gradle plugin setup
* Add switching animation to `PiPSwitcher`
* Follow rules from `flutter_lints: ^5.0.0`

## 4.0.1

* Fix for SDK versions not supporting auto-enabled PiP

## 4.0.0

* *BREAKING* `EnableManual` is now `ImmediatePiP`
* *BREAKING* `AutoEnable` is now `OnLeavePiP`
* *BREAKING* `.dispose()` is no longer available, as the `Floating()` constructor returns a singleton now
* Cancel `OnLeavePiP` instructions via `cancelOnLeavePiP` method

## 3.0.0

* *BREAKING* `.enable()` is now `enable(EnableManual())`
* Enter automatic PiP mode on app minimize via `enable(AutoEnable())`
* *BREAKING* `pipStatus$` is now `pipStatusStream`

## 2.0.2

* Update topics
* Update screenshots
* Switch to lints_core

## 2.0.1

* AGP 8 compatibility
* JVM target set to 1.8
* Move from jcenter to mavenCentral

Thanks [@deckerst](https://github.com/deckerst)!

## 2.0.0

* Add `sourceRectHint` [support](https://developer.android.com/reference/android/app/PictureInPictureParams.Builder#setSourceRectHint(android.graphics.Rect)).

**Breaking**:

* `.enable(Rational.landscape())` is now `.enable(aspectRatio: Rational.landscape())`

## 1.1.3

* Drop Kotlin to 1.7.10
* Bump Gradle to 7.2.0
* Bump Gradle distributionUrl to 7.5

## 1.1.2

* Bump Kotlin to 1.8.0

## 1.1.1+1

* Fix showcase GIF link

## 1.1.1

* Fix `java.lang.RuntimeException` caused by an uninitialized `Timer`

## 1.1.0

* Add custom aspect ratio support

## 1.0.0

* BREAKING: Floating class does not have static members anymore. It should be instantiated before use and dispose afterwards with `dispose()`.
* BREAKING: Name changes:
  * from `isInPipMode` to `pipStatus`. It also returns one of `PiPStatus` enum values rather than a `bool`.
  * from `enablePip()` to `enable()`. It also returns one of `PiPStatus` enum values rather than a `bool`.
* Added a `pipStatus$` stream that notifies listeners about changes in the current PiP status.
* Added a `PiPSwitcher` widget that renders proper widgets for current PiP status.

## 0.1.1

* Updated docs

## 0.1.0

* Null-safety migration
* Added tests
* Added docs

## 0.0.1

* Checking if device supports PiP mode
* Checking current PiP status
* Enabling PiP
