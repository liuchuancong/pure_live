// A runnable tour of `pure_uikit_background`.
//
// Every visual on screen is driven by a field on the caller —
// `PureBackground.paused`, `ImageBackground.letterboxBlurSigma`,
// `BackgroundOverlay.opacity`, `VideoBackground.underlay` — because the
// package refuses to pick defaults for them. Flip the switches at the
// top and watch each variant respond; there is no code path in the
// package that reads `AppLifecycleState`, `dart:io`, or a hard-coded
// color to fill in a blank.
import 'dart:convert' show base64Decode;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart';

void main() => runApp(const BackgroundDemoApp());

/// Root of the demo app.
class BackgroundDemoApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pure_uikit_background demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const DemoHomePage(),
    );
  }
}

/// Home page: a control panel above a gallery of every config variant.
class DemoHomePage extends StatefulWidget {
  const new({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  static const List<Color> _palette = [Color(0xFF12203A), Color(0xFF061220)];
  static const Color _placeholder = Color(0xFF0F1522);

  bool _hasBackground = true;
  bool _paused = false;
  bool _useUnderlay = true;
  bool _useFallback = true;
  bool _useLetterbox = true;
  bool _useOverlay = true;
  double _overlayOpacity = 0.35;
  double _blurSigma = 0;
  double _letterboxSigma = 24;

  @override
  Widget build(BuildContext context) {
    final heroConfig = _hasBackground ? _heroConfig() : null;
    return Scaffold(
      appBar: AppBar(title: const Text('pure_uikit_background demo')),
      body: Column(
        children: [
          _ControlPanel(
            hasBackground: _hasBackground,
            paused: _paused,
            underlay: _useUnderlay,
            fallback: _useFallback,
            letterbox: _useLetterbox,
            overlay: _useOverlay,
            overlayOpacity: _overlayOpacity,
            blurSigma: _blurSigma,
            letterboxSigma: _letterboxSigma,
            onHasBackground: (v) => setState(() => _hasBackground = v),
            onPaused: (v) => setState(() => _paused = v),
            onUnderlay: (v) => setState(() => _useUnderlay = v),
            onFallback: (v) => setState(() => _useFallback = v),
            onLetterbox: (v) => setState(() => _useLetterbox = v),
            onOverlay: (v) => setState(() => _useOverlay = v),
            onOverlayOpacity: (v) => setState(() => _overlayOpacity = v),
            onBlurSigma: (v) => setState(() => _blurSigma = v),
            onLetterboxSigma: (v) => setState(() => _letterboxSigma = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeroSection(config: heroConfig, paused: _paused),
                const SizedBox(height: 20),
                _VariantCard(
                  label: 'SolidBackground',
                  caption: 'One color. Nothing else decided by the package.',
                  config: SolidBackground(color: const Color(0xFF1B7F5A), overlay: _maybeOverlay()),
                  paused: _paused,
                ),
                _VariantCard(
                  label: 'GradientBackground',
                  caption: 'Any two or more colors become a linear gradient.',
                  config: GradientBackground(
                    colors: const [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
                    overlay: _maybeOverlay(),
                  ),
                  paused: _paused,
                ),
                _VariantCard(
                  label: 'ImageBackground · underlay + fallback + letterbox',
                  caption:
                      'Caller picks every surface. The URL is intentionally '
                      'invalid so you can see the caller-supplied fallback take '
                      'over — the package never injects a default color.',
                  config: ImageBackground(
                    source: const NetworkImageSource('https://example.invalid/x.jpg'),
                    fit: _useLetterbox ? BoxFit.contain : BoxFit.cover,
                    placeholderColor: _placeholder,
                    underlay: _useUnderlay ? const GradientBackground(colors: _palette) : null,
                    fallback: _useFallback ? const SolidBackground(color: Color(0xFF302A4F)) : null,
                    letterboxBlurSigma: _useLetterbox ? _letterboxSigma : null,
                    blurSigma: _blurSigma,
                    overlay: _maybeOverlay(),
                  ),
                  paused: _paused,
                ),
                _VariantCard(
                  label: 'VideoBackground · animated fake source',
                  caption:
                      'A TweenAnimation-driven gradient stands in for a '
                      'real decoder. Toggle "paused" above — it flows through '
                      'PureBackground.paused → BackgroundVideoSource.buildView. '
                      'The package does not read AppLifecycleState on its own.',
                  config: VideoBackground(
                    source: const _FakeVideoSource(),
                    underlay: _useUnderlay ? const SolidBackground(color: Color(0xFF050510)) : null,
                    fallback: _useFallback ? const GradientBackground(colors: _palette) : null,
                    blurSigma: _blurSigma,
                    overlay: _maybeOverlay(),
                  ),
                  paused: _paused,
                ),
                _VariantCard(
                  label: 'BackgroundLayerStack',
                  caption:
                      'Bottom-to-top stack with per-layer opacity and '
                      'blend. Same primitives as every other variant.',
                  config: const BackgroundLayerStack(
                    layers: [
                      BackgroundLayer(config: GradientBackground(colors: _palette)),
                      BackgroundLayer(config: SolidBackground(color: Color(0xFFE76F51)), opacity: 0.35),
                      BackgroundLayer(config: SolidBackground(color: Color(0xFFFFFFFF)), opacity: 0.08),
                    ],
                  ),
                  paused: _paused,
                ),
                _VariantCard(
                  label: 'ProviderImageSource',
                  caption:
                      'The caller owns the ImageProvider: FileImage, '
                      'MemoryImage, CachedNetworkImageProvider, ResizeImage, ... '
                      'Here we hand the package a broken PNG; its error path '
                      "shows the caller's fallback (again, not a package "
                      'default).',
                  config: ImageBackground(
                    source: ProviderImageSource(MemoryImage(_brokenPngBytes)),
                    underlay: _useUnderlay ? const GradientBackground(colors: _palette) : null,
                    fallback: _useFallback ? const SolidBackground(color: Color(0xFF302A4F)) : null,
                    blurSigma: _blurSigma,
                    overlay: _maybeOverlay(),
                  ),
                  paused: _paused,
                ),
                const SizedBox(height: 8),
                const _PolicyNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BackgroundOverlay? _maybeOverlay() =>
      _useOverlay ? BackgroundOverlay(color: Colors.black, opacity: _overlayOpacity) : null;

  BackgroundConfig _heroConfig() => ImageBackground(
    source: const NetworkImageSource('https://example.invalid/hero.jpg'),
    placeholderColor: _placeholder,
    underlay: const GradientBackground(colors: _palette),
    fallback: const SolidBackground(color: Color(0xFF2A1E52)),
    blurSigma: _blurSigma,
    overlay: _maybeOverlay(),
  );
}

/// The panel at the top of the screen: switches and sliders that
/// rewrite the config the gallery feeds into `PureBackground`.
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
    final style = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _switchTile('wallpaper', hasBackground, onHasBackground, style),
          _switchTile('paused', paused, onPaused, style),
          _switchTile('underlay', underlay, onUnderlay, style),
          _switchTile('fallback', fallback, onFallback, style),
          _switchTile('letterbox fill', letterbox, onLetterbox, style),
          _switchTile('overlay', overlay, onOverlay, style),
          _sliderTile('overlay opacity', overlayOpacity, 0, 1, onOverlayOpacity),
          _sliderTile('blur sigma', blurSigma, 0, 24, onBlurSigma),
          if (letterbox) _sliderTile('letterbox sigma', letterboxSigma, 4, 48, onLetterboxSigma),
        ],
      ),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged, TextStyle? style) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _sliderTile(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return SizedBox(
      width: 280,
      height: 40,
      child: Row(
        children: [
          SizedBox(width: 128, child: Text('$label  ${value.toStringAsFixed(2)}')),
          Expanded(
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// The scrolling hero panel: the same [PureBackground] widget with a
/// `config` that flips to `null` when the "wallpaper" switch is off.
/// The `child` (this card) is never remounted.
class _HeroSection extends StatelessWidget {
  const new({required this.config, required this.paused});

  final BackgroundConfig? config;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: PureBackground(
        config: config,
        paused: paused,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'PureBackground(config: hasBackground ? imageCfg : null)\n'
                  'Same widget shape on both sides — no Navigator remount.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card showing one variant with a caption and the exact config
/// fields that produced it.
class _VariantCard extends StatelessWidget {
  const new({required this.label, required this.caption, required this.config, required this.paused});

  final String label;
  final String caption;
  final BackgroundConfig config;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PureBackground(config: config, paused: paused),
            ),
          ),
          const SizedBox(height: 6),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Reminder printed at the bottom of the gallery.
class _PolicyNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Package policy: nothing here is a default. Remove `underlay`, '
      '`fallback`, `letterboxBlurSigma` or the `paused` value and the '
      'corresponding layer simply disappears. This demo owns every '
      'color, sigma and lifecycle signal.',
      style: Theme.of(context).textTheme.bodySmall,
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
