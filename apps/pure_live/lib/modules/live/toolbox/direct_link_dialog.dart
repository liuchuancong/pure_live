import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// Opens [room]'s direct stream links: the site's own playback capability
/// answers the qualities, and the dialog lists each playable line with a
/// copy action. The link tool and the room card's menu open the same dialog.
Future<void> showRoomDirectLinks(BuildContext context, WidgetRef ref, LiveRoom room) async {
  final t = context.t;
  final playback = ref.read(sitesProvider).getById(room.ref.platform)?.capability<LivePlaybackProvider>();
  if (playback == null) {
    showDsToast(context: context, title: t.toolbox.linkDirectEmpty, status: DsStatus.danger);
    return;
  }
  final answer = await playback.getQualities(room: room);
  if (!context.mounted) return;
  final qualities = answer.fold((_) => const <LivePlayQuality>[], (qualities) => qualities);
  if (qualities.isEmpty) {
    showDsToast(context: context, title: t.toolbox.linkDirectEmpty, status: DsStatus.danger);
    return;
  }
  await showDsDialog<void>(
    context: context,
    builder: (context) => DirectLinkDialog(room: room, playback: playback, qualities: qualities),
  );
}

/// The room's direct stream links: the quality picker over the lines the
/// site answered for it, each URL with its own copy action — the same
/// capability the player uses.
final class DirectLinkDialog extends ConsumerStatefulWidget {
  const DirectLinkDialog({required this.room, required this.playback, required this.qualities, super.key});

  final LiveRoom room;
  final LivePlaybackProvider playback;
  final List<LivePlayQuality> qualities;

  @override
  ConsumerState<DirectLinkDialog> createState() => _DirectLinkDialogState();
}

final class _DirectLinkDialogState extends ConsumerState<DirectLinkDialog> {
  int _quality = 0;
  List<LivePlayLine> _lines = const [];
  bool _loading = true;
  String? _error;

  /// Drops a superseded answer when the viewer flips quality quickly.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final answer = await widget.playback.getLines(
      room: widget.room,
      quality: widget.qualities[_quality.clamp(0, widget.qualities.length - 1)],
    );
    if (!mounted || generation != _generation) return;
    answer.match(
      (error) => setState(() {
        _loading = false;
        _error = error.message;
      }),
      (lines) => setState(() {
        _loading = false;
        _lines = lines;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.toolbox.linkDirectTitle),
      description: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s12,
          children: [
            if (widget.qualities.length > 1)
              AdaptiveChoiceField<int>(
                value: _quality,
                title: t.toolbox.linkDirectQuality,
                onChanged: (value) {
                  if (value == _quality) return;
                  setState(() => _quality = value);
                  unawaited(_load());
                },
                options: [
                  for (final (index, quality) in widget.qualities.indexed)
                    DsSelectOption(value: index, label: quality.label),
                ],
                semanticLabel: t.toolbox.linkDirectQuality,
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: DsSpace.s24),
                child: Center(child: DsSpinner(style: DsSpinnerStyle(size: 24))),
              )
            else if (_error != null)
              DsAlert(status: DsStatus.danger, title: Text(t.toolbox.linkDirectFailed), description: Text(_error!))
            else if (_lines.isEmpty)
              DsEmptyState(icon: const DsIcon(DsIcons.link2), title: Text(t.toolbox.linkDirectEmpty))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: DsListSection(
                    header: Text(t.toolbox.linkDirectLines),
                    children: [
                      for (final (index, line) in _lines.indexed)
                        DsListRow(
                          leading: const DsIcon(DsIcons.link2),
                          title: Text(line.lineLabel ?? t.room.line(n: index + 1)),
                          description: Text(line.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: DsButton(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            onPressed: () => unawaited(_copy(line)),
                            child: Text(t.toolbox.linkDirectCopy),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }

  Future<void> _copy(LivePlayLine line) async {
    await Clipboard.setData(ClipboardData(text: line.url));
    if (mounted) {
      showDsToast(context: context, title: context.t.toolbox.linkDirectCopyDone);
    }
  }
}
