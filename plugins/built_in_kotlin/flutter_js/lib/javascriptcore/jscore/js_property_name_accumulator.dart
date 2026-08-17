import 'dart:ffi';

/// An ordered set used to collect the names of a JavaScript object's properties.
class JSPropertyNameAccumulator {
  /// C pointer
  final Pointer pointer;

  JSPropertyNameAccumulator(this.pointer);
}
