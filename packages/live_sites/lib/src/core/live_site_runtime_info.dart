import 'package:live_sites/src/core/site_facts.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The lifecycle state of a site instance.
enum LiveSiteStatus {
  /// Constructed, not yet initialized.
  uninitialized,

  /// `initialize` is running.
  initializing,

  /// Ready to serve capabilities.
  ready,

  /// Serving with reduced capability (a resource failed but the site
  /// remains usable).
  degraded,

  /// Currently unusable; a transient condition, not a disposal.
  unavailable,

  /// Disposed; the instance is not reusable.
  disposed,
}

/// The current runtime status of a site instance, with the platform facts a
/// caller asks about beside it.
///
/// Deliberately coarse: runtime status never replaces operation-level error
/// handling, and a transient API failure must not mark every capability
/// unavailable. The facts ([isVoiceLive], [hasSuperChats], [superChatUnit])
/// are platform-wide truths, not this instance's state — they ride here so
/// a status read answers them in one place; build them with
/// [LiveSiteRuntimeInfo.of] so they come from [SiteFacts], never by hand.
class LiveSiteRuntimeInfo {
  /// Builds a status snapshot with explicit facts.
  const LiveSiteRuntimeInfo({
    required this.status,
    this.message,
    this.lastCheckedAt,
    this.isVoiceLive = false,
    this.hasSuperChats = false,
    this.superChatUnit,
  });

  /// Builds a status snapshot for [siteId], its facts taken from
  /// [SiteFacts].
  LiveSiteRuntimeInfo.of(String siteId, {required this.status, this.message, this.lastCheckedAt})
    : isVoiceLive = SiteFacts.isVoiceLive(siteId),
      hasSuperChats = SiteFacts.hasSuperChats(siteId),
      superChatUnit = SiteFacts.superChatUnitOf(siteId);

  /// The lifecycle state.
  final LiveSiteStatus status;

  /// A diagnostic message, when the state needs one.
  final String? message;

  /// When the status was last refreshed, UTC.
  final DateTime? lastCheckedAt;

  /// Whether the platform is voice only: its picture is a placeholder or a
  /// plain background, never a real one, so a room shows its cover instead
  /// of the video.
  final bool isVoiceLive;

  /// Whether the platform's danmaku reports super chats or paid messages
  /// like them, so an empty list from it says the room has none instead of
  /// "they will show up here".
  final bool hasSuperChats;

  /// The unit the platform's super chat prices are counted in, when it has
  /// super chats at all.
  final LiveGiftUnit? superChatUnit;
}
