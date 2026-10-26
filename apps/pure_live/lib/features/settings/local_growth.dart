import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;

/// The growth numbers the reference uses (D08.3): watching earns once per
/// [watchStep] up to a day's cap, the first room of the day checks in, and a
/// local danmaku earns a little experience.
abstract final class LocalGrowthRules {
  /// Playing time that earns one step.
  static const Duration watchStep = Duration(minutes: 10);

  /// Experience one watch step gives.
  static const int watchExperience = 10;

  /// Coins one watch step gives.
  static const int watchCoins = 20;

  /// The most experience watching gives a day; past it, neither experience
  /// nor coins follow until the next day.
  static const int watchDailyExperience = 300;

  /// The first room of the day's experience.
  static const int checkInExperience = 20;

  /// The first room of the day's coins.
  static const int checkInCoins = 100;

  /// Experience one local danmaku gives.
  static const int chatExperience = 1;

  /// The most experience local danmaku give a day.
  static const int chatDailyExperience = 50;
}

/// What local growth gave on one local day (the reference's
/// `localInteraction.growthDay`, stored as JSON): counts of another day
/// read as nothing given, so a new day starts from zero without a midnight
/// job.
@immutable
final class LocalGrowthDay {
  /// Creates the counts of [day] (`yyyy-MM-dd`).
  const LocalGrowthDay({
    required this.day,
    this.watched = Duration.zero,
    this.watchExperience = 0,
    this.checkedIn = false,
    this.chatExperience = 0,
  });

  /// Today's empty counts.
  factory LocalGrowthDay.today([DateTime? at]) => LocalGrowthDay(day: dayOf(at ?? DateTime.now()));

  /// The counts stored in [json] when they belong to [at]'s day, otherwise
  /// nothing given.
  factory LocalGrowthDay.read(String? json, {DateTime? at}) {
    final day = dayOf(at ?? DateTime.now());
    final stored = parse(json);
    return stored != null && stored.day == day ? stored : LocalGrowthDay(day: day);
  }

  /// The counts in [json] whatever their day; null when none or unreadable
  /// (a hand-edited backup). Negative numbers read as zero.
  static LocalGrowthDay? parse(String? json) {
    if (json == null || json.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final data = decoded;
    final day = data['day'];
    if (day is! String || day.isEmpty) return null;
    int number(String key) => switch (data[key]) {
      final num value when value > 0 => value.toInt(),
      _ => 0,
    };
    return LocalGrowthDay(
      day: day,
      watched: Duration(milliseconds: number('watchedMs')),
      watchExperience: number('watchExp'),
      checkedIn: data['checkedIn'] == true,
      chatExperience: number('chatExp'),
    );
  }

  /// The device's local day of [at], `yyyy-MM-dd`.
  static String dayOf(DateTime at) {
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
  }

  /// The local day these counts belong to.
  final String day;

  /// How long a room played that day.
  final Duration watched;

  /// The experience watching gave that day.
  final int watchExperience;

  /// Whether the first room of the day gave its check-in.
  final bool checkedIn;

  /// The experience local danmaku gave that day.
  final int chatExperience;

  /// A copy with the given fields replaced.
  LocalGrowthDay copyWith({
    Duration? watched,
    int? watchExperience,
    bool? checkedIn,
    int? chatExperience,
  }) => LocalGrowthDay(
    day: day,
    watched: watched ?? this.watched,
    watchExperience: watchExperience ?? this.watchExperience,
    checkedIn: checkedIn ?? this.checkedIn,
    chatExperience: chatExperience ?? this.chatExperience,
  );

  /// The stored form.
  String encode() => jsonEncode({
    'day': day,
    'watchedMs': watched.inMilliseconds,
    'watchExp': watchExperience,
    'checkedIn': checkedIn,
    'chatExp': chatExperience,
  });

  @override
  bool operator ==(Object other) => other is LocalGrowthDay && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
