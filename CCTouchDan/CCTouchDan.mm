#import "CCTouchDan.h"

#import "TDNUserDefaults.h"

@implementation CCTouchDan {
    BOOL _gIsAnyScreenCaptured;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _gIsAnyScreenCaptured = [self isAnyScreenCaptured];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(screenCapturedDidChange:)
                                                   name:UIScreenCapturedDidChangeNotification
                                                 object:nil];
    }
    return self;
}

- (BOOL)isAnyScreenCaptured {
    BOOL isCaptured = NO;
    for (UIScreen *screen in UIScreen.screens) {
        if (screen.isCaptured) {
            isCaptured = YES;
            break;
        }
    }
    return isCaptured;
}

- (void)screenCapturedDidChange:(NSNotification *)notification {
    BOOL isAnyScreenCaptured = [self isAnyScreenCaptured];

    if (_gIsAnyScreenCaptured != isAnyScreenCaptured) {
        _gIsAnyScreenCaptured = isAnyScreenCaptured;

        if (isAnyScreenCaptured) {
            [self setSelected:YES forceEnable:NO];
        }

        [self refreshState];
    }
}

- (UIImage *)iconGlyph {
    return [UIImage imageNamed:@"icon"
                     inBundle:[NSBundle bundleForClass:[self class]]
compatibleWithTraitCollection:nil];
}

- (UIColor *)selectedColor {
    return TDN_COLOR;
}

- (BOOL)isSelected {
    if (!tdnBool(@"isEnabled")) {
        return NO;
    }

    if (_gIsAnyScreenCaptured) {
        return !tdnBool(@"disableOverrideWhenRecording");
    }

    if (tdnBool(@"isRecordingOnly")) {
        return tdnBool(@"enableOverride");
    }

    return !tdnBool(@"disableOverride");
}

- (void)setSelected:(BOOL)selected {
    [self setSelected:selected forceEnable:YES];
}

- (void)setSelected:(BOOL)selected forceEnable:(BOOL)forceEnable {
    TDNUserDefaults *defaults = [TDNUserDefaults standardUserDefaults];

    [defaults beginUpdates];

    if (forceEnable) {
        BOOL isEnabled = tdnBool(@"isEnabled");
        if (!isEnabled) {
            [defaults setBool:YES forKey:@"isEnabled"];
        }
    }

    if (_gIsAnyScreenCaptured) {
        [defaults setBool:!selected forKey:@"disableOverrideWhenRecording"];
    } else {
        [defaults setBool:selected forKey:@"enableOverride"];
        [defaults setBool:!selected forKey:@"disableOverride"];
    }

    [defaults endUpdates];
}

@end
