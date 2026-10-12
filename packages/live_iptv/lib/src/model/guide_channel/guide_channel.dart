import 'package:freezed_annotation/freezed_annotation.dart';

part 'guide_channel.freezed.dart';

/// A guide channel as a parser read it, before it is stored.
///
/// No JSON: a parsed guide channel is turned into an `EpgChannel` the moment
/// it is saved, so its three fields never cross the storage boundary as
/// themselves, and giving it a `toJson` would invite writing the wrong
/// record.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class GuideChannel with _$GuideChannel {
  /// A parsed guide channel.
  const factory GuideChannel({
    /// The guide's own channel id: `tvg-id` in a playlist matches it.
    required String id,

    /// Every `display-name` of the channel, in file order.
    @Default(<String>[]) List<String> displayNames,

    /// The channel's icon, when the guide names one.
    String? iconUrl,
  }) = _GuideChannel;
}
