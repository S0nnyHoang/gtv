#!/bin/bash
# Dành cho lúc phát triển: build rồi cài GTV.app vào /Applications và mở.
# Người dùng cuối dùng file .dmg (./dmg.sh).
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/GTV.app"
cp -R build/GTV.app "$DEST/"
open "$DEST/GTV.app"

echo "Đã cài $DEST/GTV.app. Biểu tượng V/E sẽ hiện trên thanh menu."
