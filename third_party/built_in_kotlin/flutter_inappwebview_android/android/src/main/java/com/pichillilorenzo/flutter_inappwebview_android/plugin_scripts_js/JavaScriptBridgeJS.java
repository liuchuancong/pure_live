package com.pichillilorenzo.flutter_inappwebview_android.plugin_scripts_js;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pichillilorenzo.flutter_inappwebview_android.Util;
import com.pichillilorenzo.flutter_inappwebview_android.types.PluginScript;
import com.pichillilorenzo.flutter_inappwebview_android.types.UserScriptInjectionTime;

import java.util.Set;

public class JavaScriptBridgeJS {
  @NonNull
  private static String _JAVASCRIPT_BRIDGE_NAME = "flutter_inappwebview";

  public static void set_JAVASCRIPT_BRIDGE_NAME(@NonNull String bridgeName) {
    _JAVASCRIPT_BRIDGE_NAME = bridgeName;
  }

  @NonNull
  public static String get_JAVASCRIPT_BRIDGE_NAME() {
    return _JAVASCRIPT_BRIDGE_NAME;
  }

  public static final String JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT_GROUP_NAME = "IN_APP_WEBVIEW_JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT";

  private static final String VAR_JAVASCRIPT_BRIDGE_BRIDGE_SECRET = "$IN_APP_WEBVIEW_JAVASCRIPT_BRIDGE_BRIDGE_SECRET";

  public static PluginScript JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT(@NonNull String expectedBridgeSecret,
                                                                @Nullable Set<String> allowedOriginRules,
                                                                boolean forMainFrameOnly) {
    String source = Util.replaceAll(JavaScriptBridgeJS.JAVASCRIPT_BRIDGE_JS_SOURCE(), VAR_JAVASCRIPT_BRIDGE_BRIDGE_SECRET, expectedBridgeSecret);
    return new PluginScript(
            JavaScriptBridgeJS.JAVASCRIPT_BRIDGE_JS_PLUGIN_SCRIPT_GROUP_NAME,
            source,
            UserScriptInjectionTime.AT_DOCUMENT_START,
            null,
            true,
            allowedOriginRules,
            forMainFrameOnly
    );
  }

  public static String JAVASCRIPT_UTIL_VAR_NAME() {
    return "window." + get_JAVASCRIPT_BRIDGE_NAME() + "._Util";
  }

  public static String WEB_MESSAGE_CHANNELS_VARIABLE_NAME() {
    return "window." + get_JAVASCRIPT_BRIDGE_NAME() + "._webMessageChannels";
  }

  public static String UTIL_JS_SOURCE() {
    return JAVASCRIPT_UTIL_VAR_NAME() + " = {" +
            "    support: {" +
            "        searchParams: 'URLSearchParams' in window," +
            "        iterable: 'Symbol' in window && 'iterator' in Symbol," +
            "        blob:" +
            "            'FileReader' in window &&" +
            "            'Blob' in window &&" +
            "            (function() {" +
            "              try {" +
            "                new Blob();" +
            "                return true;" +
            "              } catch (e) {" +
            "                return false;" +
            "              }" +
            "            })()," +
            "        formData: 'FormData' in window," +
            "        arrayBuffer: 'ArrayBuffer' in window" +
            "    }," +
            "    isDataView: function(obj) {" +
            "        return obj && DataView.prototype.isPrototypeOf(obj);" +
            "    }," +
            "    fileReaderReady: function(reader) {" +
            "          return new Promise(function(resolve, reject) {" +
            "                reader.onload = function() {" +
            "                    resolve(reader.result);" +
            "                };" +
            "                reader.onerror = function() {" +
            "                    reject(reader.error);" +
            "                };" +
            "          });" +
            "    }," +
            "    readBlobAsArrayBuffer: function(blob) {" +
            "        var reader = new FileReader();" +
            "        var promise = " + JAVASCRIPT_UTIL_VAR_NAME() + ".fileReaderReady(reader);" +
            "        reader.readAsArrayBuffer(blob);" +
            "        return promise;" +
            "    }," +
            "    convertBodyToArrayBuffer: function(body) {" +
            "        var viewClasses = [" +
            "            '[object Int8Array]'," +
            "            '[object Uint8Array]'," +
            "            '[object Uint8ClampedArray]'," +
            "            '[object Int16Array]'," +
            "            '[object Uint16Array]'," +
            "            '[object Int32Array]'," +
            "            '[object Uint32Array]'," +
            "            '[object Float32Array]'," +
            "            '[object Float64Array]'" +
            "        ];" +
            "        var isArrayBufferView = null;" +
            "        if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.arrayBuffer) {" +
            "            isArrayBufferView =" +
            "                ArrayBuffer.isView ||" +
            "                function(obj) {" +
            "                    return obj && viewClasses.indexOf(Object.prototype.toString.call(obj)) > -1;" +
            "                };" +
            "        }" +
            "        var bodyUsed = false;" +
            "        this._bodyInit = body;" +
            "        if (!body) {" +
            "            this._bodyText = '';" +
            "        } else if (typeof body === 'string') {" +
            "            this._bodyText = body;" +
            "        } else if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.blob && Blob.prototype.isPrototypeOf(body)) {" +
            "            this._bodyBlob = body;" +
            "        } else if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.formData && FormData.prototype.isPrototypeOf(body)) {" +
            "            this._bodyFormData = body;" +
            "        } else if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.searchParams && URLSearchParams.prototype.isPrototypeOf(body)) {" +
            "            this._bodyText = body.toString();" +
            "        } else if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.arrayBuffer && " + JAVASCRIPT_UTIL_VAR_NAME() + ".support.blob && " + JAVASCRIPT_UTIL_VAR_NAME() + ".isDataView(body)) {" +
            "            this._bodyArrayBuffer = bufferClone(body.buffer);" +
            "            this._bodyInit = new Blob([this._bodyArrayBuffer]);" +
            "        } else if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.arrayBuffer && (ArrayBuffer.prototype.isPrototypeOf(body) || isArrayBufferView(body))) {" +
            "            this._bodyArrayBuffer = bufferClone(body);" +
            "        } else {" +
            "            this._bodyText = body = Object.prototype.toString.call(body);" +
            "        }" +
            "        this.blob = function () {" +
            "            if (bodyUsed) {" +
            "                return Promise.reject(new TypeError('Already read'));" +
            "            }" +
            "            bodyUsed = true;" +
            "            if (this._bodyBlob) {" +
            "                return Promise.resolve(this._bodyBlob);" +
            "            } else if (this._bodyArrayBuffer) {" +
            "                return Promise.resolve(new Blob([this._bodyArrayBuffer]));" +
            "            } else if (this._bodyFormData) {" +
            "                throw new Error('could not read FormData body as blob');" +
            "            } else {" +
            "                return Promise.resolve(new Blob([this._bodyText]));" +
            "            }" +
            "        };" +
            "        if (this._bodyArrayBuffer) {" +
            "            if (bodyUsed) {" +
            "                return Promise.reject(new TypeError('Already read'));" +
            "            }" +
            "            bodyUsed = true;" +
            "            if (ArrayBuffer.isView(this._bodyArrayBuffer)) {" +
            "                return Promise.resolve(" +
            "                  this._bodyArrayBuffer.buffer.slice(" +
            "                    this._bodyArrayBuffer.byteOffset," +
            "                    this._bodyArrayBuffer.byteOffset + this._bodyArrayBuffer.byteLength" +
            "                  )" +
            "                );" +
            "            } else {" +
            "                return Promise.resolve(this._bodyArrayBuffer);" +
            "            }" +
            "        }" +
            "        return this.blob().then(" + JAVASCRIPT_UTIL_VAR_NAME() + ".readBlobAsArrayBuffer);" +
            "    }," +
            "    isString: function(variable) {" +
            "        return typeof variable === 'string' || variable instanceof String;" +
            "    }," +
            "    convertBodyRequest: function(body) {" +
            "        if (body == null) {" +
            "            return new Promise(function(resolve, reject) { resolve(null); });" +
            "        }" +
            "        if (" + JAVASCRIPT_UTIL_VAR_NAME() + ".isString(body) || (" + JAVASCRIPT_UTIL_VAR_NAME() + ".support.searchParams && body instanceof URLSearchParams)) {" +
            "            return new Promise(function(resolve, reject) { resolve(body.toString()); });" +
            "        }" +
            "        if (window.Response != null) {" +
            "            return new Response(body).arrayBuffer().then(function(arrayBuffer) {" +
            "                return Array.from(new Uint8Array(arrayBuffer));" +
            "            });" +
            "        }" +
            "        return " + JAVASCRIPT_UTIL_VAR_NAME() + ".convertBodyToArrayBuffer(body).then(function(arrayBuffer) {" +
            "            return Array.from(new Uint8Array(arrayBuffer));" +
            "        });" +
            "    }," +
            "    arrayBufferToString: function(arrayBuffer) {" +
            "        var uint8Array = new Uint8Array(arrayBuffer);" +
            "        return uint8Array.reduce(function(acc, i) { return acc += String.fromCharCode.apply(null, [i]); }, '');" +
            "    }," +
            "    isBodyFormData: function(bodyString) {" +
            "        return bodyString.indexOf('------WebKitFormBoundary') >= 0;" +
            "    }," +
            "    getFormDataContentType: function(bodyString) {" +
            "        var boundary = bodyString.substr(2, 40);" +
            "        return 'multipart/form-data; boundary=' + boundary;" +
            "    }," +
            "    convertHeadersToJson: function(headers) {" +
            "        var headersObj = {};" +
            "        for (var header of headers.keys()) {" +
            "          var value = headers.get(header);" +
            "          headersObj[header] = value;" +
            "        }" +
            "        return headersObj;" +
            "    }," +
            "    convertJsonToHeaders: function(headersJson) {" +
            "        return new Headers(headersJson);" +
            "    }," +
            "    convertCredentialsToJson: function(credentials) {" +
            "        var credentialsObj = {};" +
            "        if (window.FederatedCredential != null && credentials instanceof FederatedCredential) {" +
            "          credentialsObj.type = credentials.type;" +
            "          credentialsObj.id = credentials.id;" +
            "          credentialsObj.name = credentials.name;" +
            "          credentialsObj.protocol = credentials.protocol;" +
            "          credentialsObj.provider = credentials.provider;" +
            "          credentialsObj.iconURL = credentials.iconURL;" +
            "        } else if (window.PasswordCredential != null && credentials instanceof PasswordCredential) {" +
            "          credentialsObj.type = credentials.type;" +
            "          credentialsObj.id = credentials.id;" +
            "          credentialsObj.name = credentials.name;" +
            "          credentialsObj.password = credentials.password;" +
            "          credentialsObj.iconURL = credentials.iconURL;" +
            "        } else {" +
            "          credentialsObj.type = 'default';" +
            "          credentialsObj.value = credentials;" +
            "        }" +
            "        return credentialsObj;" +
            "    }," +
            "    convertJsonToCredential: function(credentialsJson) {" +
            "        var credentials;" +
            "        if (window.FederatedCredential != null && credentialsJson.type === 'federated') {" +
            "          credentials = new FederatedCredential({" +
            "            id: credentialsJson.id," +
            "            name: credentialsJson.name," +
            "            protocol: credentialsJson.protocol," +
            "            provider: credentialsJson.provider," +
            "            iconURL: credentialsJson.iconURL" +
            "          });" +
            "        } else if (window.PasswordCredential != null && credentialsJson.type === 'password') {" +
            "          credentials = new PasswordCredential({" +
            "            id: credentialsJson.id," +
            "            name: credentialsJson.name," +
            "            password: credentialsJson.password," +
            "            iconURL: credentialsJson.iconURL" +
            "          });" +
            "        } else {" +
            "          credentials = credentialsJson.value == null ? undefined : credentialsJson.value;" +
            "        }" +
            "        return credentials;" +
            "    }" +
            "};";
  }

  public static String JAVASCRIPT_BRIDGE_JS_SOURCE() {
    return "if (window." + get_JAVASCRIPT_BRIDGE_NAME() + " != null) {" +
            "  (function(window) {" +
            "    var bridgeSecret = '" + VAR_JAVASCRIPT_BRIDGE_BRIDGE_SECRET + "';" +
            "    var origin = '';" +
            "    var requestUrl = '';" +
            "    var isMainFrame = false;" +
            "    var _JSON_stringify;" +
            "    var _Array_slice;" +
            "    var _setTimeout;" +
            "    var _Promise;" +
            "    var _javaInjectedObject;" +
            "    try {" +
            "      origin = window.location.origin;" +
            "    } catch (_) {}" +
            "    try {" +
            "      requestUrl = window.location.href;" +
            "    } catch (_) {}" +
            "    try {" +
            "      isMainFrame = window === window.top;" +
            "    } catch (_) {}" +
            "    try {" +
            "      _JSON_stringify = window.JSON.stringify;" +
            "      _Array_slice = window.Array.prototype.slice;" +
            "      _Array_slice.call = window.Function.prototype.call;" +
            "      _setTimeout = window.setTimeout;" +
            "      _Promise = window.Promise;" +
            "      _javaInjectedObject = window." + get_JAVASCRIPT_BRIDGE_NAME() + ";" +
            "    } catch (_) { return; }" +
            "    window." + get_JAVASCRIPT_BRIDGE_NAME() + ".callHandler = function() {" +
            "      var _callHandlerID = _setTimeout(function(){});" +
            "      _javaInjectedObject._callHandler(_JSON_stringify({" +
            "        'handlerName': arguments[0]," +
            "        '_callHandlerID': _callHandlerID," +
            "        '_bridgeSecret': bridgeSecret," +
            "        'origin': origin," +
            "        'requestUrl': requestUrl," +
            "        'isMainFrame': isMainFrame," +
            "        'args': _JSON_stringify(_Array_slice.call(arguments, 1))" +
            "      }));" +
            "      return new _Promise(function(resolve, reject) {" +
            "        try {" +
            "          (isMainFrame ? window : window.top)." + get_JAVASCRIPT_BRIDGE_NAME() + "[_callHandlerID] = {resolve: resolve, reject: reject};" +
            "        } catch(e) { resolve(); }" +
            "      });" +
            "    };" +
            "  })(window);" +
            "}" +
            "if (window.top != null && window.top !== window && window." + get_JAVASCRIPT_BRIDGE_NAME() + " == null) {" +
            "  window." + get_JAVASCRIPT_BRIDGE_NAME() + " = {};" +
            "  (function(window) {" +
            "    var bridgeSecret = '" + VAR_JAVASCRIPT_BRIDGE_BRIDGE_SECRET + "';" +
            "    var origin = '';" +
            "    var requestUrl = '';" +
            "    var isMainFrame = false;" +
            "    var _JSON_stringify;" +
            "    var _Array_slice;" +
            "    var _setTimeout;" +
            "    var _Promise;" +
            "    var _javaInjectedObject;" +
            "    try {" +
            "      origin = window.location.origin;" +
            "    } catch (_) {}" +
            "    try {" +
            "      requestUrl = window.location.href;" +
            "    } catch (_) {}" +
            "    try {" +
            "      isMainFrame = window === window.top;" +
            "    } catch (_) {}" +
            "    try {" +
            "      _JSON_stringify = window.JSON.stringify;" +
            "      _Array_slice = window.Array.prototype.slice;" +
            "      _Array_slice.call = window.Function.prototype.call;" +
            "      _setTimeout = window.setTimeout;" +
            "      _Promise = window.Promise;" +
            "      _javaInjectedObject = window.top." + get_JAVASCRIPT_BRIDGE_NAME() + ";" +
            "    } catch (_) { return; }" +
            "    window." + get_JAVASCRIPT_BRIDGE_NAME() + ".callHandler = function() {" +
            "      var _callHandlerID = _setTimeout(function(){});" +
            "      try {" +
            "        _javaInjectedObject._callHandler(_JSON_stringify({" +
            "          'handlerName': arguments[0]," +
            "          '_callHandlerID': _callHandlerID," +
            "          '_bridgeSecret': bridgeSecret," +
            "          'origin': origin," +
            "          'requestUrl': requestUrl," +
            "          'isMainFrame': isMainFrame," +
            "          'args': _JSON_stringify(_Array_slice.call(arguments, 1))" +
            "        }));" +
            "        return new _Promise(function(resolve, reject) {" +
            "          _javaInjectedObject[_callHandlerID] = {resolve: resolve, reject: reject};" +
            "        });" +
            "      } catch (error) {" +
            "        return new _Promise(function(resolve, reject) { resolve(); });" +
            "      }" +
            "    };" +
            "  })(window);" +
            "}" +
            "if (window." + get_JAVASCRIPT_BRIDGE_NAME() + " != null) {" +
            "  " + UTIL_JS_SOURCE() +
            "}";
  }

  public static String PLATFORM_READY_JS_SOURCE() {
    return "(function() {" +
            "  if ((window.top == null || window.top === window) && window." + get_JAVASCRIPT_BRIDGE_NAME() + " != null && window." + get_JAVASCRIPT_BRIDGE_NAME() + "._platformReady == null) {" +
            "    window.dispatchEvent(new Event('flutterInAppWebViewPlatformReady'));" +
            "    window." + get_JAVASCRIPT_BRIDGE_NAME() + "._platformReady = true;" +
            "  }" +
            "})();";
  }
}
