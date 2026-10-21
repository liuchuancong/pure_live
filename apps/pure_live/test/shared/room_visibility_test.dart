// The discovery rule, pinned: a carousel never plays, an unpassable
// restriction always hides, and a login or age check hides only while the
// platform has no signed-in account.
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart'
    show LiveRestriction, LiveRoom, LiveStatus, RoomBroadcast, RoomContent;
import 'package:pure_live/shared/rooms/room_visibility.dart';

LiveRoom _room({LiveStatus? liveStatus, LiveRestriction? restriction}) => LiveRoom.normalized(
  platform: 'douyu',
  roomId: '1',
  content: const RoomContent(title: 't'),
  broadcast: RoomBroadcast(liveStatus: liveStatus, restriction: restriction),
);

void main() {
  test('an ordinary live room plays', () {
    expect(cannotPlayHere(_room(liveStatus: LiveStatus.live), signedIn: false), isFalse);
  });

  test('a carousel never plays', () {
    expect(cannotPlayHere(_room(liveStatus: LiveStatus.carousel), signedIn: true), isTrue);
  });

  test('a login check lifts with the platform cookie', () {
    final room = _room(restriction: LiveRestriction.needsLogin);
    expect(cannotPlayHere(room, signedIn: false), isTrue);
    expect(cannotPlayHere(room, signedIn: true), isFalse);
  });

  test('an adult check lifts with the platform cookie', () {
    final room = _room(restriction: LiveRestriction.adult);
    expect(cannotPlayHere(room, signedIn: false), isTrue);
    expect(cannotPlayHere(room, signedIn: true), isFalse);
  });

  test('an unpassable restriction hides even when signed in', () {
    for (final restriction in [
      LiveRestriction.paid,
      LiveRestriction.subscribersOnly,
      LiveRestriction.private,
      LiveRestriction.appOnly,
      LiveRestriction.regionBlocked,
      LiveRestriction.password,
      LiveRestriction.unplayable,
    ]) {
      expect(cannotPlayHere(_room(restriction: restriction), signedIn: true), isTrue, reason: restriction.name);
    }
  });
}
