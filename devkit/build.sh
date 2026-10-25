#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
variant="${1:-roothide}"
case "$variant" in
  rootful) source devkit/env.sh ;;
  rootless) source devkit/rootless.sh ;;
  roothide) source devkit/roothide.sh ;;
  *) printf '%s\n' 'Usage: devkit/build.sh [roothide|rootless|rootful]' >&2; exit 2 ;;
esac
[[ -f "$THEOS/makefiles/common.mk" ]] || { printf 'Theos not found at %s\n' "$THEOS" >&2; exit 1; }
export FINALPACKAGE=1
# Match Swift's public SDK to the selected Xcode compiler. Older patched SDKs
# contribute private linker stubs only, never SwiftUI/Foundation interfaces.
sdk_path="${TOUCHDAN_SDK_PATH:-$(xcrun --sdk iphoneos --show-sdk-path)}"
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
private_frameworks="${TOUCHDAN_PRIVATE_FRAMEWORKS:-$THEOS/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks}"
# The vendored Swift 5.10 libraries reference the iOS 16 UIKit Swift overlay.
# Newer SDKs omit those legacy exports; link its SDK stub explicitly, not code.
uikit_overlay="${TOUCHDAN_UIKIT_OVERLAY:-$THEOS/sdks/iPhoneOS16.5.sdk/usr/lib/swift/libswiftUIKit.tbd}"
[[ -f "$uikit_overlay" ]] || { printf 'Missing UIKit compatibility stub: %s\n' "$uikit_overlay" >&2; exit 1; }
for framework in Preferences FrontBoardServices ControlCenterUIKit; do
  [[ -d "$private_frameworks/$framework.framework" ]] || { printf 'Missing private framework stub: %s\n' "$framework" >&2; exit 1; }
done
make clean package "TARGET=iphone:clang:$sdk_version:16.0" \
  "SYSROOT=$sdk_path" "ISYSROOT=$sdk_path" \
  "TARGET_PRIVATE_FRAMEWORK_PATH=$private_frameworks" "ADDITIONAL_LDFLAGS=$uikit_overlay" \
  "ADDITIONAL_CFLAGS=-Wno-error=deprecated-declarations"
