//
//  UIWindowScene+TouchVisualizer.m
//  TDNTouchVisualizer
//
//  Created by Leo Natan on 3/24/21.
//

#import <TDNTouchVisualizer/TDNTouchVisualizerWindow.h>
#import <TDNTouchVisualizer/UIWindowScene+TouchVisualizer.h>

#import <objc/runtime.h>

#import "TouchDan-Swift.h"

static const void *TDNTouchVisualizerWindowKey = &TDNTouchVisualizerWindowKey;

__attribute__((visibility("hidden")))
@interface _TDNSceneTouchVisualizerWindow : TDNTouchVisualizerWindow
@end
@implementation _TDNSceneTouchVisualizerWindow

#ifndef LNPopupControllerEnforceStrictClean
+ (void)load {
    @autoreleasepool {
        NSMutableString *name = [@"_" mutableCopy];
        [name appendString:@"canAffect"];
        [name appendString:[NSStringFromClass(UIStatusBarManager.class) substringWithRange:NSMakeRange(2, 9)]];
        [name appendString:[NSStringFromClass(UIBarAppearance.class) substringFromIndex:5]];

        Method m = class_getInstanceMethod(self, @selector(_cASBA));
        class_addMethod(self, NSSelectorFromString(name), method_getImplementation(m), method_getTypeEncoding(m));

        name = [@"_" mutableCopy];
        [name appendString:[NSStringFromSelector(@selector(canBecomeFirstResponder)) substringToIndex:9]];
        [name appendString:[NSStringFromSelector(@selector(isKeyWindow)) substringFromIndex:2]];

        m = class_getInstanceMethod(self, @selector(_cASBA));
        class_addMethod(self, NSSelectorFromString(name), method_getImplementation(m), method_getTypeEncoding(m));
    }
}

//_canAffectStatusBarAppearance
- (BOOL)_cASBA {
    return NO;
}

//_canBecomeKeyWindow
- (BOOL)_cBKW {
    return NO;
}
#endif

- (UIWindow *)overlayWindow {
    return self;
}

@end

__attribute__((visibility("hidden")))
@interface UIWindow (TDNTouchVisualizerForwarding)
@end
@implementation UIWindow (TDNTouchVisualizerForwarding)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      Method m1 = class_getInstanceMethod(self, @selector(sendEvent:));
      Method m2 = class_getInstanceMethod(self, @selector(__tdn_vis_sendEvent:));
      method_exchangeImplementations(m1, m2);
    });
}

- (void)__tdn_vis_sendEvent:(UIEvent *)event {
    if ([self isKindOfClass:[_TDNSceneTouchVisualizerWindow class]]) {
        return;
    }

    if (self.windowScene.tdn_touchVisualizerEnabled) {
        [self.windowScene.tdn_touchVisualizerWindow sendEvent:event];
    }

    [self __tdn_vis_sendEvent:event];
}

@end

@implementation UIWindowScene (TDNTouchVisualizer)

- (TDNTouchVisualizerWindow *)tdn_touchVisualizerWindow {
    TDNTouchVisualizerWindow *rv = objc_getAssociatedObject(self, TDNTouchVisualizerWindowKey);

    NSString *processName = [[NSProcessInfo processInfo] processName];
    if (rv == nil && [processName isEqualToString:@"SpringBoard"]) {
        rv = [_TDNSceneTouchVisualizerWindow new];
        rv.windowLevel = CGFLOAT_MAX;
        rv.backgroundColor = [UIColor.greenColor colorWithAlphaComponent:0.0];
        rv.hidden = YES;
        rv.userInteractionEnabled = NO;
        rv.frame = UIScreen.mainScreen.bounds;
        rv.windowScene = self;

        objc_setAssociatedObject(self, TDNTouchVisualizerWindowKey, rv, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return rv;
}

- (void)setTdn_touchVisualizerEnabled:(BOOL)tdn_touchVisualizerEnabled {
    TDNTouchVisualizerWindow *window = self.tdn_touchVisualizerWindow;
    window.touchVisualizationEnabled = tdn_touchVisualizerEnabled;
    window.hidden = tdn_touchVisualizerEnabled == NO;
}

- (BOOL)tdn_touchVisualizerEnabled {
    TDNTouchVisualizerWindow *window = self.tdn_touchVisualizerWindow;
    return window != nil && !window.hidden && window.touchVisualizationEnabled;
}

@end
