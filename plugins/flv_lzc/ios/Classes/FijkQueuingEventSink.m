// MIT License
//
// Copyright (c) [2019] [Befovy]
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "FijkQueuingEventSink.h"

@implementation FijkQueuingEventSink {
    NSMutableArray *_eventQueue;
    BOOL _done;
    FlutterEventSink _delegate;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _delegate = nil;
        _done = false;
        _eventQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)maybeFlush {
    if (_delegate == nil)
        return;

    for (NSObject *event in _eventQueue) {
        _delegate(event);
    }
    [_eventQueue removeAllObjects];
}

- (void)enqueue:(const NSObject *)event {
    if (_done)
        return;
    [_eventQueue addObject:event];
}

- (void)setDelegate:(FlutterEventSink)sink {
    _delegate = sink;
    [self maybeFlush];
}

- (void)endOfStream {
    [self enqueue:FlutterEndOfEventStream];
    [self maybeFlush];
    _done = TRUE;
}

- (void)error:(NSString *)code
      message:(NSString *_Nullable)message
      details:(id _Nullable)details {
    [self enqueue:[FlutterError errorWithCode:code
                                      message:message
                                      details:details]];
    [self maybeFlush];
}

- (void)success:(NSObject *)event {
    [self enqueue:event];
    [self maybeFlush];
}

- (void)dealloc {
    if (_eventQueue) {
        [_eventQueue removeAllObjects];
        _eventQueue = nil;
    }
}

@end
