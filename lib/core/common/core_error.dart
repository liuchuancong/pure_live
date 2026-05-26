import 'package:pure_live/plugins/locale_helper.dart';

class HttpError extends Error {
  final int statusCode;
  final String message;

  HttpError(this.message, {this.statusCode = 0});

  @override
  String toString() {
    if (statusCode != 0) {
      return statusCodeToString(statusCode);
    }
    return message;
  }

  String statusCodeToString(int statusCode) {
    switch (statusCode) {
      case 400:
        return i18n("http_error_400");
      case 401:
        return i18n("http_error_401");
      case 403:
        return i18n("http_error_403");
      case 404:
        return i18n("http_error_404");
      case 500:
        return i18n("http_error_500");
      case 502:
        return i18n("http_error_502");
      case 503:
        return i18n("http_error_503");
      default:
        return i18n("http_error_default", args: {"statusCode": statusCode.toString()});
    }
  }
}
