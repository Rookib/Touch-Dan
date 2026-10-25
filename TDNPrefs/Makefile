ifeq ($(THEOS_DEVICE_SIMULATOR),1)
ARCHS := x86_64 arm64
TARGET := simulator:clang:latest:16.0
IPHONE_SIMULATOR_ROOT := $(shell ../devkit/sim-root.sh)
else
ARCHS := arm64 arm64e
TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES := Preferences
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := TDNPrefs

TDNPrefs_FILES += $(wildcard *.mm)
TDNPrefs_FILES += $(wildcard *.swift)

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TDNPrefs_FILES += ../libroot/dyn.c
endif
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
TDNPrefs_LIBRARIES += roothide
endif

TDNPrefs_CFLAGS += -fobjc-arc
TDNPrefs_CFLAGS += -I..
TDNPrefs_CFLAGS += -DPACKAGE_VERSION=\"$(PACKAGE_VERSION)\"

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TDNPrefs_CFLAGS += -DIPHONE_SIMULATOR_ROOT=\"$(IPHONE_SIMULATOR_ROOT)\"
endif

# swift-create-xcframework --no-debug-symbols --static-library --platform ios --xc-setting ARCHS="arm64 arm64e" --clean SwiftUIIntrospect

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TDNPrefs_LDFLAGS += -FFrameworks/_Simulator
TDNPrefs_LDFLAGS += -FFrameworks/_Simulator/MCEmojiPicker.xcframework/ios-arm64_x86_64-simulator -framework MCEmojiPicker
TDNPrefs_LDFLAGS += -FFrameworks/_Simulator/SwiftUIIntrospect.xcframework/ios-arm64_x86_64-simulator -framework SwiftUIIntrospect
TDNPrefs_SWIFTFLAGS += -FFrameworks/_Simulator/MCEmojiPicker.xcframework/ios-arm64_x86_64-simulator -framework MCEmojiPicker
TDNPrefs_SWIFTFLAGS += -FFrameworks/_Simulator/SwiftUIIntrospect.xcframework/ios-arm64_x86_64-simulator -framework SwiftUIIntrospect
else
TDNPrefs_LDFLAGS += -FFrameworks
TDNPrefs_LDFLAGS += -FFrameworks/MCEmojiPicker.xcframework/ios-arm64_arm64e -framework MCEmojiPicker
TDNPrefs_LDFLAGS += -FFrameworks/SwiftUIIntrospect.xcframework/ios-arm64_arm64e -framework SwiftUIIntrospect
TDNPrefs_SWIFTFLAGS += -FFrameworks/MCEmojiPicker.xcframework/ios-arm64_arm64e -framework MCEmojiPicker
TDNPrefs_SWIFTFLAGS += -FFrameworks/SwiftUIIntrospect.xcframework/ios-arm64_arm64e -framework SwiftUIIntrospect
endif

TDNPrefs_FRAMEWORKS += UIKit
TDNPrefs_PRIVATE_FRAMEWORKS += Preferences

TDNPrefs_SWIFT_BRIDGING_HEADER += TDNPrefs-Bridging-Header.h
TDNPrefs_INSTALL_PATH += /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
