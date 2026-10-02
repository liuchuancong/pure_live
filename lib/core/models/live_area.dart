import 'dart:convert';

class LiveArea {
  String? platform = '';
  String? areaType = '';
  String? typeName = '';
  String? areaId = '';
  String? areaName = '';
  String? areaPic = '';
  String? shortName = '';

  LiveArea({this.platform, this.areaType, this.typeName, this.areaId, this.areaName, this.areaPic, this.shortName});

  LiveArea.fromJson(Map<String, dynamic> json)
    : platform = json['platform'] ?? '',
      areaType = json['areaType'] ?? '',
      typeName = json['typeName'] ?? '',
      areaId = json['areaId'] ?? '',
      areaName = json['areaName'] ?? '',
      areaPic = json['areaPic'] ?? '',
      shortName = json['shortName'] ?? '';

  /// Stable collection identity, not object equality: this model is mutable.
  String? get identityKey => identityKeyFor(platform: platform, areaId: areaId, areaType: areaType);

  bool hasSameIdentity(LiveArea other) {
    final key = identityKey;
    return key != null && key == other.identityKey;
  }

  /// Legacy sites identify categories by platform and ID, independently of
  /// parent taxonomy. IPTV likewise resolves globally unique channel IDs.
  /// Missevan catalog IDs and tag IDs are separate API namespaces.
  static String? identityKeyFor({String? platform, String? areaId, String? areaType}) {
    final site = platform?.trim().toLowerCase() ?? '';
    final id = areaId?.trim() ?? '';
    if (site.isEmpty || id.isEmpty) return null;
    final namespace = site == 'missevan' ? areaType?.trim().toLowerCase() ?? '' : '';
    return jsonEncode([site, namespace, id]);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'platform': platform,
    'areaType': areaType,
    'typeName': typeName,
    'areaId': areaId,
    'areaName': areaName,
    'areaPic': areaPic,
    'shortName': shortName,
  };
}
