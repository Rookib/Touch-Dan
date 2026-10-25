#!/usr/bin/env python3
"""Exercise the production RootHide defaults implementation on macOS Foundation.

The complete TDNUserDefaults.mm and actual Swift presets are compiled unchanged,
apart from a unique test domain/notification and a fixture-only TDNPaths provider.
UIKit is replaced by Foundation in the copied header. Each scenario runs in a new
process. A mandatory sandbox permits writes only below work/ and denies cfprefsd
connections; CFFIXED_USER_HOME points to the fixture, without changing HOME.

This tests guards and host Foundation behavior, not UIKit, RootHide's path resolver,
or iOS/cfprefsd integration. A missing explicit plist is reported UNVERIFIED, never
accepted because synchronize returned YES; --require-persistence makes this a
nonzero exit. No device is accessed.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]

PROVIDER = r'''
#import <Foundation/Foundation.h>
extern NSString *TDNTestProviderPath;
extern NSUInteger TDNTestProviderCalls;
static inline NSString *TDNJailbreakPath(NSString *path) {
    if (![path isEqualToString:@"/var/mobile/Library/Preferences/io.github.suckdrygod.touchdan.plist"])
        [NSException raise:@"TestBoundary" format:@"Unexpected production path"];
    TDNTestProviderCalls++;
    return TDNTestProviderPath;
}
'''

SWIFT_BRIDGE = r'''
import Foundation
@_cdecl("TDNTestApplyActualPreset")
public func tdnTestApplyActualPreset(_ raw: UnsafeMutableRawPointer, _ index: Int32) {
    let defaults = Unmanaged<TDNUserDefaults>.fromOpaque(raw).takeUnretainedValue()
    TDNStylePreset.allCases[Int(index)].apply(to: defaults)
}
'''

HARNESS = r'''
NSString *TDNTestProviderPath;
NSUInteger TDNTestProviderCalls;
extern "C" void TDNTestApplyActualPreset(void *, int32_t);
static NSMutableArray<NSDictionary *> *results;
static void Check(BOOL ok, NSString *name, NSString *detail = @"", BOOL unverified = NO) {
    [results addObject:@{@"name":name, @"passed":@(ok), @"detail":detail,
                        @"status":ok ? @"PASS" : (unverified ? @"UNVERIFIED" : @"FAIL")}];
}
static void SetAllKinds(TDNUserDefaults *d) {
    [d setObject:@"new object" forKey:@"testObject"];
    [d setBool:YES forKey:@"isEnabled"];
    [d setInteger:42 forKey:@"fillSize"];
    [d setFloat:0.5f forKey:@"alpha"];
    [d setDouble:3.25 forKey:@"borderWidth"];
    [d setValue:@"new image" forKey:@"imageFillName"];
}
static void CheckNoMutation(TDNUserDefaults *d, NSString *name, void (^operation)(void)) {
    NSDictionary *before = d.dictionaryRepresentation;
    operation();
    Check([before isEqualToDictionary:d.dictionaryRepresentation], name);
}
static void CheckBlockedWrites(TDNUserDefaults *d) {
    CheckNoMutation(d, @"setObject rejects unavailable or changed provider", ^{
        [d setObject:@"blocked" forKey:@"testObject"]; });
    CheckNoMutation(d, @"setBool rejects unavailable or changed provider", ^{
        [d setBool:YES forKey:@"isRecordingOnly"]; });
    CheckNoMutation(d, @"setInteger rejects unavailable or changed provider", ^{
        [d setInteger:91 forKey:@"fillSize"]; });
    CheckNoMutation(d, @"setFloat rejects unavailable or changed provider", ^{
        [d setFloat:0.1f forKey:@"alpha"]; });
    CheckNoMutation(d, @"setDouble rejects unavailable or changed provider", ^{
        [d setDouble:7.5 forKey:@"borderWidth"]; });
    CheckNoMutation(d, @"setValue rejects unavailable or changed provider", ^{
        [d setValue:@"blocked image" forKey:@"imageFillName"]; });
    CheckNoMutation(d, @"removeObject rejects unavailable or changed provider", ^{
        [d removeObjectForKey:@"testObject"]; });
    for (int i = 0; i < 3; i++) {
        CheckNoMutation(d, [NSString stringWithFormat:@"actual Swift preset %d is blocked", i], ^{
            TDNTestApplyActualPreset((__bridge void *)d, i); });
    }
    CheckNoMutation(d, @"reset rejects unavailable or changed provider", ^{
        [d resetToDefaultValues]; });
}
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 3) return 64;
        results = [NSMutableArray array];
        NSString *scenario = [NSString stringWithUTF8String:argv[1]];
        NSString *fixture = [NSString stringWithUTF8String:argv[2]];
        NSString *expectedHome = [fixture stringByAppendingPathComponent:@"home"];
        if (![NSHomeDirectory() isEqualToString:expectedHome]) {
            fprintf(stderr, "CFFIXED_USER_HOME isolation is unavailable; refusing to run.\n");
            return 65;
        }
        NSString *explicitPath = [fixture stringByAppendingPathComponent:@"hidden/Preferences/touch-dan-test.plist"];
        NSString *changedPath = [fixture stringByAppendingPathComponent:@"replacement/Preferences/touch-dan-test.plist"];
        BOOL unavailable = [scenario isEqualToString:@"unavailable"];
        TDNTestProviderPath = unavailable ? nil : explicitPath;
        TDNUserDefaults *d = [TDNUserDefaults standardUserDefaults];
        Check(d != nil, @"defaults object initialized");
        Check(TDNTestProviderCalls > 0, @"production initialization calls fixture provider");
        Check([d tdn_canPersistSettings] == !unavailable, @"initial write eligibility");
        Check([d integerForKey:@"fillSize"] == 26 && ![d boolForKey:@"isEnabled"], @"registered defaults loaded");

        if ([scenario isEqualToString:@"valid"]) {
            SetAllKinds(d);
            Check([[d objectForKey:@"testObject"] isEqual:@"new object"], @"setObject stores value");
            Check([d boolForKey:@"isEnabled"], @"setBool stores value");
            Check([d integerForKey:@"fillSize"] == 42, @"setInteger stores value");
            Check([d floatForKey:@"alpha"] == 0.5f, @"setFloat stores value");
            Check([d doubleForKey:@"borderWidth"] == 3.25, @"setDouble stores value");
            Check([[d objectForKey:@"imageFillName"] isEqual:@"new image"], @"setValue stores value");
            [d setObject:@YES forKey:@"enableOverride"];
            [d setBool:YES forKey:@"isRecordingOnly"];
            Check(![d boolForKey:@"enableOverride"], @"master mode change clears override");
            for (int i = 0; i < 3; i++) {
                TDNTestApplyActualPreset((__bridge void *)d, i);
                NSInteger expectedSize[] = {26, 28, 30};
                Check([d integerForKey:@"fillSize"] == expectedSize[i],
                      [NSString stringWithFormat:@"actual Swift preset %d applies in batch", i]);
                Check([d boolForKey:@"isEnabled"] && [[d objectForKey:@"imageFillName"] isEqual:@"new image"],
                      [NSString stringWithFormat:@"actual Swift preset %d preserves master and image", i]);
            }
            [d synchronize];
            NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:explicitPath];
            Check([disk[@"testObject"] isEqual:@"new object"] && [disk[@"fillSize"] integerValue] == 30,
                  @"explicit absolute suite persists to the exact requested plist",
                  disk ? @"Read the explicit plist after synchronize." :
                  @"No explicit plist after synchronize: persistence is not verified under isolated macOS Foundation.", disk == nil);
            [d removeObjectForKey:@"testObject"];
            Check([d objectForKey:@"testObject"] == nil, @"removeObject removes accepted value");
            [d resetToDefaultValues];
            Check([d integerForKey:@"fillSize"] == 26 && ![d boolForKey:@"isEnabled"] &&
                  [[d objectForKey:@"imageFillName"] isEqual:@"default.png"], @"reset restores registered defaults");
            [d synchronize];
        } else if ([scenario isEqualToString:@"changed"]) {
            SetAllKinds(d);
            Check([[d objectForKey:@"testObject"] isEqual:@"new object"], @"initial provider accepts a value before changing");
            [d synchronize];
            NSData *before = [NSData dataWithContentsOfFile:explicitPath];
            TDNTestProviderPath = changedPath;
            Check(![d tdn_canPersistSettings], @"changed provider disables writes");
            CheckBlockedWrites(d);
            [d synchronize];
            NSData *after = [NSData dataWithContentsOfFile:explicitPath];
            Check((before == nil && after == nil) || [before isEqualToData:after],
                  @"changed provider leaves original fixture bytes unchanged",
                  before ? @"Existing file bytes unchanged." : @"Absent before and after; this is not proof of persistence.");
            Check(![[NSFileManager defaultManager] fileExistsAtPath:changedPath], @"changed provider does not create replacement plist");
        } else if (unavailable) {
            CheckBlockedWrites(d);
            [d synchronize];
            Check(![[NSFileManager defaultManager] fileExistsAtPath:explicitPath], @"unavailable provider creates no explicit plist");
        } else {
            return 64;
        }
        NSString *readOnly = [kDefaultsSuiteName stringByAppendingString:@".readonly"];
        NSDictionary *fallback = [d persistentDomainForName:readOnly];
        Check(fallback.count == 0, @"fallback read-only suite has no persistent keys");
        NSString *regularFile = [[expectedHome stringByAppendingPathComponent:@"Library/Preferences"]
            stringByAppendingPathComponent:[kDefaultsSuiteName stringByAppendingString:@".plist"]];
        Check(![[NSFileManager defaultManager] fileExistsAtPath:regularFile], @"normal default domain plist was not created");
        NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"scenario":scenario, @"checks":results}
            options:0 error:nil];
        fwrite(json.bytes, 1, json.length, stdout);
        fputc('\n', stdout);
        return 0;
    }
}
'''


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise RuntimeError("Production boundary changed; review the harness: " + before)
    return text.replace(before, after, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    default_work = ROOT.parents[1] / "work" if ROOT.parent.name == "outputs" else ROOT / "work"
    parser.add_argument("--work-dir", type=Path, default=default_work,
                        help="Scratch parent; everything generated stays below this directory.")
    parser.add_argument("--require-persistence", action="store_true",
                        help="Exit 2 if absolute-suite disk persistence remains unverified.")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("This host test requires macOS Foundation and sandbox-exec.")
    if not Path("/usr/bin/sandbox-exec").exists():
        parser.error("sandbox-exec is required; refusing an unrestricted preferences test.")
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="touch-dan-preferences-", dir=str(work)))
    suite = "io.github.touchdan.host-test." + uuid.uuid4().hex
    implementation_path = ROOT / "TDNPrefs/TDNUserDefaults.mm"
    source = implementation_path.read_text()
    source = replace_once(source, 'kDefaultsSuiteName = @"io.github.suckdrygod.touchdan"',
                          'kDefaultsSuiteName = @"' + suite + '"')
    header = (ROOT / "TDNPrefs/TDNUserDefaults.h").read_text()
    header = replace_once(header, "#import <UIKit/UIKit.h>", "#import <Foundation/Foundation.h>")
    header = replace_once(header, '"io.github.suckdrygod.touchdan.reload-prefs"', '"' + suite + '.reload-prefs"')
    (run / "TDNUserDefaults.h").write_text(header)
    (run / "TDNPaths.h").write_text(PROVIDER)
    (run / "preferences-tests.mm").write_text(source + "\n" + HARNESS)
    (run / "PresetBridge.swift").write_text(SWIFT_BRIDGE)
    cache = run / "module-cache"
    cache.mkdir()
    subprocess.run([
        "xcrun", "--sdk", "macosx", "clang++", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror",
        "-Wno-deprecated-declarations", "-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1",
        "-fmodules-cache-path=" + str(cache), "-c", str(run / "preferences-tests.mm"),
        "-o", str(run / "preferences-tests.o")
    ], check=True)
    executable = run / "preferences-tests"
    subprocess.run([
        "xcrun", "--sdk", "macosx", "swiftc", "-parse-as-library", "-module-cache-path", str(cache),
        "-import-objc-header", str(run / "TDNUserDefaults.h"),
        str(ROOT / "TDNPrefs/TDNStylePreset.swift"), str(run / "PresetBridge.swift"),
        str(run / "preferences-tests.o"), "-Xlinker", "-lc++", "-o", str(executable)
    ], check=True)
    report = {
        "scope": "macOS Foundation with cfprefsd denied; not iOS or RootHide integration",
        "source_sha256": hashlib.sha256(implementation_path.read_bytes()).hexdigest(),
        "preset_sha256": hashlib.sha256((ROOT / "TDNPrefs/TDNStylePreset.swift").read_bytes()).hexdigest(),
        "suite": suite, "scenarios": [], "isolation": "sandbox write allowlist + CFFIXED_USER_HOME",
    }
    for scenario in ("valid", "unavailable", "changed"):
        fixture = run / scenario
        home = fixture / "home"
        (home / "Library/Preferences").mkdir(parents=True)
        profile = fixture / "sandbox.sb"
        profile.write_text(
            '(version 1)\n(allow default)\n(deny file-write*)\n'
            '(allow file-write* (subpath ' + json.dumps(str(fixture)) + '))\n'
            '(deny mach-lookup (global-name "com.apple.cfprefsd.daemon") '
            '(global-name "com.apple.cfprefsd.agent"))\n'
        )
        environment = dict(os.environ)
        environment["CFFIXED_USER_HOME"] = str(home)
        result = subprocess.run([
            "/usr/bin/sandbox-exec", "-f", str(profile), str(executable), scenario, str(fixture)
        ], env=environment, text=True, capture_output=True, timeout=30)
        if result.returncode:
            data = {"scenario": scenario, "checks": [{"name": "isolated test process completes",
                    "passed": False, "detail": result.stderr.strip()}]}
        else:
            data = json.loads(result.stdout)
        if result.stderr.strip():
            data["host_stderr"] = result.stderr.strip()
        # This also catches unintended suite-domain writes beneath the isolated
        # home. Sandbox denial, not this enumeration, protects the real home.
        unexpected = [str(p.relative_to(fixture)) for p in home.rglob("*.plist")]
        data["checks"].append({"name": "isolated home contains no unintended preference plists",
                               "passed": not unexpected, "detail": unexpected})
        report["scenarios"].append(data)
        for check in data["checks"]:
            check.setdefault("status", "PASS" if check["passed"] else "FAIL")
            print(check["status"] + " [" + scenario + "] " + check["name"])
    checks = [check for scenario in report["scenarios"] for check in scenario["checks"]]
    report["passed"] = sum(check["status"] == "PASS" for check in checks)
    report["failed"] = sum(check["status"] == "FAIL" for check in checks)
    report["unverified"] = sum(check["status"] == "UNVERIFIED" for check in checks)
    report_path = run / "report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("\n{} passed; {} failed; {} UNVERIFIED. Report: {}".format(
        report["passed"], report["failed"], report["unverified"], report_path))
    if report["unverified"]:
        print("Absolute-suite persistence is UNVERIFIED in this isolated host; iOS/cfprefsd needs device validation.")
    if report["failed"]:
        return 1
    return 2 if args.require_persistence and report["unverified"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
