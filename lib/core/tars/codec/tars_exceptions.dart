/// Tars 编解码两侧的协议异常，载荷都只有一条消息。
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
