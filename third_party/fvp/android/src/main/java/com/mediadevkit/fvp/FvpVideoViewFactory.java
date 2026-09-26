/*
 * Copyright (c) 2026 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.mediadevkit.fvp;

import android.content.Context;

import java.util.Map;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/** Creates {@link FvpVideoView}s for the "fvp/video-view" platform view type. */
public class FvpVideoViewFactory extends PlatformViewFactory {
    FvpVideoViewFactory() {
        super(StandardMessageCodec.INSTANCE);
    }

    @Override
    @SuppressWarnings("unchecked")
    public PlatformView create(Context context, int viewId, Object args) {
        return new FvpVideoView(context, viewId, (Map<String, Object>) args);
    }
}
