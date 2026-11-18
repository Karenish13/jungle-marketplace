#!/bin/bash
# Checks that the core package and the app use nothing newer than iOS 14.
#
# Why this exists: Xcode 16 and newer refuse to build below iOS 15, so a normal build on a
# current Mac never warns about iOS 15-only code. This script calls the Swift compiler
# directly with an iOS 14 target, which it still accepts, and type-checks every source file.
# It does not produce an app; the real iOS 14 build comes from Xcode 15 on the legacy Mac.
#
# Usage, from anywhere:  Scripts/check-ios14.sh
# Prints "iOS 14 check passed" and exits 0, or prints the compiler errors and exits 1.

set -euo pipefail
cd "$(dirname "$0")/.."

SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios14.0-simulator"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "Checking DiagnosticsCore against iOS 14…"
find Packages/DiagnosticsCore/Sources -name '*.swift' -print0 |
  xargs -0 xcrun swiftc -sdk "$SDK" -target "$TARGET" -swift-version 5 \
    -module-name DiagnosticsCore -parse-as-library \
    -emit-module -emit-module-path "$OUT/DiagnosticsCore.swiftmodule"

echo "Checking the app against iOS 14…"
find App -name '*.swift' -print0 |
  xargs -0 xcrun swiftc -typecheck -sdk "$SDK" -target "$TARGET" -swift-version 5 \
    -I "$OUT" -parse-as-library

echo "iOS 14 check passed"
