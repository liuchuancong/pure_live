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

import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;

import tv.danmaku.ijk.media.player.misc.IMediaDataSource;

class FileMediaDataSource implements IMediaDataSource {
    private RandomAccessFile mFile;
    private long mFileSize;

    public FileMediaDataSource(File file) {
        try {
            mFile = new RandomAccessFile(file, "r");
            mFileSize = mFile.length();
        } catch (IOException e) {
            mFile = null;
            mFileSize = -1;
            Log.e("DataSource", "failed to open RandomAccess" + e.getMessage());
        }
    }

    @Override
    public int readAt(long position, byte[] buffer, int offset, int size) {
        if (size == 0)
            return 0;
        int length = -1;
        if (mFile != null) {
            try {
                if (mFile.getFilePointer() != position)
                    mFile.seek(position);
                length = mFile.read(buffer, 0, size);
            } catch (IOException e) {
                Log.e("DataSource", "failed to read" + e.getMessage());
            }
        }
        return length;
    }

    @Override
    public long getSize() {
        return mFileSize;
    }

    @Override
    public void close() {
        if (mFile != null) {
            try {
                mFile.close();
                mFileSize = 0;
                mFile = null;
            } catch (IOException e) {
                Log.e("DataSource", "failed to close" + e.getMessage());
            }
        }
    }
}
