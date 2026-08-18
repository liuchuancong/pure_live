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

#import "FijkHostOption.h"

@implementation FijkHostOption {
    NSMutableDictionary<NSString *, NSNumber *> *_intOption;

    NSMutableDictionary<NSString *, NSString *> *_strOption;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _intOption = [[NSMutableDictionary alloc] init];
        _strOption = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setIntValue:(NSNumber *)value forKey:(NSString *)key {
    _intOption[key] = value;
}

- (void)setStrValue:(NSString *)value forKey:(NSString *)key {
    _strOption[key] = value;
}

- (NSNumber *)getIntValue:(NSString *)key defalt:(NSNumber *)defalt {
    NSNumber *value = defalt;
    if ([_intOption objectForKey:key] != nil) {
        value = [_intOption objectForKey:key];
    }
    return value;
}

- (NSString *)getStrValue:(NSString *)key defalt:(NSString *)defalt {
    NSString *value = defalt;
    if ([_strOption objectForKey:key] != nil) {
        value = [_strOption objectForKey:key];
    }
    return value;
}

@end
