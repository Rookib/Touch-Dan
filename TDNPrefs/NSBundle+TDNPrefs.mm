#import "NSBundle+TDNPrefs.h"

#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUUID.h>
#import <HBLog.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#import "TDNPaths.h"

static NSString *TDNCachedImagePath;
static NSDate *TDNCachedImageDate;
static NSNumber *TDNCachedImageSize;
static UIImage *TDNCachedImage;
static NSString *const TDNTemporaryImagePrefix = @".touchdan-tmp-";

static BOOL TDNIsImageExtension(NSString *extension) {
    if (extension.length == 0 || extension.length > 10) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
    return [extension rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static BOOL TDNIsManagedImageName(NSString *name) {
    if (name.length == 0 || ![name isEqualToString:name.lastPathComponent] || name.isAbsolutePath) return NO;
    return TDNIsImageExtension(name.pathExtension) &&
        [[NSUUID alloc] initWithUUIDString:name.stringByDeletingPathExtension] != nil;
}

static BOOL TDNIsTemporaryImageName(NSString *name) {
    return [name hasPrefix:TDNTemporaryImagePrefix] &&
        [[NSUUID alloc] initWithUUIDString:[name substringFromIndex:TDNTemporaryImagePrefix.length]] != nil;
}

static NSString *TDNImageRoot(void) {
    NSString *root = TDNJailbreakPath(@"/var/mobile/Library/Touch-Dan");
    return root.length > 1 && root.isAbsolutePath ? root : nil;
}

static BOOL TDNEnsureImageRoot(NSString *root) {
    if (root.length == 0) return NO;
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager createDirectoryAtPath:root withIntermediateDirectories:YES
                           attributes:@{NSFilePosixPermissions: @0700} error:nil]) return NO;
    struct stat info;
    return lstat(root.fileSystemRepresentation, &info) == 0 && S_ISDIR(info.st_mode);
}

static void TDNClearImageCache(void) {
    TDNCachedImagePath = nil;
    TDNCachedImageDate = nil;
    TDNCachedImageSize = nil;
    TDNCachedImage = nil;
}

static NSString *TDNWriteImageData(NSData *data, NSString *extension) {
    NSString *root = TDNImageRoot();
    if (data.length == 0 || !TDNEnsureImageRoot(root)) return nil;
    if (!TDNIsImageExtension(extension)) extension = @"img";

    // Every output, including the temporary file, stays in this validated directory.
    int directory = open(root.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return nil;
    NSString *name = [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, extension];
    NSString *temporaryName = [TDNTemporaryImagePrefix stringByAppendingString:NSUUID.UUID.UUIDString];
    int output = openat(directory, temporaryName.fileSystemRepresentation,
                        O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (output < 0) {
        close(directory);
        return nil;
    }
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger remaining = data.length;
    BOOL success = YES;
    while (remaining > 0) {
        ssize_t count = write(output, bytes, MIN(remaining, (NSUInteger)(1024 * 1024)));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) { success = NO; break; }
        bytes += count;
        remaining -= (NSUInteger)count;
    }
    if (close(output) != 0) success = NO;
    if (success) {
        success = renameat(directory, temporaryName.fileSystemRepresentation,
                           directory, name.fileSystemRepresentation) == 0;
    }
    if (!success) unlinkat(directory, temporaryName.fileSystemRepresentation, 0);
    close(directory);
    return success ? name : nil;
}

static BOOL TDNCleanImageFiles(NSString *keepName, BOOL removeAll) {
    NSString *root = TDNImageRoot();
    if (root.length == 0) return NO;
    struct stat info;
    if (lstat(root.fileSystemRepresentation, &info) != 0) return errno == ENOENT;
    if (!S_ISDIR(info.st_mode)) return NO;
    NSFileManager *manager = NSFileManager.defaultManager;
    NSArray<NSString *> *names = [manager contentsOfDirectoryAtPath:root error:nil];
    if (!names) return NO;
    int directory = open(root.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return NO;
    BOOL success = YES;
    for (NSString *name in names) {
        BOOL temporary = TDNIsTemporaryImageName(name);
        if ((!TDNIsManagedImageName(name) && !temporary) || [name isEqualToString:keepName]) continue;
        struct stat entry;
        if (fstatat(directory, name.fileSystemRepresentation, &entry, AT_SYMLINK_NOFOLLOW) != 0) {
            if (errno != ENOENT) success = NO;
            continue;
        }
        // Never recurse into unexpected directories. A symlink itself can be unlinked safely.
        if (!S_ISREG(entry.st_mode) && !S_ISLNK(entry.st_mode)) continue;
        // Leave another in-flight save alone; reap only abandoned staging files.
        if (temporary && !removeAll && [NSDate.date timeIntervalSince1970] - entry.st_mtime < 600) continue;
        if (unlinkat(directory, name.fileSystemRepresentation, 0) != 0 && errno != ENOENT) success = NO;
    }
    close(directory);
    if (removeAll && success) {
        NSArray *remaining = [manager contentsOfDirectoryAtPath:root error:nil];
        if (!remaining) return NO;
        if (remaining.count == 0) success = [manager removeItemAtPath:root error:nil];
    }
    return success;
}

@implementation NSBundle (TouchDan)

+ (NSBundle *)tdn_supportBundle {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"TDNPrefs"
                                                                  ofType:@"bundle"];
      NSString *aliasBundlePath;
      aliasBundlePath = TDNJailbreakPath(@"/Library/PreferenceBundles/TDNPrefs.bundle");
      NSString *bundlePath = tweakBundlePath ?: aliasBundlePath;
      if (bundlePath.length > 0) bundle = [NSBundle bundleWithPath:bundlePath];
#if TARGET_IPHONE_SIMULATOR
      if (!bundle) {
          aliasBundlePath = @"/opt/simject/PreferenceBundles/TDNPrefs.bundle";
          bundle = [NSBundle bundleWithPath:aliasBundlePath];
      }
#endif
      NSLog(@"[TouchDan] Support bundle path: %@", [bundle bundlePath]);
    });
    return bundle;
}

+ (NSString *)tdn_packageVersion {
    return @PACKAGE_VERSION;
}

+ (UIImage *)tdn_defaultFillImage {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      image = [UIImage imageNamed:@"default"
                       inBundle:[self tdn_supportBundle]
  compatibleWithTraitCollection:nil];
    });
    return image;
}

+ (UIImage *)tdn_fillImageNamed:(NSString *)name {
    if (!name || [name isEqualToString:@"default.png"]) {
        @synchronized(NSBundle.class) { TDNClearImageCache(); }
        return [self tdn_defaultFillImage];
    }
    NSString *root = TDNImageRoot();
    if (!root || !TDNIsManagedImageName(name)) {
        @synchronized(NSBundle.class) { TDNClearImageCache(); }
        return [self tdn_defaultFillImage];
    }
    NSString *imagePath = [root stringByAppendingPathComponent:name];
    struct stat info;
    if (lstat(imagePath.fileSystemRepresentation, &info) != 0 || !S_ISREG(info.st_mode)) {
        @synchronized(NSBundle.class) { TDNClearImageCache(); }
        return [self tdn_defaultFillImage];
    }
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:imagePath error:nil];
    NSDate *modified = attributes[NSFileModificationDate];
    NSNumber *size = attributes[NSFileSize];
    @synchronized(NSBundle.class) {
        if ([imagePath isEqualToString:TDNCachedImagePath] &&
            [modified isEqualToDate:TDNCachedImageDate] && [size isEqualToNumber:TDNCachedImageSize] && TDNCachedImage) {
            return TDNCachedImage;
        }
        TDNCachedImagePath = imagePath;
        TDNCachedImageDate = modified;
        TDNCachedImageSize = size;
        TDNCachedImage = [UIImage imageWithContentsOfFile:imagePath];
        return TDNCachedImage ?: [self tdn_defaultFillImage];
    }
}

+ (NSString *)tdn_saveFillImageWithPath:(NSString *)path {
    if (path.length == 0 || !path.isAbsolutePath) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
    return TDNWriteImageData(data, path.pathExtension);
}

+ (NSString *)tdn_saveFillImageWithImage:(UIImage *)image {
    return image ? TDNWriteImageData(UIImagePNGRepresentation(image), @"png") : nil;
}

+ (BOOL)tdn_removeUnusedFillImagesKeeping:(NSString *)name {
    if (![name isEqualToString:@"default.png"] && !TDNIsManagedImageName(name)) return NO;
    BOOL success = TDNCleanImageFiles(name, NO);
    @synchronized(NSBundle.class) {
        if (![TDNCachedImagePath.lastPathComponent isEqualToString:name]) TDNClearImageCache();
    }
    return success;
}

+ (BOOL)tdn_removeAllFillImages {
    BOOL success = TDNCleanImageFiles(nil, YES);
    if (success) {
        @synchronized(NSBundle.class) { TDNClearImageCache(); }
    }
    return success;
}

@end
