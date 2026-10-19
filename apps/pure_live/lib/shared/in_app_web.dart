import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The in-app browser (the reference's `InAppWeb`, backed by
/// webview_flutter). Web search runs its platform's search page inside the
/// app where a WebView exists; everywhere else the caller falls back to
/// the system browser.
///
/// webview_flutter ships Android, iOS and macOS only — Windows and Linux
/// have no plugin, so there they take the reference's own
/// no-WebView branch: the search opens in the system browser and the page
/// explains how to come back with a room link. (The reference's
/// flutter_inappwebview could also run on Windows behind the WebView2
/// runtime; that path is not available to this build, and the desktop
/// User-Agent override and navigation interception it provided have no
/// webview_flutter equivalent — room links are therefore recognised from
/// the address a page STOPPED at, not from every navigation attempt.)
abstract final class InAppWeb {
  /// Whether pages can open web content in the app; the app sets it at
  /// boot from [detect]; false in tests.
  static bool available = false;

  /// Whether this device has a usable WebView.
  static Future<bool> detect() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } on Object {
      return false;
    }
  }
}

/// Whether [uri] may be loaded inside the app: web pages only (3.x refused
/// app schemes, files and JavaScript URLs).
bool isWebPage(Uri? uri) => uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

/// A web page in the app: only an http(s) initial address, a progress line
/// while loading, the failure in words through [failureBuilder], and the
/// back request going back in the page first (see `InAppWebPageState`).
final class InAppWebPage extends StatefulWidget {
  /// Creates the view of [initial].
  const new({
    required this.initial,
    this.onPage,
    this.failureBuilder,
    this.progressHeight = 2,
    this.progressKey,
    super.key,
  });

  /// The first address; non-web schemes are refused with the failure
  /// builder (or a bare error box) instead of being loaded.
  final Uri initial;

  /// Called with the address each finished page sits at.
  final void Function(Uri uri)? onPage;

  /// Draws the load failure with a retry.
  final Widget Function(BuildContext context, VoidCallback retry)? failureBuilder;

  /// The progress line's thickness.
  final double progressHeight;

  /// A key for the progress line, for tests that watch the load.
  final Key? progressKey;

  @override
  State<InAppWebPage> createState() => InAppWebPageState();
}

/// The page's state, public so a host page can drive [navigateBack].
final class InAppWebPageState extends State<InAppWebPage> {
  WebViewController? _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (isWebPage(widget.initial)) {
      final controller = WebViewController();
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      unawaited(
        controller.setNavigationDelegate(
          NavigationDelegate(
            onProgress: (value) => setState(() => _progress = value),
            onPageFinished: (url) => unawaited(_reportStop(url)),
            onWebResourceError: (error) {
              // Only a main-frame failure replaces the page; a broken
              // image inside it must not.
              if (error.isForMainFrame ?? true) {
                setState(() {
                  _failed = true;
                  _progress = 0;
                });
              }
            },
          ),
        ),
      );
      unawaited(controller.loadRequest(widget.initial));
      _controller = controller;
    } else {
      _failed = true;
    }
  }

  Future<void> _reportStop(String url) async {
    final uri = Uri.tryParse(url);
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = 100;
      _failed = false;
    });
    if (uri != null && isWebPage(uri)) {
      widget.onPage?.call(uri);
    }
  }

  void _retry() {
    final controller = _controller;
    if (controller == null) {
      // A refused address never became a controller; loading it still
      // cannot work.
      return;
    }
    setState(() => _failed = false);
    unawaited(controller.reload());
  }

  /// Whether the WebView can step back in its own history.
  Future<bool> navigateBack() async {
    final controller = _controller;
    if (_failed || controller == null) {
      return false;
    }
    if (await controller.canGoBack()) {
      await controller.goBack();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_progress > 0 && _progress < 100 && !_failed)
          SizedBox(
            height: widget.progressHeight,
            width: double.infinity,
            child: LinearProgressIndicator(
              key: widget.progressKey,
              value: _progress / 100,
              minHeight: widget.progressHeight,
            ),
          ),
        Expanded(
          child: _failed
              ? widget.failureBuilder?.call(context, _retry) ?? const Center(child: Text('加载失败'))
              : WebViewWidget(key: const ValueKey('in-app-web-view'), controller: _controller!),
        ),
      ],
    );
  }
}
