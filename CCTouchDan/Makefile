ifeq ($(THEOS_DEVICE_SIMULATOR),1)
ARCHS := x86_64 arm64
TARGET := simulator:clang:latest:16.0
IPHONE_SIMULATOR_ROOT := $(shell ../devkit/sim-root.sh)
else
ARCHS := arm64 arm64e
TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES := SpringBoard
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := CCTouchDan

CCTouchDan_BUNDLE_EXTENSION += bundle

CCTouchDan_FILES += CCTouchDan.mm
CCTouchDan_FILES += $(wildcard ../TDNPrefs/*.mm)

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
CCTouchDan_FILES += ../libroot/dyn.c
endif
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
CCTouchDan_LIBRARIES += roothide
endif

CCTouchDan_CFLAGS += -fobjc-arc
CCTouchDan_CFLAGS += -I../TDNPrefs
CCTouchDan_CFLAGS += -DPACKAGE_VERSION=\"$(PACKAGE_VERSION)\"

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
CCTouchDan_CFLAGS += -DIPHONE_SIMULATOR_ROOT=\"$(IPHONE_SIMULATOR_ROOT)\"
endif

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
CCTouchDan_LDFLAGS += -FFrameworks/_Simulator
endif

CCTouchDan_FRAMEWORKS += UIKit
CCTouchDan_PRIVATE_FRAMEWORKS += ControlCenterUIKit
CCTouchDan_INSTALL_PATH += /Library/ControlCenter/Bundles

include $(THEOS_MAKE_PATH)/bundle.mk
