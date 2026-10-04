#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
build_directory="$project_directory/.build/checks"

if [[ -n "${SDKROOT:-}" ]]; then
    sdk_path="$SDKROOT"
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
else
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
fi

/bin/mkdir -p "$build_directory/ModuleCache"

CLANG_MODULE_CACHE_PATH="$build_directory/ModuleCache" swiftc \
    -sdk "$sdk_path" \
    "$project_directory/Sources/AutoClicker/Models.swift" \
    "$project_directory/Sources/AutoClicker/SettingsValidator.swift" \
    "$project_directory/Sources/AutoClicker/MouseClickEngine.swift" \
    "$project_directory/Checks/AutoClickerChecks.swift" \
    -o "$build_directory/AutoClickerChecks"

# The checks above never compile the UI, so a SwiftUI API newer than the package's
# macOS 13 minimum would only fail later at release build time.
CLANG_MODULE_CACHE_PATH="$build_directory/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$build_directory/ModuleCache" swift build \
    --package-path "$project_directory" \
    --scratch-path "$project_directory/.build" \
    --disable-sandbox \
    --sdk "$sdk_path" \
    --target AutoClicker

"$build_directory/AutoClickerChecks"
