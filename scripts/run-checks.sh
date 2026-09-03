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

"$build_directory/AutoClickerChecks"
