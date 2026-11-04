import io

p = 'apps/pure_live/lib/modules/live/recorder/pages/recorder_page.dart'
s = io.open(p, encoding='utf-8').read()


def once(old, new=''):
    global s
    assert s.count(old) == 1, (old[:70], s.count(old))
    s = s.replace(old, new)


# 1. the global live-check page goes with its settings
once(
    """  /// Watching followed rooms for a live start, and picking a capture back up
  /// after a restart.
  Widget _polling(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    return DsListSection(
      header: Text(t.recorder.liveCheckGroup),
      children: [
        _RecordSwitch(
          icon: DsIcons.clock,
          title: t.recorder.enablePolling,
          description: t.recorder.enablePollingDesc,
          value: settings.schedule.pollingEnabled,
          onChanged: (value) => controller.pollingEnabled = value,
        ),
        _RecordSwitch(
          icon: DsIcons.power,
          title: t.recorder.autoStartOnBoot,
          description: t.recorder.autoStartOnBootDesc,
          value: settings.schedule.autoStartOnBoot,
          onChanged: (value) => controller.autoStartOnBoot = value,
        ),
      ],
    );
  }

""",
)
once(
    """/// The recording settings' categories: where a file lands and how it names
/// itself, how a capture is segmented and recovered, the background and
/// capacity limits, and the live check that starts captures on its own.""",
    """/// The recording settings' categories: where a file lands and how it names
/// itself, how a capture is segmented and recovered, and the background and
/// capacity limits. The live check belongs to each room now.""",
)
once(
    """  /// Background behaviour, concurrency and the managed cache.
  runtime,

  /// Watching followed rooms for a live start.
  polling,
}""",
    """  /// Background behaviour, concurrency and the managed cache.
  runtime,
}""",
)
once(
    """              DsTab(value: RecordingTab.runtime, label: Text(t.recorder.settingsTabRuntime)),
              DsTab(value: RecordingTab.polling, label: Text(t.recorder.settingsTabPolling)),""",
    """              DsTab(value: RecordingTab.runtime, label: Text(t.recorder.settingsTabRuntime)),""",
)
once(
    """          RecordingTab.runtime => _runtime(context),
          RecordingTab.polling => _polling(context),""",
    """          RecordingTab.runtime => _runtime(context),""",
)

# 2. the task list no longer warns about a global switch it cannot show
once(
    """            // With the live check off nothing begins a take on its own, so the
            // banner covers the scheduled rows too: a stopped task whose window
            // is meant to re-arm it is just as stranded as a room waiting to go
            // live.
            if (!polling && pollingBannerTasks)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
                child: DsAlert(
                  title: Text(t.recorder.pollingOff),
                  status: DsStatus.warning,
                  action: DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () {
                      ref.read(recordingSettingsProvider.notifier).pollingEnabled = true;
                      showDsToast(
                        context: context,
                        title: t.recorder.pollingEnabledToast(
                          seconds: ref.read(recordingSettingsProvider).schedule.liveCheckSeconds,
                        ),
                        status: DsStatus.success,
                      );
                    },
                    child: Text(t.recorder.pollingEnable),
                  ),
                ),
              ),
""",
)
once(
    """              polling: polling,
              pollingBannerTasks: store.tasks.any((task) => task.needsLiveCheck),
""",
)
once(
    """    required bool polling,
    required bool pollingBannerTasks,
""",
)

# 3. the room editor is a panel — a side panel on a window, a sheet on a phone
once(
    """    final draft = await showDsDialog<_ScheduleDraft>(
      context: context,
      builder: (context) => _ScheduleDialog(task: task),
    );""",
    """    final draft = await showDsPanel<_ScheduleDraft>(
      context: context,
      builder: (context) => _RoomSettingsPanel(task: task),
    );""",
)
once(
    """final class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.task});""",
    """final class _RoomSettingsPanel extends StatefulWidget {
  const _RoomSettingsPanel({required this.task});""",
)
once(
    """  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

final class _ScheduleDialogState extends State<_ScheduleDialog> {""",
    """  @override
  State<_RoomSettingsPanel> createState() => _RoomSettingsPanelState();
}

final class _RoomSettingsPanelState extends State<_RoomSettingsPanel> {""",
)
once(
    """    return DsDialog(
      title: Text(t.recorder.roomSettings),
      icon: const DsIcon(DsIcons.calendarClock),
      style: const DsDialogStyle(width: 460),
      description: Column(""",
    """    return DsPanel(
      title: Text(t.recorder.roomSettings),
      child: Column(""",
)
once(
    """      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop((
                    enabled: _enabled,
                    days: _days,
                    start: _start,
                    end: _end,
                    stopAtEnd: _stopAtEnd,
                    checkSeconds: _checkSeconds,
                    checkBackoff: _checkBackoff,
                    maxCheckSeconds: _maxCheckSeconds,
                  )),
          child: Text(t.common.confirm),
        ),
      ],
    );""",
    """      footer: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.common.cancel),
            ),
          ),
          Expanded(
            child: DsButton(
              onPressed: () => Navigator.of(context)
                  .pop((
                    enabled: _enabled,
                    days: _days,
                    start: _start,
                    end: _end,
                    stopAtEnd: _stopAtEnd,
                    checkSeconds: _checkSeconds,
                    checkBackoff: _checkBackoff,
                    maxCheckSeconds: _maxCheckSeconds,
                  )),
              child: Text(t.common.confirm),
            ),
          ),
        ],
      ),
    );""",
)

# 4. every row edits its room from a button of its own
once(
    """                      Row(mainAxisSize: MainAxisSize.min, spacing: DsSpace.s4, children: [action, menu()]),""",
    """                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s4,
                        children: [
                          DsButton.icon(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            semanticLabel: t.recorder.roomSettings,
                            onPressed: onSchedule,
                            icon: const DsIcon(DsIcons.settings2, size: 14),
                          ),
                          action,
                          menu(),
                        ],
                      ),""",
)
once(
    """                        Row(spacing: DsSpace.s8, children: [badge, const Spacer(), action]),""",
    """                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            badge,
                            const Spacer(),
                            DsButton.icon(
                              variant: DsButtonVariant.secondary,
                              size: DsSize.sm,
                              semanticLabel: t.recorder.roomSettings,
                              onPressed: onSchedule,
                              icon: const DsIcon(DsIcons.settings2, size: 14),
                            ),
                            action,
                          ],
                        ),""",
)

# 5. a live take needs no coloured edge
once(
    """          // The live take's own edge: a thin band that says "writing" before
          // the badge is read.
          if (recording)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: IgnorePointer(child: ColoredBox(color: colors.danger.fill)),
            ),
""",
)
io.open(p, 'w', encoding='utf-8').write(s)

# 6. the check runs without a switch: the rooms own their cadence
p2 = 'apps/pure_live/lib/modules/live/recorder/data/recording_settings.dart'
s = io.open(p2, encoding='utf-8').read()
assert s.count("pollingEnabled: _storedBool('recorder.pollingEnabled') ?? false,") == 1
s = s.replace(
    "pollingEnabled: _storedBool('recorder.pollingEnabled') ?? false,",
    "// The check is on by design now: each room owns its cadence, and the\n        // page no longer offers a switch that would strand every room.\n        pollingEnabled: true,",
)
assert s.count("autoStartOnBoot: _storedBool('recorder.autoStartOnBoot') ?? false,") == 1
s = s.replace(
    "autoStartOnBoot: _storedBool('recorder.autoStartOnBoot') ?? false,",
    "autoStartOnBoot: true,",
)
io.open(p2, 'w', encoding='utf-8').write(s)

# 7. the search index loses the removed switch
p3 = 'apps/pure_live/lib/features/settings/surface/settings_search.dart'
s = io.open(p3, encoding='utf-8').read()
line = "      t.recorder.enablePolling,\n"
assert s.count(line) == 1, s.count(line)
s = s.replace(line, "")
io.open(p3, 'w', encoding='utf-8').write(s)
print('ok')
