#!/bin/bash
# Type-checks the app and the widget extension as Mac Catalyst iOS 18, for machines without full
# Xcode. Not an iOS build. ActivityKit and WidgetKit are marked unavailable on Catalyst, so this
# builds stand-ins from the macOS SDK's .swiftinterface files with those bans removed (WidgetKit's
# one `macCatalyst 18.2` is lowered to 18.0), in a temp folder. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
S=$(xcrun --show-sdk-path --sdk macosx)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
TARGET=arm64-apple-ios18.0-macabi
FLAGS=(-target "$TARGET" -sdk "$S" -I "$T" -Fsystem "$S/System/iOSSupport/System/Library/Frameworks" -I "$S/System/iOSSupport/usr/lib/swift")

for m in ActivityKit WidgetKit; do
  sed -E -e 's/@available\(macCatalyst, unavailable\)//g' -e 's/macCatalyst 18\.2/macCatalyst 18.0/g' \
    -e "s/-target arm64e-apple-macos[0-9.]+/-target $TARGET/" \
    "$S/System/Library/Frameworks/$m.framework/Versions/A/Modules/$m.swiftmodule/arm64e-apple-macos.swiftinterface" \
    > "$T/$m.swiftinterface"
  swiftc -frontend -compile-module-from-interface -module-name "$m" "$T/$m.swiftinterface" -o "$T/$m.swiftmodule" "${FLAGS[@]}"
done

# The app imports ShopperKit; build its module first.
swiftc -emit-module -parse-as-library -module-name ShopperKit -emit-module-path "$T/ShopperKit.swiftmodule" "${FLAGS[@]}" $(find ShopperKit/Sources/ShopperKit -name '*.swift')
echo "App:"; swiftc -typecheck "${FLAGS[@]}" $(find CheckPrice Shared -name '*.swift') && echo "  ok"
echo "Widget:"; swiftc -typecheck -parse-as-library "${FLAGS[@]}" $(find Widget Shared -name '*.swift') && echo "  ok"
