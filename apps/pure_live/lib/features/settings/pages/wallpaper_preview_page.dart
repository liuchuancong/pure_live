import 'dart:async' show unawaited;
import 'dart:typed_data' show Uint8List;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/panes/background_panes.dart' show backgroundFitLabel;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart'
    show BackgroundConfig, ImageBackground, ProviderImageSource, PureBackground, SolidBackground, VideoBackground;

/// What a preview page walks: the entries of one grid page, or a random-image
/// API that answers one picture at a time.
final class WallpaperPreviewSubject {
  /// A catalogue list, opening on [index].
  const WallpaperPreviewSubject.items(this.items, this.index) : source = null;

  /// A random source: the next picture is always another fetch.
  const WallpaperPreviewSubject.random(this.source) : items = const [], index = 0;

  /// The entries on screen, in grid order.
  final List<WallpaperItem> items;

  /// Which entry the page opens on.
  final int index;

  /// The random source, when the page walks an API instead of a list.
  final RandomWallpaperSource? source;

  /// Whether this is a random-image preview rather than a catalogue list.
  bool get isRandom => source != null;

  /// The entry in view, or null for a random preview.
  WallpaperItem? itemAt(int index) => index >= 0 && index < items.length ? items[index] : null;
}

/// Opens a wallpaper full-window and alone: no sidebar, no title bar, and no
/// panel over the picture. One row at the bottom switches entries and opens
/// the display settings, which live in a dialog of their own.
Future<void> showWallpaperPreview(BuildContext context, List<WallpaperItem> items, int index) {
  return _openPreview(context, WallpaperPreviewSubject.items(items, index));
}

/// Opens the next picture from [source] in the same page; the picture is only
/// fetched there, and the page offers another until the viewer keeps one.
Future<void> showRandomWallpaperPreview(BuildContext context, RandomWallpaperSource source) {
  return _openPreview(context, WallpaperPreviewSubject.random(source));
}

Future<void> _openPreview(BuildContext context, WallpaperPreviewSubject subject) {
  // The root navigator, so the page covers the shell instead of opening as
  // another pane inside it.
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(fullscreenDialog: true, builder: (context) => WallpaperPreviewPage(subject: subject)));
}

/// The preview page.
final class WallpaperPreviewPage extends ConsumerStatefulWidget {
  /// The page for [subject].
  const WallpaperPreviewPage({required this.subject, super.key});

  /// What is being walked.
  final WallpaperPreviewSubject subject;

  @override
  ConsumerState<WallpaperPreviewPage> createState() => _WallpaperPreviewPageState();
}

final class _WallpaperPreviewPageState extends ConsumerState<WallpaperPreviewPage> {
  late int _index = widget.subject.index;

  /// The fetched random picture; a catalogue entry paints from its own URL.
  Uint8List? _bytes;
  String _extension = 'jpg';
  bool _loading = false;
  bool _saving = false;
  RandomWallpaperFailure? _failure;
  int _generation = 0;

  /// The preview's own transport. An applied wallpaper always loops muted,
  /// so these only shape what the viewer hears while deciding.
  bool _paused = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    // The wallpaper behind this page stands down while it is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(backgroundPreviewOpenProvider.notifier).open();
    });
    if (widget.subject.isRandom) unawaited(_fetch());
  }

  @override
  void dispose() {
    ref.read(backgroundPreviewOpenProvider.notifier).close();
    super.dispose();
  }

  Future<void> _fetch() async {
    final generation = ++_generation;
    if (!_loading) setState(() => _loading = true);
    final source = widget.subject.source;
    if (source == null) return;
    try {
      final picture = await ref.read(randomWallpaperClientProvider).fetch(source);
      if (!mounted || generation != _generation) return;
      setState(() {
        _bytes = picture.bytes;
        _extension = picture.format;
        _failure = null;
        _loading = false;
      });
    } on RandomWallpaperFailure catch (failure) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = failure;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = RandomWallpaperFailure(RandomWallpaperFailureKind.network, '$error');
        _loading = false;
      });
    }
  }

  /// Steps through the grid page; a random source has no list, so its next
  /// stop is another fetch.
  void _step(int delta) {
    if (widget.subject.isRandom) {
      if (delta > 0) unawaited(_fetch());
      return;
    }
    final count = widget.subject.items.length;
    if (count == 0) return;
    setState(() => _index = (_index + delta + count) % count);
  }

  Future<void> _apply() async {
    final t = context.t;
    final controller = ref.read(backgroundSettingsProvider.notifier);
    final item = widget.subject.itemAt(_index);
    if (item != null) {
      if (item.video) {
        controller.setVideoUrl(item.url);
      } else {
        controller.setImageUrl(item.url);
      }
      if (!mounted) return;
      showDsToast(context: context, title: t.settings.backgroundLibraryApplied);
      Navigator.of(context).pop();
      return;
    }
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _saving = true);
    await controller.useRandomImage(bytes, extension: _extension);
    if (!mounted) return;
    final error = ref.read(backgroundSettingsProvider).error;
    if (error.isNotEmpty) {
      setState(() => _saving = false);
      showDsToast(
        context: context,
        title: t.settings.backgroundImportFailed,
        description: error,
        status: DsStatus.danger,
      );
      return;
    }
    showDsToast(context: context, title: t.wallpaper.applied);
    Navigator.of(context).pop();
  }

  /// The candidate with the display settings on it, in the same shape the app
  /// background paints with.
  BackgroundConfig? _configOf(BuildContext context, BackgroundSettings settings) {
    final colors = DsTheme.colorsOf(context);
    final overlay = appBackgroundOverlay(context, opacity: settings.maskOpacity, blurSigma: settings.overlayBlurSigma);
    final underlay = SolidBackground(color: colors.canvas);
    final item = widget.subject.itemAt(_index);
    if (item != null) {
      if (item.video) {
        return VideoBackground(
          source: AppBackgroundVideoSource(Uri.parse(item.url)),
          fit: settings.fit,
          underlay: underlay,
          fallback: underlay,
          muted: _muted,
          overlay: overlay,
        );
      }
      return ImageBackground(
        source: ProviderImageSource(cachedImage(item.url)),
        fit: settings.fit,
        placeholderColor: colors.canvas,
        underlay: underlay,
        fallback: underlay,
        overlay: overlay,
      );
    }
    final bytes = _bytes;
    if (bytes == null) return null;
    return ImageBackground(
      source: ProviderImageSource(MemoryImage(bytes)),
      fit: settings.fit,
      placeholderColor: colors.canvas,
      underlay: underlay,
      fallback: underlay,
      overlay: overlay,
    );
  }

  String _title(Translations t) {
    final item = widget.subject.itemAt(_index);
    if (item != null) {
      final name = item.name.trim();
      final count = '${_index + 1}/${widget.subject.items.length}';
      return name.isEmpty ? count : '$name · $count';
    }
    final source = widget.subject.source;
    return source == null ? t.wallpaper.previewTitle : source.label(t);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final config = _configOf(context, settings);
    final isVideo = widget.subject.itemAt(_index)?.video ?? false;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (config != null)
            PureBackground(config: config, paused: _paused, child: const SizedBox.shrink())
          else if (_failure != null)
            _FailureView(failure: _failure, onRetry: () => unawaited(_fetch()))
          else
            const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
          // One row at the bottom, and nothing else over the picture.
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.s12),
                child: _BottomBar(
                  title: _title(t),
                  isVideo: isVideo,
                  paused: _paused,
                  muted: _muted,
                  saving: _saving || (_loading && config == null),
                  canStep: widget.subject.items.length > 1,
                  onClose: () => Navigator.of(context).pop(),
                  onPrevious: () => _step(-1),
                  onNext: () => _step(1),
                  onSettings: () => unawaited(_showDisplaySettings()),
                  onTogglePause: () => setState(() => _paused = !_paused),
                  onToggleMute: () => setState(() => _muted = !_muted),
                  onApply: () => unawaited(_apply()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The display settings, in a dialog: the page itself stays clean, and the
  /// picture behind the sheet keeps answering to every change.
  Future<void> _showDisplaySettings() {
    final t = context.t;
    return showDsDialog<void>(
      context: context,
      builder: (dialogContext) => _DisplaySettingsDialog(title: t.settings.backgroundDisplay),
    );
  }
}

/// The single bottom row: close, where the viewer is, the steps, the display
/// settings, the video transport, and the apply action.
final class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.title,
    required this.isVideo,
    required this.paused,
    required this.muted,
    required this.saving,
    required this.canStep,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onSettings,
    required this.onTogglePause,
    required this.onToggleMute,
    required this.onApply,
  });

  final String title;
  final bool isVideo;
  final bool paused;
  final bool muted;
  final bool saving;
  final bool canStep;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSettings;
  final VoidCallback onTogglePause;
  final VoidCallback onToggleMute;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DecoratedBox(
      decoration: DsBoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DsRadii.pill),
        shadows: theme.shadows.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s6, DsSpace.s12, DsSpace.s6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              onPressed: onClose,
              icon: const DsIcon(DsIcons.close),
              semanticLabel: t.common.close,
            ),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(color: colors.text),
              ),
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              onPressed: canStep ? onPrevious : null,
              icon: const DsIcon(DsIcons.chevronLeft),
              semanticLabel: t.settings.backgroundPreviewPrevious,
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              onPressed: onNext,
              icon: const DsIcon(DsIcons.chevronRight),
              semanticLabel: t.settings.backgroundPreviewNext,
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              onPressed: onSettings,
              icon: const DsIcon(DsIcons.slidersHorizontal),
              semanticLabel: t.settings.backgroundDisplay,
            ),
            if (isVideo) ...[
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                onPressed: onTogglePause,
                icon: DsIcon(paused ? DsIcons.play : DsIcons.pause),
                semanticLabel: paused ? t.room.play : t.room.pause,
              ),
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                onPressed: onToggleMute,
                icon: DsIcon(muted ? DsIcons.volumeOff : DsIcons.volume),
                semanticLabel: muted ? t.room.unmute : t.room.mute,
              ),
            ],
            DsButton(
              size: DsSize.sm,
              loading: saving,
              onPressed: saving ? null : onApply,
              child: Text(t.settings.backgroundApply),
            ),
          ],
        ),
      ),
    );
  }
}

/// The display settings sheet: the fit as a dropdown and the scrim's two
/// sliders, all writing the app's own background settings so the picture
/// behind answers at once.
final class _DisplaySettingsDialog extends ConsumerWidget {
  const _DisplaySettingsDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    return DsDialog(
      title: Text(title),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          SettingsChoiceRow<BoxFit>(
            leading: const DsIcon(DsIcons.expand),
            title: t.settings.backgroundFit,
            description: t.settings.backgroundFitDescription,
            value: settings.fit,
            options: [for (final fit in kBackgroundFits) DsSelectOption(value: fit, label: backgroundFitLabel(t, fit))],
            onChanged: controller.setFit,
          ),
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.contrast),
            title: t.settings.backgroundMask,
            description: t.settings.backgroundMaskDescription,
            detail: Text('${(settings.maskOpacity * 100).round()}%'),
            controlWidth: 220,
            control: DsSlider(
              value: settings.maskOpacity,
              max: 0.8,
              divisions: 16,
              onChanged: controller.setMaskOpacity,
              semanticLabel: t.settings.backgroundMask,
            ),
          ),
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.dropletLines),
            title: t.settings.backgroundOverlayBlur,
            description: t.settings.backgroundOverlayBlurDescription,
            detail: Text('${settings.overlayBlurSigma.round()}'),
            controlWidth: 220,
            control: DsSlider(
              value: settings.overlayBlurSigma,
              max: 24,
              divisions: 24,
              onChanged: controller.setOverlayBlurSigma,
              semanticLabel: t.settings.backgroundOverlayBlur,
            ),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 560),
      actions: [
        DsButton(
          variant: DsButtonVariant.ghost,
          onPressed: settings.kind == BackgroundKind.none ? null : controller.clear,
          child: Text(t.settings.backgroundClear),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}

/// A random source that did not answer with a picture, with the retry in
/// place instead of a dead preview.
final class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure, required this.onRetry});

  final RandomWallpaperFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final unsupported = failure?.kind == RandomWallpaperFailureKind.unsupported;
    final detail = failure?.detail ?? '';
    return ColoredBox(
      color: colors.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              DsIcon(unsupported ? DsIcons.imageOff : DsIcons.cloudOff, size: 28, color: colors.textSubtle),
              Text(
                unsupported ? t.wallpaper.unsupported : t.wallpaper.fetchFailed,
                textAlign: TextAlign.center,
                style: theme.typography.body.copyWith(color: colors.text),
              ),
              if (detail.isNotEmpty && !unsupported)
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.refreshCw),
                onPressed: onRetry,
                child: Text(t.wallpaper.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
