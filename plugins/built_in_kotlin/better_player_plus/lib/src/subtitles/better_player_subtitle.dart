import 'package:better_player_plus/src/core/better_player_utils.dart';

class BetterPlayerSubtitle {
  factory BetterPlayerSubtitle(String value, bool isWebVTT) {
    try {
      if (!value.startsWith('NOTE') && !value.startsWith('LANGUAGE')) {
        final scanner = value.split('\n');
        if (scanner.length == 2) {
          return _handle2LinesSubtitles(scanner);
        }
        if (scanner.length > 2) {
          return _handle3LinesAndMoreSubtitles(scanner, isWebVTT);
        }
      }
    } on Exception catch (_) {
      BetterPlayerUtils.log('Failed to parse subtitle line: $value');
    }
    return BetterPlayerSubtitle._();
  }

  BetterPlayerSubtitle._({this.index, this.start, this.end, this.texts});

  static const String timerSeparator = ' --> ';
  final int? index;
  final Duration? start;
  final Duration? end;
  final List<String>? texts;

  static BetterPlayerSubtitle _handle2LinesSubtitles(List<String> scanner) {
    try {
      if (!scanner.any((p) => p.startsWith('NOTE') || p.startsWith('LANGUAGE'))) {
        final timeSplit = scanner[0].split(timerSeparator);
        if (timeSplit.length == 2) {
          final start = _stringToDuration(timeSplit[0]);
          final end = _stringToDuration(timeSplit[1]);
          final texts = scanner.sublist(1, scanner.length);

          return BetterPlayerSubtitle._(index: -1, start: start, end: end, texts: texts);
        }
      }
    } on Exception catch (_) {
      BetterPlayerUtils.log('Failed to parse subtitle line: $scanner');
    }
    return BetterPlayerSubtitle._();
  }

  static BetterPlayerSubtitle _handle3LinesAndMoreSubtitles(List<String> scanner, bool isWebVTT) {
    try {
      if (!scanner.any((p) => p.startsWith('NOTE') || p.startsWith('LANGUAGE'))) {
        int? index = -1;
        List<String> timeSplit = [];
        int firstLineOfText = 0;
        if (scanner[0].contains(timerSeparator)) {
          timeSplit = scanner[0].split(timerSeparator);
          firstLineOfText = 1;
        } else {
          index = int.tryParse(scanner[0]);
          timeSplit = scanner[1].split(timerSeparator);
          firstLineOfText = 2;
        }

        final start = _stringToDuration(timeSplit[0]);
        final end = _stringToDuration(timeSplit[1]);
        final texts = scanner.sublist(firstLineOfText, scanner.length);
        return BetterPlayerSubtitle._(index: index, start: start, end: end, texts: texts);
      }
    } on Exception catch (_) {
      BetterPlayerUtils.log('Failed to parse subtitle line: $scanner');
    }
    return BetterPlayerSubtitle._();
  }

  static Duration _stringToDuration(String value) {
    try {
      final valueSplit = value.split(' ');
      String componentValue;

      if (valueSplit.length > 1) {
        componentValue = valueSplit[0];
      } else {
        componentValue = value;
      }

      final component = componentValue.split(':');
      // Interpret a missing hour component to mean 00 hours
      if (component.length == 2) {
        component.insert(0, '00');
      } else if (component.length != 3) {
        return Duration.zero;
      }

      final secsAndMillisSplitChar = component[2].contains(',') ? ',' : '.';
      final secsAndMillsSplit = component[2].split(secsAndMillisSplitChar);
      if (secsAndMillsSplit.length != 2) {
        return Duration.zero;
      }

      final result = Duration(
        hours: int.tryParse(component[0])!,
        minutes: int.tryParse(component[1])!,
        seconds: int.tryParse(secsAndMillsSplit[0])!,
        milliseconds: int.tryParse(secsAndMillsSplit[1])!,
      );
      return result;
    } on Exception catch (_) {
      BetterPlayerUtils.log('Failed to process value: $value');
      return Duration.zero;
    }
  }

  @override
  String toString() => 'BetterPlayerSubtitle{index: $index, start: $start, end: $end, texts: $texts}';
}
