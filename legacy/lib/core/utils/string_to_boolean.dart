extension TextUtilsNullableStringExtension on String? {
  bool get isNull => this == null;

  bool get isNullOrEmpty => this == null || this!.trim().isEmpty;

  bool get isNotNullOrEmpty => this != null && this!.trim().isNotEmpty;

  bool toBoolean() {
    if (isNullOrEmpty) return false;
    return this!.toLowerCase() == "true";
  }

  String getNotNullOrEmptyByDefault(String defaultTxt) {
    if (isNullOrEmpty) {
      return defaultTxt;
    }
    return this!;
  }

  String appendTxt(String? txt) {
    if (isNullOrEmpty) {
      return "";
    }
    final tmp = this!;
    if (txt.isNull) {
      return tmp;
    }
    return tmp + txt!;
  }

  String appendLeftTxt(String? txt) {
    if (isNullOrEmpty) {
      return "";
    }
    final tmp = this!;
    if (txt.isNull) {
      return tmp;
    }
    return txt! + tmp;
  }
}

extension TextUtilsStringExtension on String {
  bool toBoolean() {
    return toLowerCase() == "true";
  }

  String getNotNullOrEmptyByDefault(String defaultTxt) {
    if (trim().isEmpty) {
      return defaultTxt;
    }
    return this;
  }

  String appendTxt(String? txt) {
    if (trim().isEmpty) return "";
    if (txt == null) return this;
    return this + txt;
  }

  String appendLeftTxt(String? txt) {
    if (trim().isEmpty) return "";
    if (txt == null) return this;
    return txt + this;
  }
}
