#!/bin/bash
# Baut CareerPilot als Release, prüft die App auf persönliche Spuren und packt sie als ZIP.
# Die App ist nur ad hoc signiert (nicht von Apple notarisiert), siehe README, Abschnitt "Installieren".
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

version="$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' CareerPilot.xcodeproj/project.pbxproj | head -1)"
work="${TMPDIR:-/tmp}/CareerPilot-Release"
output="release"
rm -rf "$work"
mkdir -p "$work" "$output"

# Archivieren statt nur bauen: Nur so werden Debug-Symbole und Pfade aus dem Programm entfernt.
# Code-Coverage aus: sonst stünden Quellpfade im Programm. Ohne die Basis-Entitlements fehlt
# "get-task-allow", die App lässt sich dann nicht von anderen Prozessen debuggen.
xcodebuild archive -project CareerPilot.xcodeproj -scheme CareerPilot -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$work/CareerPilot.xcarchive" \
  -derivedDataPath "$work/DerivedData" \
  ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  | tail -3

app="$work/CareerPilot.xcarchive/Products/Applications/CareerPilot.app"
[ -d "$app" ] || { echo "FEHLER: App nicht gefunden" >&2; exit 1; }

echo "Prüfe die App auf persönliche Spuren ..."
if LC_ALL=C grep -rlaE "/Users/|/private/var|$(id -un)" "$app" >/dev/null; then
  echo "FEHLER: In der App stehen lokale Pfade oder der Benutzername. Nicht veröffentlichen." >&2
  LC_ALL=C grep -rlaE "/Users/|/private/var|$(id -un)" "$app" >&2
  exit 1
fi
if codesign -d --entitlements :- "$app" 2>/dev/null | grep -q "get-task-allow"; then
  echo "FEHLER: Die App enthält das Debug-Entitlement get-task-allow." >&2
  exit 1
fi
codesign --verify --deep --strict "$app"

zip="$output/CareerPilot-$version-macOS-unsigned.zip"
rm -f "$zip"
ditto -c -k --norsrc --noextattr --keepParent "$app" "$zip"
printf '\nFertig: %s\n' "$zip"
shasum -a 256 "$zip"
lipo -archs "$app/Contents/MacOS/CareerPilot" | sed 's/^/Architekturen: /'
