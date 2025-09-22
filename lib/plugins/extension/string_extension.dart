
extension StringExtension on String? {
  bool get isNull => this == null;
  bool get isNullOrEmpty => this == null || this?.trim() == "";

  bool get isNotNullOrEmpty => this != null && this?.trim() != "";

  /// 获取内容，空值选择默认内容
  String getNotNullOrEmptyByDefault(String defaultTxt) {
    if(isNullOrEmpty) {
      return defaultTxt;
    }
    return this!;
  }

  /// 在右边添加 字符串
  String appendTxt(String? txt) {
    if(isNullOrEmpty) {
      return "";
    }
    var tmp = this ?? "";
    if(txt.isNull) {
      return tmp;
    }
    return tmp + txt!;
  }

  /// 在左边添加 字符串
  String appendLeftTxt(String? txt) {
    if(isNullOrEmpty) {
      return "";
    }
    var tmp = this ?? "";
    if(txt.isNull) {
      return tmp;
    }
    return txt! + tmp ;
  }
}