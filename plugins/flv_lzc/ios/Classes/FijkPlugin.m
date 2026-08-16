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

#import "FijkPlugin.h"
#import "FijkPlayer.h"
#import "FijkQueuingEventSink.h"

#import <AVKit/AVKit.h>
#import <Flutter/Flutter.h>
#import <IJKMediaPlayer/IJKMediaPlayer.h>
#import <MediaPlayer/MediaPlayer.h>

typedef NS_ENUM(int, FijkVoUIMode) {
    hideUIWhenPlayable = 0,
    hideUIWhenPlaying,
    neverShowUI,
    alwaysShowUI,
};

@implementation FijkPlugin {
    NSObject<FlutterPluginRegistrar> *_registrar;
    NSMutableDictionary<NSNumber *, FijkPlayer *> *_fijkPlayers;

    FijkQueuingEventSink *_eventSink;
    FlutterEventChannel *_eventChannel;

    MPVolumeView *_volumeView;
    UISlider *_volumeViewSlider;
    BOOL _volumeInWindow;

    int _volumeUIMode;
    BOOL _eventListening;
    float _volStep;
    BOOL _showOsUI;
}

static FijkPlugin *_instance = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel =
        [FlutterMethodChannel methodChannelWithName:@"befovy.com/fijk"
                                    binaryMessenger:[registrar messenger]];
    FijkPlugin *instance = [[FijkPlugin alloc] initWithRegistrar:registrar];
    _instance = instance;
    [registrar addMethodCallDelegate:instance channel:channel];

    FijkPlayer *player = [[FijkPlayer alloc] initJustTexture];
    int64_t vid = [[registrar textures] registerTexture:player];
    [player shutdown];
    [[registrar textures] unregisterTexture:vid];
}

+ (FijkPlugin *)singleInstance {
    return _instance;
}

- (instancetype)initWithRegistrar:
    (NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    if (self) {
        _registrar = registrar;
        _fijkPlayers = [[NSMutableDictionary alloc] init];
        _eventListening = FALSE;
        _volumeUIMode = alwaysShowUI;
        _volStep = 1.0 / 16.0;
        _showOsUI = YES;
        _eventSink = [[FijkQueuingEventSink alloc] init];

        _eventChannel =
            [FlutterEventChannel eventChannelWithName:@"befovy.com/fijk/event"
                                      binaryMessenger:[registrar messenger]];
        [_eventChannel setStreamHandler:self];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(volumeChange:)
                   name:@"AVSystemController_SystemVolumeDidChangeNotification"
                 object:nil];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {

    NSDictionary *argsMap = call.arguments;
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        NSString *osVersion = [[UIDevice currentDevice] systemVersion];
        result([@"iOS " stringByAppendingString:osVersion]);
    } else if ([@"init" isEqualToString:call.method]) {
        NSLog(@"FLUTTER: %s %@", "call init:", argsMap);
        result(NULL);
    } else if ([@"createPlayer" isEqualToString:call.method]) {
        FijkPlayer *fijkplayer =
            [[FijkPlayer alloc] initWithRegistrar:_registrar];
        NSNumber *playerId = fijkplayer.playerId;
        _fijkPlayers[playerId] = fijkplayer;
        result(playerId);
    } else if ([@"releasePlayer" isEqualToString:call.method]) {
        NSNumber *pid = argsMap[@"pid"];
        FijkPlayer *fijkPlayer = [_fijkPlayers objectForKey:pid];
        [fijkPlayer shutdown];
        if (fijkPlayer != nil) {
            [_fijkPlayers removeObjectForKey:pid];
        }
        result(nil);
    } else if ([@"logLevel" isEqualToString:call.method]) {
        NSNumber *level = argsMap[@"level"];
        int l = [level intValue] / 100;
        l = l < 0 ? 0 : l;
        l = l > 8 ? 8 : l;
        [IJKFFMoviePlayerController setLogLevel:l];
        result(nil);
    } else if ([@"setOrientationPortrait" isEqualToString:call.method]) {
        UIInterfaceOrientationMask mask = [[UIApplication sharedApplication]
            supportedInterfaceOrientationsForWindow:nil];
        UIDeviceOrientation deviceOrientation =
            [UIDevice currentDevice].orientation;
        BOOL changed = NO;
        if (deviceOrientation != UIDeviceOrientationPortrait &&
            deviceOrientation != UIDeviceOrientationPortraitUpsideDown) {
            if (mask & UIInterfaceOrientationMaskPortraitUpsideDown) {
                [[UIDevice currentDevice]
                    setValue:@(UIInterfaceOrientationPortraitUpsideDown)
                      forKey:@"orientation"];
                changed = YES;
            } else if (mask & UIInterfaceOrientationMaskPortrait) {
                [[UIDevice currentDevice]
                    setValue:@(UIInterfaceOrientationPortrait)
                      forKey:@"orientation"];
                changed = YES;
            }
        }
        [UIViewController attemptRotationToDeviceOrientation];
        result(@(changed));
    } else if ([@"setOrientationLandscape" isEqualToString:call.method]) {
        UIInterfaceOrientationMask mask = [[UIApplication sharedApplication]
            supportedInterfaceOrientationsForWindow:nil];
        UIDeviceOrientation deviceOrientation =
            [UIDevice currentDevice].orientation;
        BOOL changed = NO;
        if (deviceOrientation != UIDeviceOrientationLandscapeLeft &&
            deviceOrientation != UIDeviceOrientationLandscapeRight) {
            if (mask & UIInterfaceOrientationMaskLandscapeRight) {
                [[UIDevice currentDevice]
                    setValue:@(UIInterfaceOrientationLandscapeRight)
                      forKey:@"orientation"];
                changed = YES;
            } else if (mask & UIInterfaceOrientationMaskLandscapeLeft) {
                [[UIDevice currentDevice]
                    setValue:@(UIInterfaceOrientationLandscapeLeft)
                      forKey:@"orientation"];
                changed = YES;
            }
        }
        [UIViewController attemptRotationToDeviceOrientation];
        result(@(changed));
    } else if ([@"setOrientationAuto" isEqualToString:call.method]) {
        UIInterfaceOrientationMask mask = [[UIApplication sharedApplication]
            supportedInterfaceOrientationsForWindow:nil];

        if (mask & UIInterfaceOrientationMaskPortrait)
            [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationPortrait)
                                        forKey:@"orientation"];
        [UIViewController attemptRotationToDeviceOrientation];
        result(nil);
    } else if ([@"setScreenOn" isEqualToString:call.method]) {
        bool screenOn = false;
        NSNumber* on = argsMap[@"on"];
        screenOn = on == nil ? false : on.boolValue;
        [self setScreenOn:screenOn];
        result(nil);
    } else if ([@"isScreenKeptOn" isEqualToString:call.method]) {
        bool isIdleTimerDisabled =  [[UIApplication sharedApplication] isIdleTimerDisabled];
        result(@(isIdleTimerDisabled));
    } else if ([@"brightness" isEqualToString:call.method]) {
        float brightness = [UIScreen mainScreen].brightness;
        result(@(brightness));
    } else if ([@"setBrightness" isEqualToString:call.method]) {
        float brightness = [UIScreen mainScreen].brightness;
        NSNumber* arg = argsMap[@"brightness"];
        brightness = arg == nil ? brightness : arg.floatValue;
        [[UIScreen mainScreen] setBrightness:brightness];
        result(nil);
    } else if ([@"volumeUp" isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"step"];
        float step = number == nil ? _volStep : [number floatValue];
        float vol = [self getSystemVolume];
        vol += step;
        vol = [self setSystemVolume:vol];
        result(@(vol));
    } else if ([@"volumeDown" isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"step"];
        float step = number == nil ? _volStep : [number floatValue];
        float vol = [self getSystemVolume];
        vol -= step;
        vol = [self setSystemVolume:vol];
        result(@(vol));
    } else if ([@"volumeMute" isEqualToString:call.method]) {
        float vol = [self setSystemVolume:0.0f];
        result(@(vol));
    } else if ([@"volumeSet" isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"vol"];
        float v = number == nil ? [self getSystemVolume] : [number floatValue];
        v = [self setSystemVolume:v];
        result(@(v));
    } else if ([@"systemVolume" isEqualToString:call.method]) {
        result(@([self getSystemVolume]));
    } else if ([@"volUiMode" isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"mode"];
        _volumeUIMode = [number intValue];
        [self updateVolumeVisiablity];
        result(nil);
    } else if ([@"onLoad" isEqualToString:call.method]) {
        [self initVolumeView];
        _eventListening = YES;
        result(nil);
    } else if ([@"onUnload" isEqualToString:call.method]) {
        _eventListening = NO;
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)initVolumeView {
    if (_volumeView == nil) {
        _volumeView =
            [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 10, 10)];
        _volumeView.hidden = NO;
    }
    if (_volumeViewSlider == nil) {
        for (UIView *view in [_volumeView subviews]) {
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
                _volumeViewSlider = (UISlider *)view;
                _volumeViewSlider.value = [AVAudioSession sharedInstance].outputVolume;
                break;
            }
        }
    }
    if (!_volumeInWindow) {
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        if (window != nil) {
            [window addSubview:_volumeView];
            _volumeInWindow = YES;
        }
    }
    [self updateVolumeVisiablity];
}

- (void)onPlayingChange:(int)delta {
    _playingCnt += delta;
    [self updateVolumeVisiablity];
}

- (void)onPlayableChange:(int)delta {
    _playableCnt += delta;
    [self updateVolumeVisiablity];
}

- (void)setScreenOn:(BOOL)on {
    [UIApplication sharedApplication].idleTimerDisabled = on;
}

- (float)getSystemVolume {
    [self initVolumeView];
    if (_volumeViewSlider == nil) {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        CGFloat currentVol = audioSession.outputVolume;
        return currentVol;
    } else {
        return _volumeViewSlider.value;
    }
}

- (float)setSystemVolume:(float)vol {
    [self initVolumeView];
    if (vol > 1.0) {
        vol = 1.0;
    } else if (vol < 0) {
        vol = 0.0;
    }
    [_volumeViewSlider setValue:vol animated:FALSE];
    vol = _volumeViewSlider.value;
    [self sendVolumeChange:vol];
    return vol;
}

- (void)updateVolumeVisiablity {
    if (_volumeView == nil || _volumeInWindow == FALSE) {
        _showOsUI = YES;
        return;
    }
    if (_volumeUIMode == alwaysShowUI) {
        _showOsUI = YES;
        _volumeView.hidden = YES;
    } else if (_volumeUIMode == neverShowUI) {
        _showOsUI = NO;
        _volumeView.hidden = NO;
    } else if (_volumeUIMode == hideUIWhenPlaying) {
        _volumeView.hidden = _playingCnt <= 0;
        _showOsUI = _volumeView.hidden;
    } else if (_volumeUIMode == hideUIWhenPlayable) {
        _volumeView.hidden = _playableCnt <= 0;
        _showOsUI = _volumeView.hidden;
    }
}

- (void)volumeChange:(NSNotification *)notifi {
    NSString *style = [notifi.userInfo
        objectForKey:@"AVSystemController_AudioCategoryNotificationParameter"];
    CGFloat value = [[notifi.userInfo
        objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"]
        doubleValue];
    if ([style isEqualToString:@"Audio/Video"]) {
        [self sendVolumeChange:value];
    }
}

- (void)sendVolumeChange:(float)value {
    if (_eventListening) {
        [_eventSink success:@{
            @"event" : @"volume",
            @"sui" : @(_showOsUI),
            @"vol" : @(value)
        }];
    }
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
    [_eventSink setDelegate:nil];
    return nil;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:
                                           (nonnull FlutterEventSink)events {
    [_eventSink setDelegate:events];
    return nil;
}

@end
