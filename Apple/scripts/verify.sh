#!/bin/bash
set -euo pipefail
apple_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$apple_root/build/verification"
/usr/bin/python3 -m unittest discover -s "$apple_root/scripts/tests" -v > "$apple_root/build/verification/conversion-tests.log" 2>&1
/usr/bin/python3 "$apple_root/scripts/export_icon.py" --check
/usr/bin/python3 "$apple_root/scripts/convert_assets.py"
swift test --package-path "$apple_root" > "$apple_root/build/verification/tests.log" 2>&1
# SwiftPM may print per-target XCTest failures at the end; retain and inspect the full log.
/usr/bin/python3 - "$apple_root/build/verification/tests.log" <<'PY_CHECK'
import re
import sys
from pathlib import Path
log = Path(sys.argv[1]).read_text()
if re.search(r'Some test targets reported failures|error:| failed ', log):
    print(log)
    sys.exit(1)
PY_CHECK
"$apple_root/scripts/build.sh" > "$apple_root/build/verification/macos-build.log" 2>&1
swift build --package-path "$apple_root" --target PetRendering --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" --scratch-path "$apple_root/build/ios" > "$apple_root/build/verification/ios-build.log" 2>&1
codesign --verify --strict "$apple_root/build/Build/Products/Release/iPet.app"
printf '%s\n' 'Core/rendering tests, macOS Release build, iOS Simulator shared-module build and signature verification passed.'
