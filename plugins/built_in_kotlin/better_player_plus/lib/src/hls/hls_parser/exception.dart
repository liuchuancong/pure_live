class ParserException implements Exception {
  ParserException(this.message) : super();

  final String message;

  @override
  String toString() => 'SignalException: $message';
}

class UnrecognizedInputFormatException extends ParserException {
  UnrecognizedInputFormatException(super.message, this.uri);

  final Uri? uri;
}
