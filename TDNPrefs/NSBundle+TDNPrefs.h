#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface NSBundle (TouchDan)

@property(class, nonatomic, readonly) NSBundle *tdn_supportBundle;
@property(class, nonatomic, readonly) NSString *tdn_packageVersion;

+ (UIImage *)tdn_fillImageNamed:(NSString *)name;
+ (NSString *_Nullable)tdn_saveFillImageWithPath:(NSString *)path;
+ (NSString *_Nullable)tdn_saveFillImageWithImage:(UIImage *)image;
+ (BOOL)tdn_removeUnusedFillImagesKeeping:(NSString *)name NS_SWIFT_NAME(tdn_removeUnusedFillImages(keeping:));
+ (BOOL)tdn_removeAllFillImages;

@end

NS_ASSUME_NONNULL_END
