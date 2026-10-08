import 'dart:ffi';

import 'jsc_ffi.dart';

/// enum JSType
/// A constant identifying the type of a JSValue.
class JSType {
  /// The unique undefined value.
  static const int kJSTypeUndefined = 0;

  /// The unique null value.
  static const int kJSTypeNull = 1;

  /// A primitive boolean value, one of true or false.
  static const int kJSTypeBoolean = 2;

  /// A primitive number value.
  static const int kJSTypeNumber = 3;

  /// A primitive string value.
  static const int kJSTypeString = 4;

  /// An object value (meaning that this JSValueRef is a JSObjectRef).
  static const int kJSTypeObject = 5;

  /// A primitive symbol value.
  static const int kJSTypeSymbol = 6;
}

/// enum JSTypedArrayType
/// A constant identifying the Typed Array type of a JSObjectRef.
class JSTypedArrayType {
  /// Int8Array
  static const int kJSTypedArrayTypeInt8Array = 0;

  /// Int16Array
  static const int kJSTypedArrayTypeInt16Array = 1;

  /// Int32Array
  static const int kJSTypedArrayTypeInt32Array = 2;

  /// Uint8Array
  static const int kJSTypedArrayTypeUint8Array = 3;

  /// Uint8ClampedArray
  static const int kJSTypedArrayTypeUint8ClampedArray = 4;

  /// Uint16Array
  static const int kJSTypedArrayTypeUint16Array = 5;

  /// Uint32Array
  static const int kJSTypedArrayTypeUint32Array = 6;

  /// Float32Array
  static const int kJSTypedArrayTypeFloat32Array = 7;

  /// Float64Array
  static const int kJSTypedArrayTypeFloat64Array = 8;

  /// ArrayBuffer
  static const int kJSTypedArrayTypeArrayBuffer = 9;

  /// Not a Typed Array
  static const int kJSTypedArrayTypeNone = 10;
}

/// Returns a JavaScript value's type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue whose type you want to obtain.
/// [@result] (JSType) A value of type JSType that identifies value's type.
final int Function(Pointer ctx, Pointer value) jSValueGetType = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueGetType')
    .asFunction();

/// Tests whether a JavaScript value's type is the undefined type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the undefined type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsUndefined = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>(
        'JSValueIsUndefined')
    .asFunction();

/// Tests whether a JavaScript value's type is the null type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the null type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsNull = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsNull')
    .asFunction();

/// Tests whether a JavaScript value's type is the boolean type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the boolean type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsBoolean = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsBoolean')
    .asFunction();

/// Tests whether a JavaScript value's type is the number type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the number type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsNumber = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsNumber')
    .asFunction();

/// Tests whether a JavaScript value's type is the string type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the string type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsString = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsString')
    .asFunction();

/// Tests whether a JavaScript value's type is the symbol type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the symbol type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsSymbol = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsSymbol')
    .asFunction();

/// Tests whether a JavaScript value's type is the object type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value's type is the object type, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsObject = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsObject')
    .asFunction();

/// Tests whether a JavaScript value is an object with a given class in its class chain.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [jsClass] (JSClassRef) The JSClass to test against.
/// [@result] (bool) true if value is an object and has jsClass in its class chain, otherwise false.
final int Function(Pointer ctx, Pointer value, Pointer jsClass)
    jSValueIsObjectOfClass = JscFfi.lib
        .lookup<NativeFunction<Int8 Function(Pointer, Pointer, Pointer)>>(
            'JSValueIsObjectOfClass')
        .asFunction();

/// Tests whether a JavaScript value is an array.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value is an array, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsArray = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsArray')
    .asFunction();

/// Tests whether a JavaScript value is a date.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [@result] (bool) true if value is a date, otherwise false.
final int Function(Pointer ctx, Pointer value) jSValueIsDate = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueIsDate')
    .asFunction();

/// Returns a JavaScript value's Typed Array type.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue whose Typed Array type to return.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSTypedArrayType) A value of type JSTypedArrayType that identifies value's Typed Array type, or kJSTypedArrayTypeNone if the value is not a Typed Array object.
final int Function(Pointer ctx, Pointer value, Pointer exception)
    jSValueGetTypedArrayType = JscFfi.lib
        .lookup<NativeFunction<Int8 Function(Pointer, Pointer, Pointer)>>(
            'JSValueGetTypedArrayType')
        .asFunction();

/// Tests whether two JavaScript values are equal, as compared by the JS == operator.
/// [ctx] (JSContextRef) The execution context to use.
/// [a] (JSValueRef) The first value to test.
/// [b] (JSValueRef) The second value to test.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if the two values are equal, false if they are not equal or an exception is thrown.
final int Function(
    Pointer ctx,
    Pointer a,
    Pointer b,
    Pointer
        exception) jSValueIsEqual = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer, Pointer, Pointer)>>(
        'JSValueIsEqual')
    .asFunction();

/// Tests whether two JavaScript values are strict equal, as compared by the JS === operator.
/// [ctx] (JSContextRef) The execution context to use.
/// [a] (JSValueRef) The first value to test.
/// [b] (JSValueRef) The second value to test.
/// [@result] (bool) true if the two values are strict equal, otherwise false.
final int Function(Pointer ctx, Pointer a, Pointer b) jSValueIsStrictEqual =
    JscFfi.lib
        .lookup<NativeFunction<Int8 Function(Pointer, Pointer, Pointer)>>(
            'JSValueIsStrictEqual')
        .asFunction();

/// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the JS instanceof operator.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to test.
/// [constructor] (JSObjectRef) The constructor to test against.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if value is an object constructed by constructor, as compared by the JS instanceof operator, otherwise false.
final int Function(
    Pointer ctx,
    Pointer value,
    Pointer constructor,
    Pointer
        exception) jSValueIsInstanceOfConstructor = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer, Pointer, Pointer)>>(
        'JSValueIsInstanceOfConstructor')
    .asFunction();

/// Creates a JavaScript value of the undefined type.
/// [ctx] (JSContextRef) The execution context to use.
/// [@result] (JSValueRef) The unique undefined value.
final Pointer Function(Pointer ctx) jSValueMakeUndefined = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSValueMakeUndefined')
    .asFunction();

/// Creates a JavaScript value of the null type.
/// [ctx] (JSContextRef) The execution context to use.
/// [@result] (JSValueRef) The unique null value.
final Pointer Function(Pointer ctx) jSValueMakeNull = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSValueMakeNull')
    .asFunction();

/// Creates a JavaScript value of the boolean type.
/// [ctx] (JSContextRef) The execution context to use.
/// [boolean] (bool) The bool to assign to the newly created JSValue.
/// [@result] (JSValueRef) A JSValue of the boolean type, representing the value of boolean.
final Pointer Function(Pointer ctx, int boolean) jSValueMakeBoolean = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer, Int8)>>(
        'JSValueMakeBoolean')
    .asFunction();

/// Creates a JavaScript value of the number type.
/// [ctx] (JSContextRef) The execution context to use.
/// [number] (double) The double to assign to the newly created JSValue.
/// [@result] (JSValueRef) A JSValue of the number type, representing the value of number.
final Pointer Function(Pointer ctx, double number) jSValueMakeNumber = JscFfi
    .lib
    .lookup<NativeFunction<Pointer Function(Pointer, Double)>>(
        'JSValueMakeNumber')
    .asFunction();

/// Creates a JavaScript value of the string type.
/// [ctx] (JSContextRef) The execution context to use.
/// [string] (JSStringRef) The JSString to assign to the newly created JSValue. The newly created JSValue retains string, and releases it upon garbage collection.
/// [@result] (JSValueRef) A JSValue of the string type, representing the value of string.
final Pointer Function(Pointer ctx, Pointer string) jSValueMakeString = JscFfi
    .lib
    .lookup<NativeFunction<Pointer Function(Pointer, Pointer)>>(
        'JSValueMakeString')
    .asFunction();

/// Creates a JavaScript value of the symbol type.
/// [ctx] (JSContextRef) The execution context to use.
/// [description] (JSStringRef) A description of the newly created symbol value.
/// [@result] (JSValueRef) A unique JSValue of the symbol type, whose description matches the one provided.
final Pointer Function(Pointer ctx, Pointer description) jSValueMakeSymbol =
    JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer)>>(
            'JSValueMakeSymbol')
        .asFunction();

/// Creates a JavaScript value from a JSON formatted string.
/// [ctx] (JSContextRef) The execution context to use.
/// [string] (JSStringRef) The JSString containing the JSON string to be parsed.
/// [@result] (JSValueRef) A JSValue containing the parsed value, or NULL if the input is invalid.
final Pointer Function(Pointer ctx, Pointer string) jSValueMakeFromJSONString =
    JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer)>>(
            'JSValueMakeFromJSONString')
        .asFunction();

/// Creates a JavaScript string containing the JSON serialized representation of a JS value.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The value to serialize.
/// [indent] (unsigned) The number of spaces to indent when nesting.  If 0, the resulting JSON will not contains newlines.  The size of the indent is clamped to 10 spaces.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSStringRef) A JSString with the result of serialization, or NULL if an exception is thrown.
final Pointer Function(
    Pointer ctx,
    Pointer value,
    int indent,
    Pointer
        exception) jSValueCreateJSONString = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer, Pointer, Int32, Pointer)>>(
        'JSValueCreateJSONString')
    .asFunction();

/// Converts a JavaScript value to boolean and returns the resulting boolean.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [@result] (bool) The boolean result of conversion.
final int Function(Pointer ctx, Pointer value) jSValueToBoolean = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>('JSValueToBoolean')
    .asFunction();

/// Converts a JavaScript value to number and returns the resulting number.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (double) The numeric result of conversion, or NaN if an exception is thrown.
final double Function(Pointer ctx, Pointer value, Pointer exception)
    jSValueToNumber = JscFfi.lib
        .lookup<NativeFunction<Double Function(Pointer, Pointer, Pointer)>>(
            'JSValueToNumber')
        .asFunction();

/// Converts a JavaScript value to string and copies the result into a JavaScript string.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSStringRef) A JSString with the result of conversion, or NULL if an exception is thrown. Ownership follows the Create Rule.
final Pointer Function(Pointer ctx, Pointer value, Pointer exception)
    jSValueToStringCopy = JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer, Pointer)>>(
            'JSValueToStringCopy')
        .asFunction();

/// Converts a JavaScript value to object and returns the resulting object.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to convert.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) The JSObject result of conversion, or NULL if an exception is thrown.
final Pointer Function(Pointer ctx, Pointer value, Pointer exception)
    jSValueToObject = JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer, Pointer)>>(
            'JSValueToObject')
        .asFunction();

/// Protects a JavaScript value from garbage collection.
/// Use this method when you want to store a JSValue in a global or on the heap, where the garbage collector will not be able to discover your reference to it.
///
/// A value may be protected multiple times and must be unprotected an equal number of times before becoming eligible for garbage collection.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to protect.
final void Function(Pointer ctx, Pointer value) jSValueProtect = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer, Pointer)>>('JSValueProtect')
    .asFunction();

/// Unprotects a JavaScript value from garbage collection.
/// A value may be protected multiple times and must be unprotected an
/// equal number of times before becoming eligible for garbage collection.
/// [ctx] (JSContextRef) The execution context to use.
/// [value] (JSValueRef) The JSValue to unprotect.
final void Function(Pointer ctx, Pointer value) jSValueUnprotect = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer, Pointer)>>('JSValueUnprotect')
    .asFunction();
