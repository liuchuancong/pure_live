import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/core/portrait_stream_support.dart';

@immutable
class PortraitOrientationPickerResult {
  const PortraitOrientationPickerResult({required this.orientation, required this.remember});

  final PortraitOrientationOverride orientation;
  final bool remember;
}

/// Room-local orientation picker used from the playback controls.
///
/// The remember switch is a draft owned by this route. Dismissing the dialog
/// therefore leaves both the global preference and the room override intact;
/// choosing an orientation commits the pair as one result.
class PortraitOrientationPickerDialog extends StatefulWidget {
  const PortraitOrientationPickerDialog({super.key, required this.selected, required this.remember});

  final PortraitOrientationOverride selected;
  final bool remember;

  @override
  State<PortraitOrientationPickerDialog> createState() => _PortraitOrientationPickerDialogState();
}

class _PortraitOrientationPickerDialogState extends State<PortraitOrientationPickerDialog> {
  late bool _remember = widget.remember;

  void _select(PortraitOrientationOverride orientation) {
    Navigator.of(context).pop(PortraitOrientationPickerResult(orientation: orientation, remember: _remember));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('portrait-orientation-picker-dialog'),
      scrollable: true,
      title: Text(i18n('portrait_room_override')),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      content: Column(
        key: const ValueKey('portrait-orientation-picker-content'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in PortraitOrientationOverride.values)
            SimpleDialogOption(
              key: ValueKey('portrait-room-override-${item.name}'),
              onPressed: () => _select(item),
              child: Row(
                children: [
                  Icon(
                    item == widget.selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: item == widget.selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_orientationLabel(item))),
                ],
              ),
            ),
          const Divider(height: 1),
          SwitchListTile(
            key: const ValueKey('portrait-room-remember-draft'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            title: Text(i18n('portrait_remember_room_override')),
            subtitle: Text(i18n('portrait_remember_room_override_desc')),
            value: _remember,
            onChanged: (value) => setState(() => _remember = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('portrait-orientation-picker-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n('cancel')),
        ),
      ],
    );
  }
}

/// Portrait-fullscreen presentation picker with a bounded scrolling body.
/// Long translated descriptions and accessibility text scaling stay reachable
/// while the cancel action remains outside the scrolling content.
class PortraitFullscreenDisplayModePickerDialog extends StatelessWidget {
  const PortraitFullscreenDisplayModePickerDialog({super.key, required this.selected});

  final PortraitFullscreenDisplayMode selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('portrait-fullscreen-display-picker-dialog'),
      scrollable: true,
      title: Text(i18n('portrait_fullscreen_display_mode')),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      content: Column(
        key: const ValueKey('portrait-fullscreen-display-picker-content'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in PortraitFullscreenDisplayMode.values)
            SimpleDialogOption(
              key: ValueKey('portrait-fullscreen-display-${item.name}'),
              onPressed: () => Navigator.of(context).pop(item),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      item == selected ? Icons.radio_button_checked_rounded : portraitFullscreenDisplayModeIcon(item),
                      color: item == selected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayModeLabel(item)),
                        const SizedBox(height: 2),
                        Text(
                          _displayModeDescription(item),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('portrait-fullscreen-display-picker-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n('cancel')),
        ),
      ],
    );
  }
}

IconData portraitFullscreenDisplayModeIcon(PortraitFullscreenDisplayMode value) => switch (value) {
  PortraitFullscreenDisplayMode.complete => Icons.crop_free_rounded,
  PortraitFullscreenDisplayMode.ambient => Icons.blur_on_rounded,
  PortraitFullscreenDisplayMode.balanced => Icons.fit_screen_rounded,
  PortraitFullscreenDisplayMode.cover => Icons.fullscreen_rounded,
};

String _orientationLabel(PortraitOrientationOverride value) => switch (value) {
  PortraitOrientationOverride.automatic => i18n('portrait_override_auto'),
  PortraitOrientationOverride.portrait => i18n('portrait_override_portrait'),
  PortraitOrientationOverride.landscape => i18n('portrait_override_landscape'),
};

String _displayModeLabel(PortraitFullscreenDisplayMode value) => switch (value) {
  PortraitFullscreenDisplayMode.complete => i18n('portrait_fullscreen_display_complete'),
  PortraitFullscreenDisplayMode.ambient => i18n('portrait_fullscreen_display_ambient'),
  PortraitFullscreenDisplayMode.balanced => i18n('portrait_fullscreen_display_balanced'),
  PortraitFullscreenDisplayMode.cover => i18n('portrait_fullscreen_display_cover'),
};

String _displayModeDescription(PortraitFullscreenDisplayMode value) => switch (value) {
  PortraitFullscreenDisplayMode.complete => i18n('portrait_fullscreen_display_complete_desc'),
  PortraitFullscreenDisplayMode.ambient => i18n('portrait_fullscreen_display_ambient_desc'),
  PortraitFullscreenDisplayMode.balanced => i18n('portrait_fullscreen_display_balanced_desc'),
  PortraitFullscreenDisplayMode.cover => i18n('portrait_fullscreen_display_cover_desc'),
};
