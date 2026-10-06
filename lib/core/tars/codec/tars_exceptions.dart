class TarsDecodeException extends Error {
  String message;
  TarsDecodeException(this.message);

  @override
  String toString() => message;
}

class TarsEncodeException extends Error {
  String message;
  TarsEncodeException(this.message);

  @override
  String toString() => message;
}
