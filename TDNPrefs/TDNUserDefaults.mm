#import "TDNUserDefaults.h"
#import "TDNPaths.h"

#import <notify.h>

static NSString *const kDefaultsSuiteName = @"io.github.suckdrygod.touchdan";
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static NSString *const kRootHidePreferencesPath = @"/var/mobile/Library/Preferences/io.github.suckdrygod.touchdan.plist";
#endif

@implementation TDNUserDefaults {
    NSInteger _updateCount;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *_tdnPreferencesPath;
#endif
}

+ (TDNUserDefaults *)standardUserDefaults {
    static dispatch_once_t onceToken;
    static TDNUserDefaults *defaults = nil;
    dispatch_once(&onceToken, ^{
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
      // RootHide's own Bootstrap uses an absolute plist suite. Resolve it
      // explicitly rather than relying on cfprefsd's ordinary-domain redirect.
      // https://github.com/roothide/Bootstrap/blob/main/Bootstrap/NSUserDefaults%2BappDefaults.m
      NSString *path = TDNJailbreakPath(kRootHidePreferencesPath);
      if (path && ![[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent
                                            withIntermediateDirectories:YES attributes:nil error:nil]) {
          path = nil;
      }
      NSString *readOnlySuite = [kDefaultsSuiteName stringByAppendingString:@".readonly"];
      defaults = [[self alloc] initWithSuiteName:path ?: readOnlySuite];
      if (!defaults) {
          path = nil;
          defaults = [[self alloc] initWithSuiteName:readOnlySuite];
      }
      defaults->_tdnPreferencesPath = path;
#else
      defaults = [[self alloc] initWithSuiteName:kDefaultsSuiteName];
#endif
      defaults->_updateCount = 0;
      [defaults registerDefaults];
    });
    return defaults;
}

- (void)registerDefaults {
    [self registerDefaults:@{
        @"isEnabled" : @NO,
        @"isRecordingOnly" : @NO,

        @"fillColorString" : @"235,59,90,0.5",
        @"borderColorString" : @"235,59,90",

        @"alpha" : @0.5,
        @"fillSize" : @40.0,
        @"borderWidth" : @3.0,
        @"cornerRadius" : @30.0,
        @"animationDuration" : @0.3,
        @"liftScale" : @2.0,

        @"useQuickPathEffect" : @NO,
        @"quickPathFillColorString" : @"235,59,90,0.5",

        @"useMorphEffect" : @NO,
        @"useTrackingEffect" : @YES,
        @"trackingFillColorString" : @"235,59,90,0.2",
        @"trackingBorderColorString" : @"235,59,90,0.4",

        @"useImageEffect" : @NO,
        @"imageShouldAutoRotate" : @NO,
        @"imageFillName" : @"default.png",

        @"enableOverride" : @NO,
        @"disableOverride" : @NO,
        @"disableOverrideWhenRecording" : @NO,
    }];
}

- (void)beginUpdates {
    _updateCount++;
}

- (void)endUpdates {
    if (_updateCount > 0) {
        _updateCount--;
    }
    if (_updateCount == 0) {
        [self darwinNotify];
    }
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if (![self tdn_canPersistSettings]) return;
    [self beginUpdates];
    [super setObject:value forKey:key];
    if ([key isEqualToString:@"isEnabled"] || [key isEqualToString:@"isRecordingOnly"]) {
        [super setObject:@NO forKey:@"enableOverride"];
        [super setObject:@NO forKey:@"disableOverride"];
        [super setObject:@NO forKey:@"disableOverrideWhenRecording"];
    }
    [self endUpdates];
}

- (BOOL)tdn_canPersistSettings {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    // A failed or changed hidden root must never fall back to a normal domain.
    return _tdnPreferencesPath != nil &&
        [_tdnPreferencesPath isEqualToString:TDNJailbreakPath(kRootHidePreferencesPath)];
#else
    return YES;
#endif
}

// Route the scalar setters used by AppStorage through the same write guard.
- (void)setBool:(BOOL)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setInteger:(NSInteger)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setFloat:(float)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setDouble:(double)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setValue:(id)value forKey:(NSString *)key { [self setObject:value forKey:key]; }

- (void)removeObjectForKey:(NSString *)key {
    if (![self tdn_canPersistSettings]) return;
    [super removeObjectForKey:key];
}

- (void)resetToDefaultValues {
    if (![self tdn_canPersistSettings]) return;
    [self beginUpdates];
    for (NSString *key in self.dictionaryRepresentation.allKeys) {
        if ([key hasPrefix:@"_"]) {
            continue;
        }
        [self removeObjectForKey:key];
    }
    [self endUpdates];
}

- (void)darwinNotify {
    notify_post(TDN_NOTIFY_NAME);
}

+ (NSSet<NSString *> *)longScreenshotterKeys {
    static NSSet<NSString *> *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      keys = [NSSet setWithArray:@[
        @"com.sugarmo.ScrollClip.ScreenRecording",
        @"com.xcvzaq.imagejoin.ScrollRecord",
        @"com.abighead.stiiitch.Scrollshot",
        @"yang6wolf.Stitch.Recorder",
        @"com.wysdev.zeta.screenrecording",
        @"com.doukan.webscreenshot.stitch",
        @"com.tailor.screenshot.picsew.TailorBroadcastUploadExtension",
        @"com.zsp.scrolling.screenshots.extension",
        @"com.mind.stitch.ScrollRecorder",
        @"com.gendago.scroll-screenshot.-----",
        @"com.fan.scrollrecord.uploader",
        @"com.keyi.changjietu.luzhi",
      ]];
    });
    return keys;
}

@end
