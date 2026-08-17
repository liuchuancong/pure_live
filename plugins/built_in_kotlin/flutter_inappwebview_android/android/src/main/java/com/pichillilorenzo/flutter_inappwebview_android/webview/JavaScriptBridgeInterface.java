package com.pichillilorenzo.flutter_inappwebview_android.webview;

import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pichillilorenzo.flutter_inappwebview_android.plugin_scripts_js.JavaScriptBridgeJS;
import com.pichillilorenzo.flutter_inappwebview_android.print_job.PrintJobController;
import com.pichillilorenzo.flutter_inappwebview_android.print_job.PrintJobSettings;
import com.pichillilorenzo.flutter_inappwebview_android.types.JavaScriptHandlerFunctionData;
import com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview.InAppWebView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.regex.Pattern;

public class JavaScriptBridgeInterface {
  private static final String LOG_TAG = "JSBridgeInterface";
  private InAppWebView inAppWebView;
  @NonNull
  private final String expectedBridgeSecret;

  public JavaScriptBridgeInterface(InAppWebView inAppWebView, @NonNull String expectedBridgeSecret) {
    this.inAppWebView = inAppWebView;
    this.expectedBridgeSecret = expectedBridgeSecret;
  }

  @JavascriptInterface
  public void _hideContextMenu() {
    if (inAppWebView == null) {
      return;
    }

    final Handler handler = new Handler(inAppWebView.getWebViewLooper());
    handler.post(new Runnable() {
      @Override
      public void run() {
        if (inAppWebView != null && inAppWebView.floatingContextMenu != null) {
          inAppWebView.hideContextMenu();
        }
      }
    });
  }

  @JavascriptInterface
  public void _callHandler(final String jsonStringifiedData) {
    if (inAppWebView == null) {
      return;
    }

    JSONObject data;
    try {
      data = new JSONObject(jsonStringifiedData);
    } catch (Exception e) {
      e.printStackTrace();
      Log.e(LOG_TAG, "Cannot convert jsonStringifiedData parameter of _callHandler method to a valid JSONObject");
      return;
    }

    if (!data.has("handlerName") || data.isNull("handlerName")) {
      Log.d(LOG_TAG, "handlerName is null or undefined");
      return;
    }

    final String handlerName = data.optString("handlerName");
    final String bridgeSecret = data.optString("_bridgeSecret");
    final Integer _callHandlerID = data.optInt("_callHandlerID");
    final String origin = data.optString("origin");
    final String requestUrl = data.optString("requestUrl");
    final Boolean isMainFrame = data.optBoolean("isMainFrame");
    final String args = data.optString("args");

    if (!expectedBridgeSecret.equals(bridgeSecret)) {
      Log.e(LOG_TAG, "Bridge access attempt with wrong secret token, possibly from malicious code from origin: " + origin);
      return;
    }

    boolean isOriginAllowed = false;
    if (inAppWebView.customSettings.javaScriptHandlersOriginAllowList != null) {
      for (Pattern allowedOrigin : inAppWebView.customSettings.javaScriptHandlersOriginAllowList) {
        if (allowedOrigin.matcher(origin).matches()) {
          isOriginAllowed = true;
          break;
        }
      }
    } else {
      // origin is by default allowed if the allow list is null
      isOriginAllowed = true;
    }
    if (!isOriginAllowed) {
      Log.e(LOG_TAG, "Bridge access attempt from an origin not allowed: " + origin);
      return;
    }

    if (inAppWebView.customSettings.javaScriptHandlersForMainFrameOnly && !isMainFrame) {
      Log.e(LOG_TAG, "Bridge access attempt from a sub-frame origin: " + origin);
      return;
    }

    // java.lang.RuntimeException: Methods marked with @UiThread must be executed on the main thread.
    // https://github.com/pichillilorenzo/flutter_inappwebview/issues/98
    final Handler handler = new Handler(inAppWebView.getWebViewLooper());
    handler.post(new Runnable() {
      @Override
      public void run() {
        if (inAppWebView == null) {
          // The webview has already been disposed, ignore.
          return;
        }

        boolean isInternalHandler = true;
        switch (handlerName) {
          case "onPrintRequest":
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
              PrintJobSettings settings = new PrintJobSettings();
              settings.handledByClient = true;
              final String printJobId = inAppWebView.printCurrentPage(settings);
              if (inAppWebView != null && inAppWebView.channelDelegate != null) {
                inAppWebView.channelDelegate.onPrintRequest(inAppWebView.getUrl(), printJobId, new WebViewChannelDelegate.PrintRequestCallback() {
                  @Override
                  public boolean nonNullSuccess(@NonNull Boolean handledByClient) {
                    return !handledByClient;
                  }

                  @Override
                  public void defaultBehaviour(@Nullable Boolean handledByClient) {
                    if (inAppWebView != null && inAppWebView.plugin != null && inAppWebView.plugin.printJobManager != null) {
                      PrintJobController printJobController = inAppWebView.plugin.printJobManager.jobs.get(printJobId);
                      if (printJobController != null) {
                        printJobController.disposeNoCancel();
                      }
                    }
                  }

                  @Override
                  public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                    Log.e(LOG_TAG, errorCode + ", " + ((errorMessage != null) ? errorMessage : ""));
                    defaultBehaviour(null);
                  }
                });
              }
            }
            break;
          case "callAsyncJavaScript":
            try {
              JSONArray arguments = new JSONArray(args);
              JSONObject jsonObject = arguments.getJSONObject(0);
              String resultUuid = jsonObject.getString("resultUuid");
              ValueCallback<String> callAsyncJavaScriptCallback = inAppWebView.callAsyncJavaScriptCallbacks.get(resultUuid);
              if (callAsyncJavaScriptCallback != null) {
                callAsyncJavaScriptCallback.onReceiveValue(jsonObject.toString());
                inAppWebView.callAsyncJavaScriptCallbacks.remove(resultUuid);
              }
            } catch (JSONException e) {
              Log.e(LOG_TAG, "", e);
            }
            break;
          case "evaluateJavaScriptWithContentWorld":
            try {
              JSONArray arguments = new JSONArray(args);
              JSONObject jsonObject = arguments.getJSONObject(0);
              String resultUuid = jsonObject.getString("resultUuid");
              ValueCallback<String> evaluateJavaScriptCallback = inAppWebView.evaluateJavaScriptContentWorldCallbacks.get(resultUuid);
              if (evaluateJavaScriptCallback != null) {
                evaluateJavaScriptCallback.onReceiveValue(jsonObject.has("value") ? jsonObject.get("value").toString() : "null");
                inAppWebView.evaluateJavaScriptContentWorldCallbacks.remove(resultUuid);
              }
            } catch (JSONException e) {
              Log.e(LOG_TAG, "", e);
            }
            break;
          default:
            isInternalHandler = false;
            break;
        }

        if (isInternalHandler) {
          if (inAppWebView != null) {
            String sourceCode = "if (window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "] != null) { " +
                    "window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "].resolve(); " +
                    "delete window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "]; " +
                    "}";
            inAppWebView.evaluateJavascript(sourceCode, (ValueCallback<String>) null);
          }
          return;
        }


        if (inAppWebView.channelDelegate != null) {
          JavaScriptHandlerFunctionData data = new JavaScriptHandlerFunctionData(origin, requestUrl, isMainFrame, args);
          // invoke flutter javascript handler and send back flutter data as a JSON Object to javascript
          inAppWebView.channelDelegate.onCallJsHandler(handlerName, data, new WebViewChannelDelegate.CallJsHandlerCallback() {
            @Override
            public void defaultBehaviour(@Nullable Object json) {
              if (inAppWebView == null) {
                // The webview has already been disposed, ignore.
                return;
              }
              String sourceCode = "if (window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "] != null) { " +
                      "window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "].resolve(" + json + "); " +
                      "delete window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "]; " +
                      "}";
              inAppWebView.evaluateJavascript(sourceCode, (ValueCallback<String>) null);
            }

            @Override
            public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
              String message = errorCode + ((errorMessage != null) ? ", " + errorMessage : "");
              Log.e(LOG_TAG, message);

              if (inAppWebView == null) {
                // The webview has already been disposed, ignore.
                return;
              }

              String sourceCode = "if (window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "] != null) { " +
                      "window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "].reject(new Error(" + JSONObject.quote(message) + ")); " +
                      "delete window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + "[" + _callHandlerID + "]; " +
                      "}";
              inAppWebView.evaluateJavascript(sourceCode, (ValueCallback<String>) null);
            }
          });
        }
      }
    });
  }

  public void dispose() {
    inAppWebView = null;
  }
}
