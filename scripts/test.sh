#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Some Command Line Tools releases bundle Swift Testing but omit its macro search path.
# Full Xcode toolchains resolve the plugin without extra flags.
developer_dir="$(xcode-select -p)"
if [[ "$developer_dir" == */CommandLineTools ]]; then
    previous=
    for argument in "$@"; do
        if [[ "$previous:$argument" == --arch:x86_64 || "$argument" == --arch=x86_64 ]]; then
            frameworks="$developer_dir/Library/Developer/Frameworks"
            for name in Testing _Testing_Foundation; do
                library="$frameworks/$name.framework/$name"
                if [[ -f "$library" ]] && ! lipo "$library" -verify_arch x86_64; then
                    echo "x86_64 test bundles require a toolchain with Intel Testing frameworks; use a physical Intel Mac." >&2
                    exit 1
                fi
            done
        fi
        previous="$argument"
    done
fi
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ "$developer_dir" == */CommandLineTools && -f "$testing_plugin" ]]; then
    swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$testing_plugin" "$@"
else
    swift test --disable-xctest "$@"
fi
