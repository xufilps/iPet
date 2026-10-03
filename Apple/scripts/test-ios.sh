#!/bin/bash
set -euo pipefail
apple_root="$(cd "$(dirname "$0")/.." && pwd)"
# The shared TestAction and UI launch environment isolate the Debug app host as well as model fixtures.
if [ -z "${IPET_IOS_TEST_DEVICE_ID:-}" ]; then
    IPET_IOS_TEST_DEVICE_ID="$(xcrun simctl list devices available --json | /usr/bin/python3 -c 'import json,re,sys; d=json.load(sys.stdin); print(next((x["udid"] for runtime,rows in d["devices"].items() if (m:=re.search(r"iOS-(\d+)",runtime)) and int(m.group(1))>=26 for x in rows if x.get("isAvailable") and x["name"].startswith("iPhone")),""))')"
fi
if [ -z "$IPET_IOS_TEST_DEVICE_ID" ]; then
    echo 'Install an available iPhone Simulator runtime with iOS 26 or later before testing.' >&2
    exit 1
fi
xcodebuild -project "$apple_root/iPet.xcodeproj" -scheme iPet-iOS -configuration Debug -destination "platform=iOS Simulator,id=$IPET_IOS_TEST_DEVICE_ID" -derivedDataPath "$apple_root/build/iOS" CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -collect-test-diagnostics never test
