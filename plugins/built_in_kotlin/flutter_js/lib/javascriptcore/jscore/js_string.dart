import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../binding/js_string_ref.dart' as JSStringRef;

/// A UTF16 character buffer. The fundamental string representation in JavaScript.
class JSString {
  /// C pointer
  late Pointer _pointer;
  get pointer => _pointer;

  JSString(this._pointer);

  /// Creates a JavaScript string from dart String.
  /// [string] The dart String.
  JSString.fromString(String? string) {
    if (string == null) {
      _pointer = nullptr;
    } else {
      var cString = string.toNativeUtf8();
      _pointer = JSStringRef.jSStringCreateWithUTF8CString(cString);
      malloc.free(cString);
    }
  }

  /// Retains a JavaScript string.
  /// [@result] (JSStringRef) A JSString that is the same as string.
  void retain() {
    _pointer = JSStringRef.jSStringRetain(_pointer);
  }

  /// Releases a JavaScript string.
  void release() {
    if (_pointer != nullptr) {
      JSStringRef.jSStringRelease(_pointer);
    }
  }

  /// Returns the number of Unicode characters in a JavaScript string.
  int get length {
    return JSStringRef.jSStringGetLength(_pointer);
  }

  /// Returns dart String
  String? get string {
    if (_pointer == nullptr) return null;
    var cString = JSStringRef.jSStringGetCharactersPtr(_pointer);
    if (cString == nullptr) {
      return null;
    }
    int cStringLength = JSStringRef.jSStringGetLength(_pointer);
    return String.fromCharCodes(Uint16List.view(
        cString.cast<Uint16>().asTypedList(cStringLength).buffer,
        0,
        cStringLength));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JSString &&
          runtimeType == other.runtimeType &&
          JSStringRef.jSStringIsEqual(_pointer, other.pointer) == 1 ||
      other is String && string == other;

  @override
  int get hashCode => _pointer.hashCode;
}

/// JSStringRef pointer
class JSStringPointer {
  /// C pointer
  final Pointer<Pointer> pointer;

  /// Pointer array count
  final int count;

  JSStringPointer([Pointer? value])
      : this.count = 1,
        this.pointer = malloc.call<Pointer>(1) {
    pointer.value = value ?? nullptr;
  }

  /// JSStringRef array
  JSStringPointer.array(List<String> array)
      : this.count = array.length,
        this.pointer = malloc.call<Pointer>(array.length) {
    for (int i = 0; i < array.length; i++) {
      this.pointer[i] = JSString.fromString(array[i]).pointer;
    }
  }

  /// Get JSValue
  /// [index] Array index
  JSString getValue([int index = 0]) {
    return JSString(pointer[index]);
  }
}
