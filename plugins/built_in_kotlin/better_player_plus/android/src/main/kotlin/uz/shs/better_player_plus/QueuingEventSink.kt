// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package uz.shs.better_player_plus

import io.flutter.plugin.common.EventChannel.EventSink
import java.util.ArrayList

/**
 * And implementation of [EventSink] which can wrap an underlying sink.
 * It delivers messages immediately when downstream is available, but it queues messages before
 * the delegate event sink is set with setDelegate.
 * This class is not thread-safe. All calls must be done on the same thread or synchronized
 * externally.
 */
internal class QueuingEventSink : EventSink {
    private var delegate: EventSink? = null
    private val eventQueue = ArrayList<Any>()
    private var done = false
    fun setDelegate(delegate: EventSink?) {
        this.delegate = delegate
        maybeFlush()
    }

    override fun endOfStream() {
        enqueue(EndOfStreamEvent())
        maybeFlush()
        done = true
    }

    override fun error(code: String, message: String, details: Any) {
        enqueue(ErrorEvent(code, message, details))
        maybeFlush()
    }

    override fun success(event: Any) {
        enqueue(event)
        maybeFlush()
    }

    private fun enqueue(event: Any) {
        if (done) {
            return
        }
        eventQueue.add(event)
    }

    private fun maybeFlush() {
        if (delegate == null) {
            return
        }
        for (event in eventQueue) {
            when (event) {
                is EndOfStreamEvent -> {
                    delegate!!.endOfStream()
                }

                is ErrorEvent -> {
                    delegate!!.error(event.code, event.message, event.details)
                }

                else -> {
                    delegate!!.success(event)
                }
            }
        }
        eventQueue.clear()
    }

    private class EndOfStreamEvent
    private class ErrorEvent(
        var code: String,
        var message: String,
        var details: Any
    )
}