import 'dart:ffi';

import 'jsc_ffi.dart';

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
/// [@result] (JSContextGroupRef) The created JSContextGroup.
final Pointer Function() jSContextGroupCreate = JscFfi.lib
    .lookup<NativeFunction<Pointer Function()>>('JSContextGroupCreate')
    .asFunction();

/// Retains a JavaScript context group.
/// [group] (JSContextGroupRef) The JSContextGroup to retain.
/// [@result] (JSContextGroupRef) A JSContextGroup that is the same as group.
final Pointer Function(Pointer group) jSContextGroupRetain = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSContextGroupRetain')
    .asFunction();

/// Releases a JavaScript context group.
/// [group] (JSContextGroupRef) The JSContextGroup to release.
final void Function(Pointer group) jSContextGroupRelease = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer)>>('JSContextGroupRelease')
    .asFunction();

/// Creates a global JavaScript execution context.
/// JSGlobalContextCreate allocates a global object and populates it with all the
/// built-in JavaScript objects, such as Object, Function, String, and Array.
///
/// In WebKit version 4.0 and later, the context is created in a unique context group.
/// Therefore, scripts may execute in it concurrently with scripts executing in other contexts.
/// However, you may not use values created in the context in other contexts.
/// [globalObjectClass] (JSClassRef) The class to use when creating the global object. Pass NULL to use the default object class.
/// [@result] (JSGlobalContextRef) A JSGlobalContext with a global object of class globalObjectClass.
final Pointer Function(Pointer globalObjectClass) jSGlobalContextCreate = JscFfi
    .lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSGlobalContextCreate')
    .asFunction();

/// Creates a global JavaScript execution context in the context group provided.
/// JSGlobalContextCreateInGroup allocates a global object and populates it with
/// all the built-in JavaScript objects, such as Object, Function, String, and Array.
/// [group] (JSContextGroupRef) The context group to use. The created global context retains the group. Pass NULL to create a unique group for the context.
/// [globalObjectClass] (JSClassRef) The class to use when creating the global object. Pass NULL to use the default object class.
/// [@result] (JSGlobalContextRef) A JSGlobalContext with a global object of class globalObjectClass and a context group equal to group.
final Pointer Function(Pointer group, Pointer globalObjectClass)
    jSGlobalContextCreateInGroup = JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer)>>(
            'JSGlobalContextCreateInGroup')
        .asFunction();

/// Retains a global JavaScript execution context.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext to retain.
/// [@result] (JSGlobalContextRef) A JSGlobalContext that is the same as ctx.
final Pointer Function(Pointer ctx) jSGlobalContextRetain = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSGlobalContextRetain')
    .asFunction();

/// Releases a global JavaScript execution context.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext to release.
final void Function(Pointer ctx) jSGlobalContextRelease = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer)>>('JSGlobalContextRelease')
    .asFunction();

/// Gets the global object of a JavaScript execution context.
/// [ctx] (JSContextRef) The JSContext whose global object you want to get.
/// [@result] (JSObjectRef) ctx's global object.
final Pointer Function(Pointer ctx) jSContextGetGlobalObject = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>(
        'JSContextGetGlobalObject')
    .asFunction();

/// Gets the context group to which a JavaScript execution context belongs.
/// [ctx] (JSContextRef) The JSContext whose group you want to get.
/// [@result] (JSContextGroupRef) ctx's group.
final Pointer Function(Pointer ctx) jSContextGetGroup = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSContextGetGroup')
    .asFunction();

/// Gets the global context of a JavaScript execution context.
/// [ctx] (JSContextRef) The JSContext whose global context you want to get.
/// [@result] (JSGlobalContextRef) ctx's global context.
final Pointer Function(Pointer ctx) jSContextGetGlobalContext = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>(
        'JSContextGetGlobalContext')
    .asFunction();

/// Gets a copy of the name of a context.
/// A JSGlobalContext's name is exposed for remote debugging to make it
/// easier to identify the context you would like to attach to.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext whose name you want to get.
/// [@result] (JSStringRef) The name for ctx.
final Pointer Function(Pointer ctx) jSGlobalContextCopyName = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>(
        'JSGlobalContextCopyName')
    .asFunction();

/// Sets the remote debugging name for a context.
/// [ctx] (JSGlobalContextRef) The JSGlobalContext that you want to name.
/// [name] (JSStringRef) The remote debugging name to set on ctx.
final void Function(Pointer ctx, Pointer name) jSGlobalContextSetName = JscFfi
    .lib
    .lookup<NativeFunction<Void Function(Pointer, Pointer)>>(
        'JSGlobalContextSetName')
    .asFunction();
