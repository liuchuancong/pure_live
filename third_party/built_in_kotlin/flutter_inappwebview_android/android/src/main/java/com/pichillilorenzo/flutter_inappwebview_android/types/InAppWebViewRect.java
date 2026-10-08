package com.pichillilorenzo.flutter_inappwebview_android.types;

import android.graphics.Rect;

import androidx.annotation.Nullable;

import java.util.HashMap;
import java.util.Map;

public class InAppWebViewRect {
  private double height;
  private double width;
  private double x;
  private double y;

  public InAppWebViewRect(double height, double width, double x, double y) {
    this.height = height;
    this.width = width;
    this.x = x;
    this.y = y;
  }

  @Nullable
  public static InAppWebViewRect fromMap(@Nullable Map<String, Object> map) {
    if (map == null) {
      return null;
    }
    double height = (double) map.get("height");
    double width = (double) map.get("width");
    double x = (double) map.get("x");
    double y = (double) map.get("y");
    return new InAppWebViewRect(height, width, x, y);
  }

  public Map<String, Object> toMap() {
    Map<String, Object> map = new HashMap<>();
    map.put("height", height);
    map.put("width", width);
    map.put("x", x);
    map.put("y", y);
    return map;
  }

  public Rect toRect() {
    return new Rect((int) x, (int) y, (int) (x + width), (int) (y + height));
  }

  public double getHeight() {
    return height;
  }

  public void setHeight(double height) {
    this.height = height;
  }

  public double getWidth() {
    return width;
  }

  public void setWidth(double width) {
    this.width = width;
  }

  public double getX() {
    return x;
  }

  public void setX(double x) {
    this.x = x;
  }

  public double getY() {
    return y;
  }

  public void setY(double y) {
    this.y = y;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;

    InAppWebViewRect that = (InAppWebViewRect) o;
    return Double.compare(height, that.height) == 0 && Double.compare(width, that.width) == 0 && Double.compare(x, that.x) == 0 && Double.compare(y, that.y) == 0;
  }

  @Override
  public int hashCode() {
    int result = Double.hashCode(height);
    result = 31 * result + Double.hashCode(width);
    result = 31 * result + Double.hashCode(x);
    result = 31 * result + Double.hashCode(y);
    return result;
  }

  @Override
  public String toString() {
    return "InAppWebViewRect{" +
            "height=" + height +
            ", width=" + width +
            ", x=" + x +
            ", y=" + y +
            '}';
  }
}
