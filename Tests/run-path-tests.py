#!/usr/bin/env python3
"""Compile TDNPaths.h against public Theos headers and mock path providers.

These host tests use public headers, mock path providers, and real filesystem
fixtures for symlink checks. They do not access a device or emulate cfprefsd.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--theos", type=Path, default=Path.home() / "theos")
parser.add_argument("--roothide-theos", type=Path, default=Path.home() / "theos-roothide")
args = parser.parse_args()

source = r'''
#import <Foundation/Foundation.h>
#include <stdio.h>
#include "TDN_PATH_HEADER"

static NSString *prefix;
static NSString *lastInput;
static NSUInteger calls;

char *libroot_dyn_jbrootpath(const char *path, char *resolvedPath) {
    calls++;
    lastInput = [NSString stringWithUTF8String:path];
    snprintf(resolvedPath, PATH_MAX, "%s%s", prefix.UTF8String, path);
    return resolvedPath;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc != 3) return 2;
    prefix = [NSString stringWithUTF8String:argv[1]];
    NSArray<NSString *> *paths = @[
        @"/Library/PreferenceBundles/TDNPrefs.bundle",
        @"/var/mobile/Library/Touch-Dan"
    ];
    NSUInteger checks = 0;
    for (NSString *path in paths) {
        NSString *actual = TDNJailbreakPath(path);
        checks++;
        if (![actual isEqualToString:[prefix stringByAppendingString:path]]) return 3;
        checks++;
        if (![lastInput isEqualToString:path]) return 4;
    }
    prefix = @"/changed-provider-root";
    checks++;
    if (![TDNJailbreakPath(paths[0]) isEqualToString:[prefix stringByAppendingString:paths[0]]]) return 5;
    checks++;
    if (calls != 3) return 6;
    printf("PASS: %s — %lu path checks against public headers and mock provider.\n", argv[2], (unsigned long)checks);
  }
  return 0;
}
'''.replace('"TDN_PATH_HEADER"', json.dumps(str(ROOT / "TDNPrefs/TDNPaths.h")))

roothide_source = r'''
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>
#include "TDN_PATH_HEADER"

static NSString *prefix;
static NSString *forcedCandidate;
static unsigned long long brand = 0x0102030405060700ULL;
static NSUInteger mode;
static NSUInteger checks;
#define CHECK(test, label) do { checks++; if (!(test)) { fprintf(stderr, "FAIL: %s\n", label); return 1; } } while (0)

unsigned long long jbrand(void) { return brand; }
NSString * __attribute__((overloadable)) jbroot(NSString *path) {
    if (mode == 1) return path;
    if (mode == 2) return nil;
    if ([path isEqualToString:@"/"]) return prefix;
    if (mode == 3) return path;
    if (mode == 4) return @"relative/output";
    return forcedCandidate ?: [prefix stringByAppendingString:path];
}

int main(int argc, const char *argv[]) {
 @autoreleasepool {
    if (argc != 5) return 2;
    prefix = [NSString stringWithUTF8String:argv[1]];
    NSString *primary = prefix;
    NSString *secondary = [NSString stringWithUTF8String:argv[2]];
    NSString *outside = [NSString stringWithUTF8String:argv[3]];
    NSString *wrongSecondary = [NSString stringWithUTF8String:argv[4]];
    NSString *data = @"/var/mobile/Library/Touch-Dan";
    CHECK([TDNJailbreakPath(@"/Library/PreferenceBundles/TDNPrefs.bundle")
           isEqualToString:[primary stringByAppendingString:@"/Library/PreferenceBundles/TDNPrefs.bundle"]], "primary package resource");
    CHECK([TDNJailbreakPath(data) isEqualToString:[secondary stringByAppendingString:data]], "official secondary var symlinks");
    CHECK([TDNJailbreakPath(@"/private/var/mobile/Library/Touch-Dan")
           isEqualToString:[secondary stringByAppendingString:data]], "private var alias");
    CHECK([TDNJailbreakPath(@"/") isEqualToString:primary], "current primary root");
    CHECK([TDNJailbreakPath(@"/tmp/new-file") isEqualToString:[secondary stringByAppendingString:@"/var/tmp/new-file"]], "temporary path remains in hidden secondary root");
    CHECK(TDNJailbreakPath(nil) == nil, "nil input");
    CHECK(TDNJailbreakPath(@"") == nil, "empty input");
    CHECK(TDNJailbreakPath(@"var/mobile") == nil, "relative input");
    CHECK(TDNJailbreakPath(@"/Library/../var/mobile") == nil, "parent traversal input");
    unichar characters[] = {'/', 'x', 0, 'y'};
    CHECK(TDNJailbreakPath([NSString stringWithCharacters:characters length:4]) == nil, "embedded NUL input");
    mode = 1; CHECK(TDNJailbreakPath(data) == nil, "provider root falls back to real slash");
    mode = 2; CHECK(TDNJailbreakPath(data) == nil, "nil provider root");
    mode = 3; CHECK(TDNJailbreakPath(data) == nil, "provider returns unchanged destination");
    mode = 4; CHECK(TDNJailbreakPath(data) == nil, "relative provider destination");
    mode = 0;
    brand = 0; CHECK(TDNJailbreakPath(data) == nil, "missing active brand");
    brand = 1; CHECK(TDNJailbreakPath(data) == nil, "different active brand");
    brand = 0x0102030405060700ULL;
    prefix = [outside stringByAppendingPathComponent:primary.lastPathComponent];
    CHECK(TDNJailbreakPath(data) == nil, "nonexistent current root");
    prefix = outside; CHECK(TDNJailbreakPath(data) == nil, "ordinary directory cannot be root");
    prefix = primary;
    CHECK(TDNJailbreakPath(@"/Library/Escape/new") == nil, "symlink escapes primary root");
    CHECK(TDNJailbreakPath(@"/Library/Broken/new") == nil, "dangling symlink");
    CHECK(TDNJailbreakPath(@"/Library/Loop/new") == nil, "symlink loop");
    CHECK(TDNJailbreakPath(@"/var/mobile/Containers/new") == nil, "system-container mirror is not writable hidden data");
    CHECK([TDNJailbreakPath(@"/Library/Internal/new")
           isEqualToString:[primary stringByAppendingString:@"/Library/PreferenceBundles/new"]], "internal symlink remains inside primary");
    CHECK(TDNJailbreakPath(@"/var/mobile/Library/Escape/new") == nil, "symlink escapes secondary root");
    CHECK(TDNJailbreakPath(@"/Library/File/child") == nil, "file cannot be missing-directory ancestor");
    CHECK([TDNJailbreakPath(@"/Library/new/dir/file")
           isEqualToString:[primary stringByAppendingString:@"/Library/new/dir/file"]], "new nested path under verified ancestor");
    forcedCandidate = [primary stringByAppendingString:@"-neighbor/file"];
    CHECK(TDNJailbreakPath(data) == nil, "sibling name cannot pass root prefix check");
    forcedCandidate = nil;
    NSString *backlink = [secondary stringByAppendingPathComponent:@".jbroot"];
    if (unlink(backlink.fileSystemRepresentation) || symlink(outside.fileSystemRepresentation, backlink.fileSystemRepresentation)) return 2;
    CHECK(TDNJailbreakPath(data) == nil, "secondary with wrong backlink");
    if (unlink(backlink.fileSystemRepresentation) || symlink(primary.fileSystemRepresentation, backlink.fileSystemRepresentation)) return 2;
    NSString *varLink = [primary stringByAppendingPathComponent:@"private/var"];
    if (unlink(varLink.fileSystemRepresentation) || symlink([wrongSecondary stringByAppendingPathComponent:@"var"].fileSystemRepresentation, varLink.fileSystemRepresentation)) return 2;
    CHECK(TDNJailbreakPath(data) == nil, "secondary with wrong brand");
    if (unlink(varLink.fileSystemRepresentation) || symlink([secondary stringByAppendingPathComponent:@"var"].fileSystemRepresentation, varLink.fileSystemRepresentation)) return 2;
    CHECK([TDNJailbreakPath(data) isEqualToString:[secondary stringByAppendingString:data]], "provider revalidated after restored topology");
    printf("PASS: RootHide — %lu fail-closed checks using mocked APIs and real symlink fixtures.\n", (unsigned long)checks);
 }
 return 0;
}
'''.replace('"TDN_PATH_HEADER"', json.dumps(str(ROOT / "TDNPrefs/TDNPaths.h")))

cases = [
    ("rootful", args.theos, "", []),
    ("rootless", args.theos, "/var/jb", ["-DTHEOS_PACKAGE_SCHEME_ROOTLESS=1"]),
]
scratch = ROOT / ".theos"
scratch.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix="touch-dan-path-tests-", dir=scratch) as directory:
    directory = Path(directory)
    source_path = directory / "paths.mm"
    source_path.write_text(source)
    for name, theos, prefix, flags in cases:
        header = theos / "vendor/include" / ("roothide.h" if name == "roothide" else "libroot.h")
        if not header.is_file():
            raise FileNotFoundError(f"Required public Theos header missing: {header}")
        executable = directory / name
        subprocess.run([
            "xcrun", "--sdk", "macosx", "clang++", "-std=c++17", "-fobjc-arc", "-fblocks",
            "-Wall", "-Wextra", "-Werror", "-framework", "Foundation",
            "-I", str(theos / "vendor/include"), *flags, str(source_path), "-o", str(executable)
        ], check=True)
        subprocess.run([str(executable), prefix, name], check=True)

    primary = directory / "primary" / ".jbroot-0102030405060700"
    secondary = directory / "AppGroup" / primary.name
    outside = directory / "outside"
    wrong_secondary = directory / "AppGroup" / ".jbroot-0000000000000001"
    for path in (primary / "Library/PreferenceBundles", primary / "private", secondary / "var/mobile/Library", secondary / "var/tmp", outside, wrong_secondary / "var", Path(str(primary) + "-neighbor")):
        path.mkdir(parents=True)
    (primary / "var").symlink_to("private/var")
    (primary / "private/var").symlink_to(secondary / "var")
    (primary / "tmp").symlink_to("var/tmp")
    (secondary / ".jbroot").symlink_to(primary)
    (primary / "Library/Escape").symlink_to(outside)
    (primary / "Library/Broken").symlink_to(outside / "missing")
    (primary / "Library/Loop").symlink_to("Loop")
    (primary / "Library/Internal").symlink_to(primary / "Library/PreferenceBundles")
    (primary / "Library/File").write_text("fixture")
    (secondary / "var/mobile/Containers").symlink_to(outside)
    (secondary / "var/mobile/Library/Escape").symlink_to(outside)
    source_path.write_text(roothide_source)
    executable = directory / "roothide"
    subprocess.run([
        "xcrun", "--sdk", "macosx", "clang++", "-std=c++17", "-fobjc-arc", "-fblocks",
        "-Wall", "-Wextra", "-Werror", "-framework", "Foundation",
        "-I", str(args.roothide_theos / "vendor/include"), "-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1",
        str(source_path), "-o", str(executable)
    ], check=True)
    subprocess.run([str(executable), str(primary), str(secondary), str(outside), str(wrong_secondary)], check=True)
print("PASS: public-header compilation for rootful/rootless/RootHide; all fixtures were inside the project .theos directory.")
print("Device runtime, preferences sharing, simulator adapters, and concurrent symlink replacement are not validated.")
