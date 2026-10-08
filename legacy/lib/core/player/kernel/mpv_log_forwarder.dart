import 'dart:async';
import 'dart:developer' as developer;

import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;

final Expando<StreamSubscription<mk.PlayerLog>> _forwarders = Expando<StreamSubscription<mk.PlayerLog>>();

void attachMpvLogForwarder(mk.Player player) {
  if (_forwarders[player] != null) return;
  _forwarders[player] = player.stream.log.listen((entry) {
    developer.log('${entry.prefix}/${entry.level}: ${entry.text}', name: 'mpv');
  });
}
