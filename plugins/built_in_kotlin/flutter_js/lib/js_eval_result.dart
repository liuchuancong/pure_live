class JsEvalResult {
  final String stringResult;
  final dynamic rawResult;
  final bool isPromise;
  final bool isError;

  JsEvalResult(this.stringResult, this.rawResult,
      {this.isError = false, this.isPromise = false});

  toString() => stringResult;
}
