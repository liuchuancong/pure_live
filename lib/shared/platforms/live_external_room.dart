import 'package:pure_live/core/models/live_room.dart';

class RoomExternalTarget {
  const RoomExternalTarget({required this.web, this.native});

  final String web;
  final String? native;
}

abstract interface class LiveSiteExternalRoomResolver {
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom);
}

String? sanitizedExternalRoomId(String? value) {
  final id = value?.trim();
  if (id == null || id.isEmpty || id == '.' || id == '..' || RegExp(r'[\s\x00-\x1f/\\?#%]').hasMatch(id)) {
    return null;
  }
  return id;
}

RoomExternalTarget? officialExternalRoom(String Function() build) {
  try {
    return RoomExternalTarget(web: build());
  } on FormatException {
    return null;
  }
}
