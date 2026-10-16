# Photomath - smart math camera solver for jailbroken iOS. One source tree, two packages (Theos):
#   make package                               armv7 for iOS 6.x (the iOS 9.3 SDK, deployment target 6.0)
#   make package THEOS_PACKAGE_SCHEME=rootless arm64 for iOS 14-17 (the iOS 16.5 SDK, deployment target 14.0):
#                                              the .deb for rootless jailbreaks, the IPA for TrollStore
# (`make clean` between the two; CI builds both, see .github/workflows/build.yml)

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
TARGET := iphone:clang:16.5:14.0
ARCHS := arm64
else
TARGET := iphone:clang:9.3:6.0
ARCHS := armv7
endif
DEBUG ?= 0

THEOS_DEVICE_IP ?= 192.168.1.166
THEOS_DEVICE_USER ?= root

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := Photomath

# iosMath (LaTeX rendering, MIT) is fetched into vendor/iosMath by CI; the NS*/AppKit files are macOS only.
IOSMATH_FILES := $(filter-out %NSBezierPath+addLineToPoint.m %NSColor+HexString.m %NSView+backgroundColor.m, \
                   $(wildcard vendor/iosMath/iosMath/lib/*.m) \
                   $(wildcard vendor/iosMath/iosMath/render/*.m) \
                   $(wildcard vendor/iosMath/iosMath/render/internal/*.m))

Photomath_FILES := $(wildcard src/*.m) $(wildcard src/*/*.m) \
                   vendor/mbedtls_glue.c \
                   $(wildcard vendor/mbedtls/library/*.c) \
                   $(IOSMATH_FILES)

Photomath_FRAMEWORKS := UIKit Foundation CoreGraphics QuartzCore CoreText Security ImageIO AVFoundation CoreMedia CoreVideo AssetsLibrary
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
Photomath_FRAMEWORKS += PhotosUI
endif

# Flags for every C-family file (also the vendored mbedTLS sources)
Photomath_CFLAGS := -Isrc -Isrc/Net -Isrc/Model -Isrc/Theme -Isrc/UI -Isrc/Util \
                    -Ivendor -Ivendor/mbedtls/include -Ivendor/mbedtls/library \
                    -Ivendor/iosMath/iosMath/lib -Ivendor/iosMath/iosMath/render -Ivendor/iosMath/iosMath/render/internal \
                    -Os -fvisibility=hidden \
                    -Wall -Wno-unused-variable -Wno-unused-function -Wno-unused-but-set-variable \
                    -Wno-deprecated-declarations -Wno-unknown-warning-option \
                    -Wno-nullability-completeness -Wno-nullability-completeness-on-arrays -Wno-error

Photomath_OBJCFLAGS := -fobjc-arc -Wunguarded-availability -include UIKit/UIKit.h

Photomath_LDFLAGS := -lz

include $(THEOS)/makefiles/application.mk

PHOTOMATH_STAGED_APP := $(THEOS_STAGING_DIR)/Applications/Photomath.app

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
after-stage::
	python3 "$(THEOS_PROJECT_DIR)/tools/modern_bundle.py" "$(PHOTOMATH_STAGED_APP)"
	ldid -S"$(THEOS_PROJECT_DIR)/entitlements-arm64.xml" "$(PHOTOMATH_STAGED_APP)/Photomath"

before-package::
	sed -i -e 's/^Depends: .*/Depends: firmware (>= 15.0)/' "$(THEOS_STAGING_DIR)/DEBIAN/control"
	printf '%s\n' '#!/bin/sh' '[ "$$1" = configure ] || exit 0' \
		'command -v uicache >/dev/null 2>&1 && { uicache -p /var/jb/Applications/Photomath.app >/dev/null 2>&1 || uicache -a >/dev/null 2>&1; }' \
		'exit 0' > "$(THEOS_STAGING_DIR)/DEBIAN/postinst"
	printf '%s\n' '#!/bin/sh' '[ "$$1" = remove ] || exit 0' \
		'command -v uicache >/dev/null 2>&1 && uicache -a >/dev/null 2>&1' \
		'exit 0' > "$(THEOS_STAGING_DIR)/DEBIAN/postrm"
	chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/postinst" "$(THEOS_STAGING_DIR)/DEBIAN/postrm"
endif
