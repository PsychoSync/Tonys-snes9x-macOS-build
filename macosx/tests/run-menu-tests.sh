#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
derived="${1:-$root/macosx/Build/MenuTests}"
arch="$(uname -m)"

xcodebuild -quiet -project "$root/macosx/snes9x.xcodeproj" \
    -scheme snes9x -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build

products="$derived/Build/Products/Release"
object_dir="$derived/Build/Intermediates.noindex/snes9x.build/Release/Snes9x.build/Objects-normal/$arch"
objects=()
for object in "$object_dir"/*.o; do
    if [[ "$(basename "$object")" != main.o ]]; then
        objects+=("$object")
    fi
done

test_app="$derived/MenuRegressionTests.app"
ditto "$products/Snes9x.app" "$test_app"
plutil -replace CFBundleIdentifier -string com.snes9x.MenuRegressionTests "$test_app/Contents/Info.plist"

xcrun clang++ -arch "$arch" -std=c++11 -fobjc-arc -fblocks -fexceptions -fobjc-exceptions -D__MACOSX__ \
    -I "$root" -I "$root/macosx" -I "$root/macosx/Snes9x" \
    -F "$products" -framework Cocoa -framework Carbon -framework MetalKit \
    -framework snes9x_framework -Wl,-rpath,"$products" \
    "$root/macosx/tests/menu-regression.mm" "${objects[@]}" \
    -o "$test_app/Contents/MacOS/Snes9x"

"$test_app/Contents/MacOS/Snes9x"
