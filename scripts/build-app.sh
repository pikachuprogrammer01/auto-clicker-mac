#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
build_directory="$project_directory/.build"
app_path="$project_directory/dist/Auto Clicker.app"

if [[ -n "${SDKROOT:-}" ]]; then
    sdk_path="$SDKROOT"
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
else
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
fi

export CLANG_MODULE_CACHE_PATH="$build_directory/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_directory/ModuleCache"

swift build \
    --package-path "$project_directory" \
    --scratch-path "$build_directory" \
    --disable-sandbox \
    --sdk "$sdk_path" \
    -c release

binary_directory="$(swift build \
    --package-path "$project_directory" \
    --scratch-path "$build_directory" \
    --disable-sandbox \
    --sdk "$sdk_path" \
    -c release \
    --show-bin-path)"

if [[ -d "$app_path" ]]; then
    /bin/rm -rf "$app_path"
fi

/bin/mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
/bin/cp "$binary_directory/AutoClicker" "$app_path/Contents/MacOS/AutoClicker"
/bin/cp "$project_directory/Support/Info.plist" "$app_path/Contents/Info.plist"
/bin/cp "$project_directory/LICENSE" "$app_path/Contents/Resources/LICENSE"
/usr/bin/codesign --force --sign - --timestamp=none "$app_path"

print "Built: $app_path"
