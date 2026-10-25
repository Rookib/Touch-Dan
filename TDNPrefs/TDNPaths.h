#pragma once

#import <Foundation/Foundation.h>

// RootHide uses its public path API; ordinary Theos retains libroot support.
// Do not include libroot's internal header to bypass RootHide's migration check.
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#import <roothide.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syslimits.h>
#else
#import <libroot.h>
#endif

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)

static inline BOOL TDNPathIsAbsoluteAndUnambiguous(NSString * _Nullable path) {
    if (![path isKindOfClass:NSString.class] || path.length == 0 || !path.isAbsolutePath) return NO;
    // Check embedded NUL before asking Foundation for a filesystem encoding:
    // fileSystemRepresentation raises for strings that contain NUL characters.
    const char *utf8 = path.UTF8String;
    if (utf8 == NULL || strlen(utf8) >= PATH_MAX ||
        strlen(utf8) != [path lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) return NO;
    char bytes[PATH_MAX];
    if (![path getFileSystemRepresentation:bytes maxLength:sizeof(bytes)]) return NO;
    for (NSString *component in path.pathComponents) {
        if ([component isEqualToString:@"."] || [component isEqualToString:@".."]) return NO;
    }
    return YES;
}

static inline NSString * _Nullable TDNExistingCanonicalPath(NSString * _Nonnull path) {
    char resolved[PATH_MAX];
    return realpath(path.fileSystemRepresentation, resolved) ? [NSString stringWithUTF8String:resolved] : nil;
}

static inline BOOL TDNPathIsWithin(NSString * _Nonnull path, NSString * _Nullable root) {
    return root != nil && ([path isEqualToString:root] ||
                           [path hasPrefix:[root stringByAppendingString:@"/"]]);
}

// Resolve existing ancestors without treating a dangling symlink as a missing
// directory. New leaf components are appended only after a real directory exists.
static inline NSString * _Nullable TDNCanonicalPathAllowingMissingLeaf(NSString * _Nonnull path) {
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    NSString *ancestor = path;
    struct stat info;
    while (lstat(ancestor.fileSystemRepresentation, &info) != 0) {
        if (errno != ENOENT || [ancestor isEqualToString:@"/"]) return nil;
        [missing insertObject:ancestor.lastPathComponent atIndex:0];
        NSString *parent = ancestor.stringByDeletingLastPathComponent;
        if ([parent isEqualToString:ancestor] || parent.length == 0) return nil;
        ancestor = parent;
    }
    NSString *resolved = TDNExistingCanonicalPath(ancestor);
    if (resolved == nil) return nil;
    if (missing.count > 0 && (stat(resolved.fileSystemRepresentation, &info) != 0 || !S_ISDIR(info.st_mode))) return nil;
    for (NSString *component in missing) resolved = [resolved stringByAppendingPathComponent:component];
    return resolved;
}

#endif

// Returns nil on RootHide if resolution is unsafe. Callers must not fall back to
// the input path. Revalidate before each write/delete; this does not lock paths
// against a separate process changing symlinks after the check.
static inline NSString * _Nullable TDNJailbreakPath(NSString * _Nullable path) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!TDNPathIsAbsoluteAndUnambiguous(path)) return nil;
    NSString *rawRoot = jbroot(@"/");
    unsigned long long currentBrand = jbrand();
    if (!TDNPathIsAbsoluteAndUnambiguous(rawRoot) || [rawRoot isEqualToString:@"/"] || currentBrand == 0) return nil;
    NSString *root = TDNExistingCanonicalPath(rawRoot);
    NSString *rootName = [NSString stringWithFormat:@".jbroot-%016llX", currentBrand];
    struct stat info;
    if (root == nil || [root.lastPathComponent caseInsensitiveCompare:rootName] != NSOrderedSame ||
        stat(root.fileSystemRepresentation, &info) != 0 || !S_ISDIR(info.st_mode)) return nil;

    NSString *converted = jbroot(path);
    if (!TDNPathIsAbsoluteAndUnambiguous(converted) || [converted isEqualToString:path]) return nil;
    NSString *candidate = TDNCanonicalPathAllowingMissingLeaf(converted);
    if (candidate == nil) return nil;
    if (TDNPathIsWithin(candidate, root)) return candidate;

    // Official RootHide moves /var into a same-brand secondary AppGroup root.
    // Accept only its /var subtree and require its .jbroot link to point back.
    // https://github.com/roothide/Bootstrap/blob/main/Bootstrap/bootstrap.m
    NSString *varRoot = TDNExistingCanonicalPath([rawRoot stringByAppendingPathComponent:@"var"]);
    NSString *secondary = varRoot.stringByDeletingLastPathComponent;
    if (varRoot == nil || ![varRoot.lastPathComponent isEqualToString:@"var"] ||
        [secondary.lastPathComponent caseInsensitiveCompare:rootName] != NSOrderedSame ||
        stat(varRoot.fileSystemRepresentation, &info) != 0 || !S_ISDIR(info.st_mode)) return nil;
    NSString *backlink = TDNExistingCanonicalPath([secondary stringByAppendingPathComponent:@".jbroot"]);
    if (![backlink isEqualToString:root] || !TDNPathIsWithin(candidate, varRoot)) return nil;
    return candidate;
#else
    return JBROOT_PATH_NSSTRING(path);
#endif
}
