/*
 * @Description: ffi
 * @Author: ekibun
 * @Date: 2020-09-19 10:29:04
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:14:35
 */
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

extension ListFirstWhere<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } on StateError {
      return null;
    }
  }
}

abstract class JSRef {
  int _refCount = 0;
  void dup() {
    _refCount++;
  }

  void free() {
    _refCount--;
    if (_refCount < 0) destroy();
  }

  void destroy();

  static void freeRecursive(dynamic obj) {
    _callRecursive(obj, (ref) => ref.free());
  }

  static void dupRecursive(dynamic obj) {
    _callRecursive(obj, (ref) => ref.dup());
  }

  static void _callRecursive(
    dynamic obj,
    void Function(JSRef) cb, [
    Set? cache,
  ]) {
    if (obj == null) return;
    if (cache == null) cache = Set();
    if (cache.contains(obj)) return;
    if (obj is List) {
      cache.add(obj);
      List.from(obj).forEach((e) => _callRecursive(e, cb, cache));
    }
    if (obj is Map) {
      cache.add(obj);
      obj.values.toList().forEach((e) => _callRecursive(e, cb, cache));
    }
    if (obj is JSRef) {
      cb(obj);
    }
  }
}

abstract class JSRefLeakable {}

class JSEvalFlag {
  static const GLOBAL = 0 << 0;
  static const MODULE = 1 << 0;
}

class JSChannelType {
  static const METHON = 0;
  static const MODULE = 1;
  static const PROMISE_TRACK = 2;
  static const FREE_OBJECT = 3;
}

class JSProp {
  static const CONFIGURABLE = (1 << 0);
  static const WRITABLE = (1 << 1);
  static const ENUMERABLE = (1 << 2);
  static const C_W_E = (CONFIGURABLE | WRITABLE | ENUMERABLE);
}

class JSTag {
  static const FIRST = -11; /* first negative tag */
  static const BIG_DECIMAL = -11;
  static const BIG_INT = -10;
  static const BIG_FLOAT = -9;
  static const SYMBOL = -8;
  static const STRING = -7;
  static const MODULE = -3; /* used internally */
  static const FUNCTION_BYTECODE = -2; /* used internally */
  static const OBJECT = -1;

  static const INT = 0;
  static const BOOL = 1;
  static const NULL = 2;
  static const UNDEFINED = 3;
  static const UNINITIALIZED = 4;
  static const CATCH_OFFSET = 5;
  static const EXCEPTION = 6;
  static const FLOAT64 = 7;
}

abstract base class JSValue extends Opaque {}

abstract base class JSContext extends Opaque {}

abstract base class JSRuntime extends Opaque {}

abstract base class JSPropertyEnum extends Opaque {}

final DynamicLibrary _qjsLib = Platform.environment['FLUTTER_TEST'] == 'true'
    ? (Platform.isWindows
        ? DynamicLibrary.open('quickjs_c_bridge.dll')
        : Platform.isMacOS
            ? DynamicLibrary.process()
            : DynamicLibrary.open(
                Platform.environment['LIBQUICKJSC_TEST_PATH'] ??
                    'libquickjs_c_bridge_plugin.so'))
    : (Platform.isWindows
        ? DynamicLibrary.open('quickjs_c_bridge.dll')
        : (Platform.isLinux
            ? DynamicLibrary.open(Platform.environment['LIBQUICKJSC_PATH'] ??
                'libquickjs_c_bridge_plugin.so')
            : (Platform.isAndroid
                ? DynamicLibrary.open('libfastdev_quickjs_runtime.so')
                : DynamicLibrary.process())));

/// DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> obj,
) jsThrow = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsThrow')
    .asFunction();

/// JSValue *jsEXCEPTION()
final Pointer<JSValue> Function() jsEXCEPTION = _qjsLib
    .lookup<NativeFunction<Pointer<JSValue> Function()>>('jsEXCEPTION')
    .asFunction();

/// JSValue *jsUNDEFINED()
final Pointer<JSValue> Function() jsUNDEFINED = _qjsLib
    .lookup<NativeFunction<Pointer<JSValue> Function()>>('jsUNDEFINED')
    .asFunction();

typedef _JSChannel = Pointer<JSValue> Function(
    Pointer<JSContext> ctx, int method, Pointer<JSValue> argv);
typedef _JSChannelNative = Pointer<JSValue> Function(
    Pointer<JSContext> ctx, IntPtr method, Pointer<JSValue> argv);

/// JSRuntime *jsNewRuntime(JSChannel channel)
final Pointer<JSRuntime> Function(
  Pointer<NativeFunction<_JSChannelNative>>,
  int,
) _jsNewRuntime = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSRuntime> Function(
              Pointer<NativeFunction<_JSChannelNative>>,
              Int64,
            )>>('jsNewRuntime')
    .asFunction();

class _RuntimeOpaque {
  final _JSChannel _channel;
  List<JSRef> _ref = [];
  final ReceivePort _port;
  int? _dartObjectClassId;
  _RuntimeOpaque(this._channel, this._port);

  int? get dartObjectClassId => _dartObjectClassId;

  void addRef(JSRef ref) => _ref.add(ref);

  bool removeRef(JSRef ref) => _ref.remove(ref);

  JSRef? getRef(bool Function(JSRef ref) test) {
    return _ref.firstWhereOrNull(test);
  }
}

final Map<Pointer<JSRuntime>, _RuntimeOpaque> runtimeOpaques = Map();

Pointer<JSValue> channelDispacher(
  Pointer<JSContext> ctx,
  int type,
  Pointer<JSValue> argv,
) {
  final rt = type == JSChannelType.FREE_OBJECT
      ? ctx.cast<JSRuntime>()
      : jsGetRuntime(ctx);
  return runtimeOpaques[rt]!._channel(ctx, type, argv);
}

Pointer<JSRuntime> jsNewRuntime(
  _JSChannel callback,
  int timeout,
  ReceivePort port,
) {
  final rt = _jsNewRuntime(Pointer.fromFunction(channelDispacher), timeout);
  runtimeOpaques[rt] = _RuntimeOpaque(callback, port);
  return rt;
}

/// DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
final void Function(
  Pointer<JSRuntime>,
  int,
) jsSetMaxStackSize = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSRuntime>,
              IntPtr,
            )>>('jsSetMaxStackSize')
    .asFunction();

/// DLLEXPORT void jsSetMemoryLimit(JSRuntime *rt, size_t limit);
final void Function(
  Pointer<JSRuntime>,
  int,
) jsSetMemoryLimit = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSRuntime>,
              IntPtr,
            )>>('jsSetMemoryLimit')
    .asFunction();

/// void jsFreeRuntime(JSRuntime *rt)
final void Function(
  Pointer<JSRuntime>,
) _jsFreeRuntime = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSRuntime>,
            )>>('jsFreeRuntime')
    .asFunction();

void jsFreeRuntime(
  Pointer<JSRuntime> rt,
) {
  final referenceleak = <String>[];
  final opaque = runtimeOpaques[rt];
  if (opaque != null) {
    while (opaque._ref.isNotEmpty) {
      final ref = opaque._ref.first;
      ref.destroy();
      runtimeOpaques[rt]?._ref.remove(ref);
    }
    while (opaque._ref.isNotEmpty) {
      final ref = opaque._ref.first;
      final objStrs = ref.toString().split('\n');
      final objStr = objStrs.length > 0 ? objStrs[0] + " ..." : objStrs[0];
      referenceleak.add(
          "  ${identityHashCode(ref)}\t${ref._refCount + 1}\t${ref.runtimeType.toString()}\t$objStr");
      ref.destroy();
    }
  }
  _jsFreeRuntime(rt);
  if (referenceleak.length > 0) {
    throw ('reference leak:\n    ADDR\tREF\tTYPE\tPROP\n' +
        referenceleak.join('\n'));
  }
}

/// JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> funcData,
) jsNewCFunction = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsNewCFunction')
    .asFunction();

/// JSContext *jsNewContext(JSRuntime *rt)
final Pointer<JSContext> Function(
  Pointer<JSRuntime> rt,
) _jsNewContext = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSContext> Function(
              Pointer<JSRuntime>,
            )>>('jsNewContext')
    .asFunction();

Pointer<JSContext> jsNewContext(Pointer<JSRuntime> rt) {
  final ctx = _jsNewContext(rt);
  if (ctx.address == 0) throw Exception('Context create failed!');
  final runtimeOpaque = runtimeOpaques[rt];
  if (runtimeOpaque == null) throw Exception('Runtime has been released!');
  runtimeOpaque._dartObjectClassId = jsNewClass(ctx, 'DartObject');
  return ctx;
}

/// void jsFreeContext(JSContext *ctx)
final void Function(
  Pointer<JSContext>,
) jsFreeContext = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSContext>,
            )>>('jsFreeContext')
    .asFunction();

/// JSRuntime *jsGetRuntime(JSContext *ctx)
final Pointer<JSRuntime> Function(
  Pointer<JSContext>,
) jsGetRuntime = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSRuntime> Function(
              Pointer<JSContext>,
            )>>('jsGetRuntime')
    .asFunction();

/// JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int eval_flags)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<Utf8> input,
  int inputLen,
  Pointer<Utf8> filename,
  int evalFlags,
) _jsEval = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<Utf8>,
              IntPtr,
              Pointer<Utf8>,
              Int32,
            )>>('jsEval')
    .asFunction();

Pointer<JSValue> jsEval(
  Pointer<JSContext> ctx,
  String input,
  String filename,
  int evalFlags,
) {
  final utf8input = input.toNativeUtf8();
  final utf8filename = filename.toNativeUtf8();
  final val = _jsEval(
    ctx,
    utf8input,
    utf8input.length,
    utf8filename,
    evalFlags,
  );
  malloc.free(utf8input);
  malloc.free(utf8filename);
  runtimeOpaques[jsGetRuntime(ctx)]?._port.sendPort.send(#eval);
  return val;
}

/// DLLEXPORT int32_t jsValueGetTag(JSValue *val)
final int Function(
  Pointer<JSValue> val,
) jsValueGetTag = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSValue>,
            )>>('jsValueGetTag')
    .asFunction();

/// void *jsValueGetPtr(JSValue *val)
final int Function(
  Pointer<JSValue> val,
) jsValueGetPtr = _qjsLib
    .lookup<
        NativeFunction<
            IntPtr Function(
              Pointer<JSValue>,
            )>>('jsValueGetPtr')
    .asFunction();

/// DLLEXPORT bool jsTagIsFloat64(int32_t tag)
final int Function(
  int val,
) jsTagIsFloat64 = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Int32,
            )>>('jsTagIsFloat64')
    .asFunction();

/// JSValue *jsNewBool(JSContext *ctx, int val)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  int val,
) jsNewBool = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Int32,
            )>>('jsNewBool')
    .asFunction();

/// JSValue *jsNewInt64(JSContext *ctx, int64_t val)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  int val,
) jsNewInt64 = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Int64,
            )>>('jsNewInt64')
    .asFunction();

/// JSValue *jsNewFloat64(JSContext *ctx, double val)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  double val,
) jsNewFloat64 = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Double,
            )>>('jsNewFloat64')
    .asFunction();

/// JSValue *jsNewString(JSContext *ctx, const char *str)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<Utf8> str,
) _jsNewString = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<Utf8>,
            )>>('jsNewString')
    .asFunction();

Pointer<JSValue> jsNewString(
  Pointer<JSContext> ctx,
  String str,
) {
  final utf8str = str.toNativeUtf8();
  final jsStr = _jsNewString(ctx, utf8str);
  malloc.free(utf8str);
  return jsStr;
}

/// JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<Uint8> buf,
  int len,
) jsNewArrayBufferCopy = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<Uint8>,
              IntPtr,
            )>>('jsNewArrayBufferCopy')
    .asFunction();

/// JSValue *jsNewArray(JSContext *ctx)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
) jsNewArray = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
            )>>('jsNewArray')
    .asFunction();

/// JSValue *jsNewObject(JSContext *ctx)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
) jsNewObject = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
            )>>('jsNewObject')
    .asFunction();

/// void jsFreeValue(JSContext *ctx, JSValue *val, int32_t free)
final void Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
  int free,
) _jsFreeValue = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
              Int32,
            )>>('jsFreeValue')
    .asFunction();

void jsFreeValue(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val, {
  bool free = true,
}) {
  _jsFreeValue(ctx, val, free ? 1 : 0);
}

/// void jsFreeValue(JSRuntime *rt, JSValue *val, int32_t free)
final void Function(
  Pointer<JSRuntime> rt,
  Pointer<JSValue> val,
  int free,
) _jsFreeValueRT = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSRuntime>,
              Pointer<JSValue>,
              Int32,
            )>>('jsFreeValueRT')
    .asFunction();

void jsFreeValueRT(
  Pointer<JSRuntime> rt,
  Pointer<JSValue> val, {
  bool free = true,
}) {
  _jsFreeValueRT(rt, val, free ? 1 : 0);
}

/// JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsDupValue = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsDupValue')
    .asFunction();

/// JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
final Pointer<JSValue> Function(
  Pointer<JSRuntime> rt,
  Pointer<JSValue> val,
) jsDupValueRT = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSRuntime>,
              Pointer<JSValue>,
            )>>('jsDupValueRT')
    .asFunction();

/// int32_t jsToBool(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsToBool = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsToBool')
    .asFunction();

/// int64_t jsToFloat64(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsToInt64 = _qjsLib
    .lookup<
        NativeFunction<
            Int64 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsToInt64')
    .asFunction();

/// double jsToFloat64(JSContext *ctx, JSValueConst *val)
final double Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsToFloat64 = _qjsLib
    .lookup<
        NativeFunction<
            Double Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsToFloat64')
    .asFunction();

/// const char *jsToCString(JSContext *ctx, JSValue *val)
final Pointer<Utf8> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) _jsToCString = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<Utf8> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsToCString')
    .asFunction();

/// void jsFreeCString(JSContext *ctx, const char *ptr)
final void Function(
  Pointer<JSContext> ctx,
  Pointer<Utf8> val,
) jsFreeCString = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSContext>,
              Pointer<Utf8>,
            )>>('jsFreeCString')
    .asFunction();

String jsToCString(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) {
  final ptr = _jsToCString(ctx, val);
  if (ptr.address == 0) throw Exception('JSValue cannot convert to string');
  final str = ptr.toDartString();
  jsFreeCString(ctx, ptr);
  return str;
}

/// DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<Utf8> name,
) _jsNewClass = _qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
              Pointer<JSContext>,
              Pointer<Utf8>,
            )>>('jsNewClass')
    .asFunction();

int jsNewClass(
  Pointer<JSContext> ctx,
  String name,
) {
  final utf8name = name.toNativeUtf8();
  final val = _jsNewClass(
    ctx,
    utf8name,
  );
  malloc.free(utf8name);
  return val;
}

/// DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  int classId,
  int opaque,
) jsNewObjectClass = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Uint32,
              IntPtr,
            )>>('jsNewObjectClass')
    .asFunction();

/// DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid)
final int Function(
  Pointer<JSValue> obj,
  int classid,
) jsGetObjectOpaque = _qjsLib
    .lookup<
        NativeFunction<
            IntPtr Function(
              Pointer<JSValue>,
              Uint32,
            )>>('jsGetObjectOpaque')
    .asFunction();

/// uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
final Pointer<Uint8> Function(
  Pointer<JSContext> ctx,
  Pointer<IntPtr> psize,
  Pointer<JSValue> val,
) jsGetArrayBuffer = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<Uint8> Function(
              Pointer<JSContext>,
              Pointer<IntPtr>,
              Pointer<JSValue>,
            )>>('jsGetArrayBuffer')
    .asFunction();

/// int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsIsFunction = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsIsFunction')
    .asFunction();

/// int32_t jsIsPromise(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsIsPromise = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsIsPromise')
    .asFunction();

/// int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsIsArray = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsIsArray')
    .asFunction();

/// DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValueConst *val);
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsIsError = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsIsError')
    .asFunction();

/// DLLEXPORT JSValue *jsNewError(JSContext *ctx);
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
) jsNewError = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
            )>>('jsNewError')
    .asFunction();

/// JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> thisObj,
  int prop,
) jsGetProperty = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
              Uint32,
            )>>('jsGetProperty')
    .asFunction();

/// int jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop, JSValue *val, int flags)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> thisObj,
  int prop,
  Pointer<JSValue> val,
  int flag,
) jsDefinePropertyValue = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
              Uint32,
              Pointer<JSValue>,
              Int32,
            )>>('jsDefinePropertyValue')
    .asFunction();

/// void jsFreeAtom(JSContext *ctx, JSAtom v)
final void Function(
  Pointer<JSContext> ctx,
  int v,
) jsFreeAtom = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSContext>,
              Uint32,
            )>>('jsFreeAtom')
    .asFunction();

/// JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val,
) jsValueToAtom = _qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsValueToAtom')
    .asFunction();

/// JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  int val,
) jsAtomToValue = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Uint32,
            )>>('jsAtomToValue')
    .asFunction();

/// int jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
///                           uint32_t *plen, JSValueConst *obj, int flags)
final int Function(
  Pointer<JSContext> ctx,
  Pointer<Pointer<JSPropertyEnum>> ptab,
  Pointer<Uint32> plen,
  Pointer<JSValue> obj,
  int flags,
) jsGetOwnPropertyNames = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSContext>,
              Pointer<Pointer<JSPropertyEnum>>,
              Pointer<Uint32>,
              Pointer<JSValue>,
              Int32,
            )>>('jsGetOwnPropertyNames')
    .asFunction();

/// JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int i)
final int Function(
  Pointer<JSPropertyEnum> ptab,
  int i,
) jsPropertyEnumGetAtom = _qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
              Pointer<JSPropertyEnum>,
              Int32,
            )>>('jsPropertyEnumGetAtom')
    .asFunction();

/// uint32_t sizeOfJSValue()
final int Function() _sizeOfJSValue = _qjsLib
    .lookup<NativeFunction<Uint32 Function()>>('sizeOfJSValue')
    .asFunction();

final sizeOfJSValue = _sizeOfJSValue();

/// void setJSValueList(JSValue *list, int i, JSValue *val)
final void Function(
  Pointer<JSValue> list,
  int i,
  Pointer<JSValue> val,
) setJSValueList = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSValue>,
              Uint32,
              Pointer<JSValue>,
            )>>('setJSValueList')
    .asFunction();

/// JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
///                 int argc, JSValueConst *argv)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> funcObj,
  Pointer<JSValue> thisObj,
  int argc,
  Pointer<JSValue> argv,
) _jsCall = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
              Pointer<JSValue>,
              Int32,
              Pointer<JSValue>,
            )>>('jsCall')
    .asFunction();

Pointer<JSValue> jsCall(
  Pointer<JSContext> ctx,
  Pointer<JSValue> funcObj,
  Pointer<JSValue> thisObj,
  List<Pointer<JSValue>> argv,
) {
  final jsArgs = calloc<Uint8>(
    argv.length > 0 ? sizeOfJSValue * argv.length : 1,
  ).cast<JSValue>();
  for (int i = 0; i < argv.length; ++i) {
    Pointer<JSValue> jsArg = argv[i];
    setJSValueList(jsArgs, i, jsArg);
  }
  final func1 = jsDupValue(ctx, funcObj);
  final _thisObj = thisObj;
  final jsRet = _jsCall(ctx, funcObj, _thisObj, argv.length, jsArgs);
  jsFreeValue(ctx, func1);
  malloc.free(jsArgs);
  runtimeOpaques[jsGetRuntime(ctx)]?._port.sendPort.send(#call);
  return jsRet;
}

/// int jsIsException(JSValueConst *val)
final int Function(
  Pointer<JSValue> val,
) jsIsException = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSValue>,
            )>>('jsIsException')
    .asFunction();

/// JSValue *jsGetException(JSContext *ctx)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
) jsGetException = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
            )>>('jsGetException')
    .asFunction();

/// int jsExecutePendingJob(JSRuntime *rt)
final int Function(
  Pointer<JSRuntime> ctx,
) jsExecutePendingJob = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
              Pointer<JSRuntime>,
            )>>('jsExecutePendingJob')
    .asFunction();

/// JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
final Pointer<JSValue> Function(
  Pointer<JSContext> ctx,
  Pointer<JSValue> resolvingFuncs,
) jsNewPromiseCapability = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<JSValue> Function(
              Pointer<JSContext>,
              Pointer<JSValue>,
            )>>('jsNewPromiseCapability')
    .asFunction();

/// void jsFree(JSContext *ctx, void *ptab)
final void Function(
  Pointer<JSContext> ctx,
  Pointer<JSPropertyEnum> ptab,
) jsFree = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<JSContext>,
              Pointer<JSPropertyEnum>,
            )>>('jsFree')
    .asFunction();
