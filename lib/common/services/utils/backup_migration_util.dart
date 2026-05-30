import 'dart:convert';

class BackupMigrationUtil {
  static List<T> parseObjectList<T>(dynamic data, T Function(Map<String, dynamic>) factory) {
    if (data == null || data is! List) {
      return [];
    }

    return data.map<T>((item) {
      if (item is String) {
        return factory(Map<String, dynamic>.from(jsonDecode(item)));
      }

      if (item is Map) {
        return factory(Map<String, dynamic>.from(item));
      }

      throw Exception('Unsupported backup item type: ${item.runtimeType}');
    }).toList();
  }
}
