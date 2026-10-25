export PACKAGE_VERSION := 0.1.0

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
ARCHS := arm64 x86_64
TARGET := simulator:clang:latest:16.0
FWK_DIR := Frameworks/_Simulator
IPHONE_SIMULATOR_ROOT := $(shell devkit/sim-root.sh)
else
ARCHS := arm64 arm64e
TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES := SpringBoard
FWK_DIR := Frameworks
endif

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += TDNPrefs
SUBPROJECTS += CCTouchDan

include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME := TouchDan

TouchDan_USE_MODULES := 0

TouchDan_FILES += $(wildcard TDNPrefs/*.mm)
TouchDan_FILES += $(wildcard TDNQuickPath/*.swift)
TouchDan_FILES += $(wildcard TDNTouchVisualizer/Private/*.m)
TouchDan_FILES += TouchDan.xm

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TouchDan_FILES += libroot/dyn.c
endif

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
TouchDan_LIBRARIES += roothide
endif

TouchDan_CFLAGS += -fobjc-arc
TouchDan_CFLAGS += -I.
TouchDan_CFLAGS += -ITDNTouchVisualizer
TouchDan_CFLAGS += -ITDNTouchVisualizer/Private
TouchDan_CFLAGS += -DPACKAGE_VERSION=\"$(PACKAGE_VERSION)\"

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TouchDan_CFLAGS += -DIPHONE_SIMULATOR_ROOT=\"$(IPHONE_SIMULATOR_ROOT)\"
endif

TouchDan_CCFLAGS += -Wno-unused-variable
TouchDan_CCFLAGS += -Wno-unused-function

TouchDan_LDFLAGS += -F$(FWK_DIR)

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TouchDan_LDFLAGS += -rpath /opt/simject
endif

TouchDan_SWIFT_BRIDGING_HEADER += TouchDan-Bridging-Header.h
TouchDan_PRIVATE_FRAMEWORKS += FrontBoardServices


include $(THEOS_MAKE_PATH)/tweak.mk

export DEBUG
before-all::
	devkit/standardize-entitlements.sh
	python3 devkit/prepare-licenses.py
