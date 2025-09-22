extension MapExtension on Map? {
  Map<String, String> toStringMap() {
    if (this == null) {
      return {};
    }
    var keys2 = this?.keys;
    if (keys2 == null) {
      return {};
    }
    Map<String, String> map = {};
    for (var key in keys2) {
      map[key.toString()] = this![key].toString();
    }
    return map;
  }
}
