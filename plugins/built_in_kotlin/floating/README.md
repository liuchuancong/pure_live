# floating

[![codecov](https://codecov.io/gh/wrbl606/floating/graph/badge.svg?token=C41QR8ZOEP)](https://codecov.io/gh/wrbl606/floating)

Picture in Picture management for Flutter. **Android only**

<image src="https://wrbl.xyz/floating-example.gif" alt="Picture in picture demo" width="40%">

## App configuration

Add `android:supportsPictureInPicture="true"` line to the `<activity>` tag in `android/src/main/AndroidManifest.xml`:

```xml
<manifest>
   <application>
        <activity
            android:name=".MainActivity"
            android:supportsPictureInPicture="true"
            ...
```

## Widget

This package provides a helper `PiPSwitcher` widget for switching the displayed widgets according to current PiP status. Use it like so:

```dart
PiPSwitcher(
    childWhenDisabled: Scaffold(...),
    childWhenEnabled: JustVideo(), 
)
```

## API

PiP mode in desired mode is available only in Android
so iOS and web support is not planned until
the platforms adds native support for such feature.

### Create a Floating instance

```dart
final floating = Floating();
```

### Check if PiP is available

```dart
final canUsePiP = await floating.isPipAvailable;
```

> PiP may be unavailable because of system settings managed
> by admin or device manufacturer. Also, the device may
> have Android version that was released without this feature.

### Check if app is in PiP mode

```dart
final currentStatus = await floating.pipStatus;
```

Possible statuses:

| Status | Description | Will `enable()` have an effect? |
| ------ | ----------- | ------------------------------ |
| disabled | PiP is available to use but currently disabled. | Yes |
| enabled | PiP is enabled. The app can display content but will not receive user inputs until the user decides to bring the app to it's full size. | No |
| automatic | PiP will be enabled automatically by the OS. | Yes |
| unavailable | PiP is disabled on given device. | No |

### Enable PiP mode

Enable PiP right away:

```dart
final statusAfterEnabling = await floating.enable(ImmediatePiP());
```

Enable PiP when the app gets minimized via system gesture:

```dart
final statusAfterEnabling = await floating.enable(OnLeavePiP());
```

To later cancel, use `.cancelOnLeavePiP()`.

When enabled, PiP mode can be toggled off by the user via system UI.

#### Arguments

##### `aspectRatio:`

The default 16/9 aspect ratio can be overridden with custom `Rational`.
Eg. to make PiP square use: `.enable(aspectRatio: Rational(1, 1))` or `.enable(aspectRatio: Rational.square())`.

##### `sourceRectHint:`

By default, system will simply use fade animation to tween between full app and PiP.
Switching animation can be smoother by using source rect hint ([example animation](https://developer.android.com/static/images/pip.mp4)).

Check [the example project](https://github.com/wrbl606/floating/blob/main/example/lib/main.dart) to see an example of usage.
