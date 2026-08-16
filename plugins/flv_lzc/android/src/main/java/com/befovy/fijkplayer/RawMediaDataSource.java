//MIT License
//
//Copyright (c) [2019] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

package com.befovy.fijkplayer;

import android.util.Log;

import java.io.IOException;
import java.io.InputStream;

import tv.danmaku.ijk.media.player.misc.IMediaDataSource;

class RawMediaDataSource implements IMediaDataSource {
    private InputStream mIs;
    private long mPosition = 0;

    public RawMediaDataSource(InputStream is) {
        mIs = is;
    }

    @Override
    public int readAt(long position, byte[] buffer, int offset, int size) {
        if (size <= 0)
            return size;
        int length = -1;
        try {
            if (mPosition != position) {
                mIs.reset();
                mPosition = mIs.skip(position);
            }
            length = mIs.read(buffer, offset, size);
            mPosition += length;
        } catch (IOException e) {
            Log.e("DataSource", "failed to read" + e.getMessage());
        }
        return length;
    }

    @Override
    public long getSize() {
        long size = -1;
        try {
            size = mIs.available();
        } catch (IOException e) {
            Log.e("DataSource", "failed to get size" + e.getMessage());
        }
        return size;
    }

    @Override
    public void close() {
        if (mIs != null) {
            try {
                mIs.close();
                mIs = null;
            } catch (IOException e) {
                Log.e("DataSource", "failed to close" + e.getMessage());
            }
        }
    }

}
