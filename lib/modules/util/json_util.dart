import 'dart:convert';

class JsonUtil<T> {
  static dynamic decode(dynamic data) {
    if (data.runtimeType == String) {
      return json.decode(data);
    }
    return data;
  }
}
