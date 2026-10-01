#!/bin/bash
set -euo pipefail
apple_root="$(cd "$(dirname "$0")/.." && pwd)"
/usr/bin/python3 "$apple_root/scripts/convert_assets.py"
xcodebuild -project "$apple_root/VPetApple.xcodeproj" -scheme VPetApple -configuration Release -derivedDataPath "$apple_root/build" CODE_SIGNING_ALLOWED=NO build
codesign --force --sign - "$apple_root/build/Build/Products/Release/VPetApple.app"
printf '%s\n' "$apple_root/build/Build/Products/Release/VPetApple.app"
