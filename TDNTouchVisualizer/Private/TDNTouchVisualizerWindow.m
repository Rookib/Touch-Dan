//
//  TDNTouchVisualizerWindow.m
//  TouchVisualizer
//
//  Created by Joe Blau on 3/22/14.
//  Copyright (c) 2014 conopsys. All rights reserved.
//

#import "TDNOverlayVisualizerWindow.h"
#import "TDNTouchImageFactory.h"
#import "TDNTouchImageView.h"

#import <CoreGraphics/CoreGraphics.h>
#import <TDNTouchVisualizer/TDNTouchConfig.h>
#import <TDNTouchVisualizer/TDNTouchVisualizerWindow.h>

#import "TouchDan-Swift.h"

static const NSTimeInterval TOUCH_VISUALIZER_ZERO_DELAY = 0.0;
static const NSTimeInterval TOUCH_VISUALIZER_WINDOW_REMOVE_DELAY = 6.0;

@interface UIWindow (Private)
- (UIInterfaceOrientation)_windowInterfaceOrientation;
@end

@interface FBSOrientationUpdate : NSObject
- (unsigned long long)sequenceNumber;
- (UIInterfaceOrientation)orientation;
@end

@interface FBSOrientationObserver : NSObject
- (void)setHandler:(void (^)(FBSOrientationUpdate *))handler;
- (void)invalidate;
@end

__attribute__((visibility("hidden")))
@interface TDNTouchVisualizerWindow ()

@property(nonatomic, strong) UIWindow *overlayWindow;
@property(nonatomic, assign) BOOL fingerTipRemovalScheduled;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) NSUInteger activeTouchCount;

@property(nonatomic, strong) UIImage *touchImage;
@property(nonatomic, strong) UIImage *rippleImage;

@end

@implementation TDNTouchVisualizerWindow {
    FBSOrientationObserver *_orientationObserver;
    unsigned long long _globalSequenceNumber;
    UIInterfaceOrientation _globalInterfaceOrientation;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame
        touchVisualizationEnabled:YES
                 quickPathEnabled:NO
                     morphEnabled:NO
                  trackingEnabled:NO
                    contactConfig:nil
                     rippleConfig:nil];
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene {
    self = [self initWithFrame:windowScene.coordinateSpace.bounds];
    if (self) {
        self.windowScene = windowScene;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
    touchVisualizationEnabled:(BOOL)touchVisualizationEnabled
             quickPathEnabled:(BOOL)quickPathEnabled
                 morphEnabled:(BOOL)morphEnabled
              trackingEnabled:(BOOL)trackingEnabled
                contactConfig:(nullable TDNTouchConfig *)contactConfig
                 rippleConfig:(nullable TDNTouchConfig *)rippleConfig {
    self = [super initWithFrame:frame];
    if (self) {
        _quickPathEnabled = quickPathEnabled;
        _morphEnabled = morphEnabled;
        _trackingEnabled = trackingEnabled;
        _touchVisualizationEnabled = touchVisualizationEnabled;
        _touchContactConfig = contactConfig ?: [TDNTouchConfig touchConfig];
        _touchRippleConfig = rippleConfig ?: [TDNTouchConfig rippleConfig];
        _orientationObserver = [[FBSOrientationObserver alloc] init];

        __weak typeof(self) weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *orientationUpdate) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (strongSelf != nil && orientationUpdate.sequenceNumber > strongSelf->_globalSequenceNumber) {
              strongSelf->_globalSequenceNumber = orientationUpdate.sequenceNumber;
              strongSelf->_globalInterfaceOrientation = orientationUpdate.orientation;
          }
        }];

        [self reloadRootViewController];
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    if ([_orientationObserver respondsToSelector:@selector(invalidate)]) {
        [_orientationObserver invalidate];
    }
}

- (void)reloadRootViewController {
    if (self.quickPathEnabled && !self.rootViewController) {
        self.rootViewController = [[TDNQuickPathViewController alloc] initWithNibName:nil bundle:nil];
    }
    if (!self.quickPathEnabled && self.rootViewController) {
        self.rootViewController = nil;
    }
}

- (void)setQuickPathEnabled:(BOOL)quickPathEnabled {
    if (_quickPathEnabled == quickPathEnabled) {
        return;
    }
    if (!quickPathEnabled) {
        [self tdn_endAllQuickPathTouches];
    }
    _quickPathEnabled = quickPathEnabled;
    [self reloadRootViewController];
}

- (void)setMorphEnabled:(BOOL)morphEnabled {
    _morphEnabled = morphEnabled;
    if (!morphEnabled) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)setTouchVisualizationEnabled:(BOOL)touchVisualizationEnabled {
    _touchVisualizationEnabled = touchVisualizationEnabled;
    if (!touchVisualizationEnabled) {
        [self resetTouchVisualization];
    }
}

- (void)resetTouchVisualization {
    self.activeTouchCount = 0;
    [self.timer invalidate];
    self.timer = nil;
    [self tdn_endAllQuickPathTouches];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                            selector:@selector(removeInactiveFingerTips)
                                              object:nil];
    self.fingerTipRemovalScheduled = NO;

    // The scene subclass draws in itself; do not allocate an overlay during cleanup.
    UIWindow *overlay = _overlayWindow ?: self;
    for (UIView *view in overlay.subviews.copy) {
        if ([view isKindOfClass:TDNTouchImageView.class]) {
            [NSObject cancelPreviousPerformRequestsWithTarget:view
                                                    selector:@selector(removeFromSuperview)
                                                      object:nil];
            [view.layer removeAllAnimations];
            [view removeFromSuperview];
        }
    }
}

- (void)setTouchContactConfig:(TDNTouchConfig *)touchContactConfig {
    _touchContactConfig = touchContactConfig;
    _touchImage = nil;
}

- (void)setTouchRippleConfig:(TDNTouchConfig *)touchRippleConfig {
    _touchRippleConfig = touchRippleConfig;
    _rippleImage = nil;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (self.traitCollection.userInterfaceStyle == previousTraitCollection.userInterfaceStyle) {
        return;
    }

    _touchImage = nil;
    _rippleImage = nil;
}

#pragma mark - Touch / Ripple and Images

- (UIImage *)touchImage {
    if (_touchImage == nil) {
        _touchImage = [TDNTouchImageFactory imageWithTouchConfig:self.touchContactConfig];
    }

    return _touchImage;
}

- (UIImage *)rippleImage {
    if (_rippleImage == nil) {
        _rippleImage = [TDNTouchImageFactory imageWithTouchConfig:self.touchRippleConfig];
    }

    return _rippleImage;
}

#pragma mark - Active

- (BOOL)anyScreenIsMirrored {
    if ([UIScreen instancesRespondToSelector:@selector(mirroredScreen)] == NO) {
        return NO;
    }

    for (UIScreen *screen in UIScreen.screens) {
        if (screen.mirroredScreen != nil) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - UIWindow overrides

- (CGPoint)locationOfTouch:(UITouch *)touch {
    UIInterfaceOrientation o = [self _windowInterfaceOrientation];
    UIWindow *overlayWindow = self.overlayWindow;
    CGRect fixedSpace = overlayWindow.screen.fixedCoordinateSpace.bounds;
    CGFloat fixedWidth = CGRectGetWidth(fixedSpace);
    CGFloat fixedHeight = CGRectGetHeight(fixedSpace);
    CGPoint a = [touch locationInView:nil];
    CGPoint b = a;
    switch (o) {
    case UIInterfaceOrientationPortrait:
        break;
    case UIInterfaceOrientationPortraitUpsideDown:
        a.x = fixedWidth - b.x;
        a.y = fixedHeight - b.y;
        break;
    case UIInterfaceOrientationLandscapeLeft:
        a.x = fixedHeight - b.y;
        a.y = b.x;
        break;
    case UIInterfaceOrientationLandscapeRight:
        a.x = b.y;
        a.y = fixedWidth - b.x;
        break;
    default:
        break;
    }
    return a;
}

- (CGAffineTransform)coordinateTransform {
    CGAffineTransform affineTransform = CGAffineTransformIdentity;
    UIInterfaceOrientation windowOrientation = [self _windowInterfaceOrientation];
    switch (windowOrientation) {
    case UIInterfaceOrientationPortrait:
        break;
    case UIInterfaceOrientationPortraitUpsideDown:
        affineTransform = CGAffineTransformConcat(affineTransform, CGAffineTransformMakeRotation(M_PI));
        break;
    case UIInterfaceOrientationLandscapeLeft:
        affineTransform = CGAffineTransformConcat(affineTransform, CGAffineTransformMakeRotation(M_PI_2));
        break;
    case UIInterfaceOrientationLandscapeRight:
        affineTransform = CGAffineTransformConcat(affineTransform, CGAffineTransformMakeRotation(-M_PI_2));
        break;
    default:
        break;
    }
    UIInterfaceOrientation orientation = self->_globalInterfaceOrientation;
    switch (orientation) {
    case UIInterfaceOrientationPortrait:
        break;
    case UIInterfaceOrientationPortraitUpsideDown:
        affineTransform = CGAffineTransformConcat(affineTransform, CGAffineTransformMakeRotation(M_PI));
        break;
    case UIInterfaceOrientationLandscapeLeft:
        affineTransform = CGAffineTransformConcat(affineTransform, CGAffineTransformMakeRotation(-M_PI_2));
        break;
    case UIInterfaceOrientationLandscapeRight:
        affineTransform = CGAffineTransformConcat(affineTransform, CGAffineTransformMakeRotation(M_PI_2));
        break;
    default:
        break;
    }
    return affineTransform;
}

- (void)tdn_sendQuickPathEvent:(UIEvent *)event {
    if (!self.touchVisualizationEnabled || !self.quickPathEnabled) {
        return;
    }
    [super tdn_sendQuickPathEvent:event];
}

- (void)sendTouchEvent:(UIEvent *)event {
    if (!self.touchVisualizationEnabled) {
        return;
    }

    NSSet<UITouch *> *touches = event.allTouches;
    NSUInteger activeTouchCount = 0;
    for (UITouch *touch in touches) {
        if (touch.type == UITouchTypeDirect &&
            (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved ||
             touch.phase == UITouchPhaseStationary)) {
            activeTouchCount++;
        }
    }
    self.activeTouchCount = activeTouchCount;

    CGAffineTransform coordinateTransform = self.coordinateTransform;
    for (UITouch *touch in touches) {

        if (touch.type != UITouchTypeDirect) {
            continue;
        }

        switch (touch.phase) {
        case UITouchPhaseRegionEntered:
        case UITouchPhaseRegionMoved:
        case UITouchPhaseRegionExited:
            continue;
        default:
            break;
        }

        CGPoint newCenter = [self locationOfTouch:touch];
        TDNTouchImageView *touchView = (TDNTouchImageView *)[self.overlayWindow viewWithTag:touch.hash];

        CGAffineTransform newTransform;
        if (self.touchContactConfig.shouldAutoRotate && touchView != nil) {
            CGPoint previousCenter = touchView.center;
            CGFloat distance = sqrt(pow(newCenter.x - previousCenter.x, 2) + pow(newCenter.y - previousCenter.y, 2));
            if (distance > 1) {
                // Use new angle to rotate
                CGFloat radians = atan2(newCenter.y - previousCenter.y, newCenter.x - previousCenter.x) + M_PI_2;
                newTransform = CGAffineTransformRotate(coordinateTransform, radians);
            } else {
                // Use previous angle to rotate
                CGAffineTransform previousTransform = touchView.transform;
                CGFloat radians = atan2(previousTransform.b, previousTransform.a);
                newTransform = CGAffineTransformRotate(coordinateTransform, radians);
            }
        } else {
            // No rotation
            newTransform = coordinateTransform;
        }

        switch (touch.phase) {
        case UITouchPhaseBegan:
        case UITouchPhaseMoved: {
            [self _handleTouchMoved:touch inView:touchView toCenter:newCenter withTransform:newTransform];
        }
        case UITouchPhaseStationary: {
            [self _handleTouchStationary:touch
                                  inView:touchView
                                toCenter:newCenter
                           withTransform:newTransform
                              coordinate:coordinateTransform];
            break;
        }
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled: {
            // Do not create a new marker/timer for an already-ended, unseen touch.
            if (touchView != nil) {
                [self _handleTouchMoved:touch inView:touchView toCenter:newCenter withTransform:newTransform];
                [self _handleTouchStationary:touch
                                      inView:touchView
                                    toCenter:newCenter
                               withTransform:newTransform
                                  coordinate:coordinateTransform];
            }
            [self _removeFingerTipWithHash:touch.hash animated:YES];
            break;
        }
        default:
            break;
        }
    }

    if (self.activeTouchCount == 0) {
        [self.timer invalidate];
        self.timer = nil;
    }
    [self _scheduleFingerTipRemoval];
}

- (void)_handleTouchMoved:(UITouch *)touch
                   inView:(UIView *)touchView
                 toCenter:(CGPoint)newCenter
            withTransform:(CGAffineTransform)newTransform {

    if (self.trackingEnabled && touchView != nil) {
        TDNTouchImageView *rippleView = [[TDNTouchImageView alloc] initWithImage:self.rippleImage];
        [self.overlayWindow addSubview:rippleView];

        rippleView.alpha = self.touchRippleConfig.alpha;
        rippleView.center = newCenter;
        rippleView.transform = newTransform;

        CGFloat fadeDuration = self.touchRippleConfig.fadeDuration;
        [UIView animateWithDuration:fadeDuration
            delay:TOUCH_VISUALIZER_ZERO_DELAY
            options:UIViewAnimationOptionCurveEaseIn
            animations:^{
                rippleView.alpha = 0.0;
                CGFloat newRadius =
                    _trackingEnabled ? self.touchRippleConfig.radius - 1.0 : self.touchRippleConfig.radius;
                CGRect newFrame = CGRectInset(rippleView.frame, newRadius, newRadius);
                CGFloat newScale = newFrame.size.width / rippleView.frame.size.width;
                rippleView.transform = CGAffineTransformScale(rippleView.transform, newScale, newScale);
            }
            completion:^(BOOL finished) {
                [rippleView removeFromSuperview];
            }];
    }
}

- (void)_handleTouchStationary:(UITouch *)touch
                        inView:(TDNTouchImageView *)touchView
                      toCenter:(CGPoint)newCenter
                 withTransform:(CGAffineTransform)newTransform
                    coordinate:(CGAffineTransform)coordinateTransform {

    touchView.transform = newTransform;

    if (touch.phase != UITouchPhaseStationary && touchView != nil && touchView.isFadingOut) {
        if (self.timer.userInfo == touchView) {
            [self.timer invalidate];
            self.timer = nil;
        }
        [touchView removeFromSuperview];
        touchView = nil;
    }

    if (touchView == nil && touch.phase != UITouchPhaseStationary) {
        touchView = [[TDNTouchImageView alloc] initWithImage:self.touchImage];
        touchView.transform = coordinateTransform;
        [self.overlayWindow addSubview:touchView];

        if (self.morphEnabled) {
            if (self.timer) {
                [self.timer invalidate];
            }

            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.touchContactConfig.morphDelay
                                                            target:self
                                                        selector:@selector(performMorphWithTouchView:)
                                                        userInfo:touchView
                                                            repeats:YES];
        }
    }

    if (!touchView.isFadingOut) {
        touchView.alpha = self.touchContactConfig.alpha;
        touchView.center = newCenter;
        touchView.tag = touch.hash;
        touchView.timestamp = touch.timestamp;
        touchView.shouldAutomaticallyRemoveAfterTimeout =
            [self shouldAutomaticallyRemoveFingerTipForTouch:touch];
    }
}

- (BOOL)hasAnyTouch {
    return self.activeTouchCount > 0;
}

- (UIWindow *)overlayWindow {
    if (_overlayWindow == nil) {
        _overlayWindow = [[TDNOverlayVisualizerWindow alloc] initWithFrame:self.frame];
        _overlayWindow.userInteractionEnabled = NO;
        _overlayWindow.windowLevel = CGFLOAT_MAX;
        _overlayWindow.backgroundColor = UIColor.clearColor;
        _overlayWindow.hidden = NO;
        _overlayWindow.windowScene = self.windowScene;
    }

    return _overlayWindow;
}

#pragma mark - Private

- (void)_scheduleFingerTipRemoval {
    if (self.fingerTipRemovalScheduled == YES) {
        return;
    }

    self.fingerTipRemovalScheduled = YES;
    [self performSelector:@selector(removeInactiveFingerTips) withObject:nil afterDelay:0.1];
}

- (void)removeInactiveFingerTips {
    self.fingerTipRemovalScheduled = NO;

    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    BOOL needsRemovalCheck = NO;

    for (TDNTouchImageView *touchView in self.overlayWindow.subviews) {
        if ([touchView isKindOfClass:TDNTouchImageView.class] == NO) {
            continue;
        }

        if (touchView.shouldAutomaticallyRemoveAfterTimeout &&
            now > touchView.timestamp + TOUCH_VISUALIZER_WINDOW_REMOVE_DELAY) {
            [self _removeFingerTipWithHash:touchView.tag animated:YES];
        }
        if (touchView.shouldAutomaticallyRemoveAfterTimeout && !touchView.isFadingOut) {
            needsRemovalCheck = YES;
        }
    }

    // The QuickPath hosting view can remain forever; only live markers need polling.
    // Fading markers and ripples already have their own completion/removal callbacks.
    if (needsRemovalCheck) {
        [self _scheduleFingerTipRemoval];
    }
}

- (void)_removeFingerTipWithHash:(NSUInteger)hash animated:(BOOL)animated {
    TDNTouchImageView *touchView = (TDNTouchImageView *)[self.overlayWindow viewWithTag:hash];
    if (touchView != nil && self.timer.userInfo == touchView) {
        [self.timer invalidate];
        self.timer = nil;
    }
    if (touchView == nil || touchView.isFadingOut) {
        return;
    }

    BOOL animationsWereEnabled = [UIView areAnimationsEnabled];

    dispatch_block_t animations = ^{
      touchView.alpha = 0.0;
      touchView.transform = CGAffineTransformScale(touchView.transform, self.touchContactConfig.liftScale,
                                                   self.touchContactConfig.liftScale);
    };

    if (animated) {
        [UIView setAnimationsEnabled:YES];
        [UIView animateWithDuration:self.touchContactConfig.fadeDuration animations:animations];
        [UIView setAnimationsEnabled:animationsWereEnabled];
    } else {
        animations();
    }

    touchView.fadingOut = YES;
    [touchView performSelector:@selector(removeFromSuperview)
                    withObject:nil
                    afterDelay:self.touchContactConfig.fadeDuration];
}

- (BOOL)shouldAutomaticallyRemoveFingerTipForTouch:(UITouch *)touch {
    return YES;
}

- (void)performMorphWithTouchView:(NSTimer *)timer {
    TDNTouchImageView *touchView = timer.userInfo;
    if (timer != self.timer || !self.morphEnabled || !self.touchVisualizationEnabled ||
        ![self hasAnyTouch] || touchView.superview == nil || touchView.isFadingOut) {
        [timer invalidate];
        if (timer == self.timer) self.timer = nil;
        return;
    }
    NSTimeInterval morphDuration = self.touchContactConfig.morphDuration;

    // Start
    CGAffineTransform transform = touchView.transform;
    touchView.transform = CGAffineTransformScale(transform, 1, 1);
    [UIView animateWithDuration:morphDuration / 4
        delay:TOUCH_VISUALIZER_ZERO_DELAY
        options:0
        animations:^{
          // End
          touchView.transform = CGAffineTransformScale(transform, 1, 1.2);
        }
        completion:^(BOOL finished) {
          if (!finished || !self.morphEnabled || touchView.superview == nil || touchView.isFadingOut) return;
          [UIView animateWithDuration:morphDuration / 4
              delay:TOUCH_VISUALIZER_ZERO_DELAY
              options:0
              animations:^{
                // End
                touchView.transform = CGAffineTransformScale(transform, 1.2, 0.9);
              }
              completion:^(BOOL finished) {
                if (!finished || !self.morphEnabled || touchView.superview == nil || touchView.isFadingOut) return;
                [UIView animateWithDuration:morphDuration / 4
                    delay:TOUCH_VISUALIZER_ZERO_DELAY
                    options:0
                    animations:^{
                      // End
                      touchView.transform = CGAffineTransformScale(transform, 0.9, 0.9);
                    }
                    completion:^(BOOL finished) {
                      if (!finished || !self.morphEnabled || touchView.superview == nil || touchView.isFadingOut) return;
                      [UIView animateWithDuration:morphDuration / 4
                          delay:TOUCH_VISUALIZER_ZERO_DELAY
                          options:0
                          animations:^{
                            // End
                            touchView.transform = CGAffineTransformScale(transform, 1, 1);
                          }
                          completion:^(BOOL finished) {
                            if (!finished || !self.morphEnabled || touchView.superview == nil || touchView.isFadingOut) return;
                            // If there are no touches, remove this morping touch
                            if (![self hasAnyTouch]) {
                                [touchView removeFromSuperview];
                            }
                          }];
                    }];
              }];
        }];
}

+ (BOOL)_isSystemWindow {
    return YES;
}

- (BOOL)_ignoresHitTest {
    return YES;
}

- (BOOL)_shouldCreateContextAsSecure {
    return YES;
}

@end
