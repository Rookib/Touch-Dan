#import <UIKit/UIKit.h>

#define tdnBool(key) [[TDNUserDefaults standardUserDefaults] boolForKey:key]
#define TDN_NOTIFY_NAME "io.github.suckdrygod.touchdan.reload-prefs"
#define TDN_COLOR [UIColor colorWithRed:235.0 / 255 green:59.0 / 255 blue:90.0 / 255 alpha:1.0]

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface TDNUserDefaults : NSUserDefaults

+ (NSSet<NSString *> *)longScreenshotterKeys;

@property(class, readonly, strong) TDNUserDefaults *standardUserDefaults;

- (void)beginUpdates;
- (void)endUpdates;

- (void)resetToDefaultValues;
- (void)darwinNotify;
- (BOOL)tdn_canPersistSettings;

@end

NS_ASSUME_NONNULL_END
