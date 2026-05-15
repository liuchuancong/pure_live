import 'package:easy_localization/easy_localization.dart';

String i18n(String key, {Map<String, String>? args}) {
  return tr(key, namedArgs: args);
}
