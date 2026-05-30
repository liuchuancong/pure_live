import 'dart:convert';

class HuyaEmojiModel {
  final String sId;
  final String sName;
  final String sEscape;
  final String sUrl;
  final String sFlexiUrl;
  final String sExtraUrl;
  final String sExtraFlexiUrl;
  final int iType;
  final int lPackageId;
  final int iFrameSize;
  final int iPrice;
  final String localFile;

  HuyaEmojiModel({
    required this.sId,
    required this.sName,
    required this.sEscape,
    required this.sUrl,
    required this.sFlexiUrl,
    required this.sExtraUrl,
    required this.sExtraFlexiUrl,
    required this.iType,
    required this.lPackageId,
    required this.iFrameSize,
    required this.iPrice,
    required this.localFile,
  });

  factory HuyaEmojiModel.fromJson(Map<String, dynamic> json) {
    return HuyaEmojiModel(
      sId: json['sId'] ?? '',
      sName: json['sName'] ?? '',
      sEscape: json['sEscape'] ?? '',
      sUrl: json['sUrl'] ?? '',
      sFlexiUrl: json['sFlexiUrl'] ?? '',
      sExtraUrl: json['sExtraUrl'] ?? '',
      sExtraFlexiUrl: json['sExtraFlexiUrl'] ?? '',
      iType: json['iType'] ?? 0,
      lPackageId: json['lPackageId'] ?? 0,
      iFrameSize: json['iFrameSize'] ?? 0,
      iPrice: json['iPrice'] ?? 0,
      localFile: json['local_file'] ?? '',
    );
  }

  static Map<String, HuyaEmojiModel> parseEmojiRegistry(String rawJsonStr) {
    final Map<String, dynamic> decoded = jsonDecode(rawJsonStr);
    return decoded.map((key, value) => MapEntry(key, HuyaEmojiModel.fromJson(value as Map<String, dynamic>)));
  }
}
