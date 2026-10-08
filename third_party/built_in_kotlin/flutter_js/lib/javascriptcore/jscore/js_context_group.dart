import 'dart:ffi';
import '../binding/js_context_ref.dart' as JSContextRef;

/// JSContextGroupRef A group that associates JavaScript contexts with one another. Contexts in the same group may share and exchange JavaScript objects.
class JSContextGroup {
  /// C pointer
  final Pointer pointer;

  JSContextGroup(this.pointer);

  /// Creates a JavaScript context group.
  /// A JSContextGroup associates JavaScript contexts with one another.
  /// Contexts in the same group may share and exchange JavaScript objects. Sharing and/or exchanging
  /// JavaScript objects between contexts in different groups will produce undefined behavior.
  /// When objects from the same context group are used in multiple threads, explicit
  /// synchronization is required.
  ///
  /// A JSContextGroup may need to run deferred tasks on a run loop, such as garbage collection
  /// or resolving WebAssembly compilations. By default, calling JSContextGroupCreate will use
  /// the run loop of the thread it was called on. Currently, there is no API to change a
  /// JSContextGroup's run loop once it has been created.
  JSContextGroup.create() : this.pointer = JSContextRef.jSContextGroupCreate();

  /// Retains a JavaScript context group.
  /// [@result] (JSContextGroupRef) A JSContextGroup that is the same as group.
  JSContextGroup retain() {
    return JSContextGroup(JSContextRef.jSContextGroupRetain(pointer));
  }

  /// Releases a JavaScript context group.
  void release() {
    return JSContextRef.jSContextGroupRelease(pointer);
  }
}
