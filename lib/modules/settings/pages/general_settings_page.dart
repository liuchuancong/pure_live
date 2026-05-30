import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class GeneralSettingsPage extends GetView<SettingsService> {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("general"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("general")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('splash_animation'),
              subtitle: i18n("splash_animation_subtitle"),
              value: SettingsService.to.app.showSplashPage,
              icon: Remix.rocket_2_line,
            ),
            context.buildSwitchTile(
              title: i18n('enable_auto_check_update'),
              subtitle: "",
              value: SettingsService.to.app.enableAutoCheckUpdate,
              icon: Remix.refresh_line,
            ),
            if (Platform.isWindows) ...[
              context.buildSwitchTile(
                title: i18n("startup"),
                subtitle: "",
                value: SettingsService.to.startup.enableStartUp,
                icon: Remix.windows_line,
              ),
              context.buildTile(
                icon: Remix.aspect_ratio_line,
                title: i18n("window_size"),
                subtitle:
                    "${SettingsService.to.window.storedWidth.v.toInt()} × ${SettingsService.to.window.storedHeight.v.toInt()}",
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showWindowSizeDialog(context),
              ),
              context.buildSwitchTile(
                title: i18n("no_exit_confirm"),
                subtitle: "",
                value: SettingsService.to.exit.dontAskExit,
                icon: Remix.error_warning_line,
              ),
            ],
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showWindowSizeDialog(BuildContext context) {
    final widthController = TextEditingController(text: SettingsService.to.window.storedWidth.v.toInt().toString());
    final heightController = TextEditingController(text: SettingsService.to.window.storedHeight.v.toInt().toString());

    final presets = [
      {'name': '1080 × 720 (默认)', 'w': 1080.0, 'h': 720.0},
      {'name': '1280 × 720 (720P)', 'w': 1280.0, 'h': 720.0},
      {'name': '1600 × 900', 'w': 1600.0, 'h': 900.0},
      {'name': '1920 × 1080 (1080P)', 'w': 1920.0, 'h': 1080.0},
      {'name': '2560 × 1440 (2K)', 'w': 2560.0, 'h': 1440.0},
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(i18n("window_size")),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n("preset_options"),
                    style: TextStyle(fontSize: 13, color: theme.hintColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) {
                      return ActionChip(
                        label: Text(preset['name'] as String),
                        onPressed: () {
                          widthController.text = (preset['w'] as double).toInt().toString();
                          heightController.text = (preset['h'] as double).toInt().toString();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    i18n("custom_input"),
                    style: TextStyle(fontSize: 13, color: theme.hintColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: i18n("width"),
                            hintText: "1080",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("×", style: TextStyle(fontSize: 18)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: i18n("height"),
                            hintText: "720",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n("cancel"))),
            TextButton(
              onPressed: () async {
                final double? w = double.tryParse(widthController.text);
                final double? h = double.tryParse(heightController.text);
                if (w != null && h != null && w > 0 && h > 0) {
                  SettingsService.to.window.storedWidth.v = w;
                  SettingsService.to.window.storedHeight.v = h;
                  SettingsService.to.window.updateSize(Size(w, h));
                  await Future.microtask(() async {
                    await windowManager.setSize(Size(w, h), animate: true);
                    await windowManager.center();
                    SettingsService.to.window.setTracking(true);
                  });

                  Navigator.pop(Get.context!);
                  ToastUtil.show(i18n("save_success"));
                } else {
                  ToastUtil.show(i18n("invalid_input"));
                }
              },
              child: Text(
                i18n("confirm"),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
