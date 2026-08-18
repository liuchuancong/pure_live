import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../binding/js_value_ref.dart' as JSValueRef;
import '../flutter_jscore.dart';

/// enum JSType
/// A constant identifying the type of a JSValue.
enum JSType {
  /// The unique undefined value.
  kJSTypeUndefined,

  /// The unique null value.
  kJSTypeNull,

  /// A primitive boolean value, one of true or false.
  kJSTypeBoolean,

  /// A primitive number value.
  kJSTypeNumber,

  /// A primitive string value.
  kJSTypeString,

  /// An object value (meaning that this JSValueRef is a JSObjectRef).
  kJSTypeObject,

  /// A primitive symbol value.
  kJSTypeSymbol
}

/// enum JSTypedArrayType
/// A constant identifying the Typed Array type of a JSObjectRef.
enum JSTypedArrayType {
  /// Int8Array
  kJSTypedArrayTypeInt8Array,

  /// Int16Array
  kJSTypedArrayTypeInt16Array,

  /// Int32Array
  kJSTypedArrayTypeInt32Array,

  /// Uint8Array
  kJSTypedArrayTypeUint8Array,

  /// Uint8ClampedArray
  kJSTypedArrayTypeUint8ClampedArray,

  /// Uint16Array
  kJSTypedArrayTypeUint16Array,

  /// Uint32Array
  kJSTypedArrayTypeUint32Array,

  /// Float32Array
  kJSTypedArrayTypeFloat32Array,

  /// Float64Array
  kJSTypedArrayTypeFloat64Array,

  /// ArrayBuffer
  kJSTypedArrayTypeArrayBuffer,

  /// Not a Typed Array
  kJSTypedArrayTypeNone,
}

/// A JavaScript value. The base type for all JavaScript values, and polymorphic functions on them.
class JSValue {
  /// enum JSType to C enum
  static int jSTypeToCEnum(JSType type) {
    switch (type) {
      case JSType.kJSTypeNull:
        return JSValueRef.JSType.kJSTypeNull;
      case JSType.kJSTypeBoolean:
        return JSValueRef.JSType.kJSTypeBoolean;
      case JSType.kJSTypeNumber:
        return JSValueRef.JSType.kJSTypeNumber;
      case JSType.kJSTypeString:
        return JSValueRef.JSType.kJSTypeString;
      case JSType.kJSTypeObject:
        return JSValueRef.JSType.kJSTypeObject;
      case JSType.kJSTypeSymbol:
        return JSValueRef.JSType.kJSTypeSymbol;
      default:
        return JSValueRef.JSType.kJSTypeUndefined;
    }
  }

  /// C enum to enum JSType
  static JSType cEnumToJSType(int typeCode) {
    switch (typeCode) {
      case JSValueRef.JSType.kJSTypeNull:
        return JSType.kJSTypeNull;
      case JSValueRef.JSType.kJSTypeBoolean:
        return JSType.kJSTypeBoolean;
      case JSValueRef.JSType.kJSTypeNumber:
        return JSType.kJSTypeNumber;
      case JSValueRef.JSType.kJSTypeString:
        return JSType.kJSTypeString;
      case JSValueRef.JSType.kJSTypeObject:
        return JSType.kJSTypeObject;
      case JSValueRef.JSType.kJSTypeSymbol:
        return JSType.kJSTypeSymbol;
      default:
        return JSType.kJSTypeUndefined;
    }
  }

  /// enum JSTypedArrayType to C enum
  static int jSTypedArrayTypeToCEnum(JSTypedArrayType type) {
    switch (type) {
      case JSTypedArrayType.kJSTypedArrayTypeInt8Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeInt8Array;
      case JSTypedArrayType.kJSTypedArrayTypeInt16Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeInt16Array;
      case JSTypedArrayType.kJSTypedArrayTypeInt32Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeInt32Array;
      case JSTypedArrayType.kJSTypedArrayTypeUint8Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint8Array;
      case JSTypedArrayType.kJSTypedArrayTypeUint8ClampedArray:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint8ClampedArray;
      case JSTypedArrayType.kJSTypedArrayTypeUint16Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint16Array;
      case JSTypedArrayType.kJSTypedArrayTypeUint32Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint32Array;
      case JSTypedArrayType.kJSTypedArrayTypeFloat32Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeFloat32Array;
      case JSTypedArrayType.kJSTypedArrayTypeFloat64Array:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeFloat64Array;
      case JSTypedArrayType.kJSTypedArrayTypeArrayBuffer:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeArrayBuffer;
      default:
        return JSValueRef.JSTypedArrayType.kJSTypedArrayTypeNone;
    }
  }

  /// C enum to enum JSTypedArrayType
  static JSTypedArrayType cEnumToJSTypedArrayType(int typeCode) {
    switch (typeCode) {
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeInt8Array:
        return JSTypedArrayType.kJSTypedArrayTypeInt8Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeInt16Array:
        return JSTypedArrayType.kJSTypedArrayTypeInt16Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeInt32Array:
        return JSTypedArrayType.kJSTypedArrayTypeInt32Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint8Array:
        return JSTypedArrayType.kJSTypedArrayTypeUint8Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint8ClampedArray:
        return JSTypedArrayType.kJSTypedArrayTypeUint8ClampedArray;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint16Array:
        return JSTypedArrayType.kJSTypedArrayTypeUint16Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeUint32Array:
        return JSTypedArrayType.kJSTypedArrayTypeUint32Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeFloat32Array:
        return JSTypedArrayType.kJSTypedArrayTypeFloat32Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeFloat64Array:
        return JSTypedArrayType.kJSTypedArrayTypeFloat64Array;
      case JSValueRef.JSTypedArrayType.kJSTypedArrayTypeArrayBuffer:
        return JSTypedArrayType.kJSTypedArrayTypeArrayBuffer;
      default:
        return JSTypedArrayType.kJSTypedArrayTypeNone;
    }
  }

  /// JavaScript context
  final JSContext context;

  /// C pointer
  final Pointer pointer;

  JSValue(this.context, this.pointer);

  /// Creates a JavaScript value of the undefined type.
  JSValue.makeUndefined(this.context)
      : this.pointer = JSValueRef.jSValueMakeUndefined(context.pointer);

  /// Creates a JavaScript value of the null type.
  JSValue.makeNull(this.context)
      : this.pointer = JSValueRef.jSValueMakeNull(context.pointer);

  /// Creates a JavaScript value of the boolean type.
  /// [boolean] The bool to assign to the newly created JSValue.
  JSValue.makeBoolean(this.context, bool boolean)
      : this.pointer = JSValueRef.jSValueMakeBoolean(
            context.pointer, boolean == true ? 1 : 0);

  /// Creates a JavaScript value of the number type.
  /// [number] The double to assign to the newly created JSValue.
  JSValue.makeNumber(this.context, double number)
      : this.pointer = JSValueRef.jSValueMakeNumber(context.pointer, number);

  /// Creates a JavaScript value of the string type.
  /// [string] The double to assign to the newly created JSValue.
  JSValue.makeString(this.context, String string)
      : this.pointer = JSValueRef.jSValueMakeString(
            context.pointer, JSString.fromString(string).pointer);

  /// Creates a JavaScript value of the symbol type.
  /// [description] A description of the newly created symbol value.
  JSValue.makeSymbol(this.context, String description)
      : this.pointer = JSValueRef.jSValueMakeSymbol(
            context.pointer, JSString.fromString(description).pointer);

  /// Creates a JavaScript value from a JSON formatted string.
  /// [string] The JSString containing the JSON string to be parsed.
  JSValue.makeFromJSONString(this.context, String string)
      : this.pointer = JSValueRef.jSValueMakeFromJSONString(
            context.pointer, JSString.fromString(string).pointer);

  /// Value type
  JSType get type {
    int typeCode = JSValueRef.jSValueGetType(context.pointer, pointer);
    return cEnumToJSType(typeCode);
  }

  /// Tests whether a JavaScript value's type is the undefined type.
  bool get isUndefined {
    return JSValueRef.jSValueIsUndefined(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the null type.
  bool get isNull {
    return JSValueRef.jSValueIsNull(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the boolean type.
  bool get isBoolean {
    return JSValueRef.jSValueIsBoolean(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the number type.
  bool get isNumber {
    return JSValueRef.jSValueIsNumber(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the string type.
  bool get isString {
    return JSValueRef.jSValueIsString(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the symbol type.
  bool get isSymbol {
    return JSValueRef.jSValueIsSymbol(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the object type.
  bool get isObject {
    return JSValueRef.jSValueIsObject(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value is an array.
  bool get isArray {
    return JSValueRef.jSValueIsArray(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value is a date.
  bool get isDate {
    return JSValueRef.jSValueIsDate(context.pointer, pointer) == 1;
  }

  /// Tests whether a JavaScript value's type is the symbol type.
  /// [jsClass] The JSClass to test against.
  bool isObjectOfClass(JSClass jsClass) {
    return JSValueRef.jSValueIsObjectOfClass(
            context.pointer, pointer, jsClass.pointer) ==
        1;
  }

  /// Returns a JavaScript value's Typed Array type.
  JSTypedArrayType getTypedArrayType({
    JSValuePointer? exception,
  }) {
    int typeCode = JSValueRef.jSValueGetTypedArrayType(context.pointer, pointer,
        (exception ?? JSValuePointer(nullptr)).pointer);
    return cEnumToJSTypedArrayType(typeCode);
  }

  /// Tests whether two JavaScript values are equal, as compared by the JS == operator.
  bool isEqual(
    JSValue other, {
    JSValuePointer? exception,
  }) {
    return JSValueRef.jSValueIsEqual(context.pointer, pointer, other.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer) ==
        1;
  }

  /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the JS instanceof operator.
  bool isInstanceOfConstructor(
    JSObject constructor, {
    JSValuePointer? exception,
  }) {
    return JSValueRef.jSValueIsInstanceOfConstructor(
            context.pointer,
            pointer,
            constructor.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer) ==
        1;
  }

  /// Creates a JavaScript string containing the JSON serialized representation of a JS value.
  /// [indent] The number of spaces to indent when nesting.  If 0, the resulting JSON will not contains newlines.  The size of the indent is clamped to 10 spaces.
  /// [exception] A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSString createJSONString({
    int indent = 4,
    JSValuePointer? exception,
  }) {
    return JSString(JSValueRef.jSValueCreateJSONString(context.pointer, pointer,
        indent, (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Converts a JavaScript value to boolean and returns the resulting boolean.
  bool get toBoolean {
    return JSValueRef.jSValueToBoolean(context.pointer, pointer) == 1;
  }

  /// Converts a JavaScript value to number and returns the resulting number.
  /// [exception] A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  double toNumber({
    JSValuePointer? exception,
  }) {
    return JSValueRef.jSValueToNumber(context.pointer, pointer,
        (exception ?? JSValuePointer(nullptr)).pointer);
  }

  /// Converts a JavaScript value to number and returns the resulting string.
  String? get string {
    JSString jsString = toStringCopy();
    final str = jsString.string;
    jsString.release();
    return str;
  }

  /// Converts a JavaScript value to string and copies the result into a JavaScript string.
  /// [exception] A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSString toStringCopy({
    JSValuePointer? exception,
  }) {
    return JSString(JSValueRef.jSValueToStringCopy(context.pointer, pointer,
        (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Converts a JavaScript value to object and returns the resulting object.
  /// [exception] A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject toObject({
    JSValuePointer? exception,
  }) {
    return JSObject(
        context,
        JSValueRef.jSValueToObject(context.pointer, pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Protects a JavaScript value from garbage collection.
  /// Use this method when you want to store a JSValue in a global or on the heap, where the garbage collector will not be able to discover your reference to it.
  ///
  /// A value may be protected multiple times and must be unprotected an equal number of times before becoming eligible for garbage collection.
  void protect() {
    JSValueRef.jSValueProtect(context.pointer, pointer);
  }

  /// Protects a JavaScript value from garbage collection.
  /// Use this method when you want to store a JSValue in a global or on the heap, where the garbage collector will not be able to discover your reference to it.
  ///
  /// A value may be protected multiple times and must be unprotected an equal number of times before becoming eligible for garbage collection.
  void unProtect() {
    JSValueRef.jSValueUnprotect(context.pointer, pointer);
  }

  /// Tests whether two JavaScript values are strict equal, as compared by the JS === operator.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JSValue &&
          runtimeType == other.runtimeType &&
          JSValueRef.jSValueIsStrictEqual(
                  context.pointer, pointer, other.pointer) ==
              1;

  @override
  int get hashCode => context.hashCode ^ pointer.hashCode;
}

/// JSValueRef pointer
class JSValuePointer {
  /// C pointer
  final Pointer<Pointer> pointer;

  /// Pointer array count
  final int count;

  JSValuePointer([Pointer? value])
      : this.count = 1,
        this.pointer = malloc.call<Pointer>(1) {
    pointer.value = value ?? nullptr;
  }

  /// JSValueRef array
  JSValuePointer.array(List<JSValue> array)
      : this.count = array.length,
        this.pointer = malloc.call<Pointer>(array.length) {
    for (int i = 0; i < array.length; i++) {
      this.pointer[i] = array[i].pointer;
    }
  }

  /// Get JSValue
  /// [index] Array index
  JSValue getValue(JSContext context, [int index = 0]) {
    return JSValue(context, pointer[index]);
  }
}
