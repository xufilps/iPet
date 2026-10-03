#!/bin/bash
set -euo pipefail
apple_root="$(cd "$(dirname "$0")/.." && pwd)"
/usr/bin/python3 "$apple_root/scripts/convert_assets.py"
/usr/bin/python3 "$apple_root/scripts/convert_gameplay.py"
/usr/bin/python3 "$apple_root/scripts/convert_dialogue.py"
xcodebuild -project "$apple_root/iPet.xcodeproj" -scheme iPet-iOS -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$apple_root/build/iOS" CODE_SIGNING_ALLOWED=NO build
codesign --force --sign - "$apple_root/build/iOS/Build/Products/Release-iphonesimulator/iPet-iOS.app"
printf '%s\n' "$apple_root/build/iOS/Build/Products/Release-iphonesimulator/iPet-iOS.app"
