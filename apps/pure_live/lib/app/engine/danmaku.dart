import 'dart:async';

import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';

/// The danmaku connection factory (doc §app/engine/danmaku): the site's
/// `LiveDanmakuProvider` session wrapped as an interaction source, the
/// shield lists applied as the filter chain, one session per room.
///
/// The shield lists come from the settings.shield keyed box — the same
/// three keys the shield page writes. Keyword rules compile as regex when
/// the pattern parses, else match plain; user rules match the sender's
/// name exactly.
Future<InteractionSession> openDanmakuSession({
  required LiveSite site,
  required String roomId,
  required List<BlockRule> shieldRules,
  AppPreferences? barrage,
}) async {
  final capability = site.capability<LiveDanmakuProvider>();
  if (capability == null) {
    throw StateError('${site.manifest.id} exposes no danmaku capability');
  }
  final source = DanmakuInteractionSource(
    connect: () {
      return capability
          .createSession(roomId: roomId)
          .then(
            (result) => result.fold(
              (error) => throw StateError('${site.manifest.id} danmaku: ${error.message}'),
              (session) => session,
            ),
          );
    },
  );
  // The filter is always there, even with an empty shield: it also carries
  // the barrage settings' emote gate and the repeat-collapse, which the room
  // rewrites live (the reference's 改动立即生效).
  final session = InteractionSession(
    sources: [source],
    filter: MessageFilter(
      rules: shieldRules,
      dropPureEmoji: barrage?.barrageNoEmoji ?? false,
      collapseRepeated: barrage?.barrageCollapse ?? false,
      repeatedWindow: Duration(seconds: (barrage?.barrageCollapseWindow ?? 5).clamp(1, 30)),
    ),
  );
  await session.start();
  return session;
}

/// The shield lists as block rules: every keyword a keyword rule (the
/// filter compiles `/regex/`-shaped patterns as regexes itself) and every
/// blocked viewer a user rule.
Future<List<BlockRule>> loadShieldRules() async {
  final repository = HiveStorageRepository<List<String>>(
    box: await StorageBoxManager().keyed<List<String>>('settings.shield'),
  );
  final rules = <BlockRule>[];
  for (final keyword in repository.get('shield.keywords') ?? const <String>[]) {
    rules.add(BlockRule(kind: BlockKind.keyword, pattern: keyword));
  }
  for (final user in repository.get('shield.users') ?? const <String>[]) {
    rules.add(BlockRule(kind: BlockKind.user, pattern: user));
  }
  for (final regex in repository.get('shield.regexes') ?? const <String>[]) {
    rules.add(BlockRule(kind: BlockKind.keyword, pattern: regex));
  }
  return rules;
}

/// Rewrites a live session's barrage filter from the stored answers — the
/// emote gate and the repeat-collapse apply at once, without a reconnect.
void applyBarrageFilterSettings(InteractionSession? session, AppPreferences preferences) {
  session?.filter
    ?..dropPureEmoji = preferences.barrageNoEmoji
    ..collapseRepeated = preferences.barrageCollapse
    ..repeatedWindow = Duration(seconds: preferences.barrageCollapseWindow.clamp(1, 30));
}

/// Appends [name] to the stored blocked viewers (the shield page's own list,
/// so the block shows up there) — a name already in it changes nothing.
///
/// This is the persistence half of the danmaku's 屏蔽此用户; the live half is
/// the caller handing the same name to the running session's
/// [MessageFilter.addUser], which takes the in-flight lines without the
/// reconnect an invalidated session would cause.
Future<void> addShieldUser(String name) => _appendShield('shield.users', name, maxLength: 64);

/// Appends [keyword] to the stored blocked keywords, the reference's 40-char
/// field cap included. The live half is [MessageFilter.addKeyword].
Future<void> addShieldKeyword(String keyword) => _appendShield('shield.keywords', keyword, maxLength: 40);

Future<void> _appendShield(String key, String value, {required int maxLength}) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final capped = trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
  final repository = HiveStorageRepository<List<String>>(
    box: await StorageBoxManager().keyed<List<String>>('settings.shield'),
  );
  final list = List<String>.from(repository.get(key) ?? const <String>[]);
  if (list.contains(capped)) {
    return;
  }
  await repository.save(key, [...list, capped]);
}
