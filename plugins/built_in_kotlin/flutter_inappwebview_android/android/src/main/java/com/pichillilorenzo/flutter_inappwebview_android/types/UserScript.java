package com.pichillilorenzo.flutter_inappwebview_android.types;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.webkit.WebViewFeature;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public class UserScript {
  @Nullable
  private String groupName;
  @NonNull
  private String source;
  @NonNull
  private UserScriptInjectionTime injectionTime;
  @NonNull
  private ContentWorld contentWorld;
  @NonNull
  private Set<String> allowedOriginRules = new HashSet<>();
  private boolean forMainFrameOnly = true;

  public UserScript(@Nullable String groupName, @NonNull String source,
                    @NonNull UserScriptInjectionTime injectionTime, @Nullable ContentWorld contentWorld,
                    @Nullable Set<String> allowedOriginRules, boolean forMainFrameOnly) {
    this.groupName = groupName;
    this.source = source;
    this.injectionTime = injectionTime;
    this.contentWorld = contentWorld == null ? ContentWorld.PAGE : contentWorld;
    this.allowedOriginRules = allowedOriginRules == null ? new HashSet<String>() {{
      add("*");
    }} : allowedOriginRules;
    this.forMainFrameOnly = forMainFrameOnly;
  }

  @Nullable
  public static UserScript fromMap(@Nullable Map<String, Object> map) {
    if (map == null) {
      return null;
    }
    String groupName = (String) map.get("groupName");
    String source = (String) map.get("source");
    UserScriptInjectionTime injectionTime = UserScriptInjectionTime.fromValue((int) map.get("injectionTime"));
    ContentWorld contentWorld = ContentWorld.fromMap((Map<String, Object>) map.get("contentWorld"));
    Set<String> allowedOriginRules = new HashSet<>((List<String>) map.get("allowedOriginRules"));
    boolean forMainFrameOnly = (boolean) map.get("forMainFrameOnly");
    assert source != null;
    return new UserScript(groupName, source, injectionTime, contentWorld, allowedOriginRules, forMainFrameOnly);
  }

  @Nullable
  public String getGroupName() {
    return groupName;
  }

  public void setGroupName(@Nullable String groupName) {
    this.groupName = groupName;
  }

  @NonNull
  public String getSource() {
    return source;
  }

  public void setSource(@NonNull String source) {
    this.source = source;
  }

  @NonNull
  public UserScriptInjectionTime getInjectionTime() {
    return injectionTime;
  }

  public void setInjectionTime(@NonNull UserScriptInjectionTime injectionTime) {
    this.injectionTime = injectionTime;
  }

  @NonNull
  public ContentWorld getContentWorld() {
    return contentWorld;
  }

  public void setContentWorld(@Nullable ContentWorld contentWorld) {
    this.contentWorld = contentWorld == null ? ContentWorld.PAGE : contentWorld;
  }

  @NonNull
  public Set<String> getAllowedOriginRules() {
    return allowedOriginRules;
  }

  public void setAllowedOriginRules(@NonNull Set<String> allowedOriginRules) {
    this.allowedOriginRules = allowedOriginRules;
  }

  public boolean isForMainFrameOnly() {
    return forMainFrameOnly;
  }

  public void setForMainFrameOnly(boolean forMainFrameOnly) {
    this.forMainFrameOnly = forMainFrameOnly;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;

    UserScript that = (UserScript) o;
    return forMainFrameOnly == that.forMainFrameOnly && Objects.equals(groupName, that.groupName) && source.equals(that.source) && injectionTime == that.injectionTime && contentWorld.equals(that.contentWorld) && allowedOriginRules.equals(that.allowedOriginRules);
  }

  @Override
  public int hashCode() {
    int result = Objects.hashCode(groupName);
    result = 31 * result + source.hashCode();
    result = 31 * result + injectionTime.hashCode();
    result = 31 * result + contentWorld.hashCode();
    result = 31 * result + allowedOriginRules.hashCode();
    result = 31 * result + Boolean.hashCode(forMainFrameOnly);
    return result;
  }

  @Override
  public String toString() {
    return "UserScript{" +
            "groupName='" + groupName + '\'' +
            ", source='" + source + '\'' +
            ", injectionTime=" + injectionTime +
            ", contentWorld=" + contentWorld +
            ", allowedOriginRules=" + allowedOriginRules +
            ", forMainFrameOnly=" + forMainFrameOnly +
            '}';
  }
}
