package com.pichillilorenzo.flutter_inappwebview_android.plugin_scripts_js;

import androidx.annotation.Nullable;

import com.pichillilorenzo.flutter_inappwebview_android.types.PluginScript;
import com.pichillilorenzo.flutter_inappwebview_android.types.UserScriptInjectionTime;

import java.util.Set;

public class OnWindowFocusEventJS {
  public static final String ON_WINDOW_FOCUS_EVENT_JS_PLUGIN_SCRIPT_GROUP_NAME = "IN_APP_WEBVIEW_ON_WINDOW_FOCUS_EVENT_JS_PLUGIN_SCRIPT";

  // This plugin is only for main frame
  public static PluginScript ON_WINDOW_FOCUS_EVENT_JS_PLUGIN_SCRIPT(@Nullable Set<String> allowedOriginRules) {
    return
            new PluginScript(
                    OnWindowFocusEventJS.ON_WINDOW_FOCUS_EVENT_JS_PLUGIN_SCRIPT_GROUP_NAME,
                    OnWindowFocusEventJS.ON_WINDOW_FOCUS_EVENT_JS_SOURCE(),
                    UserScriptInjectionTime.AT_DOCUMENT_START,
                    null,
                    false,
                    allowedOriginRules,
                    true
            );
  }

  public static String ON_WINDOW_FOCUS_EVENT_JS_SOURCE() {
    return
            "(function(){" +
                    "  window.addEventListener('focus', function(e) {" +
                    "    window." + JavaScriptBridgeJS.get_JAVASCRIPT_BRIDGE_NAME() + ".callHandler('onWindowFocus');" +
                    "  });" +
                    "})();";
  }
}
