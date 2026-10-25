#!/usr/bin/env python3
"""Exercise production image file I/O on macOS with Foundation and real files.

UIKit is a placeholder only: these checks do not test image decoding, rendering,
SwiftUI, the document picker, or a device. RootHide path validation has its own
run-path-tests.py suite. No make invocation or global temporary directory is used.
"""
from pathlib import Path
import os
import platform
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "TDNPrefs"
ARTIFACTS = PROJECT / ".theos" / "tests"
UIKIT_STUB = r'''#import <Foundation/Foundation.h>
@interface UIImage : NSObject
@property(nonatomic, copy) NSString *sourcePath;
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(id)traits;
+ (instancetype)imageWithContentsOfFile:(NSString *)path;
@end
FOUNDATION_EXPORT NSData *UIImagePNGRepresentation(UIImage *image);
'''
LIBROOT_STUB = r'''#import <Foundation/Foundation.h>
NSString *TDNTestRoot(void);
#define JBROOT_PATH_NSSTRING(path) TDNTestRoot()
'''

def main():
    if platform.system() != "Darwin":
        raise SystemExit("This test requires macOS with the Xcode command-line tools.")
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="image-storage-", dir=ARTIFACTS) as directory:
        work = Path(directory)
        stubs = work / "stubs"
        (stubs / "UIKit").mkdir(parents=True)
        (stubs / "UIKit" / "UIKit.h").write_text(UIKIT_STUB)
        (stubs / "libroot.h").write_text(LIBROOT_STUB)
        (stubs / "HBLog.h").write_text("#define HBLogWarn(...) ((void)0)\n")
        sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
        test = work / "test.mm"
        test.write_text((PROJECT / "Tests" / "image-storage-tests.mm.in").read_text())
        binary = work / "image-storage-test"
        subprocess.run([
            "xcrun", "clang++", "-fobjc-arc", "-fblocks", "-isysroot", sdk,
            "-I" + str(stubs), "-I" + str(SOURCE), '-DPACKAGE_VERSION="test"',
            str(test), str(SOURCE / "NSBundle+TDNPrefs.mm"),
            "-framework", "Foundation", "-o", str(binary),
        ], check=True)
        fixture = work / "fixture"
        try:
            subprocess.run([str(binary), str(fixture)], check=True)
        finally:
            # A failed permission test must not prevent fixture cleanup.
            if fixture.exists():
                for current, _, _ in os.walk(fixture):
                    if not Path(current).is_symlink():
                        os.chmod(current, 0o700)
    print("Image storage checks passed; generated files were removed from .theos/tests.")

if __name__ == "__main__":
    main()
