/*
 * Copyright (c) 2023-2026 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.mediadevkit.fvp;

import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.util.Log;
import android.view.Surface;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.view.TextureRegistry;
import io.flutter.view.TextureRegistry.TextureEntry;
import io.flutter.view.TextureRegistry.SurfaceTextureEntry;
import io.flutter.view.TextureRegistry.SurfaceProducer;

/** FvpPlugin */
public class FvpPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  // https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.html
  private TextureRegistry texRegistry;
  private Map<Long, TextureEntry> textures; // SurfaceProducer or SurfaceTextureEntry
  private Map<Long, Surface> surfaces;
  private boolean impeller;
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    Bundle metaData = null;
    Context appCtx = flutterPluginBinding.getApplicationContext();
    try {
        metaData = appCtx.getPackageManager().getApplicationInfo(appCtx.getPackageName(), PackageManager.GET_META_DATA).metaData;
    } catch (PackageManager.NameNotFoundException e) {
        throw new RuntimeException(e);
    }
    impeller = false;
    if (metaData != null) {
      impeller = metaData.getBoolean("io.flutter.embedding.android.EnableImpeller", false);
    }
    Log.i("FvpPlugin", "metaData: " + metaData + ", impeller: " + impeller);
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "fvp");
    channel.setMethodCallHandler(this);
    texRegistry = flutterPluginBinding.getTextureRegistry();
    textures = new HashMap<>();
    surfaces = new HashMap<>();
    // SurfaceView output for VideoViewType.platformView (full display
    // resolution on TVs with an upscaled UI layer; tunneled playback).
    flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("fvp/video-view", new FvpVideoViewFactory());
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("CreateRT")) {
      final Number h = call.argument("player");  // directly cast to long: java.lang.Integer cannot be cast to java.lang.Long
      final long handle = h.longValue();
      final int width = (int)call.argument("width");
      final int height = (int)call.argument("height");
      final boolean tunnel = (boolean)call.argument("tunnel");
      TextureEntry te = null;
      Surface surface = null;
      final SurfaceProducer sp = impeller ? texRegistry.createSurfaceProducer() : null;
      if (sp != null) {
        sp.setSize(width, height);
        surface = sp.getSurface();
        te = sp;
      } else {
        SurfaceTextureEntry ste = texRegistry.createSurfaceTexture();
        SurfaceTexture tex = ste.surfaceTexture();
        tex.setDefaultBufferSize(width, height);
        surface = new Surface(tex);
        te = ste;
      }
      final long texId = te.id();
      nativeSetSurface(handle, texId, surface, width, height, tunnel);
      textures.put(texId, te);
      surfaces.put(texId, surface);
      result.success(texId);
//// FLUTTER_3.24_BEGIN
      if (sp != null) { // FIXME: requires 3.24. how to build conditionally?
        // 3.24: https://docs.flutter.dev/release/breaking-changes/android-surface-plugins
        sp.setCallback(
                new TextureRegistry.SurfaceProducer.Callback() {
                  @Override
                  public void onSurfaceAvailable() {
                    Log.d("FvpPlugin", "SurfaceProducer.onSurfaceAvailable for textureId " + texId);
                    final Surface newSurface = sp.getSurface();
                    surfaces.put(texId, newSurface);
                    // will do nothing if same surface
                    nativeSetSurface(handle, texId, newSurface, width, height, tunnel);
                  }

                  @Override
                  public void onSurfaceCleanup() {
                    Log.d("FvpPlugin", "SurfaceProducer.onSurfaceCleanup for textureId " + texId);
                    textures.remove(texId);
                    nativeSetSurface(handle, texId, null, 0, 0, tunnel);
                  }
                }
        );
      }
//// FLUTTER_3.24_END
    } else if (call.method.equals("ReleaseRT")) {
      final int texId = call.argument("texture"); // 32bit int, 0, 1, 2 .... but SurfaceTexture.id() is long
      final long texId64 = texId; // MUST cast texId to long, otherwise remove() error
      nativeSetSurface(0, texId, null, -1, -1, false);
      TextureEntry te = textures.get(texId64);
      if (te == null) {
        Log.w("FvpPlugin", "onMethodCall: ReleaseRT texId not found: " + texId);
      } else {
        te.release();
      }
      if (textures.remove(texId64) == null) {
        Log.w("FvpPlugin", "onMethodCall: ReleaseRT texture not found for " + texId);
      }
      if (surfaces.remove(texId64) == null) {
        Log.w("FvpPlugin", "onMethodCall: ReleaseRT surface not found for " + texId);
      }
      Log.i("FvpPlugin", "onMethodCall: ReleaseRT texId: " + texId + ", surfaces: " + surfaces.size() + " textures: " + textures.size());
      result.success(null);
    } else if (call.method.equals("MixWithOthers")) {
      // TODO: Implement actual business.
      result.success(null);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    Log.i("FvpPlugin", "onDetachedFromEngine: ");
    for (long texId : textures.keySet()) { nativeSetSurface(0, texId, null, -1, -1, false);}
    surfaces = null;
    textures = null;
  }

  /*!
    \param playerHandle null to destroy
    \param texId a TextureRegistry id, or a negative synthetic id for platform views (FvpVideoView)
   */
  static native void nativeSetSurface(long playerHandle, long texId, Surface surface, int w, int h, boolean tunnel);

  /*!
    Surface size change (SurfaceHolder.Callback.surfaceChanged). Only the GL
    render path needs it; with "tunnel" the decoder owns the buffer geometry.
   */
  static native void nativeSetSurfaceSize(long texId, int w, int h);

  static {
    try {
        System.loadLibrary("mdk");
        System.loadLibrary("fvp");
    } catch (UnsatisfiedLinkError e) {
        Log.w("FvpPlugin", "static initializer: loadLibrary fvp error: " + e);
    }
  }
}
