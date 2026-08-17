package com.pichillilorenzo.flutter_inappwebview_android.types;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;
import java.util.Map;
import java.util.Objects;

public class ShowFileChooserResponse {
  private boolean handledByClient;
  @Nullable
  private List<String> filePaths;

  public ShowFileChooserResponse(boolean handledByClient, @Nullable List<String> filePaths) {
    this.handledByClient = handledByClient;
    this.filePaths = filePaths;
  }

  @Nullable
  public static ShowFileChooserResponse fromMap(@Nullable Map<String, Object> map) {
    if (map == null) {
      return null;
    }
    boolean handledByClient = (boolean) map.get("handledByClient");
    List<String> filePaths = (List<String>) map.get("filePaths");
    return new ShowFileChooserResponse(handledByClient, filePaths);
  }

  public boolean isHandledByClient() {
    return handledByClient;
  }

  public void setHandledByClient(boolean handledByClient) {
    this.handledByClient = handledByClient;
  }

  @Nullable
  public List<String> getFilePaths() {
    return filePaths;
  }

  public void setFilePaths(@Nullable List<String> filePaths) {
    this.filePaths = filePaths;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;

    ShowFileChooserResponse that = (ShowFileChooserResponse) o;
    return handledByClient == that.handledByClient && Objects.equals(filePaths, that.filePaths);
  }

  @Override
  public int hashCode() {
    int result = Boolean.hashCode(handledByClient);
    result = 31 * result + Objects.hashCode(filePaths);
    return result;
  }

  @NonNull
  @Override
  public String toString() {
    return "ShowFileChooserResponse{" +
            "handledByClient=" + handledByClient +
            ", filePaths=" + filePaths +
            '}';
  }
}
