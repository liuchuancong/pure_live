import 'dart:ffi';

import 'jsc_ffi.dart';

/// typedef JSTypedArrayBytesDeallocator A function used to deallocate bytes passed to a Typed Array constructor. The function should take two arguments. The first is a pointer to the bytes that were originally passed to the Typed Array constructor. The second is a pointer to additional information desired at the time the bytes are to be freed.
/// typedef void (*JSTypedArrayBytesDeallocator)(void* bytes, void* deallocatorContext);
typedef JSTypedArrayBytesDeallocator = Void Function(
    Pointer bytes, Pointer deallocatorContext);
typedef JSTypedArrayBytesDeallocatorDart = void Function(
    Pointer bytes, Pointer deallocatorContext);

/// Evaluates a string of JavaScript.
/// [ctx] (JSContextRef) The execution context to use.
/// [script] (JSStringRef) A JSString containing the script to evaluate.
/// [thisObject] (JSObjectRef) The object to use as "this," or NULL to use the global object as "this."
/// [sourceURL] (JSStringRef) A JSString containing a URL for the script's source file. This is used by debuggers and when reporting exceptions. Pass NULL if you do not care to include source file information.
/// [startingLineNumber] (int) An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions. The value is one-based, so the first line is line 1 and invalid values are clamped to 1.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSValueRef) The JSValue that results from evaluating script, or NULL if an exception is thrown.
final Pointer Function(Pointer ctx, Pointer script, Pointer thisObject,
        Pointer sourceURL, int startingLineNumber, Pointer<Pointer> exception)
    jSEvaluateScript = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Pointer, Pointer, Int32,
                    Pointer)>>('JSEvaluateScript')
        .asFunction();

/// Checks for syntax errors in a string of JavaScript.
/// [ctx] (JSContextRef) The execution context to use.
/// [script] (JSStringRef) A JSString containing the script to check for syntax errors.
/// [sourceURL] (JSStringRef) A JSString containing a URL for the script's source file. This is only used when reporting exceptions. Pass NULL if you do not care to include source file information in exceptions.
/// [startingLineNumber] (int) An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions. The value is one-based, so the first line is line 1 and invalid values are clamped to 1.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store a syntax error exception, if any. Pass NULL if you do not care to store a syntax error exception.
/// [@result] (bool) true if the script is syntactically correct, otherwise false.
final Pointer Function(Pointer ctx, Pointer script, Pointer sourceURL,
        int startingLineNumber, Pointer<Pointer> exception)
    jSCheckScriptSyntax = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Pointer, Int32,
                    Pointer<Pointer>)>>('JSCheckScriptSyntax')
        .asFunction();

/// Performs a JavaScript garbage collection.
/// JavaScript values that are on the machine stack, in a register,
/// protected by JSValueProtect, set as the global object of an execution context,
/// or reachable from any such value will not be collected.
///
/// During JavaScript execution, you are not required to call this function; the
/// JavaScript engine will garbage collect as needed. JavaScript values created
/// within a context group are automatically destroyed when the last reference
/// to the context group is released.
/// [ctx] (JSContextRef) The execution context to use.
final void Function(Pointer ctx) jSGarbageCollect = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer)>>('JSGarbageCollect')
    .asFunction();
