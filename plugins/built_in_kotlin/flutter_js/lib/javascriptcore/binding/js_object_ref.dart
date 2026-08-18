import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'jsc_ffi.dart';

/// enum JSPropertyAttributes
/// A set of JSPropertyAttributes. Combine multiple attributes by logically ORing them together.
class JSPropertyAttributes {
  /// Specifies that a property has no special attributes.
  static const int kJSPropertyAttributeNone = 0;

  /// Specifies that a property is read-only.
  static const int kJSPropertyAttributeReadOnly = 1 << 1;

  /// Specifies that a property should not be enumerated by JSPropertyEnumerators and JavaScript for...in loops.
  static const int kJSPropertyAttributeDontEnum = 1 << 2;

  /// Specifies that the delete operation should fail on a property.
  static const int kJSPropertyAttributeDontDelete = 1 << 3;
}

/// enum JSClassAttributes
/// A set of JSClassAttributes. Combine multiple attributes by logically ORing them together.
class JSClassAttributes {
  /// kJSClassAttributeNone Specifies that a class has no special attributes.
  static const int kJSClassAttributeNone = 0;

  /// kJSClassAttributeNoAutomaticPrototype Specifies that a class should not automatically generate a shared prototype for its instance objects. Use kJSClassAttributeNoAutomaticPrototype in combination with JSObjectSetPrototype to manage prototypes manually.
  static const int kJSClassAttributeNoAutomaticPrototype = 1 << 1;
}

/// typedef JSObjectInitializeCallback
/// The callback invoked when an object is first created.
/// [ctx] The execution context to use.
/// [object] The JSObject being created.
/// If you named your function Initialize, you would declare it like this:
///
/// void Initialize(JSContextRef ctx, JSObjectRef object);
///
/// Unlike the other object callbacks, the initialize callback is called on the least
/// derived class (the parent class) first, and the most derived class last.
/// typedef void (*JSObjectInitializeCallback) (JSContextRef ctx, JSObjectRef object);
typedef JSObjectInitializeCallback = Void Function(Pointer ctx, Pointer object);
typedef JSObjectInitializeCallbackDart = void Function(
    Pointer ctx, Pointer object);

/// typedef JSObjectFinalizeCallback
/// The callback invoked when an object is finalized (prepared for garbage collection). An object may be finalized on any thread.
/// [object] The JSObject being finalized.
/// If you named your function Finalize, you would declare it like this:
///
/// void Finalize(JSObjectRef object);
///
/// The finalize callback is called on the most derived class first, and the least
/// derived class (the parent class) last.
///
/// You must not call any function that may cause a garbage collection or an allocation
/// of a garbage collected object from within a JSObjectFinalizeCallback. This includes
/// all functions that have a JSContextRef parameter.
/// typedef void (*JSObjectFinalizeCallback) (JSObjectRef object);
typedef JSObjectFinalizeCallback = Void Function(Pointer object);
typedef JSObjectFinalizeCallbackDart = void Function(Pointer object);

/// typedef JSObjectHasPropertyCallback
/// The callback invoked when determining whether an object has a property.
/// [ctx] The execution context to use.
/// [object] The JSObject to search for the property.
/// [propertyName] A JSString containing the name of the property look up.
/// [@result] true if object has the property, otherwise false.
/// If you named your function HasProperty, you would declare it like this:
///
/// bool HasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
///
/// If this function returns false, the hasProperty request forwards to object's statically declared properties, then its parent class chain (which includes the default object class), then its prototype chain.
///
/// This callback enables optimization in cases where only a property's existence needs to be known, not its value, and computing its value would be expensive.
///
/// If this callback is NULL, the getProperty callback will be used to service hasProperty requests.
/// typedef bool (*JSObjectHasPropertyCallback) (JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
typedef JSObjectHasPropertyCallback = Int8 Function(
    Pointer ctx, Pointer object, Pointer propertyName);
typedef JSObjectHasPropertyCallbackDart = int Function(
    Pointer ctx, Pointer object, Pointer propertyName);

/// typedef JSObjectGetPropertyCallback
/// The callback invoked when getting a property's value.
/// [ctx] The execution context to use.
/// [object] The JSObject to search for the property.
/// [propertyName] A JSString containing the name of the property to get.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] The property's value if object has the property, otherwise NULL.
/// If you named your function GetProperty, you would declare it like this:
///
/// JSValueRef GetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
///
/// If this function returns NULL, the get request forwards to object's statically declared properties, then its parent class chain (which includes the default object class), then its prototype chain.
/// typedef JSValueRef (*JSObjectGetPropertyCallback) (JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
typedef JSObjectGetPropertyCallback = Pointer Function(Pointer ctx,
    Pointer object, Pointer propertyName, Pointer<Pointer> exception);
typedef JSObjectGetPropertyCallbackDart = Pointer Function(Pointer ctx,
    Pointer object, Pointer propertyName, Pointer<Pointer> exception);

/// typedef JSObjectSetPropertyCallback
/// The callback invoked when setting a property's value.
/// [ctx] The execution context to use.
/// [object] The JSObject on which to set the property's value.
/// [propertyName] A JSString containing the name of the property to set.
/// [value] A JSValue to use as the property's value.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] true if the property was set, otherwise false.
/// If you named your function SetProperty, you would declare it like this:
///
/// bool SetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef* exception);
///
/// If this function returns false, the set request forwards to object's statically declared properties, then its parent class chain (which includes the default object class).
/// typedef bool (*JSObjectSetPropertyCallback) (JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef* exception);
typedef JSObjectSetPropertyCallback = Int8 Function(Pointer ctx, Pointer object,
    Pointer propertyName, Pointer value, Pointer<Pointer> exception);
typedef JSObjectSetPropertyCallbackDart = int Function(
    Pointer ctx,
    Pointer object,
    Pointer propertyName,
    Pointer value,
    Pointer<Pointer> exception);

/// typedef JSObjectDeletePropertyCallback
/// The callback invoked when deleting a property.
/// [ctx] The execution context to use.
/// [object] The JSObject in which to delete the property.
/// [propertyName] A JSString containing the name of the property to delete.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] true if propertyName was successfully deleted, otherwise false.
/// If you named your function DeleteProperty, you would declare it like this:
///
/// bool DeleteProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
///
/// If this function returns false, the delete request forwards to object's statically declared properties, then its parent class chain (which includes the default object class).
/// typedef bool (*JSObjectDeletePropertyCallback) (JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
typedef JSObjectDeletePropertyCallback = Int8 Function(Pointer ctx,
    Pointer object, Pointer propertyName, Pointer<Pointer> exception);
typedef JSObjectDeletePropertyCallbackDart = int Function(Pointer ctx,
    Pointer object, Pointer propertyName, Pointer<Pointer> exception);

/// typedef JSObjectGetPropertyNamesCallback
/// The callback invoked when collecting the names of an object's properties.
/// [ctx] The execution context to use.
/// [object] The JSObject whose property names are being collected.
/// [propertyNames] A JavaScript property name accumulator in which to accumulate the names of object's properties.
/// If you named your function GetPropertyNames, you would declare it like this:
///
/// void GetPropertyNames(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames);
///
/// Property name accumulators are used by JSObjectCopyPropertyNames and JavaScript for...in loops.
///
/// Use JSPropertyNameAccumulatorAddName to add property names to accumulator. A class's getPropertyNames callback only needs to provide the names of properties that the class vends through a custom getProperty or setProperty callback. Other properties, including statically declared properties, properties vended by other classes, and properties belonging to object's prototype, are added independently.
/// typedef void (*JSObjectGetPropertyNamesCallback) (JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames);
typedef JSObjectGetPropertyNamesCallback = Void Function(
    Pointer ctx, Pointer object, Pointer propertyNames);
typedef JSObjectGetPropertyNamesCallbackDart = void Function(
    Pointer ctx, Pointer object, Pointer propertyNames);

/// typedef JSObjectCallAsFunctionCallback
/// The callback invoked when an object is called as a function.
/// [ctx] The execution context to use.
/// [function] A JSObject that is the function being called.
/// [thisObject] A JSObject that is the 'this' variable in the function's scope.
/// [argumentCount] An integer count of the number of arguments in arguments.
/// [arguments] A JSValue array of the  arguments passed to the function.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] A JSValue that is the function's return value.
/// If you named your function CallAsFunction, you would declare it like this:
///
/// JSValueRef CallAsFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
///
/// If your callback were invoked by the JavaScript expression 'myObject.myFunction()', function would be set to myFunction, and thisObject would be set to myObject.
///
/// If this callback is NULL, calling your object as a function will throw an exception.
/// typedef JSValueRef (*JSObjectCallAsFunctionCallback) (JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
typedef JSObjectCallAsFunctionCallback = Pointer Function(
    Pointer ctx,
    Pointer function,
    Pointer thisObject,
    Uint32 argumentCount,
    Pointer<Pointer> arguments,
    Pointer<Pointer> exception);
typedef JSObjectCallAsFunctionCallbackDart = Pointer Function(
    Pointer ctx,
    Pointer function,
    Pointer thisObject,
    int argumentCount,
    Pointer<Pointer> arguments,
    Pointer<Pointer> exception);

/// typedef JSObjectCallAsConstructorCallback
/// The callback invoked when an object is used as a constructor in a 'new' expression.
/// [ctx] The execution context to use.
/// [constructor] A JSObject that is the constructor being called.
/// [argumentCount] An integer count of the number of arguments in arguments.
/// [arguments] A JSValue array of the  arguments passed to the function.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] A JSObject that is the constructor's return value.
/// If you named your function CallAsConstructor, you would declare it like this:
///
/// JSObjectRef CallAsConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
///
/// If your callback were invoked by the JavaScript expression 'new myConstructor()', constructor would be set to myConstructor.
///
/// If this callback is NULL, using your object as a constructor in a 'new' expression will throw an exception.
/// typedef JSObjectRef (*JSObjectCallAsConstructorCallback) (JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
typedef JSObjectCallAsConstructorCallback = Pointer Function(
    Pointer ctx,
    Pointer constructor,
    Uint32 argumentCount,
    Pointer<Pointer> arguments,
    Pointer<Pointer> exception);
typedef JSObjectCallAsConstructorCallbackDart = Pointer Function(
    Pointer ctx,
    Pointer constructor,
    int argumentCount,
    Pointer<Pointer> arguments,
    Pointer<Pointer> exception);

/// typedef JSObjectHasInstanceCallback
/// hasInstance The callback invoked when an object is used as the target of an 'instanceof' expression.
/// [ctx] The execution context to use.
/// [constructor] The JSObject that is the target of the 'instanceof' expression.
/// [possibleInstance] The JSValue being tested to determine if it is an instance of constructor.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] true if possibleInstance is an instance of constructor, otherwise false.
/// If you named your function HasInstance, you would declare it like this:
///
/// bool HasInstance(JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception);
///
/// If your callback were invoked by the JavaScript expression 'someValue instanceof myObject', constructor would be set to myObject and possibleInstance would be set to someValue.
///
/// If this callback is NULL, 'instanceof' expressions that target your object will return false.
///
/// Standard JavaScript practice calls for objects that implement the callAsConstructor callback to implement the hasInstance callback as well.
/// typedef bool (*JSObjectHasInstanceCallback)  (JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception);
typedef JSObjectHasInstanceCallback = Int8 Function(Pointer ctx,
    Pointer constructor, Pointer possibleInstance, Pointer<Pointer> exception);
typedef JSObjectHasInstanceCallbackDart = int Function(Pointer ctx,
    Pointer constructor, Pointer possibleInstance, Pointer<Pointer> exception);

/// typedef JSObjectConvertToTypeCallback
/// The callback invoked when converting an object to a particular JavaScript type.
/// [ctx] The execution context to use.
/// [object] The JSObject to convert.
/// [type] A JSType specifying the JavaScript type to convert to.
/// [exception] A pointer to a JSValueRef in which to return an exception, if any.
/// [@result] The objects's converted value, or NULL if the object was not converted.
/// If you named your function ConvertToType, you would declare it like this:
///
/// JSValueRef ConvertToType(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception);
///
/// If this function returns false, the conversion request forwards to object's parent class chain (which includes the default object class).
///
/// This function is only invoked when converting an object to number or string. An object converted to boolean is 'true.' An object converted to object is itself.
/// typedef JSValueRef (*JSObjectConvertToTypeCallback) (JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception);
typedef JSObjectConvertToTypeCallback = Pointer Function(
    Pointer ctx, Pointer object, Int8 type, Pointer<Pointer> exception);
typedef JSObjectConvertToTypeCallbackDart = Pointer Function(
    Pointer ctx, Pointer object, int type, Pointer<Pointer> exception);

/// struct JSStaticValue
/// This structure describes a statically declared value property.
final class JSStaticValue extends Struct {
  /// (const char* ) A null-terminated UTF8 string containing the property's name.
  external Pointer<Utf8> name;

  /// (JSObjectGetPropertyCallback) A JSObjectGetPropertyCallback to invoke when getting the property's value.
  external Pointer<NativeFunction<JSObjectGetPropertyCallback>> getProperty;

  /// (JSObjectSetPropertyCallback) A JSObjectSetPropertyCallback to invoke when setting the property's value. May be NULL if the ReadOnly attribute is set.
  external Pointer<NativeFunction<JSObjectSetPropertyCallback>> setProperty;

  /// (unsigned) A logically ORed set of [JSPropertyAttributes] to give to the property.
  @Uint32()
  external int attributes;

  void setValue(JSStaticValueStruct struct) {
    this.name = struct.name;
    this.setProperty = struct.setProperty;
    this.getProperty = struct.getProperty;
    this.attributes = struct.attributes;
  }
}

extension JSStaticValuePointer on Pointer<JSStaticValue> {
  static Pointer<JSStaticValue> allocate(JSStaticValueStruct struct) {
    return malloc.call<JSStaticValue>(1)..ref.setValue(struct);
  }

  static Pointer<JSStaticValue> allocateArray(
      List<JSStaticValueStruct> structList) {
    final pointer = malloc.call<JSStaticValue>(structList.length + 1);
    for (int index = 0; index < structList.length; index++) {
      pointer[index].setValue(structList[index]);
    }
    pointer[structList.length].setValue(JSStaticValueStruct());
    return pointer;
  }
}

class JSStaticValueStruct {
  Pointer<Utf8> name;
  Pointer<NativeFunction<JSObjectGetPropertyCallback>> getProperty;
  Pointer<NativeFunction<JSObjectSetPropertyCallback>> setProperty;
  int attributes;

  JSStaticValueStruct({
    Pointer<Utf8>? name,
    Pointer<NativeFunction<JSObjectGetPropertyCallback>>? getProperty,
    Pointer<NativeFunction<JSObjectSetPropertyCallback>>? setProperty,
    int attributes = JSPropertyAttributes.kJSPropertyAttributeNone,
  })  : this.name = name ?? nullptr,
        this.getProperty = getProperty ?? nullptr,
        this.setProperty = setProperty ?? nullptr,
        this.attributes = attributes;
}

/// struct JSStaticFunction
/// This structure describes a statically declared function property.
final class JSStaticFunction extends Struct {
  /// (const char* ) A null-terminated UTF8 string containing the property's name.
  external Pointer<Utf8> name;

  /// (JSObjectCallAsFunctionCallback) A JSObjectCallAsFunctionCallback to invoke when the property is called as a function.
  external Pointer<NativeFunction<JSObjectCallAsFunctionCallback>>
      callAsFunction;

  /// (unsigned) A logically ORed set of [JSPropertyAttributes] to give to the property.
  @Uint32()
  external int attributes;

  void setValue(JSStaticFunctionStruct struct) {
    this.name = struct.name;
    this.callAsFunction = struct.callAsFunction;
    this.attributes = struct.attributes;
  }
}

extension JSStaticFunctionPointer on Pointer<JSStaticFunction> {
  static Pointer<JSStaticFunction> allocate(JSStaticFunctionStruct struct) {
    return malloc.call<JSStaticFunction>(1)..ref.setValue(struct);
  }

  static Pointer<JSStaticFunction> allocateArray(
      List<JSStaticFunctionStruct> structList) {
    final pointer = malloc.call<JSStaticFunction>(structList.length + 1);
    for (int index = 0; index < structList.length; index++) {
      pointer[index].setValue(structList[index]);
    }
    pointer[structList.length].setValue(JSStaticFunctionStruct());
    return pointer;
  }
}

class JSStaticFunctionStruct {
  Pointer<Utf8> name;
  Pointer<NativeFunction<JSObjectCallAsFunctionCallback>> callAsFunction;
  int attributes;

  JSStaticFunctionStruct({
    Pointer<Utf8>? name,
    Pointer<NativeFunction<JSObjectCallAsFunctionCallback>>? callAsFunction,
    int attributes = JSPropertyAttributes.kJSPropertyAttributeNone,
  })  : this.name = name ?? nullptr,
        this.callAsFunction = callAsFunction ?? nullptr,
        this.attributes = attributes;
}

/// struct JSStaticFunction
/// This structure contains properties and callbacks that define a type of object. All fields other than the version field are optional. Any pointer may be NULL.
/// The staticValues and staticFunctions arrays are the simplest and most efficient means for vending custom properties. Statically declared properties autmatically service requests like getProperty, setProperty, and getPropertyNames. Property access callbacks are required only to implement unusual properties, like array indexes, whose names are not known at compile-time.
///
/// If you named your getter function "GetX" and your setter function "SetX", you would declare a JSStaticValue array containing "X" like this:
///
/// JSStaticValue StaticValueArray[] = {
//    { "X", GetX, SetX, kJSPropertyAttributeNone },
//    { 0, 0, 0, 0 }
// };
/// Standard JavaScript practice calls for storing function objects in prototypes, so they can be shared. The default JSClass created by JSClassCreate follows this idiom, instantiating objects with a shared, automatically generating prototype containing the class's function objects. The kJSClassAttributeNoAutomaticPrototype attribute specifies that a JSClass should not automatically generate such a prototype. The resulting JSClass instantiates objects with the default object prototype, and gives each instance object its own copy of the class's function objects.
//
// A NULL callback specifies that the default object callback should substitute, except in the case of hasProperty, where it specifies that getProperty should substitute.
final class JSClassDefinition extends Struct {
  /// (int) The version number of this structure. The current version is 0.
  @Int32()
  external int version;

  /// (JSClassAttributes) A logically ORed set of [JSClassAttributes] to give to the class.
  @Int16()
  external int attributes;

  /// (const char* ) A null-terminated UTF8 string containing the class's name.
  external Pointer<Utf8> className;

  /// (JSClassRef) A JSClass to set as the class's parent class. Pass NULL use the default object class.
  external Pointer parentClass;

  /// (const JSStaticValue*) A JSStaticValue array containing the class's statically declared value properties. Pass NULL to specify no statically declared value properties. The array must be terminated by a JSStaticValue whose name field is NULL.
  external Pointer<JSStaticValue> staticValues;

  /// (const JSStaticFunction*) A JSStaticFunction array containing the class's statically declared function properties. Pass NULL to specify no statically declared function properties. The array must be terminated by a JSStaticFunction whose name field is NULL.
  external Pointer<JSStaticFunction> staticFunctions;

  /// (JSObjectInitializeCallback) The callback invoked when an object is first created. Use this callback to initialize the object.
  external Pointer<NativeFunction<JSObjectInitializeCallback>> initialize;

  /// (JSObjectFinalizeCallback) The callback invoked when an object is finalized (prepared for garbage collection). Use this callback to release resources allocated for the object, and perform other cleanup.
  external Pointer<NativeFunction<JSObjectFinalizeCallback>> finalize;

  /// (JSObjectHasPropertyCallback) The callback invoked when determining whether an object has a property. If this field is NULL, getProperty is called instead. The hasProperty callback enables optimization in cases where only a property's existence needs to be known, not its value, and computing its value is expensive.
  external Pointer<NativeFunction<JSObjectHasPropertyCallback>> hasProperty;

  /// (JSObjectGetPropertyCallback) The callback invoked when getting a property's value.
  external Pointer<NativeFunction<JSObjectGetPropertyCallback>> getProperty;

  /// (JSObjectSetPropertyCallback) The callback invoked when setting a property's value.
  external Pointer<NativeFunction<JSObjectSetPropertyCallback>> setProperty;

  /// (JSObjectDeletePropertyCallback) The callback invoked when deleting a property.
  external Pointer<NativeFunction<JSObjectDeletePropertyCallback>>
      deleteProperty;

  /// (JSObjectGetPropertyNamesCallback) The callback invoked when collecting the names of an object's properties.
  external Pointer<NativeFunction<JSObjectGetPropertyNamesCallback>>
      getPropertyNames;

  /// (JSObjectCallAsFunctionCallback) The callback invoked when an object is called as a function.
  external Pointer<NativeFunction<JSObjectCallAsFunctionCallback>>
      callAsFunction;

  /// (JSObjectCallAsConstructorCallback) The callback invoked when an object is used as the target of an 'instanceof' expression.
  external Pointer<NativeFunction<JSObjectCallAsConstructorCallback>>
      callAsConstructor;

  /// (JSObjectHasInstanceCallback) The callback invoked when an object is used as a constructor in a 'new' expression.
  external Pointer<NativeFunction<JSObjectHasInstanceCallback>> hasInstance;

  /// (JSObjectConvertToTypeCallback) The callback invoked when converting an object to a particular JavaScript type.
  external Pointer<NativeFunction<JSObjectConvertToTypeCallback>> convertToType;
}

extension JSClassDefinitionPointer on Pointer<JSClassDefinition> {
  static Pointer<JSClassDefinition> allocate({
    int version = 0,
    int attributes = JSClassAttributes.kJSClassAttributeNone,
    required Pointer<Utf8> className,
    Pointer? parentClass,
    Pointer<JSStaticValue>? staticValues,
    Pointer<JSStaticFunction>? staticFunctions,
    Pointer<NativeFunction<JSObjectInitializeCallback>>? initialize,
    Pointer<NativeFunction<JSObjectFinalizeCallback>>? finalize,
    Pointer<NativeFunction<JSObjectHasPropertyCallback>>? hasProperty,
    Pointer<NativeFunction<JSObjectGetPropertyCallback>>? getProperty,
    Pointer<NativeFunction<JSObjectSetPropertyCallback>>? setProperty,
    Pointer<NativeFunction<JSObjectDeletePropertyCallback>>? deleteProperty,
    Pointer<NativeFunction<JSObjectGetPropertyNamesCallback>>? getPropertyNames,
    Pointer<NativeFunction<JSObjectCallAsFunctionCallback>>? callAsFunction,
    Pointer<NativeFunction<JSObjectCallAsConstructorCallback>>?
        callAsConstructor,
    Pointer<NativeFunction<JSObjectHasInstanceCallback>>? hasInstance,
    Pointer<NativeFunction<JSObjectConvertToTypeCallback>>? convertToType,
  }) {
    return malloc.call<JSClassDefinition>(1)
      ..ref.version = version
      ..ref.attributes = attributes
      ..ref.className = className
      ..ref.parentClass = parentClass ?? nullptr
      ..ref.staticValues = staticValues ?? nullptr
      ..ref.staticFunctions = staticFunctions ?? nullptr
      ..ref.initialize = initialize ?? nullptr
      ..ref.finalize = finalize ?? nullptr
      ..ref.hasProperty = hasProperty ?? nullptr
      ..ref.getProperty = getProperty ?? nullptr
      ..ref.setProperty = setProperty ?? nullptr
      ..ref.deleteProperty = deleteProperty ?? nullptr
      ..ref.getPropertyNames = getPropertyNames ?? nullptr
      ..ref.callAsFunction = callAsFunction ?? nullptr
      ..ref.callAsConstructor = callAsConstructor ?? nullptr
      ..ref.hasInstance = hasInstance ?? nullptr
      ..ref.convertToType = convertToType ?? nullptr;
  }
}

/// Creates a JavaScript class suitable for use with JSObjectMake.
/// [definition] (JSClassDefinition*) A JSClassDefinition that defines the class.
/// [@result] (JSClassRef) A JSClass with the given definition. Ownership follows the Create Rule.
final Pointer Function(Pointer<JSClassDefinition> definition) jSClassCreate =
    JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer)>>('JSClassCreate')
        .asFunction();

/// Retains a JavaScript class.
/// [jsClass] (JSClassRef) The JSClass to retain.
/// [@result] (JSClassRef) A JSClass that is the same as jsClass.
final Pointer Function(Pointer jsClass) jSClassRetain = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSClassRetain')
    .asFunction();

/// Releases a JavaScript class.
/// [jsClass] (JSClassRef) The JSClass to release.
final void Function(Pointer jsClass) jSClassRelease = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer)>>('JSClassRelease')
    .asFunction();

/// Creates a JavaScript object.
/// The default object class does not allocate storage for private data, so you must provide a non-NULL jsClass to JSObjectMake if you want your object to be able to store private data.
///
/// data is set on the created object before the intialize methods in its class chain are called. This enables the initialize methods to retrieve and manipulate data through JSObjectGetPrivate.
/// [ctx] (JSContextRef) The execution context to use.
/// [jsClass] (JSClassRef) The JSClass to assign to the object. Pass NULL to use the default object class.
/// [data] (void*) A void* to set as the object's private data. Pass NULL to specify no private data.
/// [@result] (JSObjectRef) A JSObject with the given class and private data.
final Pointer Function(Pointer ctx, Pointer jsClass, Pointer data)
    jSObjectMake = JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer, Pointer)>>(
            'JSObjectMake')
        .asFunction();

/// Convenience method for creating a JavaScript function with a given callback as its implementation.
/// [ctx] (JSContextRef) The execution context to use.
/// [name] (JSStringRef) A JSString containing the function's name. This will be used when converting the function to string. Pass NULL to create an anonymous function.
/// [callAsFunction] (JSObjectCallAsFunctionCallback) The JSObjectCallAsFunctionCallback to invoke when the function is called.
/// [@result] (JSObjectRef) A JSObject that is a function. The object's prototype will be the default function prototype.
final Pointer Function(Pointer ctx, Pointer name,
        Pointer<NativeFunction<JSObjectCallAsFunctionCallback>> callAsFunction)
    jSObjectMakeFunctionWithCallback = JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer, Pointer)>>(
            'JSObjectMakeFunctionWithCallback')
        .asFunction();

/// Convenience method for creating a JavaScript constructor.
/// The default object constructor takes no arguments and constructs an object of class jsClass with no private data.
/// [ctx] (JSContextRef) The execution context to use.
/// [jsClass] (JSClassRef) A JSClass that is the class your constructor will assign to the objects its constructs. jsClass will be used to set the constructor's .prototype property, and to evaluate 'instanceof' expressions. Pass NULL to use the default object class.
/// [callAsConstructor] (JSObjectCallAsConstructorCallback) A JSObjectCallAsConstructorCallback to invoke when your constructor is used in a 'new' expression. Pass NULL to use the default object constructor.
/// [@result] (JSObjectRef) A JSObject that is a constructor. The object's prototype will be the default object prototype.
final Pointer Function(
    Pointer ctx,
    Pointer jsClass,
    Pointer<NativeFunction<JSObjectCallAsConstructorCallback>>
        callAsConstructor) jSObjectMakeConstructor = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer, Pointer, Pointer)>>(
        'JSObjectMakeConstructor')
    .asFunction();

/// Creates a JavaScript Array object.
/// The behavior of this function does not exactly match the behavior of the built-in Array constructor. Specifically, if one argument
/// is supplied, this function returns an array with one element.
/// [ctx] (JSContextRef) The execution context to use.
/// [argumentCount] (size_t) An integer count of the number of arguments in arguments.
/// [arguments] (JSValueRef[]) A JSValue array of data to populate the Array with. Pass NULL if argumentCount is 0.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObject that is an Array.
final Pointer Function(Pointer ctx, int argumentCount,
        Pointer<Pointer> arguments, Pointer<Pointer> exception)
    jSObjectMakeArray = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Uint32, Pointer,
                    Pointer<Pointer>)>>('JSObjectMakeArray')
        .asFunction();

/// Creates a JavaScript Date object, as if by invoking the built-in Date constructor.
/// [ctx] (JSContextRef) The execution context to use.
/// [argumentCount] (size_t) An integer count of the number of arguments in arguments.
/// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the Date Constructor. Pass NULL if argumentCount is 0.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObject that is a Date.
final Pointer Function(Pointer ctx, int argumentCount,
        Pointer<Pointer> arguments, Pointer<Pointer> exception)
    jSObjectMakeDate = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Uint32, Pointer,
                    Pointer<Pointer>)>>('JSObjectMakeDate')
        .asFunction();

/// Creates a JavaScript Error object, as if by invoking the built-in Error constructor.
/// [ctx] (JSContextRef) The execution context to use.
/// [argumentCount] (size_t) An integer count of the number of arguments in arguments.
/// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the Error Constructor. Pass NULL if argumentCount is 0.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObject that is a Error.
final Pointer Function(Pointer ctx, int argumentCount,
        Pointer<Pointer> arguments, Pointer<Pointer> exception)
    jSObjectMakeError = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Uint32, Pointer,
                    Pointer<Pointer>)>>('JSObjectMakeError')
        .asFunction();

/// Creates a JavaScript RegExp object, as if by invoking the built-in RegExp constructor.
/// [ctx] (JSContextRef) The execution context to use.
/// [argumentCount] (size_t) An integer count of the number of arguments in arguments.
/// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the RegExp Constructor. Pass NULL if argumentCount is 0.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObject that is a RegExp.
final Pointer Function(Pointer ctx, int argumentCount,
        Pointer<Pointer> arguments, Pointer<Pointer> exception)
    jSObjectMakeRegExp = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Uint32, Pointer,
                    Pointer<Pointer>)>>('JSObjectMakeRegExp')
        .asFunction();

/// Creates a JavaScript promise object by invoking the provided executor.
/// [ctx] (JSContextRef) The execution context to use.
/// [resolve] (JSObjectRef*) A pointer to a JSObjectRef in which to store the resolve function for the new promise. Pass NULL if you do not care to store the resolve callback.
/// [reject] (JSObjectRef*) A pointer to a JSObjectRef in which to store the reject function for the new promise. Pass NULL if you do not care to store the reject callback.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) A JSObject that is a promise or NULL if an exception occurred.
final Pointer Function(Pointer ctx, Pointer resolve, Pointer reject,
        Pointer<Pointer> exception) jSObjectMakeDeferredPromise =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Pointer,
                    Pointer<Pointer>)>>('JSObjectMakeDeferredPromise')
        .asFunction();

/// Creates a function with a given script as its body.
/// Use this method when you want to execute a script repeatedly, to avoid the cost of re-parsing the script before each execution.
/// [ctx] (JSContextRef) The execution context to use.
/// [name] (JSStringRef) A JSString containing the function's name. This will be used when converting the function to string. Pass NULL to create an anonymous function.
/// [parameterCount] (unsigned) An integer count of the number of parameter names in parameterNames.
/// [parameterNames] (JSStringRef[]) A JSString array containing the names of the function's parameters. Pass NULL if parameterCount is 0.
/// [body] (JSStringRef) A JSString containing the script to use as the function's body.
/// [sourceURL] (JSStringRef) A JSString containing a URL for the script's source file. This is only used when reporting exceptions. Pass NULL if you do not care to include source file information in exceptions.
/// [startingLineNumber] (int) An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions. The value is one-based, so the first line is line 1 and invalid values are clamped to 1.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store a syntax error exception, if any. Pass NULL if you do not care to store a syntax error exception.
/// [@result] (JSObjectRef) A JSObject that is a function, or NULL if either body or parameterNames contains a syntax error. The object's prototype will be the default function prototype.
final Pointer Function(
        Pointer ctx,
        Pointer name,
        int parameterCount,
        Pointer parameterNames,
        Pointer body,
        Pointer sourceURL,
        int startingLineNumber,
        Pointer<Pointer> exception) jSObjectMakeFunction =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Int32, Pointer, Pointer,
                    Pointer, Int32, Pointer<Pointer>)>>('JSObjectMakeFunction')
        .asFunction();

/// Gets an object's prototype.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) A JSObject whose prototype you want to get.
/// [@result] (JSValueRef) A JSValue that is the object's prototype.
final Pointer Function(Pointer ctx, Pointer object) jSObjectGetPrototype =
    JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer)>>(
            'JSObjectGetPrototype')
        .asFunction();

/// Sets an object's prototype.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose prototype you want to set.
/// [value] (JSValueRef) A JSValue to set as the object's prototype.
final void Function(Pointer ctx, Pointer object, Pointer value)
    jSObjectSetPrototype = JscFfi.lib
        .lookup<NativeFunction<Void Function(Pointer, Pointer, Pointer)>>(
            'JSObjectSetPrototype')
        .asFunction();

/// Tests whether an object has a given property.
/// [ctx] (JSContextRef)
/// [object] (JSObjectRef) The JSObject to test.
/// [propertyName] (JSStringRef) A JSString containing the property's name.
/// [@result] (bool) true if the object has a property whose name matches propertyName, otherwise false.
final int Function(Pointer ctx, Pointer object, Pointer propertyName)
    jSObjectHasProperty = JscFfi.lib
        .lookup<NativeFunction<Int8 Function(Pointer, Pointer, Pointer)>>(
            'JSObjectHasProperty')
        .asFunction();

/// Gets a property from an object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to get.
/// [propertyName] (JSStringRef) A JSString containing the property's name.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSValueRef) The property's value if object has the property, otherwise the undefined value.
final Pointer Function(Pointer ctx, Pointer object, Pointer propertyName,
        Pointer<Pointer> exception) jSObjectGetProperty =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Pointer,
                    Pointer<Pointer>)>>('JSObjectGetProperty')
        .asFunction();

/// Sets a property on an object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to set.
/// [propertyName] (JSStringRef) A JSString containing the property's name.
/// [value] (JSValueRef) A JSValueRef to use as the property's value.
/// [attributes] (JSPropertyAttributes) A logically ORed set of JSPropertyAttributes to give to the property.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
final void Function(Pointer ctx, Pointer object, Pointer propertyName,
        Pointer value, int attributes, Pointer<Pointer> exception)
    jSObjectSetProperty = JscFfi.lib
        .lookup<
            NativeFunction<
                Void Function(Pointer, Pointer, Pointer, Pointer, Int32,
                    Pointer<Pointer>)>>('JSObjectSetProperty')
        .asFunction();

/// Deletes a property from an object.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to delete.
/// [propertyName] (JSStringRef) A JSString containing the property's name.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if the delete operation succeeds, otherwise false (for example, if the property has the kJSPropertyAttributeDontDelete attribute set).
final int Function(Pointer ctx, Pointer object, Pointer propertyName,
        Pointer<Pointer> exception) jSObjectDeleteProperty =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Int8 Function(Pointer, Pointer, Pointer,
                    Pointer<Pointer>)>>('JSObjectDeleteProperty')
        .asFunction();

/// Tests whether an object has a given property using a JSValueRef as the property key.
/// This function is the same as performing "propertyKey in object" from JavaScript.
/// [ctx] (JSContextRef)
/// [object] (JSObjectRef) The JSObject to test.
/// [propertyKey] (JSValueRef) A JSValueRef containing the property key to use when looking up the property.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if the object has a property whose name matches propertyKey, otherwise false.
final int Function(Pointer ctx, Pointer object, Pointer propertyKey,
        Pointer<Pointer> exception) jSObjectHasPropertyForKey =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Int8 Function(Pointer, Pointer, Pointer,
                    Pointer<Pointer>)>>('JSObjectHasPropertyForKey')
        .asFunction();

/// Gets a property from an object using a JSValueRef as the property key.
/// This function is the same as performing "object[propertyKey]" from JavaScript.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to get.
/// [propertyKey] (JSValueRef) A JSValueRef containing the property key to use when looking up the property.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSValueRef) The property's value if object has the property key, otherwise the undefined value.
final Pointer Function(Pointer ctx, Pointer object, Pointer propertyKey,
        Pointer<Pointer> exception) jSObjectGetPropertyForKey =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Pointer,
                    Pointer<Pointer>)>>('JSObjectGetPropertyForKey')
        .asFunction();

/// Sets a property on an object using a JSValueRef as the property key.
/// This function is the same as performing "object[propertyKey] = value" from JavaScript.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to set.
/// [propertyKey] (JSValueRef) A JSValueRef containing the property key to use when looking up the property.
/// [value] (JSValueRef) A JSValueRef to use as the property's value.
/// [attributes] (JSPropertyAttributes) A logically ORed set of JSPropertyAttributes to give to the property.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
final void Function(Pointer ctx, Pointer object, Pointer propertyKey,
        Pointer value, int attributes, Pointer<Pointer> exception)
    jSObjectSetPropertyForKey = JscFfi.lib
        .lookup<
            NativeFunction<
                Void Function(Pointer, Pointer, Pointer, Pointer, Int32,
                    Pointer<Pointer>)>>('JSObjectSetPropertyForKey')
        .asFunction();

/// Deletes a property from an object using a JSValueRef as the property key.
/// This function is the same as performing "delete object[propertyKey]" from JavaScript.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to delete.
/// [propertyKey] (JSValueRef) A JSValueRef containing the property key to use when looking up the property.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (bool) true if the delete operation succeeds, otherwise false (for example, if the property has the kJSPropertyAttributeDontDelete attribute set).
final int Function(Pointer ctx, Pointer object, Pointer propertyKey,
        Pointer<Pointer> exception) jSObjectDeletePropertyForKey =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Int8 Function(Pointer, Pointer, Pointer,
                    Pointer<Pointer>)>>('JSObjectDeletePropertyForKey')
        .asFunction();

/// Gets a property from an object by numeric index.
/// Calling JSObjectGetPropertyAtIndex is equivalent to calling JSObjectGetProperty with a string containing propertyIndex, but JSObjectGetPropertyAtIndex provides optimized access to numeric properties.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to get.
/// [propertyIndex] (unsigned) An integer value that is the property's name.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSValueRef) The property's value if object has the property, otherwise the undefined value.
final Pointer Function(Pointer ctx, Pointer object, int propertyIndex,
        Pointer<Pointer> exception) jSObjectGetPropertyAtIndex =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Int32,
                    Pointer<Pointer>)>>('JSObjectGetPropertyAtIndex')
        .asFunction();

/// Sets a property on an object by numeric index.
/// Calling JSObjectSetPropertyAtIndex is equivalent to calling JSObjectSetProperty with a string containing propertyIndex, but JSObjectSetPropertyAtIndex provides optimized access to numeric properties.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject whose property you want to set.
/// [propertyIndex] (unsigned) The property's name as a number.
/// [value] (JSValueRef) A JSValue to use as the property's value.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
final void Function(Pointer ctx, Pointer object, int propertyIndex,
        Pointer value, Pointer<Pointer> exception) jSObjectSetPropertyAtIndex =
    JscFfi.lib
        .lookup<
            NativeFunction<
                Void Function(Pointer, Pointer, Int32, Pointer,
                    Pointer<Pointer>)>>('JSObjectSetPropertyAtIndex')
        .asFunction();

/// Gets an object's private data.
/// [object] (JSObjectRef) A JSObject whose private data you want to get.
/// [@result] (void*) A void* that is the object's private data, if the object has private data, otherwise NULL.
final Pointer Function(Pointer object) jSObjectGetPrivate = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>('JSObjectGetPrivate')
    .asFunction();

/// Sets a pointer to private data on an object.
/// The default object class does not allocate storage for private data. Only objects created with a non-NULL JSClass can store private data.
/// [object] (JSObjectRef) The JSObject whose private data you want to set.
/// [data] (void*) A void* to set as the object's private data.
/// [@result] (bool) true if object can store private data, otherwise false.
final int Function(Pointer object, Pointer data) jSObjectSetPrivate = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>(
        'JSObjectSetPrivate')
    .asFunction();

/// Tests whether an object can be called as a function.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject to test.
/// [@result] (bool) true if the object can be called as a function, otherwise false.
final int Function(Pointer ctx, Pointer object) jSObjectIsFunction = JscFfi.lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>(
        'JSObjectIsFunction')
    .asFunction();

/// Calls an object as a function.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject to call as a function.
/// [thisObject] (JSObjectRef) The object to use as "this," or NULL to use the global object as "this."
/// [argumentCount] (size_t) An integer count of the number of arguments in arguments.
/// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the function. Pass NULL if argumentCount is 0.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSValueRef) The JSValue that results from calling object as a function, or NULL if an exception is thrown or object is not a function.
final Pointer Function(Pointer ctx, Pointer object, Pointer thisObject,
        int argumentCount, Pointer arguments, Pointer<Pointer> exception)
    jSObjectCallAsFunction = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Pointer, Uint32, Pointer,
                    Pointer<Pointer>)>>('JSObjectCallAsFunction')
        .asFunction();

/// Tests whether an object can be called as a constructor.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject to test.
/// [@result] (bool) true if the object can be called as a constructor, otherwise false.
final int Function(Pointer ctx, Pointer object) jSObjectIsConstructor = JscFfi
    .lib
    .lookup<NativeFunction<Int8 Function(Pointer, Pointer)>>(
        'JSObjectIsConstructor')
    .asFunction();

/// Calls an object as a constructor.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The JSObject to call as a constructor.
/// [argumentCount] (size_t) An integer count of the number of arguments in arguments.
/// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the constructor. Pass NULL if argumentCount is 0.
/// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
/// [@result] (JSObjectRef) The JSObject that results from calling object as a constructor, or NULL if an exception is thrown or object is not a constructor.
final Pointer Function(Pointer ctx, Pointer object, int argumentCount,
        Pointer arguments, Pointer<Pointer> exception)
    jSObjectCallAsConstructor = JscFfi.lib
        .lookup<
            NativeFunction<
                Pointer Function(Pointer, Pointer, Uint32, Pointer,
                    Pointer<Pointer>)>>('JSObjectCallAsConstructor')
        .asFunction();

/// Gets the names of an object's enumerable properties.
/// [ctx] (JSContextRef) The execution context to use.
/// [object] (JSObjectRef) The object whose property names you want to get.
/// [@result] (JSPropertyNameArrayRef) A JSPropertyNameArray containing the names object's enumerable properties. Ownership follows the Create Rule.
final Pointer Function(Pointer ctx, Pointer object) jSObjectCopyPropertyNames =
    JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Pointer)>>(
            'JSObjectCopyPropertyNames')
        .asFunction();

/// Retains a JavaScript property name array.
/// [array] (JSPropertyNameArrayRef) The JSPropertyNameArray to retain.
/// [@result] (JSPropertyNameArrayRef) A JSPropertyNameArray that is the same as array.
final Pointer Function(Pointer array) jSPropertyNameArrayRetain = JscFfi.lib
    .lookup<NativeFunction<Pointer Function(Pointer)>>(
        'JSPropertyNameArrayRetain')
    .asFunction();

/// Releases a JavaScript property name array.
/// [array] (JSPropertyNameArrayRef) The JSPropetyNameArray to release.
final void Function(Pointer array) jSPropertyNameArrayRelease = JscFfi.lib
    .lookup<NativeFunction<Void Function(Pointer)>>(
        'JSPropertyNameArrayRelease')
    .asFunction();

/// Gets a count of the number of items in a JavaScript property name array.
/// [array] (JSPropertyNameArrayRef) The array from which to retrieve the count.
/// [@result] (size_t) An integer count of the number of names in array.
final int Function(Pointer array) jSPropertyNameArrayGetCount = JscFfi.lib
    .lookup<NativeFunction<Uint32 Function(Pointer)>>(
        'JSPropertyNameArrayGetCount')
    .asFunction();

/// Gets a property name at a given index in a JavaScript property name array.
/// [array] (JSPropertyNameArrayRef) The array from which to retrieve the property name.
/// [index] (size_t) The index of the property name to retrieve.
/// [@result] (JSStringRef) A JSStringRef containing the property name.
final Pointer Function(Pointer array, int index)
    jSPropertyNameArrayGetNameAtIndex = JscFfi.lib
        .lookup<NativeFunction<Pointer Function(Pointer, Uint32)>>(
            'JSPropertyNameArrayGetNameAtIndex')
        .asFunction();

/// Adds a property name to a JavaScript property name accumulator.
/// [accumulator] (JSPropertyNameAccumulatorRef) The accumulator object to which to add the property name.
/// [propertyName] (JSStringRef) The property name to add.
final void Function(Pointer accumulator, Pointer propertyName)
    jSPropertyNameAccumulatorAddName = JscFfi.lib
        .lookup<NativeFunction<Void Function(Pointer, Pointer)>>(
            'JSPropertyNameAccumulatorAddName')
        .asFunction();
