#!/bin/bash
# Run from any directory. The fixture uses a separate port and no real AI key.
set -euo pipefail
cd "$(dirname "$0")/.."
node server/test/ui-fixture.mjs &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null || true' EXIT
sleep 1
kill -0 "$fixture_pid"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcodebuild \
  -project Savor.xcodeproj -scheme Savor -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test "$@"
