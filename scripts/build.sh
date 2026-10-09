#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
"${XCODEGEN:-xcodegen}" generate
xcodebuild -project MacPad.xcodeproj -scheme MacPad \
  -configuration "${CONFIGURATION:-Debug}" \
  -derivedDataPath "${DERIVED_DATA_PATH:-build/DerivedData}" \
  CODE_SIGNING_ALLOWED=NO "${1:-test}"
