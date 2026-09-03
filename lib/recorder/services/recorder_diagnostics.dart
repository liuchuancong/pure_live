class RecorderDiagnostics {
  const RecorderDiagnostics._();

  /// Produces a short, persistable diagnostic without stream credentials.
  ///
  /// Platform SDK exceptions often include the full signed CDN URL, cookies
  /// or query tokens. Recording tasks survive restarts, so raw exceptions must
  /// never be copied into Hive or shown in screenshots of the task list.
  static String sanitize(Object? value, {int maxLength = 320}) {
    var text = value?.toString() ?? '';
    text = text
        .replaceAll(
          RegExp(r'(?:https?|rtmps?|rtsp|srt|udp|rtp)://[^\s\]\)\}]+', caseSensitive: false),
          '[stream-url]',
        )
        .replaceAll(
          RegExp(r'(?:(?:cookie|authorization)\s*[:=]\s*)[^\r\n]+', caseSensitive: false),
          '[credential]',
        )
        .replaceAllMapped(
          RegExp(
            r'(^|[?&\s])((?:access_)?token|sign|auth|key|wssecret|txsecret)=([^&\s]+)',
            caseSensitive: false,
            multiLine: true,
          ),
          (match) => '${match.group(1)}${match.group(2)}=[redacted]',
        )
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > maxLength) text = '${text.substring(0, maxLength - 1)}…';
    return text;
  }
}
