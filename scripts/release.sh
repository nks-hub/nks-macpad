#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--help" ]]; then
  printf '%s\n' 'Build, sign, notarize and package a clean Git revision for Apple Silicon.' \
    'Required: SIGN_IDENTITY (Developer ID Application), NOTARY_PROFILE (notarytool keychain profile).' \
    'Optional: XCODEGEN (path to xcodegen). Output: dist/MacPad-*/ with ZIP, SHA-256 and JSON.'
  exit 0
fi
[[ $# -eq 0 ]] || { printf 'Use --help for usage.\n' >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || { printf 'Run this script on macOS.\n' >&2; exit 1; }
: "${SIGN_IDENTITY:?Set the Developer ID Application identity or its SHA-1 hash}"
: "${NOTARY_PROFILE:?Set the notarytool keychain profile}"
[[ -z "$(git status --porcelain)" ]] || { printf 'Commit source changes before packaging.\n' >&2; exit 1; }

commit=$(git rev-parse HEAD)
root=$(pwd -P)
mkdir -p build dist
release_dir=$(mktemp -d "$root/build/release.XXXXXX")
printf 'Build and notarization records: %s\n' "$release_dir"
mkdir "$release_dir/source"
git archive "$commit" | tar -xf - -C "$release_dir/source"
CONFIGURATION=Release DERIVED_DATA_PATH="$release_dir/DerivedData" \
  /bin/bash "$release_dir/source/scripts/build.sh" build ARCHS=arm64 ONLY_ACTIVE_ARCH=NO ENABLE_HARDENED_RUNTIME=YES
app="$release_dir/DerivedData/Build/Products/Release/MacPad.app"

codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp \
  "$app/Contents/Frameworks/MacPadCore.framework"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$app"
codesign --verify --deep --strict --verbose=2 "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$release_dir/notarization.zip"
xcrun notarytool submit "$release_dir/notarization.zip" --keychain-profile "$NOTARY_PROFILE" \
  --wait --output-format json > "$release_dir/notarization.json"
python3 - "$release_dir/notarization.json" <<'PY'
import json
import sys
from pathlib import Path
result = json.loads(Path(sys.argv[1]).read_text())
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; inspect the local notarization record.')
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

[[ "$commit" == "$(git rev-parse HEAD)" && -z "$(git status --porcelain)" ]] || {
  printf 'The source revision changed during packaging. No distribution archive was created.\n' >&2
  exit 1
}
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { printf 'Invalid bundle version.\n' >&2; exit 1; }
package="MacPad-$version-arm64-${commit:0:12}"
destination="$root/dist/$package"
[[ ! -e "$destination" ]] || {
  printf 'Artifacts for this revision already exist.\n' >&2; exit 1
}
staging=$(mktemp -d "$root/dist/.$package.XXXXXX")
name="$package.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$staging/$name"
(cd "$staging" && shasum -a 256 "$name" > "$name.sha256")
python3 - "$staging/$name" "$version" "$commit" <<'PY'
import hashlib
import json
import sys
from pathlib import Path
archive = Path(sys.argv[1])
manifest = {'version': sys.argv[2], 'commit': sys.argv[3], 'architecture': 'arm64',
            'archive': archive.name, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'notarized': True}
Path(str(archive) + '.json').write_text(json.dumps(manifest, indent=2) + '\n')
PY
python3 - "$staging" "$destination" <<'PY'
import os
import sys
# Renaming a complete directory cannot replace another nonempty release directory.
os.rename(sys.argv[1], sys.argv[2])
PY
printf 'Packaged: dist/%s/%s\n' "$package" "$name"
