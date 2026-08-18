/*
 * @Description: wrap object
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
part of './quickjs_runtime2.dart';

/// js invokable
abstract class JSInvokable extends JSRef {
  dynamic invoke(List args, [dynamic thisVal]);

  static dynamic _wrap(dynamic func) {
    return func is JSInvokable
        ? func
        : func is Function
            ? _DartFunction(func)
            : func;
  }
}

class _DartFunction extends JSInvokable {
  final Function _func;
  _DartFunction(this._func);

  @override
  invoke(List args, [thisVal]) {
    /// wrap this into function
    final passThis =
        RegExp('{.*thisVal.*}').hasMatch(_func.runtimeType.toString());
    final ret =
        Function.apply(_func, args, passThis ? {#thisVal: thisVal} : null);
    JSRef.freeRecursive(args);
    JSRef.freeRecursive(thisVal);
    return ret;
  }

  @override
  String toString() {
    return _func.toString();
  }

  @override
  destroy() {}
}

/// implement this to capture js object release.
class _DartObject extends JSRef implements JSRefLeakable {
  Object? _obj;
  Pointer<JSContext>? _ctx;
  _DartObject(Pointer<JSContext> ctx, dynamic obj) {
    _ctx = ctx;
    _obj = obj;
    if (obj is JSRef) obj.dup();
    runtimeOpaques[jsGetRuntime(ctx)]?.addRef(this);
  }

  static _DartObject? fromAddress(Pointer<JSRuntime> rt, int val) {
    return runtimeOpaques[rt]?.getRef((e) => identityHashCode(e) == val)
        as _DartObject?;
  }

  @override
  String toString() {
    if (_ctx == null) return "DartObject(released)";
    return _obj.toString();
  }

  @override
  void destroy() {
    final ctx = _ctx;
    final obj = _obj;
    _ctx = null;
    _obj = null;
    if (ctx == null) return;
    runtimeOpaques[jsGetRuntime(ctx)]?.removeRef(this);
    if (obj is JSRef) obj.free();
  }
}

/// JS Error wrapper
class JSError extends _IsolateEncodable {
  late String message;
  late String stack;
  JSError(message, [stack]) {
    if (message is JSError) {
      this.message = message.message;
      this.stack = message.stack;
    } else {
      this.message = message.toString();
      this.stack = (stack ?? StackTrace.current).toString();
    }
  }

  @override
  String toString() {
    return stack.isEmpty ? message.toString() : "$message\n$stack";
  }

  static JSError? _decode(Map obj) {
    if (obj.containsKey(#jsError))
      return JSError(obj[#jsError], obj[#jsErrorStack]);
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsError: message,
      #jsErrorStack: stack,
    };
  }
}

/// JS Object reference
/// call [release] to release js object.
class _JSObject extends JSRef {
  Pointer<JSValue>? _val;
  Pointer<JSContext>? _ctx;

  /// Create
  _JSObject(Pointer<JSContext> ctx, Pointer<JSValue> val) {
    this._ctx = ctx;
    final rt = jsGetRuntime(ctx);
    this._val = jsDupValue(ctx, val);
    runtimeOpaques[rt]?.addRef(this);
  }

  @override
  void destroy() {
    final ctx = _ctx;
    final val = _val;
    _val = null;
    _ctx = null;
    if (ctx == null || val == null) return;
    final rt = jsGetRuntime(ctx);
    runtimeOpaques[rt]?.removeRef(this);
    jsFreeValue(ctx, val);
  }

  @override
  String toString() {
    if (_ctx == null || _val == null) return "JSObject(released)";
    return jsToCString(_ctx!, _val!);
  }
}

/// JS function wrapper
class _JSFunction extends _JSObject implements JSInvokable, _IsolateEncodable {
  _JSFunction(Pointer<JSContext> ctx, Pointer<JSValue> val) : super(ctx, val);

  @override
  invoke(List<dynamic> arguments, [dynamic thisVal]) {
    final jsRet = _invoke(arguments, thisVal);
    final ctx = _ctx!;
    bool isException = jsIsException(jsRet) != 0;
    if (isException) {
      jsFreeValue(ctx, jsRet);
      throw _parseJSException(ctx);
    }
    final ret = _jsToDart(ctx, jsRet);
    jsFreeValue(ctx, jsRet);
    return ret;
  }

  Pointer<JSValue> _invoke(List<dynamic> arguments, [dynamic thisVal]) {
    final ctx = _ctx;
    final val = _val;
    if (ctx == null || val == null)
      throw JSError("InternalError: JSValue released");
    final args = arguments
        .map(
          (e) => _dartToJs(ctx, e),
        )
        .toList();
    final jsThis = _dartToJs(ctx, thisVal);
    final jsRet = jsCall(ctx, val, jsThis, args);
    jsFreeValue(ctx, jsThis);
    for (final jsArg in args) {
      jsFreeValue(ctx, jsArg);
    }
    return jsRet;
  }

  @override
  Map _encode() {
    return IsolateFunction._new(this)._encode();
  }
}

/// Dart function wrapper for isolate
class IsolateFunction extends JSInvokable implements _IsolateEncodable {
  int? _isolateId;
  SendPort? _port;
  JSInvokable? _invokable;
  IsolateFunction._fromId(this._isolateId, this._port);

  IsolateFunction._new(this._invokable) {
    _handlers.add(this);
  }
  IsolateFunction(Function func) : this._new(_DartFunction(func));

  static ReceivePort? _invokeHandler;
  static Set<IsolateFunction> _handlers = Set();

  static get _handlePort {
    if (_invokeHandler == null) {
      _invokeHandler = ReceivePort();
      _invokeHandler!.listen((msg) async {
        final msgPort = msg[#port];
        try {
          final handler = _handlers.firstWhereOrNull(
            (v) => identityHashCode(v) == msg[#handler],
          );
          if (handler == null) throw JSError('handler released');
          final ret = _encodeData(await handler._handle(msg[#msg]));
          if (msgPort != null) msgPort.send(ret);
        } catch (e) {
          final err = _encodeData(e);
          if (msgPort != null)
            msgPort.send({
              #error: err,
            });
        }
      });
    }
    return _invokeHandler!.sendPort;
  }

  _send(msg) async {
    final port = _port;
    if (port == null) return _handle(msg);
    final evaluatePort = ReceivePort();
    port.send({
      #handler: _isolateId,
      #msg: msg,
      #port: evaluatePort.sendPort,
    });
    final result = await evaluatePort.first;
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error]);
    return _decodeData(result);
  }

  _destroy() {
    _handlers.remove(this);
    _invokable?.free();
    _invokable = null;
  }

  _handle(msg) async {
    switch (msg) {
      case #dup:
        _refCount++;
        return null;
      case #free:
        _refCount--;
        if (_refCount < 0) _destroy();
        return null;
      case #destroy:
        _destroy();
        return null;
    }
    final List args = _decodeData(msg[#args]);
    final thisVal = _decodeData(msg[#thisVal]);
    return _invokable?.invoke(args, thisVal);
  }

  @override
  Future invoke(List positionalArguments, [thisVal]) async {
    final List dArgs = _encodeData(positionalArguments);
    final dThisVal = _encodeData(thisVal);
    return _send({
      #args: dArgs,
      #thisVal: dThisVal,
    });
  }

  static IsolateFunction? _decode(Map obj) {
    if (obj.containsKey(#jsFunctionPort))
      return IsolateFunction._fromId(
        obj[#jsFunctionId],
        obj[#jsFunctionPort],
      );
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsFunctionId: _isolateId ?? identityHashCode(this),
      #jsFunctionPort: _port ?? IsolateFunction._handlePort,
    };
  }

  int _refCount = 0;

  @override
  dup() {
    _send(#dup);
  }

  @override
  free() {
    _send(#free);
  }

  @override
  void destroy() {
    _send(#destroy);
  }
}
