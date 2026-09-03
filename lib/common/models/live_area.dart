class LiveArea {
  String? platform = '';
  String? areaType = '';
  String? typeName = '';
  String? areaId = '';
  String? areaName = '';
  String? areaPic = '';
  String? shortName = '';

  LiveArea({
    this.platform,
    this.areaType,
    this.typeName,
    this.areaId,
    this.areaName,
    this.areaPic,
    this.shortName,
  });

  LiveArea.fromJson(Map<String, dynamic> json)
    : platform = json['platform'] ?? '',
      areaType = json['areaType'] ?? '',
      typeName = json['typeName'] ?? '',
      areaId = json['areaId'] ?? '',
      areaName = json['areaName'] ?? '',
      areaPic = json['areaPic'] ?? '',
      shortName = json['shortName'] ?? '';

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
