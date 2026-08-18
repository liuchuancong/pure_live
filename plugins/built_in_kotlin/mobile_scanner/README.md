# mobile_scanner

[![Pub Version](https://img.shields.io/pub/v/mobile_scanner.svg)](https://pub.dev/packages/mobile_scanner)
[![Pub Version Prerelease](https://img.shields.io/pub/v/mobile_scanner.svg?include_prereleases)](https://pub.dev/packages/mobile_scanner)
[![Build Status](https://github.com/juliansteenbakker/mobile_scanner/actions/workflows/code-coverage.yml/badge.svg)](https://github.com/juliansteenbakker/mobile_scanner/actions/workflows/code-coverage.yml)
[![Style: Very Good Analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Codecov](https://codecov.io/gh/juliansteenbakker/mobile_scanner/graph/badge.svg?token=RGE4XVOGJ5)](https://codecov.io/gh/juliansteenbakker/mobile_scanner)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/juliansteenbakker)](https://github.com/sponsors/juliansteenbakker)

A fast and lightweight Flutter plugin for scanning barcodes and QR codes using the device’s camera. It supports multiple barcode formats, real-time detection, and customization options for an optimized scanning experience on multiple platforms.

## Features

- Fast barcode and QR code scanning
- Supports multiple barcode formats
- Real-time detection
- Customizable camera and scanner behavior

See the [examples](example/README.md) for runnable examples of various usages, such as the basic usage, applying a scan window, or retrieving images from the barcodes.

## Platform Support

| Android | iOS | macOS | Web | Linux | Windows |
|---------|-----|-------|-----|-------|---------|
| ✔       | ✔   | ✔     | ✔   | :x:   | :x:     |

### Features Supported

See the example app for detailed implementation information.

| Features     | Android            | iOS                | macOS              | Web |
|--------------|--------------------|--------------------|--------------------|-----|
| analyzeImage | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x: |
| returnImage  | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x: |
| scanWindow   | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x: |
| autoZoom     | :heavy_check_mark: | :x:                | :x:                | :x: |
| lensType     | :heavy_check_mark: | :heavy_check_mark: | :x:                | :x: |
| getSupportedLenses(facing:) | :heavy_check_mark: | :heavy_check_mark: | :x: | :x: |
| getBestCloseRangeScanningLens | :heavy_check_mark: (always normal) | :heavy_check_mark: (requires iOS 15, falls back to normal) | :x: (always normal) | :x: (always normal) |

### Querying supported lens types with facing filter

Use `getSupportedLenses()` to query which lens types the device has. Pass an optional `facing` parameter to restrict results to cameras on one side:

```dart
// All cameras (back + front)
final Set<CameraLensType> allLenses = await controller.getSupportedLenses();

// Back cameras only
final Set<CameraLensType> backLenses = await controller.getSupportedLenses(
  facing: CameraFacing.back,
);

if (backLenses.contains(CameraLensType.zoom)) {
  // Device has a telephoto back camera
}
```

Without a facing filter, results may include lenses from both the front and back cameras, which can cause incorrect lens-type detection when switching cameras.

The `facing` filter is supported on Android and iOS. On macOS and the web, the filter is ignored and all lenses are returned.

### Automatic best-lens selection for close-range scanning

Use `getBestCloseRangeScanningLens()` to determine which lens can focus closest to the phone, and is therefore best suited for scanning barcodes held at close range. It returns `null` if the device has no camera for the given facing direction. Combine it with `getSupportedLenses` before switching, since the returned lens type is not guaranteed to be available:

```dart
final bestLens = await controller.getBestCloseRangeScanningLens(facing: CameraFacing.back);
final supported = await controller.getSupportedLenses(facing: CameraFacing.back);

if (bestLens != null && supported.contains(bestLens)) {
  await controller.switchCamera(
    SelectCamera(facingDirection: CameraFacing.back, lensType: bestLens),
  );
}
```

This returns:
- **iOS 15+**: The camera with the shortest `AVCaptureDevice.minimumFocusDistance` — typically the ultra-wide lens on newer iPhones (macro autofocus at ~2cm), or the standard 1x camera on older models
- **iOS < 15 / macOS**: `CameraLensType.normal`, since `minimumFocusDistance` is not available
- **Android**: `CameraLensType.normal` when the device has a camera. `LENS_INFO_MINIMUM_FOCUS_DISTANCE` is only meaningful on physical sub-cameras, which — like the rest of `getSupportedLenses` — are not independently selectable through CameraX, so the main camera (which has the most capable autofocus on virtually all Android devices) is returned unconditionally
- **Web**: `CameraLensType.normal` when the device has a camera. The MediaDevices API has no concept of lens type, and its `focusDistance` capability, where available at all, is limited to Chrome on Android
- **All platforms**: `null` if there is no camera for the requested facing direction

## Installation

Add the dependency in your `pubspec.yaml` file:

```
dependencies:
  mobile_scanner: ^<latest_version>
```

Then run:

`flutter pub get`

## Configuration

### Android
This package uses by default the **bundled version** of MLKit Barcode-scanning for Android. This version is immediately available to the device. But it will increase the size of the app by approximately 3 to 10 MB.

The alternative is to use the **unbundled version** of MLKit Barcode-scanning for Android. This version is downloaded on first use via Google Play Services. It increases the app size by around 600KB.

[You can read more about the difference between the two versions here.](https://developers.google.com/ml-kit/vision/barcode-scanning/android)

To use the **unbundled version** of the MLKit Barcode-scanning, add the following line to your `/android/gradle.properties` file:
```
dev.steenbakker.mobile_scanner.useUnbundled=true
```

### iOS


Since the scanner needs to use the camera, add the following keys to your Info.plist file. (located in <project root>/ios/Runner/Info.plist)

NSCameraUsageDescription - describe why your app needs access to the camera. This is called Privacy - Camera Usage Description in the visual editor.

If you want to use the local gallery feature from [image_picker](https://pub.dev/packages/image_picker), you also need to add the following key.

NSPhotoLibraryUsageDescription - describe why your app needs permission for the photo library. This is called Privacy - Photo Library Usage Description in the visual editor.

Example,
```
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photos access to get QR code from photo library</string>
```


### macOS
Ensure that you granted camera permission in XCode -> Signing & Capabilities:

<img width="696" alt="Screenshot of XCode where Camera is checked" src="https://user-images.githubusercontent.com/24459435/193464115-d76f81d0-6355-4cb2-8bee-538e413a3ad0.png">

### Web

As of version 5.0.0 adding the barcode scanning library script to the `index.html` is no longer required,
as the script is automatically loaded on first use.

#### Detection backends

The web implementation supports three barcode detection backends. The active backend is selected
via `MobileScannerPlatform.instance.setWebBarcodeReader(reader)` before starting the scanner.

##### Auto (default)

Uses the native `BarcodeDetector` API when the browser supports it, and falls back to
`zxing-wasm` otherwise. This is the recommended setting for most apps.

##### Native BarcodeDetector

Uses the [W3C Shape Detection API](https://developer.mozilla.org/en-US/docs/Web/API/BarcodeDetector),
which is built into the browser. No external library is loaded. This is the fastest option because
detection runs natively without any JavaScript or WebAssembly overhead.

Available in Chrome 83+, Edge 83+, and Safari 17+. Not supported in Firefox.

##### zxing-wasm

Uses [zxing-wasm](https://github.com/Sec-ant/zxing-wasm), a WebAssembly port of the ZXing C++
library. The WASM binary (~2 MB) is loaded from the jsDelivr CDN on first use. Offers good
performance and works in all modern browsers, including Firefox.

##### ZXing-js (legacy)

Uses the [ZXing JavaScript library](https://github.com/zxing-js/library), a pure-JavaScript port
of ZXing. Loaded from the unpkg CDN. This backend is slower than the WASM alternative and is
provided for backward compatibility and comparison purposes only.

#### Backend comparison

| Feature                  | Native BarcodeDetector     | zxing-wasm                 | ZXing-js (legacy)          |
|--------------------------|----------------------------|----------------------------|----------------------------|
| **Performance**          | Fastest (native)           | Fast (WASM)                | Slow (pure JS)             |
| **Firefox**              | :x:                        | :heavy_check_mark:         | :heavy_check_mark:         |
| **Chrome / Edge**        | :heavy_check_mark:         | :heavy_check_mark:         | :heavy_check_mark:         |
| **Safari**               | 17+                        | :heavy_check_mark:         | :heavy_check_mark:         |
| **External dependency**  | None                       | ~2 MB WASM (CDN)           | ~600 KB JS (CDN)           |
| **Supported formats**    | Browser-dependent          | Most 1D and 2D formats     | Most 1D and 2D formats     |

#### Barcode format support per backend

| `BarcodeFormat`      | Native BarcodeDetector ¹ | zxing-wasm         | ZXing-js (legacy)  |
|----------------------|--------------------------|--------------------|--------------------|
| `aztec`              | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: ³ |
| `codabar`            | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `code39`             | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `code93`             | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `code128`            | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `dataMatrix`         | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `ean8`               | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `ean13`              | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `itf` ²              | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `pdf417`             | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: ³ |
| `qrCode`             | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `upcA`               | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `upcE`               | :heavy_check_mark:       | :heavy_check_mark: | :heavy_check_mark: |
| `maxiCode`           | :x:                      | :heavy_check_mark: | :heavy_check_mark: |
| `microQrCode`        | :x:                      | :heavy_check_mark: | :heavy_check_mark: |
| `dataBar` ⁴          | :x:                      | :heavy_check_mark: | :heavy_check_mark: |
| `dataBarExpanded` ⁴  | :x:                      | :heavy_check_mark: | :heavy_check_mark: |
| `dataBarLimited` ⁴   | :x:                      | :heavy_check_mark: | :x:                |

¹ The BarcodeDetector API defines all formats listed, but the formats that are actually
detected vary per browser and operating system. Use
[`BarcodeDetector.getSupportedFormats()`](https://developer.mozilla.org/en-US/docs/Web/API/BarcodeDetector/getSupportedFormats_static)
to query the current browser. In `WebBarcodeReader.auto` mode, mobile_scanner falls back to
zxing-wasm when the browser reports no supported formats at all.

² The `itf2of5` and `itf2of5WithChecksum` variants are decoded as plain ITF on all web
backends; no length or checksum validation is applied. The `itf14` variant is supported as a
distinct format by zxing-wasm, and decoded as plain ITF by the other backends.

³ The upstream [zxing-js library](https://github.com/zxing-js/library#supported-formats) marks
Aztec as "needs testing" and PDF417 as "not production ready".

⁴ GS1 DataBar (RSS-14) is also supported on iOS 15+ and macOS 12+ via Apple Vision.

zxing-wasm supports additional formats (such as rMQR Code), but only the formats listed above
are exposed through `BarcodeFormat`.

#### Providing a mirror for the barcode scanning library

If a different mirror is needed to load the barcode scanning library,
the source URL can be set beforehand.

```dart
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

final String scriptUrl = // ...

if (kIsWeb) {
  MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(scriptUrl);
}
```

## Usage

### Simple

Import the package with `package:mobile_scanner/mobile_scanner.dart`. The only required parameter is `onDetect`, which returns the scanned barcode or qr code.

```dart
MobileScanner(
  onDetect: (result) {
    print(result.barcodes.first.rawValue);
  },
),
```

### Advanced

If you want more control over the scanner, you need to create a new `MobileScannerController` controller. The controller contains multiple parameters to adjust the scanner.
```dart
final MobileScannerController controller = MobileScannerController(
  cameraResolution: size,
  detectionSpeed: detectionSpeed,
  detectionTimeoutMs: detectionTimeout,
  formats: selectedFormats,
  returnImage: returnImage,
  torchEnabled: true,
  invertImage: invertImage,
  autoZoom: autoZoom,
);
```

```dart
MobileScanner(
  controller: controller,
  onDetect: (result) {
    print(result.barcodes.first.rawValue);
  },
);
```

#### Switching lens types

On devices with multiple cameras (normal, wide, zoom), you can switch between lens types:

```dart
// Toggle through available lens types (normal -> wide -> zoom -> normal)
await controller.switchCamera(const ToggleLensType());

// Or select a specific lens type
await controller.switchCamera(
  const SelectCamera(lensType: CameraLensType.wide),
);

// Get supported lens types for the current camera
final Set<CameraLensType> supportedLenses = await controller.getSupportedLenses();
```

#### Lifecycle changes

If you want to pause the scanner when the app is inactive, you need to use `WidgetsBindingObserver`.

First, provide a `StreamSubscription` for the barcode events. Also, make sure to create a `MobileScannerController` with `autoStart` set to false, since we will be handling the lifecycle ourself.

```dart
final MobileScannerController controller = MobileScannerController(
  autoStart: false,
);

StreamSubscription<Object?>? _subscription;
```

Then, ensure that your `State` class mixes in `WidgetsBindingObserver`, to handle lifecyle changes, and add the required logic to the `didChangeAppLifecycleState` function:

```dart
class MyState extends State<MyStatefulWidget> with WidgetsBindingObserver {
  // ...

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the controller is not ready, do not try to start or stop it.
    // Permission dialogs can trigger lifecycle changes before the controller is ready.
    if (!controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        // Restart the scanner when the app is resumed.
        // Don't forget to resume listening to the barcode events.
        _subscription = controller.barcodes.listen(_handleBarcode);

        unawaited(controller.start());
      case AppLifecycleState.inactive:
        // Stop the scanner when the app is paused.
        // Also stop the barcode events subscription.
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
    }
  }

  // ...
}
```

Then, start the scanner in `void initState()`:

```dart
@override
void initState() {
  super.initState();
  // Start listening to lifecycle changes.
  WidgetsBinding.instance.addObserver(this);

  // Start listening to the barcode events.
  _subscription = controller.barcodes.listen(_handleBarcode);

  // Finally, start the scanner itself.
  unawaited(controller.start());
}
```

Finally, dispose of the the `MobileScannerController` when you are done with it.

```dart
@override
Future<void> dispose() async {
  // Stop listening to lifecycle changes.
  WidgetsBinding.instance.removeObserver(this);
  // Stop listening to the barcode events.
  unawaited(_subscription?.cancel());
  _subscription = null;
  // Dispose the widget itself.
  super.dispose();
  // Finally, dispose of the controller.
  await controller.dispose();
}
```

## Known Limitations

### `rawBytes` on iOS and macOS

Apple's Vision framework does not provide a direct API for reading the raw payload bytes of a scanned barcode. The `rawBytes` field is populated on a best-effort basis using two strategies, each with constraints.

#### QR codes

Two strategies are used in combination. For Byte-mode segments the error-corrected bit stream from `CIQRCodeDescriptor` is parsed directly. For all other modes the decoded string from `payloadStringValue` is re-encoded to Latin-1 as a fallback.

| Scenario                                        | `rawBytes` result                                              |
|-------------------------------------------------|----------------------------------------------------------------|
| Byte mode (UTF-8, arbitrary binary data)        | Correct — parsed directly from bit stream                      |
| Numeric mode (digits only)                      | Correct — recovered via string fallback                        |
| Alphanumeric mode (uppercase + allowed symbols) | Correct — recovered via string fallback                        |
| Kanji mode                                      | `null` — Japanese characters cannot round-trip through Latin-1 |

#### Aztec, DataMatrix, PDF417 and linear formats (Code 128, EAN, etc.)

Apple Vision decodes the payload as a string internally using a Latin-1 (ISO-8859-1) interpretation of the raw bytes. `rawBytes` is recovered by re-encoding that string back to Latin-1.

| Byte value range                                            | `rawBytes` result                                                                                            |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `0x00`–`0x7F` (ASCII)                                       | Correct                                                                                                      |
| `0xA0`–`0xFF` (upper Latin-1, includes `ø`, `é`, `ü`, etc.) | Correct                                                                                                      |
| `0x80`–`0x9F` (Windows-1252 special range)                  | `null` — Apple maps these to Unicode code points above U+00FF, which cannot be round-tripped through Latin-1 |

This means arbitrary binary payloads that happen to contain bytes in the `0x80`–`0x9F` range will result in `rawBytes` being `null` for those formats.

#### Android and Web

On Android, `rawBytes` is fully supported for all formats and encoding modes via MLKit.

On Web, support depends on the active detection backend:

| Backend                | `rawBytes` support                                      |
|------------------------|---------------------------------------------------------|
| Native BarcodeDetector | :x: Not available (browser API returns decoded text only) |
| zxing-wasm             | :heavy_check_mark: Fully supported                      |
| ZXing-js (legacy)      | :heavy_check_mark: Fully supported                      |
