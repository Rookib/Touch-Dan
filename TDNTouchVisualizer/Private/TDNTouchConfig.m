//
//  TDNTouchConfig.m
//  TDNTouchVisualizer
//
//  Created by Joseph Blau on 12/2/17.
//  Copyright © 2017 conopsys. All rights reserved.
//

#import <TDNTouchVisualizer/TDNTouchConfig.h>

static const CGFloat TDNTouchConfigContactAlpha = 1.0;
static const CGFloat TDNTouchConfigRippleAlpha = 1.0;

static const NSTimeInterval TDNTouchConfigContactFadeDuration = 0.3;
static const NSTimeInterval TDNTouchConfigRippleFadeDuration = 0.2;

@implementation TDNTouchConfig

- (instancetype)init {
    self = [super init];

    if (self) {
        self.strokeColor = UIColor.labelColor;
        self.fillColor = UIColor.systemBackgroundColor;
        self.alpha = TDNTouchConfigContactAlpha;
        self.radius = 20.0;
        self.liftScale = 2.0;
        self.borderWidth = 3.0;
        self.cornerRadius = 20.0;
        self.morphDelay = 0.6;
        self.morphDuration = 0.4;
        self.fadeDuration = TDNTouchConfigContactFadeDuration;
        self.shouldAutoRotate = NO;
        self.fillImage = nil;
    }

    return self;
}

#pragma mark - Private

+ (TDNTouchConfig *)touchConfig {
    return [TDNTouchConfig new];
}

+ (TDNTouchConfig *)rippleConfig {
    TDNTouchConfig *rv = [TDNTouchConfig new];

    rv.strokeColor = UIColor.systemBackgroundColor;
    rv.fillColor = UIColor.systemBlueColor;
    rv.alpha = TDNTouchConfigRippleAlpha;
    rv.fadeDuration = TDNTouchConfigRippleFadeDuration;

    return rv;
}

@end
