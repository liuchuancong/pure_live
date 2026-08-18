import 'dart:ffi';

import '../binding/js_base.dart' as JSBase;
import '../binding/js_context_ref.dart' as JSContextRef;
import '../binding/js_global_context_ref.dart' as JSGlobalContextRef;
import 'js_class.dart';
import 'js_context_group.dart';
import 'js_object.dart';
import 'js_string.dart';
import 'js_value.dart';

/// A JavaScript execution context. Holds the global object and other execution state.
class JSContext {
  /// C pointer
  Pointer _pointer;

  Pointer get pointer => _pointer;

  /// Exception (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSValuePointer exception = JSValuePointer();

  JSContext(this._pointer);

  /// Creates a global JavaScript execution context.
  /// JSGlobalContextCreate allocates a global object and populates it with all the
  /// built-in JavaScript objects, such as Object, Function, String, and Array.
  ///
  /// In WebKit version 4.0 and later, the context is created in a unique context group.
  /// Therefore, scripts may execute in it concurrently with scripts executing in other contexts.
  /// However, you may not use values created in the context in other contexts.
  /// [globalObjectClass] (JSClass) The class to use when creating the global object. Pass NULL to use the default object class.
  /// [@result] (JSGlobalContext) A JSGlobalContext with a global object of class globalObjectClass.
  JSContext.create({
    JSClass? globalObjectClass,
  }) : this._pointer = JSContextRef.jSGlobalContextCreate(
            globalObjectClass == null ? nullptr : globalObjectClass.pointer);

  /// Creates a global JavaScript execution context in the context group provided.
  /// JSGlobalContextCreateInGroup allocates a global object and populates it with
  /// all the built-in JavaScript objects, such as Object, Function, String, and Array.
  /// [group] (JSContextGroup) The context group to use. The created global context retains the group. Pass NULL to create a unique group for the context.
  /// [globalObjectClass] (JSClass) The class to use when creating the global object. Pass NULL to use the default object class.
  /// [@result] (JSGlobalContext) A JSGlobalContext with a global object of class globalObjectClass and a context group equal to group.
  JSContext.createInGroup({
    JSContextGroup? group,
    JSClass? globalObjectClass,
  }) : this._pointer = JSContextRef.jSGlobalContextCreateInGroup(
            group == null ? JSContextRef.jSContextGroupCreate() : group.pointer,
            globalObjectClass == null ? nullptr : globalObjectClass.pointer);

  /// Retains a global JavaScript execution context.
  /// [@result] (JSGlobalContext) A JSGlobalContext that is the same as ctx.
  void retain() {
    _pointer = JSContextRef.jSGlobalContextRetain(pointer);
  }

  /// Releases a global JavaScript execution context.
  /// [ctx] (JSGlobalContext) The JSGlobalContext to release.
  void release() {
    return JSContextRef.jSGlobalContextRelease(pointer);
  }

  /// Gets the global object of a JavaScript execution context.
  /// [@result] (JSObject) ctx's global object.
  JSObject get globalObject {
    return JSObject(this, JSContextRef.jSContextGetGlobalObject(pointer));
  }

  /// Gets the context group to which a JavaScript execution context belongs.
  /// [@result] (JSContextGroup) ctx's group.
  JSContextGroup get group {
    return JSContextGroup(JSContextRef.jSContextGetGroup(pointer));
  }

  /// Gets the global context of a JavaScript execution context.
  /// [@result] (JSGlobalContext) ctx's global context.
  /*JSGlobalContext get globalContext {
    return JSGlobalContext(JSContextRef.jSContextGetGlobalContext(pointer));
  }*/

  /// Gets a copy of the name of a context.
  /// A JSGlobalContext's name is exposed for remote debugging to make it
  /// easier to identify the context you would like to attach to.
  /// [@result] (JSString) The name for ctx.
  JSString copyName() {
    return JSString(JSContextRef.jSGlobalContextCopyName(pointer));
  }

  /// Sets the remote debugging name for a context.
  /// [name] (JSString) The remote debugging name to set on ctx.
  void setName(JSString name) {
    return JSContextRef.jSGlobalContextSetName(pointer, name.pointer);
  }

  /// Evaluates a string of JavaScript.
  /// [script] (String) A JSString containing the script to evaluate.
  /// [thisObject] (JSObject) The object to use as "this," or NULL to use the global object as "this."
  /// [sourceURL] (String) A JSString containing a URL for the script's source file. This is used by debuggers and when reporting exceptions. Pass NULL if you do not care to include source file information.
  /// [startingLineNumber] (int) An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions. The value is one-based, so the first line is line 1 and invalid values are clamped to 1.
  /// [@result] (JSValueRef) The JSValue that results from evaluating script, or NULL if an exception is thrown.
  JSValue evaluate(
    String script, {
    JSObject? thisObject,
    String? sourceURL,
    int startingLineNumber = 1,
  }) {
    return JSValue(
        this,
        JSBase.jSEvaluateScript(
          pointer,
          JSString.fromString(script).pointer,
          thisObject == null ? nullptr : thisObject.pointer,
          sourceURL == null ? nullptr : JSString.fromString(sourceURL).pointer,
          startingLineNumber,
          exception.pointer,
        ));
  }

  void setInspectable(bool inspectable) {
    JSGlobalContextRef.jSGlobalContextSetInspectable(_pointer, inspectable);
  }
}
