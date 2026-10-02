import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/features/wallpaper/wallpaper_library.dart';
import 'package:pure_live/services/background/wallpaper_catalog.dart';
import 'package:pure_live/services/background/wallpaper_media_store.dart';
import 'package:pure_live/services/background/wallpaper_repository.dart';
import 'package:remixicon/remixicon.dart';

/// Background settings: the wallpaper in use, how it is drawn, and where to get
/// a new one.
///
/// The page keeps its own scaffold transparent so the layer it is configuring
/// stays visible behind the controls - changing a mask or a blur takes effect
/// where the user is already looking.
class WallpaperPage extends StatefulWidget {
  const WallpaperPage({super.key});

  @override
  State<WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<WallpaperPage> {
  static const List<BoxFit> _fitModes = <BoxFit>[
    BoxFit.cover,
    BoxFit.contain,
    BoxFit.fill,
    BoxFit.fitWidth,
    BoxFit.fitHeight,
    BoxFit.none,
    BoxFit.scaleDown,
  ];

  final TextEditingController _urlController = TextEditingController();
  final List<WallpaperSource> _sources = WallpaperRepository.instance.loadCatalog().sources;

  late WallpaperSource _source = _sources.first;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsService.to.bg;
    final languageCode = context.locale.languageCode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(i18n('ui_background_settings')),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          context.buildGroupTitle(i18n('wallpaper_display_group')),
          Obx(
            () => context.buildModernCard([
              _FillModeRow(
                fits: _fitModes,
                selected: controller.config.v.boxFit,
                languageCode: languageCode,
                onSelected: controller.setBoxFit,
              ),
              context.buildSliderTile(
                context,
                icon: Remix.contrast_2_line,
                title: i18n('background_mask'),
                value: controller.config.v.maskOpacity,
                min: 0,
                max: 1,
                displayValue: '${(controller.config.v.maskOpacity * 100).round()}%',
                onChanged: controller.setMaskOpacity,
              ),
              context.buildSliderTile(
                context,
                icon: Remix.contrast_drop_2_line,
                title: i18n('wallpaper_blur'),
                value: controller.config.v.blurSigma,
                min: 0,
                max: BackgroundConfig.maxBlurSigma.toDouble(),
                displayValue: controller.config.v.blurSigma <= 0
                    ? i18n('wallpaper_blur_off')
                    : controller.config.v.blurSigma.toStringAsFixed(0),
                onChanged: controller.setBlurSigma,
              ),
              context.buildTile(
                icon: Remix.close_circle_line,
                title: i18n('background_clear'),
                subtitle: i18n('background_clear_desc'),
                onTap: () {
                  controller.setNone();
                  ToastUtil.show(i18n('wallpaper_background_cleared'));
                },
              ),
            ]),
          ),

          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('wallpaper_from_device')),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.image_2_line,
              title: i18n('wallpaper_pick_image'),
              subtitle: i18n('wallpaper_pick_image_desc'),
              onTap: () => _pickFile(FileType.image),
            ),
            context.buildTile(
              icon: Remix.vidicon_line,
              title: i18n('wallpaper_pick_video'),
              subtitle: i18n('wallpaper_pick_video_desc'),
              onTap: () => _pickFile(FileType.video),
            ),
            _NetworkUrlRow(
              controller: _urlController,
              onApply: () {
                final url = _urlController.text.trim();
                if (url.isEmpty) return;
                if (Uri.tryParse(url)?.hasAbsolutePath ?? false) {
                  SettingsService.to.bg.setNetworkImage(url);
                }
              },
            ),
          ]),

          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('wallpaper_library')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final source in _sources)
                ChoiceChip(
                  label: Text(source.localizedName(languageCode)),
                  selected: source.id == _source.id,
                  onSelected: (_) => setState(() => _source = source),
                ),
            ],
          ),
          const SizedBox(height: 14),
          WallpaperLibraryView(key: ValueKey<String>(_source.id), source: _source),
        ],
      ),
    );
  }

  Future<void> _pickFile(FileType type) async {
    final controller = SettingsService.to.bg;
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(type: type);
    } catch (error) {
      ToastUtil.show(i18n('background_apply_failed', args: {'msg': '$error'}));
      return;
    }
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || path.isEmpty) return;

    // The picker's path can be a cache file Android is free to evict, so the
    // media is copied into the app's own wallpaper directory first.
    final stored = await WallpaperMediaStore.importFile(path);
    if (type == FileType.video) {
      controller.setVideoPath(stored);
    } else {
      controller.setLocalImage(stored);
    }
  }
}

class _FillModeRow extends StatelessWidget {
  const _FillModeRow({
    required this.fits,
    required this.selected,
    required this.languageCode,
    required this.onSelected,
  });

  final List<BoxFit> fits;
  final BoxFit selected;
  final String languageCode;
  final ValueChanged<BoxFit> onSelected;

  static const Map<BoxFit, String> _keys = <BoxFit, String>{
    BoxFit.cover: 'wallpaper_fit_cover',
    BoxFit.contain: 'wallpaper_fit_contain',
    BoxFit.fill: 'wallpaper_fit_fill',
    BoxFit.fitWidth: 'wallpaper_fit_fit_width',
    BoxFit.fitHeight: 'wallpaper_fit_fit_height',
    BoxFit.none: 'wallpaper_fit_none',
    BoxFit.scaleDown: 'wallpaper_fit_scale_down',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n('wallpaper_fit_mode'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fit in fits)
                ChoiceChip(
                  label: Text(i18n(_keys[fit]!)),
                  selected: fit == selected,
                  onSelected: (_) => onSelected(fit),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkUrlRow extends StatelessWidget {
  const _NetworkUrlRow({required this.controller, required this.onApply});

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n('wallpaper_image_url'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: i18n('wallpaper_image_url_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: onApply, child: Text(i18n('background_apply'))),
            ],
          ),
        ],
      ),
    );
  }
}
