import 'dart:ffi';

import '../binding/js_object_ref.dart' as JSObjectRef;

import 'js_object.dart';

/// A JavaScript class. Used with JSObjectMake to construct objects with custom behavior.
class JSClass {
  /// C pointer
  Pointer pointer;

  JSClass(this.pointer);

  /// Creates a JavaScript class suitable for use with JSObjectMake.
  /// [definition] (JSClassDefinition*) A JSClassDefinition that defines the class.
  JSClass.create(JSClassDefinition definition)
      : this.pointer = JSObjectRef.jSClassCreate(definition.create());

  /// Retains a JavaScript class.
  void retain() {
    pointer = JSObjectRef.jSClassRetain(pointer);
  }

  /// Releases a JavaScript class.
  void release() {
    JSObjectRef.jSClassRelease(pointer);
  }
}
