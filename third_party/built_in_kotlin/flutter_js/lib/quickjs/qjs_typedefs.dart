import 'dart:ffi';

import 'package:flutter_js/quickjs/utf8_null_terminated.dart';

final class JSContext extends Struct {
  @Uint8()
  external int char;
}

final class JSRuntime extends Struct {
  @Uint8()
  external int char;
}

final class JSValueConst extends Struct {
  @Uint8()
  external int char;
}

const int JS_EVAL_TYPE_GLOBAL = 0;
const int JS_EVAL_TYPE_MODULE = 1;
const int JS_EVAL_TYPE_DIRECT = 2;
const int JS_EVAL_TYPE_INDIRECT = 3;

enum QuickJSTypeModule {
  JS_EVAL_TYPE_GLOBAL,
  JS_EVAL_TYPE_MODULE,
  JS_EVAL_TYPE_DIRECT,
  JS_EVAL_TYPE_INDIRECT
}

const JS_TAG_FIRST = -11,
    /* first negative tag */
    JS_TAG_BIG_DECIMAL = -11,
    JS_TAG_BIG_INT = -10,
    JS_TAG_BIG_FLOAT = -9,
    JS_TAG_SYMBOL = -8,
    JS_TAG_STRING = -7,
    JS_TAG_OBJECT = -1,
    JS_TAG_INT = 0,
    JS_TAG_BOOL = 1,
    JS_TAG_NULL = 2,
    JS_TAG_UNDEFINED = 3,
    JS_TAG_UNINITIALIZED = 4,
    JS_TAG_CATCH_OFFSET = 5,
    JS_TAG_EXCEPTION = 6,
    JS_TAG_FLOAT64 = 7;

// ignore: camel_case_types
typedef JS_NewRuntimeDartBridge = Pointer<JSRuntime> Function();

typedef ChannelCallback = Pointer<JSValueConst> Function(
  Pointer<JSContext>,
  Pointer<Utf8NullTerminated>,
  Pointer<Utf8NullTerminated>,
);

// ignore: camel_case_types
typedef JS_NewContextFn = Pointer<JSContext> Function(
  Pointer<JSRuntime>? jrt,
  Pointer<NativeFunction<ChannelCallback>>? fnConsoleLog,
  Pointer<NativeFunction<ChannelCallback>>? fnSetTimeout,
  Pointer<NativeFunction<ChannelCallback>>? fnSendNative,
);

typedef JSEvalWrapper = Pointer Function(
    Pointer<JSContext> ctx,
    Pointer<Utf8NullTerminated> input,
    int inputLength,
    Pointer<Utf8NullTerminated> filename,
    int evalFlags,
    Pointer<Int32> errors,
    Pointer<JSValueConst> result,
    Pointer<Pointer<Utf8NullTerminated>> stringResult);

// ignore: camel_case_types
typedef JS_GetNullValue = Pointer Function(
  Pointer<JSContext> ctx,
  Pointer<JSValueConst> v,
);

typedef JSEvalWrapperNative = Pointer Function(
    Pointer<JSContext> ctx,
    Pointer<Utf8NullTerminated> input,
    Int32 inputLength,
    Pointer<Utf8NullTerminated> filename,
    Int32 evalFlags,
    Pointer<Int32> errors,
    Pointer<JSValueConst> result,
    Pointer<Pointer<Utf8NullTerminated>> stringResult);

typedef JSExecutePendingJob = int Function(
  Pointer<JSRuntime> rt,
  Pointer<JSContext> ctx,
);

typedef JSExecutePendingJobNative = Uint32 Function(
  Pointer<JSRuntime> rt,
  Pointer<JSContext> ctx,
);

typedef JSCallFunction1ArgNative = Uint32 Function(
  Pointer<JSContext> ctx,
  Pointer<JSValueConst> function,
  Pointer<JSValueConst> object,
  Pointer<JSValueConst> result,
  Pointer<Pointer<Utf8NullTerminated>> stringResult,
);

typedef JSCallFunction1Arg = int Function(
  Pointer<JSContext> ctx,
  Pointer<JSValueConst> function,
  Pointer<JSValueConst> object,
  Pointer<JSValueConst> result,
  Pointer<Pointer<Utf8NullTerminated>> stringResult,
);

typedef JSGetTypeTagNative = Int32 Function(Pointer<JSValueConst> jsValue);
typedef JSGetTypeTag = int Function(Pointer<JSValueConst> jsValue);

typedef JSIsArrayNative = Int32 Function(
    Pointer<JSContext> ctx, Pointer<JSValueConst> jsValue);
typedef JSIsArray = int Function(
    Pointer<JSContext> ctx, Pointer<JSValueConst> jsValue);

typedef int JSJSONStringify(
  Pointer<JSContext> ctx,
  Pointer<JSValueConst> obj,
  Pointer<JSValueConst> res,
  Pointer<Pointer<Utf8NullTerminated>> stringResult,
);
typedef Int32 JSJSONStringifyNative(
  Pointer<JSContext> ctx,
  Pointer<JSValueConst> obj,
  Pointer<JSValueConst> res,
  Pointer<Pointer<Utf8NullTerminated>> stringResult,
);
