#!/bin/sh

cd "$(dirname "$0")"/.. || exit

plutil -convert xml1 CCTouchDan/Resources/Info.plist
plutil -convert xml1 TDNPrefs/Resources/Info.plist
