#!/bin/bash
# Build build/GTV.app (Release, chạy được trên cả Apple Silicon và Intel) bằng GTV.xcodeproj.
#
# Mặc định ký ad-hoc: chạy được trên máy build. Để phát hành cho người khác, ký bằng
# chứng chỉ Developer ID:
#   DEVELOPER_ID="Developer ID Application: Ten Ban (TEAMID1234)" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

# Sinh lại project nếu có XcodeGen (project.yml là nguồn gốc).
if command -v xcodegen >/dev/null; then xcodegen -q; fi

SIGN_ARGS=()
if [ -n "${DEVELOPER_ID:-}" ]; then
    TEAM="$(sed -E 's/.*\(([A-Z0-9]+)\)$/\1/' <<<"$DEVELOPER_ID")"
    SIGN_ARGS=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" DEVELOPMENT_TEAM="$TEAM" OTHER_CODE_SIGN_FLAGS=--timestamp)
fi

xcodebuild -project GTV.xcodeproj -scheme GTV -configuration Release \
    -derivedDataPath build/dd ONLY_ACTIVE_ARCH=NO ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
    build -quiet

rm -rf build/GTV.app
cp -R build/dd/Build/Products/Release/GTV.app build/GTV.app
codesign --verify --deep --strict build/GTV.app

echo "Đã build: build/GTV.app ($(du -sh build/GTV.app | cut -f1), $(lipo -archs build/GTV.app/Contents/MacOS/GTV))"
