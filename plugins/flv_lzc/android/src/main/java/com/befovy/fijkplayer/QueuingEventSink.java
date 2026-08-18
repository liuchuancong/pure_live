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

import java.util.ArrayList;

import io.flutter.plugin.common.EventChannel;

/**
 * And implementation of {@link EventChannel.EventSink} which can wrap an underlying sink.
 *
 * <p>It delivers messages immediately when downstream is available, but it queues messages before
 * the delegate event sink is set with setDelegate.
 *
 * <p>This class is not thread-safe. All calls must be done on the same thread or synchronized
 * externally.
 */
final class QueuingEventSink implements EventChannel.EventSink {

    private EventChannel.EventSink delegate;
    private final ArrayList<Object> eventQueue = new ArrayList<>();
    private boolean done = false;

    public void setDelegate(EventChannel.EventSink delegate) {
        this.delegate = delegate;
        maybeFlush();
    }

    @Override
    public void endOfStream() {
        enqueue(new EndOfStreamEvent());
        maybeFlush();
        done = true;
    }

    @Override
    public void error(String code, String message, Object details) {
        enqueue(new ErrorEvent(code, message, details));
        maybeFlush();
    }

    @Override
    public void success(Object event) {
        enqueue(event);
        maybeFlush();
    }

    private void enqueue(Object event) {
        if (done) {
            return;
        }
        eventQueue.add(event);
    }

    private void maybeFlush() {
        if (delegate == null) {
            return;
        }
        for (Object event : eventQueue) {
            if (event instanceof EndOfStreamEvent) {
                delegate.endOfStream();
            } else if (event instanceof ErrorEvent) {
                ErrorEvent errorEvent = (ErrorEvent) event;
                delegate.error(errorEvent.code, errorEvent.message, errorEvent.details);
            } else {
                delegate.success(event);
            }
        }
        eventQueue.clear();
    }

    private static class EndOfStreamEvent {
    }

    private static class ErrorEvent {
        final String code;
        final String message;
        final Object details;

        ErrorEvent(String code, String message, Object details) {
            this.code = code;
            this.message = message;
            this.details = details;
        }
    }
}
