import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart';
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart' show iptvClockLabel;
import 'package:pure_live/shared/widgets/app_panel.dart';

/// The reminders' own list: everything the guide's rows have booked, each
/// with its way out and its way to the picture — the one place a booking can
/// be answered without walking back to the day it was made on.
Future<void> showIptvReminders(BuildContext context) => showAppPanel<void>(
  context: context,
  builder: (context) => AppPanel(title: Text(context.t.iptv.remindersTitle), child: const _IptvRemindersList()),
);

final class _IptvRemindersList extends ConsumerWidget {
  const _IptvRemindersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final reminders = ref.watch(iptvRemindersProvider);
    if (reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(DsSpace.s16),
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.bell),
          title: Text(t.iptv.remindersEmpty),
          description: Text(t.iptv.remindersEmptyDescription),
        ),
      );
    }
    final library = ref.watch(iptvLibraryProvider).value;
    String two(int value) => value.toString().padLeft(2, '0');
    return ListView.builder(
      shrinkWrap: true,
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        final channel = library?.channelById(reminder.channelId);
        final start = reminder.start.toLocal();
        final when = '${two(start.month)}-${two(start.day)} ${iptvClockLabel(reminder.start)}';
        return DsListRow(
          title: Text(reminder.title),
          leading: const DsIcon(DsIcons.bell),
          description: Text(channel == null ? when : '${channel.entry.name} · $when'),
          // The row opens the picture: the panel closes first, so the list is
          // never covering the channel it was asked for.
          onPressed: channel == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  unawaited(context.push(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel));
                },
          trailing: DsButton.icon(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            semanticLabel: t.iptv.reminderCancelAction,
            onPressed: () => unawaited(ref.read(iptvRemindersProvider.notifier).toggle(reminder)),
            icon: const DsIcon(DsIcons.x, size: 16),
          ),
        );
      },
    );
  }
}
