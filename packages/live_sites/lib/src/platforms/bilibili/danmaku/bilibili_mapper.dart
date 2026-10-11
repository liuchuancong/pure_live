import 'package:live_sites/src/models/live_gift.dart';
import 'package:live_sites/src/models/live_message.dart';

/// Maps decoded Bilibili notice payloads into common [LiveMessage]s.
///
/// Recognised commands: `DANMU_MSG` (chat), `WATCHED_CHANGE` (audience),
/// `STOP` / `PREPARING` (stream ended), `LIVE` (stream started). Unknown
/// commands are skipped — the platform adds new ones constantly and an
/// unknown command is never an error.
abstract final class BilibiliDanmakuMapper {
  /// Maps a notice JSON object; null for commands this mapper does not
  /// model.
  static LiveMessage? notice(Object? notice) {
    if (notice is! Map<String, Object?>) {
      return null;
    }
    final cmd = notice['cmd']?.toString() ?? '';
    if (cmd.startsWith('DANMU_MSG')) {
      return _danmu(notice);
    }
    return switch (cmd) {
      'WATCHED_CHANGE' => _watchedChange(notice),
      'PREPARING' || 'STOP' => const LiveMessage(type: LiveMessageType.notice, userName: '', message: 'stream ended'),
      'LIVE' => const LiveMessage(type: LiveMessageType.notice, userName: '', message: 'stream started'),
      _ => null,
    };
  }

  /// `DANMU_MSG`: `info[1]` text, `info[2][1]` name, `info[2][0]` uid,
  /// `info[2][7]` fan badge level, `info[0][15].user.median` … the color
  /// lives at `info[0][3]` in most generations.
  static LiveMessage? _danmu(Map<String, Object?> notice) {
    final info = notice['info'];
    if (info is! List || info.length < 3) {
      return null;
    }
    final meta = info[0];
    final metaColor = meta is List && meta.length > 3 ? (meta[3] as num?)?.toInt() : null;
    final sender = info[2];
    final text = info[1]?.toString() ?? '';
    if (sender is! List || sender.length < 2) {
      return LiveMessage(type: LiveMessageType.chat, userName: '', message: text, color: metaColor);
    }
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: sender[1]?.toString() ?? '',
      userId: sender[0]?.toString(),
      message: text,
      color: metaColor,
      emotes: extractEmotes(text),
    );
  }

  /// `WATCHED_CHANGE`: `data.num` watchers.
  static LiveMessage? _watchedChange(Map<String, Object?> notice) {
    final data = notice['data'];
    final value = data is Map<String, Object?> ? data['num'] : null;
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: 'watched change',
      data: LiveAudienceUpdate(watching: (value as num?)?.toInt()),
    );
  }

  /// Extracts `[emote]` placeholders from [text] against the built-in
  /// bilibili emote table.
  static List<LiveEmote> extractEmotes(String text) {
    if (!text.contains('[')) {
      return const [];
    }
    final out = <LiveEmote>[];
    for (final match in RegExp(r'\[([^\[\]]{1,32})\]').allMatches(text)) {
      final code = match.group(1);
      final url = code == null ? null : _emoteTable[code];
      if (url != null) {
        out.add(LiveEmote(code: '[$code]', url: url));
      }
    }
    return out;
  }
}

/// A starter slice of the bilibili small-emote table; the full table
/// arrives with the emote-metadata migration.
const Map<String, String> _emoteTable = {
  '妙啊': 'https://i0.hdslb.com/bfs/emote/9c0965a3cf967e23b7b2b7ae4e4e6e5f.png',
  'CPU': 'https://i0.hdslb.com/bfs/emote/e01e15ca963ae08d0db8a5d4f4e0f4f0.png',
};
