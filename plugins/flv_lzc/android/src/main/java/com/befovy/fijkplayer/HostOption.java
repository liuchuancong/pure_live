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

import java.util.HashMap;
import java.util.Map;

final class HostOption {

    final static String REQUEST_AUDIOFOCUS = "request-audio-focus";
    final static String RELEASE_AUDIOFOCUS = "release-audio-focus";

    final static String REQUEST_SCREENON = "request-screen-on";

    final static String ENABLE_SNAPSHOT = "enable-snapshot";

    final private Map<String, Integer> mIntOption;

    final private Map<String, String> mStrOption;


    HostOption() {
        this.mIntOption = new HashMap<>();
        this.mStrOption = new HashMap<>();
    }


    void addIntOption(String key, Integer value) {
        mIntOption.put(key, value);
    }

    void addStrOption(String key, String value) {
        mStrOption.put(key, value);
    }

    @SuppressWarnings("SameParameterValue")
    int getIntOption(String key, int defalt) {
        int value = defalt;
        if (mIntOption.containsKey(key)) {
            Integer v = mIntOption.get(key);
            if (v != null)
                value = v;
        }
        return value;
    }

    public String getStrOption(String key, String defalt) {
        String value = defalt;
        if (mStrOption.containsKey(key)) {
            String v = mStrOption.get(key);
            if (v != null)
                value = v;
        }
        return value;
    }
}
