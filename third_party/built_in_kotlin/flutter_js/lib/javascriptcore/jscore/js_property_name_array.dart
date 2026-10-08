import 'dart:ffi';

import '../binding/js_object_ref.dart' as JSObjectRef;

import 'js_string.dart';

/// An array of JavaScript property names.
class JSPropertyNameArray {
  /// C pointer
  Pointer pointer;

  JSPropertyNameArray(this.pointer);

  /// Retains a JavaScript property name array.
  void retain() {
    pointer = JSObjectRef.jSPropertyNameArrayRetain(pointer);
  }

  /// Releases a JavaScript property name array.
  void release() {
    JSObjectRef.jSPropertyNameArrayRelease(pointer);
  }

  /// Gets a count of the number of items in a JavaScript property name array.
  int get count {
    return JSObjectRef.jSPropertyNameArrayGetCount(pointer);
  }

  /// Gets a property name at a given index in a JavaScript property name array.
  /// [index] (size_t) The index of the property name to retrieve.
  String propertyNameArrayGetNameAtIndex(int index) {
    return JSString(
            JSObjectRef.jSPropertyNameArrayGetNameAtIndex(pointer, index))
        .string!;
  }
}
