/// In-app tour of `live_uikit_background`, mounted under the same
/// [LiveTheme] the rest of the app uses so the demo follows the active
/// design language.
///
/// Every visual here is a caller-supplied field on a `BackgroundConfig`
/// variant: switching "wallpaper", "paused", "underlay", "fallback",
/// "letterbox fill", "overlay" or the sigma sliders only rewrites the
/// config; nothing in the plugin package decides what to paint when a
/// field is missing. That absence is the point.
library;

import 'dart:convert' show base64Decode;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
// `live_uikit` also ships a `LiveBackground` widget; the demo uses the
// plugin-package one, so hide the core's variant here.
import 'package:live_uikit/styling.dart' hide LiveBackground;
import 'package:live_uikit_background/live_uikit_background.dart';

/// A scrollable gallery with a live control panel; open from the home
/// page's "Pages" section.
class BackgroundDemoPage extends StatefulWidget {
  /// The gallery page.
  const new({super.key});

  @override
  State<BackgroundDemoPage> createState() => _BackgroundDemoPageState();
}

class _BackgroundDemoPageState extends State<BackgroundDemoPage> {
  static const List<Color> _palette = [Color(0xFF12203A), Color(0xFF061220)];
  static const Color _placeholder = Color(0xFF0F1522);
  static const Color _fallbackColor = Color(0xFF302A4F);

  bool _hasBackground = true;
  bool _paused = false;
  bool _underlay = true;
  bool _useFallback = true;
  bool _letterbox = true;
  bool _overlay = true;
  double _overlayOpacity = 0.35;
  double _blurSigma = 0;
  double _letterboxSigma = 24;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      appBar: AppBar(
        title: const Text('Background demo'),
        backgroundColor: theme.colors.bgContainer,
        foregroundColor: theme.colors.text,
      ),
      body: ListView(
        padding: EdgeInsets.all(theme.card.padding),
        children: [
          _Section(
            title: 'Caller-owned switches',
            child: _ControlPanel(
              hasBackground: _hasBackground,
              paused: _paused,
              underlay: _underlay,
              fallback: _useFallback,
              letterbox: _letterbox,
              overlay: _overlay,
              overlayOpacity: _overlayOpacity,
              blurSigma: _blurSigma,
              letterboxSigma: _letterboxSigma,
              onHasBackground: (v) => setState(() => _hasBackground = v),
              onPaused: (v) => setState(() => _paused = v),
              onUnderlay: (v) => setState(() => _underlay = v),
              onFallback: (v) => setState(() => _useFallback = v),
              onLetterbox: (v) => setState(() => _letterbox = v),
              onOverlay: (v) => setState(() => _overlay = v),
              onOverlayOpacity: (v) => setState(() => _overlayOpacity = v),
              onBlurSigma: (v) => setState(() => _blurSigma = v),
              onLetterboxSigma: (v) => setState(() => _letterboxSigma = v),
            ),
          ),
          _Section(
            title: 'Tree-shape stability (LiveBackground with null config)',
            child: SizedBox(
              height: 220,
              child: LiveBackground(
                config: _hasBackground ? _heroConfig() : null,
                paused: _paused,
                child: Padding(
                  padding: EdgeInsets.all(theme.card.padding),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Same widget whether the wallpaper is on or off — '
                      'the child text below never remounts.',
                      style: theme.text.body.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Section(
            title: 'SolidBackground',
            child: _VariantPreview(
              caption: 'One color field. Nothing else decided by the package.',
              config: SolidBackground(color: const Color(0xFF1B7F5A), overlay: _maybeOverlay()),
              paused: _paused,
            ),
          ),
          _Section(
            title: 'GradientBackground',
            child: _VariantPreview(
              caption: 'Any two or more colors become a linear gradient.',
              config: GradientBackground(
                colors: const [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
                overlay: _maybeOverlay(),
              ),
              paused: _paused,
            ),
          ),
          _Section(
            title: 'ImageBackground · underlay + fallback + letterbox',
            child: _VariantPreview(
              caption:
                  'The URL is intentionally invalid so you can see the '
                  'caller-supplied fallback take over — the package never '
                  'injects a default color. Turning "letterbox fill" on adds '
                  'a blurred cover copy of the same source; the sigma slider '
                  'only affects it when the switch is on.',
              config: ImageBackground(
                source: const NetworkImageSource('https://example.invalid/x.jpg'),
                fit: _letterbox ? BoxFit.contain : BoxFit.cover,
                placeholderColor: _placeholder,
                underlay: _underlay ? const GradientBackground(colors: _palette) : null,
                fallback: _useFallback ? const SolidBackground(color: _fallbackColor) : null,
                letterboxBlurSigma: _letterbox ? _letterboxSigma : null,
                blurSigma: _blurSigma,
                overlay: _maybeOverlay(),
              ),
              paused: _paused,
            ),
          ),
          _Section(
            title: 'VideoBackground · fake animated source',
            child: _VariantPreview(
              caption:
                  'An AnimationController stands in for a real decoder. '
                  'The "paused" switch above flows through '
                  'LiveBackground.paused → BackgroundVideoSource.buildView; '
                  'nothing in the package reads AppLifecycleState itself.',
              config: VideoBackground(
                source: const _FakeVideoSource(),
                underlay: _underlay ? const SolidBackground(color: Color(0xFF050510)) : null,
                fallback: _useFallback ? const GradientBackground(colors: _palette) : null,
                blurSigma: _blurSigma,
                overlay: _maybeOverlay(),
              ),
              paused: _paused,
            ),
          ),
          _Section(
            title: 'BackgroundLayerStack',
            child: _VariantPreview(
              caption:
                  'Three caller-composed layers with per-layer opacity '
                  'and blend. Same primitives as any other variant.',
              config: const BackgroundLayerStack(
                layers: [
                  BackgroundLayer(config: GradientBackground(colors: _palette)),
                  BackgroundLayer(config: SolidBackground(color: Color(0xFFE76F51)), opacity: 0.35),
                  BackgroundLayer(config: SolidBackground(color: Color(0xFFFFFFFF)), opacity: 0.08),
                ],
              ),
              paused: _paused,
            ),
          ),
          _Section(
            title: 'ProviderImageSource',
            child: _VariantPreview(
              caption:
                  'The caller owns the ImageProvider: FileImage, MemoryImage, '
                  'CachedNetworkImageProvider, ResizeImage... Here we hand a '
                  "truncated PNG; its error path shows the caller's fallback.",
              config: ImageBackground(
                source: ProviderImageSource(MemoryImage(_brokenPngBytes)),
                underlay: _underlay ? const GradientBackground(colors: _palette) : null,
                fallback: _useFallback ? const SolidBackground(color: _fallbackColor) : null,
                blurSigma: _blurSigma,
                overlay: _maybeOverlay(),
              ),
              paused: _paused,
            ),
          ),
        ],
      ),
    );
  }

  BackgroundOverlay? _maybeOverlay() =>
      _overlay ? BackgroundOverlay(color: Colors.black, opacity: _overlayOpacity) : null;

  BackgroundConfig _heroConfig() => ImageBackground(
    source: const NetworkImageSource('https://example.invalid/hero.jpg'),
    placeholderColor: _placeholder,
    underlay: const GradientBackground(colors: _palette),
    fallback: const SolidBackground(color: Color(0xFF2A1E52)),
    blurSigma: _blurSigma,
    overlay: _maybeOverlay(),
  );
}

class _ControlPanel extends StatelessWidget {
  const new({
    required this.hasBackground,
    required this.paused,
    required this.underlay,
    required this.fallback,
    required this.letterbox,
    required this.overlay,
    required this.overlayOpacity,
    required this.blurSigma,
    required this.letterboxSigma,
    required this.onHasBackground,
    required this.onPaused,
    required this.onUnderlay,
    required this.onFallback,
    required this.onLetterbox,
    required this.onOverlay,
    required this.onOverlayOpacity,
    required this.onBlurSigma,
    required this.onLetterboxSigma,
  });

  final bool hasBackground;
  final bool paused;
  final bool underlay;
  final bool fallback;
  final bool letterbox;
  final bool overlay;
  final double overlayOpacity;
  final double blurSigma;
  final double letterboxSigma;
  final ValueChanged<bool> onHasBackground;
  final ValueChanged<bool> onPaused;
  final ValueChanged<bool> onUnderlay;
  final ValueChanged<bool> onFallback;
  final ValueChanged<bool> onLetterbox;
  final ValueChanged<bool> onOverlay;
  final ValueChanged<double> onOverlayOpacity;
  final ValueChanged<double> onBlurSigma;
  final ValueChanged<double> onLetterboxSigma;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: theme.card.padding * 0.5,
          runSpacing: 4,
          children: [
            _switch(theme, 'wallpaper', hasBackground, onHasBackground),
            _switch(theme, 'paused', paused, onPaused),
            _switch(theme, 'underlay', underlay, onUnderlay),
            _switch(theme, 'fallback', fallback, onFallback),
            _switch(theme, 'letterbox fill', letterbox, onLetterbox),
            _switch(theme, 'overlay', overlay, onOverlay),
          ],
        ),
        SizedBox(height: theme.card.padding * 0.5),
        _slider(theme, 'overlay opacity  ${overlayOpacity.toStringAsFixed(2)}', overlayOpacity, 0, 1, onOverlayOpacity),
        _slider(theme, 'blur sigma  ${blurSigma.toStringAsFixed(1)}', blurSigma, 0, 24, onBlurSigma),
        if (letterbox)
          _slider(
            theme,
            'letterbox sigma  ${letterboxSigma.toStringAsFixed(1)}',
            letterboxSigma,
            4,
            48,
            onLetterboxSigma,
          ),
      ],
    );
  }

  Widget _switch(LiveTheme theme, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.text.body.copyWith(color: theme.colors.text)),
        LiveSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _slider(LiveTheme theme, String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.card.padding * 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.text.body.copyWith(color: theme.colors.text)),
          LiveSlider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _VariantPreview extends StatelessWidget {
  const new({required this.caption, required this.config, required this.paused});

  final String caption;
  final BackgroundConfig config;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.card.borderRadius),
            child: LiveBackground(config: config, paused: paused),
          ),
        ),
        SizedBox(height: theme.card.padding * 0.25),
        Text(caption, style: theme.text.body.copyWith(color: theme.colors.textSecondary)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.card.padding),
      child: LiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.text.title.copyWith(color: theme.colors.text)),
            SizedBox(height: theme.card.padding * 0.5),
            child,
          ],
        ),
      ),
    );
  }
}

/// A "video" that never touches a decoder: a rotating hue gradient
/// driven by an AnimationController the caller can pause.
class _FakeVideoSource implements BackgroundVideoSource {
  const new();

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    return _AnimatedVideoView(paused: paused, looping: looping);
  }
}

class _AnimatedVideoView extends StatefulWidget {
  const new({required this.paused, required this.looping});

  final bool paused;
  final bool looping;

  @override
  State<_AnimatedVideoView> createState() => _AnimatedVideoViewState();
}

class _AnimatedVideoViewState extends State<_AnimatedVideoView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _AnimatedVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.paused) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      if (widget.looping) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HSLColor.fromAHSL(1, (t * 360) % 360, 0.7, 0.4).toColor(),
                HSLColor.fromAHSL(1, (t * 360 + 120) % 360, 0.8, 0.5).toColor(),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// A deliberately-truncated PNG so the caller's `fallback` (not a
/// package default) is what covers the failure path.
final Uint8List _brokenPngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUg==');
