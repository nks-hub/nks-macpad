#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
"${XCODEGEN:-xcodegen}" generate
action="${1:-test}"
if [ "$#" -gt 0 ]; then shift; fi
case "$action" in
  test|build-for-testing) set -- "$action" ENABLE_TESTABILITY=YES "$@" ;;
  *) set -- "$action" "$@" ;;
esac
xcodebuild -project MacPad.xcodeproj -scheme "${SCHEME:-MacPad}" \
  -configuration "${CONFIGURATION:-Debug}" \
  -derivedDataPath "${DERIVED_DATA_PATH:-build/DerivedData}" \
  CODE_SIGNING_ALLOWED=NO "$@"
