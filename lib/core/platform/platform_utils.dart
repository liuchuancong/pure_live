import 'dart:io' show Platform;
import 'package:flutter/material.dart';

class PlatformUtils {
  PlatformUtils._();
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool get isDesktopNotMac => (Platform.isWindows || Platform.isLinux) && !Platform.isMacOS;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool isMobileWidth(BuildContext context) {
    return MediaQuery.of(context).size.width < 760;
  }

  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;

  static T select<T>({required T desktop, required T mobile}) {
    return isDesktop ? desktop : mobile;
  }
}
