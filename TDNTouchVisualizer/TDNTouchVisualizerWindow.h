//
//  TDNTouchVisualizerWindow.h
//  TouchVisualizer
//
//  Created by Joe Blau on 3/22/14.
//  Copyright (c) 2014 conopsys. All rights reserved.
//
#import <TDNTouchVisualizer/TDNTouchConfig.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface TDNTouchVisualizerWindow : UIWindow

@property(nonatomic, getter=isTouchVisualizationEnabled) BOOL touchVisualizationEnabled;
@property(nonatomic, getter=isQuickPathEnabled) BOOL quickPathEnabled;
@property(nonatomic, getter=isMorphEnabled) BOOL morphEnabled;
@property(nonatomic, getter=isTrackingEnabled) BOOL trackingEnabled;

@property(nonatomic, strong) TDNTouchConfig *touchContactConfig;
@property(nonatomic, strong) TDNTouchConfig *touchRippleConfig;

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene;

- (instancetype)initWithFrame:(CGRect)frame
    touchVisualizationEnabled:(BOOL)touchVisualizationEnabled
             quickPathEnabled:(BOOL)quickPathEnabled
                 morphEnabled:(BOOL)morphEnabled
              trackingEnabled:(BOOL)trackingEnabled
                contactConfig:(nullable TDNTouchConfig *)contactConfig
                 rippleConfig:(nullable TDNTouchConfig *)rippleConfig NS_DESIGNATED_INITIALIZER;

- (void)sendTouchEvent:(UIEvent *)event;
- (BOOL)hasAnyTouch;
- (void)resetTouchVisualization;

@end

NS_ASSUME_NONNULL_END
