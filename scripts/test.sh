#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Some Command Line Tools releases bundle Swift Testing but omit its macro search path.
# Full Xcode toolchains resolve the plugin without extra flags.
developer_dir="$(xcode-select -p)"
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ "$developer_dir" == */CommandLineTools && -f "$testing_plugin" ]]; then
    swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$testing_plugin" "$@"
else
    swift test --disable-xctest "$@"
fi
