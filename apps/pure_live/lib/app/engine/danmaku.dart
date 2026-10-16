import 'dart:async';

import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';

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
  final session = InteractionSession(
    sources: [source],
    filter: shieldRules.isEmpty ? null : MessageFilter(rules: shieldRules),
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
