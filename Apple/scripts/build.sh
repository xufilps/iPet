#!/bin/bash
set -euo pipefail
apple_root="$(cd "$(dirname "$0")/.." && pwd)"
/usr/bin/python3 "$apple_root/scripts/convert_assets.py"
/usr/bin/python3 "$apple_root/scripts/convert_gameplay.py"
xcodebuild -project "$apple_root/iPet.xcodeproj" -scheme iPet -configuration Release -derivedDataPath "$apple_root/build" CODE_SIGNING_ALLOWED=NO build
codesign --force --sign - "$apple_root/build/Build/Products/Release/iPet.app"
printf '%s\n' "$apple_root/build/Build/Products/Release/iPet.app"
