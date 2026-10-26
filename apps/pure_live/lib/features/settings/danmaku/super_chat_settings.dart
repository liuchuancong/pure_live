import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// Whether memberships and subscriptions also get a card among the room's
/// super chats (the reference's `superChatIncludesMembership`, on by
/// default): bilibili guards, YouTube memberships and the subscriptions of
/// the other platforms. The chat list keeps its one line either way.
const String kSuperChatIncludesMembershipKey = 'danmaku.superChatIncludesMembership';

/// Owns the membership-cards switch; on by default, the reference's value.
final class SuperChatIncludesMembershipController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kSuperChatIncludesMembershipKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kSuperChatIncludesMembershipKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The super chat board's membership-cards switch.
final superChatIncludesMembershipProvider = NotifierProvider<SuperChatIncludesMembershipController, bool>(
  SuperChatIncludesMembershipController.new,
);
