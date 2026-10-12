/// The guide formats a source can deliver.
enum GuideFormat {
  /// XMLTV — the format the ecosystem agrees on (`.xml`, and gzipped it is
  /// still XMLTV once decompressed).
  xmltv,

  /// A JSON guide: the object shape an API delivers directly.
  json;

  /// The format of [text]: a JSON object or array is [json], everything else
  /// XMLTV.
  ///
  /// Decided from the content rather than the file name: sources serve
  /// XMLTV from URLs ending in `.php`, and a source whose extension lies
  /// would otherwise never parse.
  static GuideFormat detect(String text) {
    final start = text.trimLeft();
    return start.startsWith('{') || start.startsWith('[') ? json : xmltv;
  }
}
