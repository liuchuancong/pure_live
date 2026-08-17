package com.pichillilorenzo.flutter_inappwebview_android.types;

import android.annotation.TargetApi;
import android.os.Build;
import android.webkit.WebChromeClient;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public class ShowFileChooserRequest {
  private int mode;
  @NonNull
  private List<String> acceptTypes;
  private boolean isCaptureEnabled;
  @Nullable
  private String title;
  @Nullable
  private String filenameHint;

  public ShowFileChooserRequest(int mode, @NonNull List<String> acceptTypes, boolean isCaptureEnabled, @Nullable String title, @Nullable String filenameHint) {
    this.mode = mode;
    this.acceptTypes = acceptTypes;
    this.isCaptureEnabled = isCaptureEnabled;
    this.title = title;
    this.filenameHint = filenameHint;
  }

  @TargetApi(Build.VERSION_CODES.LOLLIPOP)
  public static ShowFileChooserRequest fromFileChooserParams(WebChromeClient.FileChooserParams fileChooserParams) {
    int mode = fileChooserParams.getMode();
    List<String> acceptTypes = Arrays.asList(fileChooserParams.getAcceptTypes());
    boolean isCaptureEnabled = fileChooserParams.isCaptureEnabled();
    String title = fileChooserParams.getTitle() != null ? fileChooserParams.getTitle().toString() : null;
    String filenameHint = fileChooserParams.getFilenameHint();
    return new ShowFileChooserRequest(mode, acceptTypes, isCaptureEnabled, title, filenameHint);
  }

  @Nullable
  public static ShowFileChooserRequest fromMap(@Nullable Map<String, Object> map) {
    if (map == null) {
      return null;
    }
    int mode = (int) map.get("mode");
    List<String> acceptTypes = (List<String>) map.get("acceptTypes");
    boolean isCaptureEnabled = (boolean) map.get("isCaptureEnabled");
    String title = (String) map.get("title");
    String filenameHint = (String) map.get("filenameHint");
    return new ShowFileChooserRequest(mode, acceptTypes, isCaptureEnabled, title, filenameHint);
  }

  public Map<String, Object> toMap() {
    Map<String, Object> showFileChooserRequestMap = new HashMap<>();
    showFileChooserRequestMap.put("mode", mode);
    showFileChooserRequestMap.put("acceptTypes", acceptTypes);
    showFileChooserRequestMap.put("isCaptureEnabled", isCaptureEnabled);
    showFileChooserRequestMap.put("title", title);
    showFileChooserRequestMap.put("filenameHint", filenameHint);
    return showFileChooserRequestMap;
  }


  public int getMode() {
    return mode;
  }

  public void setMode(int mode) {
    this.mode = mode;
  }

  public @NonNull List<String> getAcceptTypes() {
    return acceptTypes;
  }

  public void setAcceptTypes(@NonNull List<String> acceptTypes) {
    this.acceptTypes = acceptTypes;
  }

  public boolean isCaptureEnabled() {
    return isCaptureEnabled;
  }

  public void setCaptureEnabled(boolean captureEnabled) {
    isCaptureEnabled = captureEnabled;
  }

  @Nullable
  public String getTitle() {
    return title;
  }

  public void setTitle(@Nullable String title) {
    this.title = title;
  }

  @Nullable
  public String getFilenameHint() {
    return filenameHint;
  }

  public void setFilenameHint(@Nullable String filenameHint) {
    this.filenameHint = filenameHint;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;

    ShowFileChooserRequest that = (ShowFileChooserRequest) o;
    return mode == that.mode && isCaptureEnabled == that.isCaptureEnabled && acceptTypes.equals(that.acceptTypes) && Objects.equals(title, that.title) && Objects.equals(filenameHint, that.filenameHint);
  }

  @Override
  public int hashCode() {
    int result = mode;
    result = 31 * result + acceptTypes.hashCode();
    result = 31 * result + Boolean.hashCode(isCaptureEnabled);
    result = 31 * result + Objects.hashCode(title);
    result = 31 * result + Objects.hashCode(filenameHint);
    return result;
  }

  @NonNull
  @Override
  public String toString() {
    return "ShowFileChooserRequest{" +
            "mode=" + mode +
            ", acceptTypes=" + acceptTypes +
            ", isCaptureEnabled=" + isCaptureEnabled +
            ", title='" + title + '\'' +
            ", filenameHint='" + filenameHint + '\'' +
            '}';
  }
}
