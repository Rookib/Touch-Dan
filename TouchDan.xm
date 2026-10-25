#import <Foundation/Foundation.h>
#import <TDNTouchVisualizer/TDNTouchVisualizer.h>
#import <UIKit/UIKit.h>

#import <dlfcn.h>
#import <HBLog.h>
#import <notify.h>

#import "TDNPrefs/NSBundle+TDNPrefs.h"
#import "TDNPrefs/TDNUserDefaults.h"
#import "TouchDan-Swift.h"

@protocol SBReachabilityObserver <NSObject>
@optional
- (void)handleReachabilityModeActivated;
- (void)handleReachabilityModeDeactivated;
- (void)handleReachabilityYOffsetDidChange;
- (void)handleWillBeginReachabilityAnimation;
- (void)handleDidEndReachabilityAnimation;
@end

@interface SBReachabilityManager : NSObject
+ (instancetype)sharedInstance;
+ (BOOL)reachabilitySupported;
- (BOOL)reachabilityEnabled;
- (BOOL)reachabilityModeActive;
- (void)addObserver:(id<SBReachabilityObserver>)observer;
@end

@interface RPBroadcastController : NSObject
@property (nonatomic, copy) NSString *tdn_inBroadcastingExtensionIdentifier;
@property (getter=isBroadcasting, nonatomic, readonly) BOOL broadcasting;
@end

@interface RPScreenRecorder : NSObject
@property (nonatomic, copy) NSString *tdn_inBroadcastingExtensionIdentifier;
@property (nonatomic, retain) RPBroadcastController *activeBroadcastController;
@property (assign, nonatomic) BOOL broadcasting;
+ (instancetype)sharedRecorder;
- (void)setupSystemBroadcastWithExtension:(NSString *)arg1 handler:(id)arg2;
- (void)startSystemBroadcastWithHandler:(id)arg1;
- (void)stopSystemBroadcastWithHandler:(id)arg1;
@end

@interface UIColor (TDN)
+ (UIColor *)tdn_colorWithRGBAString:(NSString *)rgbaString;
+ (UIColor *)tdn_colorWithRGBAString:(NSString *)rgbaString extraAlpha:(CGFloat)extraAlpha;
@end

@implementation UIColor (TDN)

+ (UIColor *)tdn_colorWithRGBAString:(NSString *)rgbaString {
    return [self tdn_colorWithRGBAString:rgbaString extraAlpha:1.0];
}

+ (UIColor *)tdn_colorWithRGBAString:(NSString *)rgbaString extraAlpha:(CGFloat)extraAlpha {
    NSArray<NSString *> *components = [rgbaString componentsSeparatedByString:@","];
    if (components.count < 3) {
        return nil;
    }
    CGFloat r = [components[0] doubleValue] / 255.0;
    CGFloat g = [components[1] doubleValue] / 255.0;
    CGFloat b = [components[2] doubleValue] / 255.0;
    CGFloat a = (components.count >= 4 ? [components[3] doubleValue] : 1.0) * extraAlpha;
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@end

static UIWindowScene *_gWindowScene = nil;
static TDNTouchVisualizerWindow *_gWindow = nil;
static TDNTouchConfig *_gTouchConfig = nil;
static TDNTouchConfig *_gRippleConfig = nil;

static BOOL _gEnabled = NO;
static BOOL _gEnabledOnlyWhenRecording = NO;
static BOOL _gQuickPathRequested = NO;
static BOOL _gMorphRequested = NO;
static BOOL _gTrackingRequested = NO;

static BOOL _gEnableOverride = NO;
static BOOL _gDisableOverride = NO;
static BOOL _gDisableOverrideWhenRecording = NO;

static BOOL _gIsRecording = NO;
static BOOL _gIsBroadcasting = NO;
static BOOL _gIsInReachability = NO;

static NSInteger HomeButtonType(void) {
    typedef CFTypeRef (*MGCopyAnswerFunction)(CFStringRef key);

    static dispatch_once_t onceToken;
    static NSInteger homeButtonType = 0;
    dispatch_once(&onceToken, ^{
      MGCopyAnswerFunction MGCopyAnswer = (MGCopyAnswerFunction)dlsym(RTLD_DEFAULT, "MGCopyAnswer");
      if (!MGCopyAnswer) {
          return;
      }

      id value = CFBridgingRelease(MGCopyAnswer(CFSTR("HomeButtonType")));
      if ([value respondsToSelector:@selector(integerValue)]) {
          homeButtonType = [value integerValue];
      }
    });
    return homeButtonType;
}

static BOOL IsRealHomeButtonDevice(void) {
    return HomeButtonType() == 1;
}

static BOOL IsAnyScreenInRecording(void) {
    for (UIScreen *screen in [UIScreen screens]) {
        if ([screen isCaptured]) {
            return YES;
        }
    }
    return NO;
}

static BOOL IsEnabled(void) {
    if (!_gEnabled || _gIsInReachability) {
        return NO;
    }

    if (_gIsRecording) {
        if (_gIsBroadcasting) {
            return NO;
        }
        return !_gDisableOverrideWhenRecording;
    }

    if (_gEnabledOnlyWhenRecording) {
        if (!_gEnableOverride) {
            return NO;
        }
    } else {
        if (_gDisableOverride) {
            return NO;
        }
    }

    return YES;
}

static BOOL ShouldKeepSystemGestureTouchStreamSending(void) {
    return IsEnabled() || [_gWindow hasAnyTouch];
}

static void ReloadStats(void) {
    _gIsRecording = IsAnyScreenInRecording();
    if (!_gIsRecording) _gIsBroadcasting = NO;
    _gIsInReachability = [[%c(SBReachabilityManager) sharedInstance] reachabilityModeActive];

    BOOL isEnabled = IsEnabled();
    // Preserve the user's choices while recording/reachability temporarily hides effects.
    _gWindow.quickPathEnabled = isEnabled && _gQuickPathRequested;
    _gWindow.morphEnabled = isEnabled && _gMorphRequested;
    _gWindow.trackingEnabled = isEnabled && _gTrackingRequested;
    _gWindowScene.tdn_touchVisualizerEnabled = isEnabled;

    HBLogDebug(@"Is Recording: %@, Is Broadcasting: %@, Is In Reachability: %@, Is Enabled: %@",
                _gIsRecording ? @"YES" : @"NO",
                _gIsBroadcasting ? @"YES" : @"NO",
                _gIsInReachability ? @"YES" : @"NO",
                _gWindowScene.tdn_touchVisualizerEnabled ? @"YES" : @"NO");
}

static void ReloadPrefs(void) {
    _gQuickPathRequested = tdnBool(@"useQuickPathEffect");
    _gMorphRequested = tdnBool(@"useMorphEffect");
    _gTrackingRequested = tdnBool(@"useTrackingEffect");

    CGFloat alpha = [[TDNUserDefaults standardUserDefaults] doubleForKey:@"alpha"];
    _gTouchConfig.alpha = alpha;
    _gRippleConfig.alpha = alpha;

    NSString *fillColorString = [[TDNUserDefaults standardUserDefaults] stringForKey:@"fillColorString"];
    if (fillColorString) {
        UIColor *fillColor = [UIColor tdn_colorWithRGBAString:fillColorString];
        if (fillColor) {
            _gTouchConfig.fillColor = fillColor;
            _gRippleConfig.fillColor = _gTrackingRequested ? fillColor : [UIColor clearColor];
        }
    }

    NSString *borderColorString = [[TDNUserDefaults standardUserDefaults] stringForKey:@"borderColorString"];
    if (borderColorString) {
        UIColor *strokeColor = [UIColor tdn_colorWithRGBAString:borderColorString];
        if (strokeColor) {
            _gTouchConfig.strokeColor = strokeColor;
            _gRippleConfig.strokeColor = _gTrackingRequested ? strokeColor : [UIColor clearColor];
        }
    }

    NSString *quickPathFillColorString =
        [[TDNUserDefaults standardUserDefaults] stringForKey:@"quickPathFillColorString"];
    if (quickPathFillColorString) {
        UIColor *quickPathFillColor = [UIColor tdn_colorWithRGBAString:quickPathFillColorString extraAlpha:alpha];
        if (quickPathFillColor) {
            [_gWindow tdn_setQuickPathFillColor:quickPathFillColor];
        }
    }

    NSString *trackingFillColorString =
        [[TDNUserDefaults standardUserDefaults] stringForKey:@"trackingFillColorString"];
    if (trackingFillColorString) {
        UIColor *trackingFillColor = [UIColor tdn_colorWithRGBAString:trackingFillColorString];
        if (trackingFillColor) {
            _gRippleConfig.fillColor = trackingFillColor;
        }
    }

    NSString *trackingBorderColorString =
        [[TDNUserDefaults standardUserDefaults] stringForKey:@"trackingBorderColorString"];
    if (trackingBorderColorString) {
        UIColor *trackingStrokeColor = [UIColor tdn_colorWithRGBAString:trackingBorderColorString];
        if (trackingStrokeColor) {
            _gRippleConfig.strokeColor = trackingStrokeColor;
        }
    }

    BOOL useImageEffect = tdnBool(@"useImageEffect");
    UIImage *fillImage = nil;
    if (useImageEffect) {
        NSString *imageFillName = [[TDNUserDefaults standardUserDefaults] stringForKey:@"imageFillName"];
        fillImage = [NSBundle tdn_fillImageNamed:imageFillName];
        _gTouchConfig.fillImage = fillImage;
    } else {
        _gTouchConfig.fillImage = nil;
    }
    if (useImageEffect && _gTrackingRequested) {
        _gRippleConfig.fillImage = fillImage;
    } else {
        _gRippleConfig.fillImage = nil;
    }

    BOOL shouldAutoRotate = tdnBool(@"imageShouldAutoRotate");
    _gTouchConfig.shouldAutoRotate = shouldAutoRotate;
    _gRippleConfig.shouldAutoRotate = shouldAutoRotate;

    NSTimeInterval fadeDuration = [[TDNUserDefaults standardUserDefaults] doubleForKey:@"animationDuration"];
    _gTouchConfig.fadeDuration = fadeDuration;
    _gRippleConfig.fadeDuration = fadeDuration * 0.667;
    [_gWindow tdn_setQuickPathAnimationDuration:fadeDuration];

    CGFloat radius = [[TDNUserDefaults standardUserDefaults] doubleForKey:@"fillSize"] / 2.0;
    _gTouchConfig.radius = radius;
    _gRippleConfig.radius = radius;
    [_gWindow tdn_setQuickPathFillWidth:radius * 0.5];

    CGFloat borderWidth = [[TDNUserDefaults standardUserDefaults] doubleForKey:@"borderWidth"];
    _gTouchConfig.borderWidth = borderWidth;
    _gRippleConfig.borderWidth = borderWidth;

    CGFloat cornerRadius = [[TDNUserDefaults standardUserDefaults] doubleForKey:@"cornerRadius"];
    _gTouchConfig.cornerRadius = cornerRadius;
    _gRippleConfig.cornerRadius = cornerRadius;

    CGFloat liftScale = [[TDNUserDefaults standardUserDefaults] doubleForKey:@"liftScale"];
    _gTouchConfig.liftScale = liftScale;
    _gRippleConfig.liftScale = liftScale;

    _gWindow.touchContactConfig = _gTouchConfig;
    _gWindow.touchRippleConfig = _gRippleConfig;

    _gEnabled = tdnBool(@"isEnabled");
    _gEnabledOnlyWhenRecording = tdnBool(@"isRecordingOnly");

    _gEnableOverride = tdnBool(@"enableOverride");
    _gDisableOverride = tdnBool(@"disableOverride");
    _gDisableOverrideWhenRecording = tdnBool(@"disableOverrideWhenRecording");

    ReloadStats();
}

__attribute__((visibility("hidden")))
@interface TDNReachabilityObserver : NSObject <SBReachabilityObserver>
@end

@implementation TDNReachabilityObserver

- (void)handleWillBeginReachabilityAnimation {
    ReloadStats();
}

- (void)handleDidEndReachabilityAnimation {
    ReloadStats();
}

@end

@interface UIWindowScene (TouchDan)
- (void)touchdan_reload;
- (void)touchdan_setup;
@end

%group TDNSpringBoard

struct BlockDescriptor {
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct Block {
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct BlockDescriptor *descriptor;
};

static NSString *BlockSig(id blockObj)
{
    if (blockObj == nil) {
        return nil;
    }
    struct Block *block = (__bridge struct Block *)blockObj;
    struct BlockDescriptor *descriptor = block->descriptor;
    if (descriptor == NULL) {
        return nil;
    }

    int copyDisposeFlag = 1 << 25;
    int signatureFlag = 1 << 30;

    if (block->flags & signatureFlag) {
        int index = 0;
        if (block->flags & copyDisposeFlag)
            index += 2;

        const char *signature = (const char *)descriptor->rest[index];
        if (signature) {
            return [NSString stringWithUTF8String:signature];
        }
    }

    return nil;
}

%hook RPScreenRecorder

%property (nonatomic, copy) NSString *tdn_inBroadcastingExtensionIdentifier;

- (void)setupSystemBroadcastWithExtension:(NSString *)arg1 handler:(id)arg2 {
    %orig;
    self.tdn_inBroadcastingExtensionIdentifier = arg1;
    HBLogDebug(@"setupSystemBroadcastWithExtension: %@", arg1);
}

- (void)startSystemBroadcastWithHandler:(void (^)(NSError *))arg1 {
    NSString *sig1 = BlockSig(arg1);
    if (![sig1 isEqualToString:@"v16@?0@\"NSError\"8"]) {
        %orig;
        return;
    }
    void (^handler)(NSError *) = ^(NSError *error) {
      _gIsBroadcasting = (!error
        && self.tdn_inBroadcastingExtensionIdentifier != nil
        && [[TDNUserDefaults longScreenshotterKeys] containsObject:self.tdn_inBroadcastingExtensionIdentifier]
      );
      ReloadStats();
      if (arg1) {
        arg1(error);
      }
    };
    %orig(handler);
}

%end

%hook RPBroadcastController

%property (nonatomic, copy) NSString *tdn_inBroadcastingExtensionIdentifier;

- (instancetype)initWithExtensionBundleID:(NSString *)arg1 broadcastURL:(id)arg2 {
    RPBroadcastController *result = %orig;
    result.tdn_inBroadcastingExtensionIdentifier = arg1;
    HBLogDebug(@"initWithExtensionBundleID: %@", arg1);
    return result;
}

- (void)startSystemBroadcastWithHandler:(void (^)(NSError *))arg1 {
    NSString *sig1 = BlockSig(arg1);
    if (![sig1 isEqualToString:@"v16@?0@\"NSError\"8"]) {
        %orig;
        return;
    }
    void (^handler)(NSError *) = ^(NSError *error) {
      _gIsBroadcasting = (!error
        && self.tdn_inBroadcastingExtensionIdentifier != nil
        && [[TDNUserDefaults longScreenshotterKeys] containsObject:self.tdn_inBroadcastingExtensionIdentifier]
      );
      ReloadStats();
      if (arg1) {
        arg1(error);
      }
    };
    %orig(handler);
}

%end

%hook UIWindowScene

- (void)_delegate_windowDidBecomeVisible:(id)arg1 {
    %orig;

    if (![NSStringFromClass([self class]) hasPrefix:@"SB"]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      [self touchdan_reload];
    });
}

%new
- (void)touchdan_reload {
    _gWindowScene = self;
    _gWindow = self.tdn_touchVisualizerWindow;
    _gTouchConfig = _gWindow.touchContactConfig;
    _gRippleConfig = _gWindow.touchRippleConfig;

    ReloadPrefs();

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [self touchdan_setup];
    });
}

%new
- (void)touchdan_setup {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(touchdan_screenCapturedDidChange:)
                                               name:UIScreenCapturedDidChangeNotification
                                             object:nil];

    static TDNReachabilityObserver *_gReachabilityObserver = nil;
    _gReachabilityObserver = [TDNReachabilityObserver new];
    [[%c(SBReachabilityManager) sharedInstance] addObserver:_gReachabilityObserver];

    int _gNotifyToken;
    notify_register_dispatch(TDN_NOTIFY_NAME, &_gNotifyToken, dispatch_get_main_queue(), ^(int token) {
      ReloadPrefs();
    });
}

%new
- (void)touchdan_screenCapturedDidChange:(NSNotification *)notification {
    ReloadStats();
}

%end

%hook _UISystemGestureWindow

- (void)sendEvent:(UIEvent *)event {
    %orig;

    if (event.type != UIEventTypeTouches) {
        return;
    }

    if (IsEnabled() || [_gWindow hasAnyTouch]) {
        [_gWindow sendTouchEvent:event];
        [_gWindow tdn_sendQuickPathEvent:event];
    }
}

%end

%end

%group TDNLegacyHomeButtonTouchStream

%hook __UISystemGestureManager

- (unsigned char)_dispatchModeForExternalGestureCompletion {
    unsigned char dispatchMode = %orig;
    if (dispatchMode == 1 && ShouldKeepSystemGestureTouchStreamSending()) {
        return 2;
    }
    return dispatchMode;
}

%end

%end

%ctor {
    NSString *bid = [NSBundle.mainBundle bundleIdentifier];
    BOOL isSpringBoard = [bid isEqualToString:@"com.apple.springboard"];
    if (isSpringBoard) {
        %init(TDNSpringBoard);
        if (IsRealHomeButtonDevice()) {
            %init(TDNLegacyHomeButtonTouchStream);
        }
    }
}
