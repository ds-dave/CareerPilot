#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# The dedicated bundle ID triggers an in-memory store and fictional data in DEBUG only.
# It also separates window/layout preferences from the regular app.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
build_dir="${TMPDIR:-/tmp}/CareerPilot-Demo"
xcodebuild -project CareerPilot.xcodeproj -scheme CareerPilot \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$build_dir" PRODUCT_BUNDLE_IDENTIFIER=app.careerpilot.preview build
printf '\nDemo app: %s/Build/Products/Debug/CareerPilot.app\n' "$build_dir"
