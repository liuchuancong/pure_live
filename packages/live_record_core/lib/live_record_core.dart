/// Recording task kernel for Pure Live.
///
/// One recording job, described on four separate axes instead of one status string,
/// and a ledger that lets a launch finish what the previous launch left:
///
/// ```dart
/// final orchestrator = RecordOrchestrator(
///   services: MyRecordServices(),   // capture, probe, files, guard, notices
///   store: RecordJsonStore(mySlots),
/// )..naming = RecordNaming(rootDirectory: '/sdcard/…/recordings');
///
/// final left = await orchestrator.restore();      // joins and names what a crash left
/// await orchestrator.watch(
///   const RecordTarget(platform: 'douyin', roomId: '8891', anchorName: '主播8891'),
/// );
/// ```
///
/// ## What this package does not do
///
/// It does not run FFmpeg, open a socket, ask a platform's API, or draw a
/// notification. Those are the [RecordServices] contract, implemented by the app
/// shell over `media_core_recording_ffmpeg` (capture and join), `media_core_native`
/// (the foreground notification and the wake lock that keeps capturing once the
/// screen is off) and `live_sites` (the room's own answer). Keeping them outside is
/// what makes the ledger testable and lets a host swap any one of them — the rule in
/// `docs/packages-migration.md` that a domain package imports no engine.
///
/// ## The naming rule, in one paragraph
///
/// FFmpeg is handed an ASCII prefix ([RecordTask.taskId]) inside an ASCII directory
/// (`<root>/<platform>/<pinyin-anchor>/<YYYY-MM-DD>`), because that is where a
/// Chinese room title breaks: the segment template repeats the prefix, and the
/// Windows path handling goes through the local code page. The Chinese name is
/// applied to the joined file afterwards ([RecordFiles.rename]), by code that has no
/// such limit — and if it fails, the recording stays exactly as usable under its
/// capture name with the intent recorded for the next launch.
library;

import 'package:live_record_core/live_record_core.dart'
    show
        AnchorDirectoryStyle,
        ArtifactStage,
        PendingAttempt,
        ProbeOutcome,
        RecordFiles,
        RecordNaming,
        RecordOrchestrator,
        RecordPaths,
        RecordServices,
        RecordStatus,
        RecordTarget,
        RecordTask,
        RecoveryReport,
        RoomState;

/// Where a recording's files live and what they are called: [RecordNaming],
/// [RecordPaths], [AnchorDirectoryStyle].
export 'src/record_naming.dart';

/// The driver: [RecordOrchestrator] and [RecoveryReport].
export 'src/record_orchestrator.dart';

/// Waiting, retrying and finishing rules.
export 'src/record_policy.dart';

/// The capture, probe, file, guard and notification contracts the app shell
/// implements, and the value types that cross them.
export 'src/record_services.dart';

/// The four state axes: [ProbeOutcome], [RoomState], [RecordStatus],
/// [ArtifactStage].
export 'src/record_status.dart';

/// The task ledger: what a task is, what it owes, and how it is stored.
export 'src/record_store.dart';

/// One recording job: [RecordTarget], [RecordTask], [PendingAttempt].
export 'src/record_task.dart';
