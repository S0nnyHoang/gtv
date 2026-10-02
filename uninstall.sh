#!/bin/bash
# Gỡ GTV.
osascript -e 'tell application id "com.gtv.inputmethod.GTV" to quit' 2>/dev/null || true
pkill -x GTVInput 2>/dev/null || true
pkill -x GTV 2>/dev/null || true
rm -rf "/Applications/GTV.app" "$HOME/Applications/GTV.app"
rm -rf "$HOME/Library/Input Methods/GTVInput.app" "$HOME/Library/Input Methods/GTV.app"
defaults delete com.gtv.inputmethod.GTV 2>/dev/null || true
echo "Đã gỡ GTV. Nếu GTV vẫn còn trong danh sách bộ gõ, hãy đăng xuất rồi đăng nhập lại."
