## 1.2.0-beta.3

- Updated flutter_inappwebview_platform_interface version to ^1.4.0-beta.3
- Implemented `saveState`, `restoreState` InAppWebViewController methods
- Implemented `onShowFileChooser` WebView event
- Merged "Android: implemented PlatformPrintJobController.onComplete" [#2216](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2216) (thanks to [Doflatango](https://github.com/Doflatango))
- Fixed "When useShouldInterceptAjaxRequest is true, some ajax requests doesn't work" [#2197](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2197)

## 1.2.0-beta.2

- Updated flutter_inappwebview_platform_interface version to ^1.4.0-beta.2
- Implemented `hideInputMethod`, `showInputMethod` InAppWebViewController methods
- Implemented `isUserInteractionEnabled`, `alpha` properties of `InAppWebViewSettings`
- Merged "Show / Hide / Disable / Enable soft Keyboard Input (Android & iOS)" [#2408](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2408) (thanks to [Mecharyry](https://github.com/Mecharyry))
- Fixed "[Android] PrintJobOrientation _TypeError (type 'Null' is not a subtype of type 'int')" [#2413](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2413)
- Fixed "Accessibility Android" [#1694](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1694)
- Fixed "Automatic font scale according to accessibility option 'font size' of device does not work on Android" [#540](https://github.com/pichillilorenzo/flutter_inappwebview/issues/540)
- Fixed "callHandler method is not injected into InAppBrowser" [#1973](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1973)

## 1.2.0-beta.1

- Updated flutter_inappwebview_platform_interface version to ^1.4.0-beta.1
- Added `InAppWebViewController.enableSlowWholeDocumentDraw` static method
- Added `CookieManager.flush` method
- Added support for `UserScript.forMainFrameOnly` parameter
- Implemented `requestFocus` WebView method
- Updated UserScript at document end implementation
- Updated `InAppWebViewController.takeScreenshot` implementation to support screenshot out of visible viewport when `InAppWebViewController.enableSlowWholeDocumentDraw` is called
- Fixed "After dispose a InAppWebViewKeepAlive using InAppWebViewController.disposeKeepAlive. NullPointerException is thrown when main activity enter destroyed state." [#2025](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2025)
- Fixed crash when trying to open InAppBrowser with R.menu.menu_main on release mode
- Fixed "android.webkit.WebSettingsWrapper cannot be cast to com.android.webview.chromium.ContentSettingsAdapter" [#2397](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2397)
- Merged "Prevent blank InAppBrowser Activity from being restored" [#1984](https://github.com/pichillilorenzo/flutter_inappwebview/pull/1984) (thanks to [ShuheiSuzuki-07](https://github.com/ShuheiSuzuki-07))
- Merged "Update Android Cookie Expiration date format to 24-hour format (HH)" [#2389](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2389) (thanks to [takuyaaaaaaahaaaaaa](https://github.com/takuyaaaaaaahaaaaaa))
- Merged "[Android] allow sync navigation requests using a regular expression" [#2008](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2008) (thanks to [lyb5834](https://github.com/lyb5834))

## 1.1.3

- Updated flutter_inappwebview_platform_interface version to ^1.3.0

## 1.1.2

- Removed webview/plugin_scripts_js/ConsoleLogJS.java file, use native WebChromeClient.onConsoleMessage instead

## 1.1.1

- Updated flutter_inappwebview_platform_interface version to ^1.2.0

## 1.1.0+4

- Updated flutter_inappwebview_platform_interface version

## 1.1.0+3

- Fixed compilation error

## 1.1.0+2

- Updated pubspec.yaml

## 1.1.0+1

- Downgraded androidx.appcompat:appcompat:1.7.0 to androidx.appcompat:appcompat:1.6.1
- Added `-dontwarn android.window.BackEvent` proguard rule

## 1.1.0

- Updated androidx.webkit:webkit:1.8.0 to androidx.webkit:webkit:1.12.0
- Updated androidx.browser:browser:1.6.0 to androidx.browser:browser:1.8.0
- Updates minimum supported SDK version to Flutter 3.24/Dart 3.5.
- Removed unsupported WebViewFeature.SUPPRESS_ERROR_PAGE
- Merged "Remove references to deprecated v1 Android embedding" [#2176](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2176) (thanks to [gmackall](https://github.com/gmackall))

## 1.0.13

- Fixed "Android emulator using API 34 fails to draw on resume sometimes" [#1981](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1981)

## 1.0.12

- Updated `flutter_inappwebview_platform_interface` version dependency to `^1.0.10`

## 1.0.11

- Updated `flutter_inappwebview_platform_interface` version dependency to `^1.0.9`
- Fix typos (thanks to [michalsrutek](https://github.com/michalsrutek))

## 1.0.10

- Updated `flutter_inappwebview_platform_interface` version dependency to `^1.0.8`
- Implemented `PlatformCustomPathHandler` class

## 1.0.9

- Updated `flutter_inappwebview_platform_interface` version dependency to `^1.0.7`
- Fixed "Cloudflare Turnstile failure" [#1738](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1738)
- Fixed `InAppWebViewController.callAsyncJavaScript` issue when the last line of the `functionBody` parameter includes a code comment

## 1.0.8

- Implemented `InAppWebViewSettings.interceptOnlyAsyncAjaxRequests`
- Implemented `PlatformInAppWebViewController.clearFormData` method
- Implemented `PlatformCookieManager.removeSessionCookies` method
- Updated `useShouldInterceptAjaxRequest` automatic infer logic
- Updated `CookieManager` methods return value

## 1.0.7

- Merged "Fixed error in InterceptAjaxRequestJS 'Failed to set responseType property'" [#1904](https://github.com/pichillilorenzo/flutter_inappwebview/pull/1904) (thanks to [EArminjon](https://github.com/EArminjon))
- Fixed shouldInterceptAjaxRequest javascript code when overriding XMLHttpRequest.open method parameters

## 1.0.6

- Fixed "getFavicons: _TypeError: type '_Map<String, dynamic>' is not a subtype of type 'Iterable<dynamic>'" [#1897](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1897)
- Fixed "onClosed not considering back navigation or up button / close button in ChromeSafariBrowser when using noHistory: true" [#1882](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1882)

## 1.0.5

- Call `super.dispose();` on `InAppBrowser` and `ChromeSafari` implementations 

## 1.0.4

- Throw platform exception when ProcessGlobalConfig.apply throws an error on the native side to be able to catch it on Flutter side

## 1.0.3

- Updated `ContentBlockerHandler` CSS_DISPLAY_NONE action type and `JavaScriptBridgeJS.JAVASCRIPT_BRIDGE_JS_SOURCE` javascript implementation code

## 1.0.2

- Updated `flutter_inappwebview_platform_interface` version dependency to `1.0.2` 
- Fixed "Crash when starting ChromeSafariBrowser on Android java.lang.NoSuchMethodError: No virtual method isEngagementSignalsApiAvailable" [#1881](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1881)

## 1.0.1

- Updated README

## 1.0.0

Initial release.
