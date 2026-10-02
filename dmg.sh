#!/bin/bash
# Đóng gói build/GTV-<phiên bản>.dmg: kéo GTV vào Applications rồi mở là xong.
#
# Phát hành cho người khác (khuyến nghị, để Gatekeeper không chặn):
#   xcrun notarytool store-credentials gtv-notary --apple-id ... --team-id ... --password ...   # làm 1 lần
#   DEVELOPER_ID="Developer ID Application: Ten Ban (TEAMID1234)" NOTARY_PROFILE=gtv-notary ./dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

VERSION="$(defaults read "$PWD/build/GTV.app/Contents/Info.plist" CFBundleShortVersionString)"
DMG="build/GTV-$VERSION.dmg"
STAGE="build/dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/GTV.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Hướng dẫn.txt" <<'EOF'
CÀI ĐẶT GTV
1. Kéo GTV vào thư mục Applications.
2. Mở GTV (từ Applications hoặc Spotlight). GTV được chọn làm bộ gõ là xong.

SỬ DỤNG
- Chuyển Anh/Việt: nhấn rồi nhả Command + Shift, hoặc chọn trong menu bộ gõ của macOS.
- Đổi sang bộ gõ khác (tiếng Nhật, ABC...): phím Globe hoặc Control + Space như bình thường.
- GTV tự được chọn khi đăng nhập (tắt được trong menu bộ gõ: "Chọn GTV khi đăng nhập").
- Đổi kiểu gõ (Telex/VNI), bảng mã...: chọn trong menu bộ gõ của macOS.
- Thoát GTV: menu bộ gõ của macOS > Thoát GTV. Mở lại GTV để dùng tiếp.

Nếu macOS báo không mở được vì "không xác định được nhà phát triển":
vào Cài đặt hệ thống > Quyền riêng tư & Bảo mật, kéo xuống và bấm "Vẫn mở".
EOF

hdiutil create -volname "GTV $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" -quiet
rm -rf "$STAGE"

if [ -n "${DEVELOPER_ID:-}" ]; then
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

echo "Đã tạo: $DMG ($(du -h "$DMG" | cut -f1))"
