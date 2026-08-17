import 'dart:ffi';

import 'package:ffi/ffi.dart';
import '../binding/js_base.dart' as JSBase;
import '../binding/js_object_ref.dart' as JSObjectRef;
import '../binding/js_typed_array.dart' as JSTypedArray;
import '../jscore/js_string.dart';

import 'js_class.dart';
import 'js_context.dart';
import 'js_property_name_accumulator.dart';
import 'js_property_name_array.dart';
import 'js_value.dart';

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
typedef JSObjectHasInstanceCallbackDart = int Function(Pointer ctx,
    Pointer constructor, Pointer possibleInstance, Pointer<Pointer> exception);

/// enum JSPropertyAttributes
/// A set of JSPropertyAttributes. Combine multiple attributes by logically ORing them together.
enum JSPropertyAttributes {
  /// Specifies that a property has no special attributes.
  kJSPropertyAttributeNone,

  /// Specifies that a property is read-only.
  kJSPropertyAttributeReadOnly,

  /// Specifies that a property should not be enumerated by JSPropertyEnumerators and JavaScript for...in loops.
  kJSPropertyAttributeDontEnum,

  /// Specifies that the delete operation should fail on a property.
  kJSPropertyAttributeDontDelete
}

/// enum JSClassAttributes
/// A set of JSClassAttributes. Combine multiple attributes by logically ORing them together.
enum JSClassAttributes {
  /// kJSClassAttributeNone Specifies that a class has no special attributes.
  kJSClassAttributeNone,

  /// kJSClassAttributeNoAutomaticPrototype Specifies that a class should not automatically generate a shared prototype for its instance objects. Use kJSClassAttributeNoAutomaticPrototype in combination with JSObjectSetPrototype to manage prototypes manually.
  kJSClassAttributeNoAutomaticPrototype,
}

/// enum JSPropertyAttributes to C enum
int jSPropertyAttributesToCEnum(JSPropertyAttributes type) {
  switch (type) {
    case JSPropertyAttributes.kJSPropertyAttributeReadOnly:
      return JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeReadOnly;
    case JSPropertyAttributes.kJSPropertyAttributeDontEnum:
      return JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeDontEnum;
    case JSPropertyAttributes.kJSPropertyAttributeDontDelete:
      return JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeDontDelete;
    default:
      return JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeNone;
  }
}

/// C enum to enum JSPropertyAttributes
JSPropertyAttributes cEnumToJSPropertyAttributes(int typeCode) {
  switch (typeCode) {
    case JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeReadOnly:
      return JSPropertyAttributes.kJSPropertyAttributeReadOnly;
    case JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeDontEnum:
      return JSPropertyAttributes.kJSPropertyAttributeDontEnum;
    case JSObjectRef.JSPropertyAttributes.kJSPropertyAttributeDontDelete:
      return JSPropertyAttributes.kJSPropertyAttributeDontDelete;
    default:
      return JSPropertyAttributes.kJSPropertyAttributeNone;
  }
}

/// enum JSClassAttributes to C enum
int jSClassAttributesToCEnum(JSClassAttributes type) {
  switch (type) {
    case JSClassAttributes.kJSClassAttributeNoAutomaticPrototype:
      return JSObjectRef
          .JSClassAttributes.kJSClassAttributeNoAutomaticPrototype;
    default:
      return JSObjectRef.JSClassAttributes.kJSClassAttributeNone;
  }
}

/// C enum to enum JSClassAttributes
JSClassAttributes cEnumToJSClassAttributes(int typeCode) {
  switch (typeCode) {
    case JSObjectRef.JSClassAttributes.kJSClassAttributeNoAutomaticPrototype:
      return JSClassAttributes.kJSClassAttributeNoAutomaticPrototype;
    default:
      return JSClassAttributes.kJSClassAttributeNone;
  }
}

/// struct JSStaticValue
/// This structure describes a statically declared value property.
class JSStaticValue {
  /// Property's name.
  String name;

  /// A JSObjectGetPropertyCallback to invoke when getting the property's value.
  Pointer<NativeFunction<JSObjectRef.JSObjectGetPropertyCallback>>? getProperty;

  /// A JSObjectSetPropertyCallback to invoke when setting the property's value. May be NULL if the ReadOnly attribute is set.
  Pointer<NativeFunction<JSObjectRef.JSObjectSetPropertyCallback>>? setProperty;

  /// (unsigned) A logically ORed set of [JSPropertyAttributes] to give to the property.
  JSPropertyAttributes attributes;

  JSStaticValue({
    required this.name,
    this.getProperty,
    this.setProperty,
    this.attributes = JSPropertyAttributes.kJSPropertyAttributeNone,
  });

  Pointer<JSObjectRef.JSStaticValue> create() {
    return JSObjectRef.JSStaticValuePointer.allocate(
        JSObjectRef.JSStaticValueStruct(
      name: name.toNativeUtf8(),
      getProperty: getProperty ?? nullptr,
      setProperty: setProperty ?? nullptr,
      attributes: jSPropertyAttributesToCEnum(attributes),
    ));
  }

  JSObjectRef.JSStaticValueStruct toStruct() {
    return JSObjectRef.JSStaticValueStruct(
      name: name.toNativeUtf8(),
      getProperty: getProperty ?? nullptr,
      setProperty: setProperty ?? nullptr,
      attributes: jSPropertyAttributesToCEnum(attributes),
    );
  }
}

extension JSStaticValueArray on List<JSStaticValue> {
  Pointer<JSObjectRef.JSStaticValue> createArray() {
    return JSObjectRef.JSStaticValuePointer.allocateArray(
        this.map((e) => e.toStruct()).toList());
  }
}

/// struct JSStaticFunction
/// This structure describes a statically declared function property.
class JSStaticFunction {
  /// Property's name.
  String name;

  /// A JSObjectCallAsFunctionCallback to invoke when the property is called as a function.
  Pointer<NativeFunction<JSObjectRef.JSObjectCallAsFunctionCallback>>?
      callAsFunction;

  /// A logically ORed set of [JSPropertyAttributes] to give to the property.
  JSPropertyAttributes attributes;

  JSStaticFunction({
    required this.name,
    this.callAsFunction,
    this.attributes = JSPropertyAttributes.kJSPropertyAttributeNone,
  });

  Pointer<JSObjectRef.JSStaticFunction> create() {
    return JSObjectRef.JSStaticFunctionPointer.allocate(
        JSObjectRef.JSStaticFunctionStruct(
      name: name.toNativeUtf8(),
      callAsFunction: callAsFunction ?? nullptr,
      attributes: jSPropertyAttributesToCEnum(attributes),
    ));
  }

  JSObjectRef.JSStaticFunctionStruct toStruct() {
    return JSObjectRef.JSStaticFunctionStruct(
      name: name.toNativeUtf8(),
      callAsFunction: callAsFunction ?? nullptr,
      attributes: jSPropertyAttributesToCEnum(attributes),
    );
  }
}

extension JSStaticFunctionArray on List<JSStaticFunction> {
  Pointer<JSObjectRef.JSStaticFunction> createArray() {
    return JSObjectRef.JSStaticFunctionPointer.allocateArray(
        this.map((e) => e.toStruct()).toList());
  }
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
class JSClassDefinition {
  /// The version number of this structure. The current version is 0.
  int version;

  /// A logically ORed set of [JSClassAttributes] to give to the class.
  JSClassAttributes attributes;

  /// A null-terminated UTF8 string containing the class's name.
  String className;

  /// A JSClass to set as the class's parent class. Pass NULL use the default object class.
  JSClass? parentClass;

  /// A JSStaticValue array containing the class's statically declared value properties. Pass NULL to specify no statically declared value properties. The array must be terminated by a JSStaticValue whose name field is NULL.
  List<JSStaticValue>? staticValues;

  /// A JSStaticFunction array containing the class's statically declared function properties. Pass NULL to specify no statically declared function properties. The array must be terminated by a JSStaticFunction whose name field is NULL.
  List<JSStaticFunction>? staticFunctions;

  /// The callback invoked when an object is first created. Use this callback to initialize the object.
  Pointer<NativeFunction<JSObjectRef.JSObjectInitializeCallback>>? initialize;

  /// The callback invoked when an object is finalized (prepared for garbage collection). Use this callback to release resources allocated for the object, and perform other cleanup.
  Pointer<NativeFunction<JSObjectRef.JSObjectFinalizeCallback>>? finalize;

  /// The callback invoked when determining whether an object has a property. If this field is NULL, getProperty is called instead. The hasProperty callback enables optimization in cases where only a property's existence needs to be known, not its value, and computing its value is expensive.
  Pointer<NativeFunction<JSObjectRef.JSObjectHasPropertyCallback>>? hasProperty;

  /// The callback invoked when getting a property's value.
  Pointer<NativeFunction<JSObjectRef.JSObjectGetPropertyCallback>>? getProperty;

  /// The callback invoked when setting a property's value.
  Pointer<NativeFunction<JSObjectRef.JSObjectSetPropertyCallback>>? setProperty;

  /// The callback invoked when deleting a property.
  Pointer<NativeFunction<JSObjectRef.JSObjectDeletePropertyCallback>>?
      deleteProperty;

  /// The callback invoked when collecting the names of an object's properties.
  Pointer<NativeFunction<JSObjectRef.JSObjectGetPropertyNamesCallback>>?
      getPropertyNames;

  /// The callback invoked when an object is called as a function.
  Pointer<NativeFunction<JSObjectRef.JSObjectCallAsFunctionCallback>>?
      callAsFunction;

  /// The callback invoked when an object is used as the target of an 'instanceof' expression.
  Pointer<NativeFunction<JSObjectRef.JSObjectCallAsConstructorCallback>>?
      callAsConstructor;

  /// The callback invoked when an object is used as a constructor in a 'new' expression.
  Pointer<NativeFunction<JSObjectRef.JSObjectHasInstanceCallback>>? hasInstance;

  /// The callback invoked when converting an object to a particular JavaScript type.
  Pointer<NativeFunction<JSObjectRef.JSObjectConvertToTypeCallback>>?
      convertToType;

  JSClassDefinition({
    this.version = 0,
    this.attributes = JSClassAttributes.kJSClassAttributeNone,
    required this.className,
    this.parentClass,
    this.staticValues,
    this.staticFunctions,
    this.initialize,
    this.finalize,
    this.hasProperty,
    this.getProperty,
    this.setProperty,
    this.deleteProperty,
    this.getPropertyNames,
    this.callAsFunction,
    this.callAsConstructor,
    this.hasInstance,
    this.convertToType,
  });

  Pointer<JSObjectRef.JSClassDefinition> create() {
    Pointer<JSObjectRef.JSStaticValue> staticValues =
        this.staticValues == null || this.staticValues!.isEmpty
            ? nullptr
            : this.staticValues!.createArray();
    Pointer<JSObjectRef.JSStaticFunction> staticFunctions =
        this.staticFunctions == null || this.staticFunctions!.isEmpty
            ? nullptr
            : this.staticFunctions!.createArray();
    return JSObjectRef.JSClassDefinitionPointer.allocate(
      version: version,
      attributes: jSClassAttributesToCEnum(attributes),
      className: className.toNativeUtf8(),
      parentClass: parentClass == null ? nullptr : parentClass!.pointer,
      staticValues: staticValues,
      staticFunctions: staticFunctions,
      initialize: initialize ?? nullptr,
      finalize: finalize ?? nullptr,
      hasProperty: hasProperty ?? nullptr,
      getProperty: getProperty ?? nullptr,
      setProperty: setProperty ?? nullptr,
      deleteProperty: deleteProperty ?? nullptr,
      getPropertyNames: getPropertyNames ?? nullptr,
      callAsFunction: callAsFunction ?? nullptr,
      callAsConstructor: callAsConstructor ?? nullptr,
      hasInstance: hasInstance ?? nullptr,
      convertToType: convertToType ?? nullptr,
    );
  }
}

/// A JavaScript object. A JSObject is a JSValue.
class JSObject {
  /// JavaScript context
  final JSContext context;

  /// C pointer
  final Pointer pointer;

  JSObject(this.context, this.pointer);

  /// Creates a JavaScript object.
  /// The default object class does not allocate storage for private data, so you must provide a non-NULL jsClass to JSObjectMake if you want your object to be able to store private data.
  ///
  /// data is set on the created object before the intialize methods in its class chain are called. This enables the initialize methods to retrieve and manipulate data through JSObjectGetPrivate.
  /// [jsClass] (JSClassRef) The JSClass to assign to the object. Pass NULL to use the default object class.
  /// [data] (void*) A void* to set as the object's private data. Pass NULL to specify no private data.
  JSObject.make(
    this.context,
    JSClass jsClass, {
    Pointer? data,
  }) : this.pointer = JSObjectRef.jSObjectMake(
            context.pointer, jsClass.pointer, data ?? nullptr);

  /// Convenience method for creating a JavaScript function with a given callback as its implementation.
  /// [name] A JSString containing the function's name. This will be used when converting the function to string. Pass NULL to create an anonymous function.
  /// [callAsFunction] The JSObjectCallAsFunctionCallback to invoke when the function is called.
  JSObject.makeFunctionWithCallback(
      this.context,
      String name,
      Pointer<NativeFunction<JSObjectRef.JSObjectCallAsFunctionCallback>>?
          callAsFunction)
      : this.pointer = JSObjectRef.jSObjectMakeFunctionWithCallback(
            context.pointer,
            JSString.fromString(name).pointer,
            callAsFunction ?? nullptr);

  /// Convenience method for creating a JavaScript constructor.
  /// The default object constructor takes no arguments and constructs an object of class jsClass with no private data.
  /// [jsClass] A JSClass that is the class your constructor will assign to the objects its constructs. jsClass will be used to set the constructor's .prototype property, and to evaluate 'instanceof' expressions. Pass NULL to use the default object class.
  /// [callAsConstructor] A JSObjectCallAsConstructorCallback to invoke when your constructor is used in a 'new' expression. Pass NULL to use the default object constructor.
  JSObject.makeConstructor(
      this.context,
      JSClass jsClass,
      Pointer<NativeFunction<JSObjectRef.JSObjectCallAsConstructorCallback>>?
          callAsConstructor)
      : this.pointer = JSObjectRef.jSObjectMakeConstructor(
            context.pointer, jsClass.pointer, callAsConstructor ?? nullptr);

  /// Creates a JavaScript Array object.
  /// The behavior of this function does not exactly match the behavior of the built-in Array constructor. Specifically, if one argument
  /// is supplied, this function returns an array with one element.
  /// [arguments] A JSValue array of data to populate the Array with. Pass NULL if argumentCount is 0.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeArray(
    this.context,
    JSValuePointer arguments, {
    JSValuePointer? exception,
  }) : this.pointer = JSObjectRef.jSObjectMakeArray(
            context.pointer,
            arguments.count,
            arguments.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Date object, as if by invoking the built-in Date constructor.
  /// [arguments] A JSValue array of arguments to pass to the Date Constructor. Pass NULL if argumentCount is 0.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeDate(
    this.context,
    JSValuePointer arguments, {
    JSValuePointer? exception,
  }) : this.pointer = JSObjectRef.jSObjectMakeDate(
            context.pointer,
            arguments.count,
            arguments.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Error object, as if by invoking the built-in Error constructor.
  /// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the Error Constructor. Pass NULL if argumentCount is 0.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeError(
    this.context,
    JSValuePointer arguments, {
    JSValuePointer? exception,
  }) : this.pointer = JSObjectRef.jSObjectMakeError(
            context.pointer,
            arguments.count,
            arguments.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript RegExp object, as if by invoking the built-in RegExp constructor.
  /// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the RegExp Constructor. Pass NULL if argumentCount is 0.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeRegExp(
    this.context,
    JSValuePointer arguments, {
    JSValuePointer? exception,
  }) : this.pointer = JSObjectRef.jSObjectMakeRegExp(
            context.pointer,
            arguments.count,
            arguments.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript promise object by invoking the provided executor.
  /// [resolve] (JSObjectRef*) A pointer to a JSObjectRef in which to store the resolve function for the new promise. Pass NULL if you do not care to store the resolve callback.
  /// [reject] (JSObjectRef*) A pointer to a JSObjectRef in which to store the reject function for the new promise. Pass NULL if you do not care to store the reject callback.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeDeferredPromise(
    this.context,
    JSObjectPointer resolve,
    JSObjectPointer reject, {
    JSValuePointer? exception,
  }) : this.pointer = JSObjectRef.jSObjectMakeDeferredPromise(
            context.pointer,
            resolve.pointer,
            reject.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a function with a given script as its body.
  /// Use this method when you want to execute a script repeatedly, to avoid the cost of re-parsing the script before each execution.
  /// [name] A JSString containing the function's name. This will be used when converting the function to string. Pass NULL to create an anonymous function.
  /// [parameterNames] (JSStringRef[]) A JSString array containing the names of the function's parameters. Pass NULL if parameterCount is 0.
  /// [body] A JSString containing the script to use as the function's body.
  /// [sourceURL] A JSString containing a URL for the script's source file. This is only used when reporting exceptions. Pass NULL if you do not care to include source file information in exceptions.
  /// [startingLineNumber] (int) An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions. The value is one-based, so the first line is line 1 and invalid values are clamped to 1.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store a syntax error exception, if any. Pass NULL if you do not care to store a syntax error exception.
  JSObject.makeFunction(
    this.context,
    String name,
    JSStringPointer parameterNames,
    String body,
    String sourceURL, {
    JSValuePointer? exception,
    int startingLineNumber = 0,
  }) : this.pointer = JSObjectRef.jSObjectMakeFunction(
            context.pointer,
            JSString.fromString(name).pointer,
            parameterNames.count,
            parameterNames.pointer,
            JSString.fromString(body).pointer,
            JSString.fromString(sourceURL).pointer,
            startingLineNumber,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Typed Array object with the given number of elements.
  /// [arrayType] A value [JSTypedArrayType] identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
  /// [length] (size_t) The number of elements to be in the new Typed Array.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeTypedArray(
    this.context,
    JSTypedArrayType arrayType,
    int length, {
    JSValuePointer? exception,
  }) : this.pointer = JSTypedArray.jSObjectMakeTypedArray(
            context.pointer,
            JSValue.jSTypedArrayTypeToCEnum(arrayType),
            length,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Typed Array object from an existing pointer.
  /// If an exception is thrown during this function the bytesDeallocator will always be called.
  /// [arrayType] A value [JSTypedArrayType] identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
  /// [bytes] (void*) A pointer to the byte buffer to be used as the backing store of the Typed Array object.
  /// [byteLength] The number of bytes pointed to by the parameter bytes.
  /// [bytesDeallocator] (JSTypedArrayBytesDeallocator) The allocator to use to deallocate the external buffer when the JSTypedArrayData object is deallocated.
  /// [deallocatorContext] (void*) A pointer to pass back to the deallocator.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeTypedArrayWithBytesNoCopy(
    this.context,
    JSTypedArrayType arrayType,
    Bytes bytes,
    Pointer<NativeFunction<JSBase.JSTypedArrayBytesDeallocator>>?
        bytesDeallocator,
    Pointer deallocatorContext, {
    JSValuePointer? exception,
  }) : this.pointer = JSTypedArray.jSObjectMakeTypedArrayWithBytesNoCopy(
            context.pointer,
            JSValue.jSTypedArrayTypeToCEnum(arrayType),
            bytes.pointer,
            bytes.length,
            bytesDeallocator ?? nullptr,
            deallocatorContext,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Typed Array object from an existing JavaScript Array Buffer object.
  /// [arrayType] A value [JSTypedArrayType] identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
  /// [buffer] An Array Buffer object that should be used as the backing store for the created JavaScript Typed Array object.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeTypedArrayWithArrayBuffer(
    this.context,
    JSTypedArrayType arrayType,
    JSObject buffer, {
    JSValuePointer? exception,
  }) : this.pointer = JSTypedArray.jSObjectMakeTypedArrayWithArrayBuffer(
            context.pointer,
            JSValue.jSTypedArrayTypeToCEnum(arrayType),
            buffer.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Typed Array object from an existing JavaScript Array Buffer object with the given offset and length.
  /// [arrayType] A value [JSTypedArrayType] identifying the type of array to create. If arrayType is kJSTypedArrayTypeNone or kJSTypedArrayTypeArrayBuffer then NULL will be returned.
  /// [buffer] (JSObjectRef) An Array Buffer object that should be used as the backing store for the created JavaScript Typed Array object.
  /// [byteOffset] (size_t) The byte offset for the created Typed Array. byteOffset should aligned with the element size of arrayType.
  /// [length] (size_t) The number of elements to include in the Typed Array.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeTypedArrayWithArrayBufferAndOffset(
    this.context,
    JSTypedArrayType arrayType,
    JSObject buffer,
    int byteOffset,
    int length, {
    JSValuePointer? exception,
  }) : this.pointer =
            JSTypedArray.jSObjectMakeTypedArrayWithArrayBufferAndOffset(
                context.pointer,
                JSValue.jSTypedArrayTypeToCEnum(arrayType),
                buffer.pointer,
                byteOffset,
                length,
                (exception ?? JSValuePointer(nullptr)).pointer);

  /// Creates a JavaScript Array Buffer object from an existing pointer.
  /// If an exception is thrown during this function the bytesDeallocator will always be called.
  /// [bytes] (void*) A pointer to the byte buffer to be used as the backing store of the Typed Array object.
  /// [bytesDeallocator] (JSTypedArrayBytesDeallocator) The allocator to use to deallocate the external buffer when the Typed Array data object is deallocated.
  /// [deallocatorContext] (void*) A pointer to pass back to the deallocator.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject.makeArrayBufferWithBytesNoCopy(
    this.context,
    Bytes bytes,
    Pointer<NativeFunction<JSBase.JSTypedArrayBytesDeallocator>>?
        bytesDeallocator,
    Pointer deallocatorContext, {
    JSValuePointer? exception,
  }) : this.pointer = JSTypedArray.jSObjectMakeArrayBufferWithBytesNoCopy(
            context.pointer,
            bytes.pointer,
            bytes.length,
            bytesDeallocator ?? nullptr,
            deallocatorContext,
            (exception ?? JSValuePointer(nullptr)).pointer);

  /// Gets an object's prototype.
  JSValue get prototype {
    return JSValue(
        context, JSObjectRef.jSObjectGetPrototype(context.pointer, pointer));
  }

  /// Sets an object's prototype.
  /// [value] (JSValueRef) A JSValue to set as the object's prototype.
  set prototype(JSValue value) {
    JSObjectRef.jSObjectSetPrototype(context.pointer, pointer, value.pointer);
  }

  /// Tests whether an object has a given property.
  /// [propertyName] (JSStringRef) A JSString containing the property's name.
  bool hasProperty(String propertyName) {
    return JSObjectRef.jSObjectHasProperty(context.pointer, pointer,
            JSString.fromString(propertyName).pointer) ==
        1;
  }

  /// Tests whether an object has a given property.
  /// [propertyName] (JSStringRef) A JSString containing the property's name.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSValue getProperty(
    String propertyName, {
    JSValuePointer? exception,
  }) {
    return JSValue(
        context,
        JSObjectRef.jSObjectGetProperty(
            context.pointer,
            pointer,
            JSString.fromString(propertyName).pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Sets a property on an object.
  /// [propertyName] A JSString containing the property's name.
  /// [value] A JSValueRef to use as the property's value.
  /// [attributes] (JSPropertyAttributes) A logically ORed set of JSPropertyAttributes to give to the property.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  void setProperty(
    String propertyName,
    JSValue value,
    JSPropertyAttributes attributes, {
    JSValuePointer? exception,
  }) {
    JSObjectRef.jSObjectSetProperty(
        context.pointer,
        pointer,
        JSString.fromString(propertyName).pointer,
        value.pointer,
        jSPropertyAttributesToCEnum(attributes),
        (exception ?? JSValuePointer(nullptr)).pointer);
  }

  /// Deletes a property from an object.
  /// [propertyName] A JSString containing the property's name.
  /// [exception] A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  /// [@result] (bool) true if the delete operation succeeds, otherwise false (for example, if the property has the kJSPropertyAttributeDontDelete attribute set).
  bool deleteProperty(
    String propertyName, {
    JSValuePointer? exception,
  }) {
    return JSObjectRef.jSObjectDeleteProperty(
            context.pointer,
            pointer,
            JSString.fromString(propertyName).pointer,
            (exception ?? JSValuePointer(nullptr)).pointer) ==
        1;
  }

  /// Tests whether an object has a given property using a JSValueRef as the property key.
  /// This function is the same as performing "propertyKey in object" from JavaScript.
  /// [propertyKey] A JSValueRef containing the property key to use when looking up the property.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  bool hasPropertyForKey(
    String propertyKey, {
    JSValuePointer? exception,
  }) {
    return JSObjectRef.jSObjectHasPropertyForKey(
            context.pointer,
            pointer,
            JSString.fromString(propertyKey).pointer,
            (exception ?? JSValuePointer(nullptr)).pointer) ==
        1;
  }

  /// Gets a property from an object using a JSValueRef as the property key.
  /// This function is the same as performing "object[propertyKey]" from JavaScript.
  /// [propertyKey] A JSValueRef containing the property key to use when looking up the property.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSValue getPropertyForKey(
    String propertyKey, {
    JSValuePointer? exception,
  }) {
    return JSValue(
        context,
        JSObjectRef.jSObjectGetPropertyForKey(
            context.pointer,
            pointer,
            JSString.fromString(propertyKey).pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Sets a property on an object using a JSValueRef as the property key.
  /// This function is the same as performing "object[propertyKey] = value" from JavaScript.
  /// [propertyKey] (JSValueRef) A JSValueRef containing the property key to use when looking up the property.
  /// [value] (JSValueRef) A JSValueRef to use as the property's value.
  /// [attributes] (JSPropertyAttributes) A logically ORed set of JSPropertyAttributes to give to the property.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  void setPropertyForKey(
    String propertyKey,
    JSValue value,
    JSPropertyAttributes attributes, {
    JSValuePointer? exception,
  }) {
    JSObjectRef.jSObjectSetPropertyForKey(
        context.pointer,
        pointer,
        JSString.fromString(propertyKey).pointer,
        value.pointer,
        jSPropertyAttributesToCEnum(attributes),
        (exception ?? JSValuePointer(nullptr)).pointer);
  }

  /// Gets a property from an object by numeric index.
  /// Calling JSObjectGetPropertyAtIndex is equivalent to calling JSObjectGetProperty with a string containing propertyIndex, but JSObjectGetPropertyAtIndex provides optimized access to numeric properties.
  /// [propertyIndex] (unsigned) An integer value that is the property's name.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSValue getPropertyAtIndex(
    int propertyIndex, {
    JSValuePointer? exception,
  }) {
    return JSValue(
        context,
        JSObjectRef.jSObjectGetPropertyAtIndex(context.pointer, pointer,
            propertyIndex, (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Sets a property on an object by numeric index.
  /// Calling JSObjectSetPropertyAtIndex is equivalent to calling JSObjectSetProperty with a string containing propertyIndex, but JSObjectSetPropertyAtIndex provides optimized access to numeric properties.
  /// [propertyIndex] (unsigned) The property's name as a number.
  /// [value] (JSValueRef) A JSValue to use as the property's value.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  void setPropertyAtIndex(
    int propertyIndex,
    JSValue value, {
    JSValuePointer? exception,
  }) {
    JSObjectRef.jSObjectSetPropertyAtIndex(
        context.pointer,
        pointer,
        propertyIndex,
        value.pointer,
        (exception ?? JSValuePointer(nullptr)).pointer);
  }

  /// Gets an object's private data.
  Pointer get private {
    return JSObjectRef.jSObjectGetPrivate(pointer);
  }

  /// Sets a pointer to private data on an object.
  /// The default object class does not allocate storage for private data. Only objects created with a non-NULL JSClass can store private data.
  /// [data] (void*) A void* to set as the object's private data.
  bool setPrivate(Pointer data) {
    return JSObjectRef.jSObjectSetPrivate(pointer, data) == 1;
  }

  /// Tests whether an object can be called as a function.
  bool get isFunction {
    return JSObjectRef.jSObjectIsFunction(context.pointer, pointer) == 1;
  }

  /// Calls an object as a function.
  /// [thisObject] (JSObjectRef) The object to use as "this," or NULL to use the global object as "this."
  /// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the function. Pass NULL if argumentCount is 0.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  /// [@result] (JSValue) The JSValue that results from calling object as a function, or NULL if an exception is thrown or object is not a function.
  JSValue callAsFunction(
    JSObject thisObject,
    JSValuePointer arguments, {
    JSValuePointer? exception,
  }) {
    return JSValue(
        context,
        JSObjectRef.jSObjectCallAsFunction(
            context.pointer,
            pointer,
            thisObject.pointer,
            arguments.count,
            arguments.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Tests whether an object can be called as a constructor.
  bool get isConstructor {
    return JSObjectRef.jSObjectIsConstructor(context.pointer, pointer) == 1;
  }

  /// Calls an object as a constructor.
  /// [arguments] (JSValueRef[]) A JSValue array of arguments to pass to the constructor. Pass NULL if argumentCount is 0.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  /// [@result] (JSObjectRef) The JSObject that results from calling object as a constructor, or NULL if an exception is thrown or object is not a constructor.
  JSObject callAsConstructor(
    JSValuePointer arguments, {
    JSValuePointer? exception,
  }) {
    return JSObject(
        context,
        JSObjectRef.jSObjectCallAsConstructor(
            context.pointer,
            pointer,
            arguments.count,
            arguments.pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Gets the names of an object's enumerable properties.
  JSPropertyNameArray copyPropertyNames() {
    return JSPropertyNameArray(
        JSObjectRef.jSObjectCopyPropertyNames(context.pointer, pointer));
  }

  /// Adds a property name to a JavaScript property name accumulator.
  /// [accumulator] (JSPropertyNameAccumulatorRef) The accumulator object to which to add the property name.
  /// [propertyName] (JSStringRef) The property name to add.
  void propertyNameAccumulatorAddName(
      JSPropertyNameAccumulator accumulator, String propertyName) {
    JSObjectRef.jSPropertyNameAccumulatorAddName(
        accumulator.pointer, JSString.fromString(propertyName).pointer);
  }

  /// Returns a temporary pointer to the backing store of a JavaScript Typed Array object.
  /// The pointer returned by this function is temporary and is not guaranteed to remain valid across JavaScriptCore API calls.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  Bytes typedArrayBytes({
    JSValuePointer? exception,
  }) {
    return Bytes(
        JSTypedArray.jSObjectGetTypedArrayBytesPtr(context.pointer, pointer,
            (exception ?? JSValuePointer(nullptr)).pointer),
        JSTypedArray.jSObjectGetTypedArrayLength(context.pointer, pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Returns the byte length of a JavaScript Typed Array object.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  int typedArrayByteLength({
    JSValuePointer? exception,
  }) {
    return JSTypedArray.jSObjectGetTypedArrayByteLength(context.pointer,
        pointer, (exception ?? JSValuePointer(nullptr)).pointer);
  }

  /// Returns the byte offset of a JavaScript Typed Array object.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  int typedArrayByteOffset({
    JSValuePointer? exception,
  }) {
    return JSTypedArray.jSObjectGetTypedArrayByteOffset(context.pointer,
        pointer, (exception ?? JSValuePointer(nullptr)).pointer);
  }

  /// Returns the JavaScript Array Buffer object that is used as the backing of a JavaScript Typed Array object.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  JSObject typedArrayBuffer({
    JSValuePointer? exception,
  }) {
    return JSObject(
        context,
        JSTypedArray.jSObjectGetTypedArrayBuffer(context.pointer, pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// Returns a pointer to the data buffer that serves as the backing store for a JavaScript Typed Array object.
  /// The pointer returned by this function is temporary and is not guaranteed to remain valid across JavaScriptCore API calls.
  /// [exception] (JSValueRef*) A pointer to a JSValueRef in which to store an exception, if any. Pass NULL if you do not care to store an exception.
  Bytes arrayBufferBytes({
    JSValuePointer? exception,
  }) {
    return Bytes(
        JSTypedArray.jSObjectGetArrayBufferBytesPtr(context.pointer, pointer,
            (exception ?? JSValuePointer(nullptr)).pointer),
        JSTypedArray.jSObjectGetArrayBufferByteLength(context.pointer, pointer,
            (exception ?? JSValuePointer(nullptr)).pointer));
  }

  /// JSObject to JSValue
  JSValue toValue() {
    return JSValue(context, pointer);
  }
}

/// JSObjectRef pointer
class JSObjectPointer {
  /// C pointer
  final Pointer<Pointer> pointer;

  /// Pointer array count
  final int count;

  JSObjectPointer([Pointer? value])
      : this.count = 1,
        this.pointer = malloc.call<Pointer>(1) {
    pointer.value = value ?? nullptr;
  }

  /// JSObjectRef array
  JSObjectPointer.array(List<JSObject> array)
      : this.count = array.length,
        this.pointer = malloc.call<Pointer>(array.length) {
    for (int i = 0; i < array.length; i++) {
      this.pointer[i] = array[i].pointer;
    }
  }

  /// Get JSValue
  /// [index] Array index
  JSObject getValue(JSContext context, [int index = 0]) {
    return JSObject(context, pointer[index]);
  }
}

/// A pointer to the byte buffer to be used as the backing store of the Typed Array object.
class Bytes {
  /// C pointer
  final Pointer pointer;

  /// Bytes count
  final int length;

  Bytes(this.pointer, this.length);
}
