#!/bin/bash
# Generate a Sparkle appcast.xml (single item) for a DMG and print it to stdout.
#
#   scripts/make_appcast.sh <dmg> <download-url>
#
# Version info is read from the GTV.app inside the DMG. Release notes come from CHANGELOG.md
# (scripts/release_notes.sh) and are converted to HTML.
#
# Signing (EdDSA, via Sparkle's sign_update):
#   SPARKLE_BIN       directory containing sign_update (default: sign_update on PATH)
#   SPARKLE_KEY_FILE  file with the private key; if unset, the key in the login keychain
#                     (account "gtv") is used.
set -euo pipefail
cd "$(dirname "$0")/.."

dmg="${1:?Usage: scripts/make_appcast.sh <dmg> <download-url>}"
url="${2:?Usage: scripts/make_appcast.sh <dmg> <download-url>}"
sign_update="${SPARKLE_BIN:+$SPARKLE_BIN/}sign_update"

# Version info from the app inside the DMG
mnt="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$dmg" -quiet
trap 'hdiutil detach "$mnt" -quiet || true; rmdir "$mnt" 2>/dev/null || true' EXIT
plist="$mnt/GTV.app/Contents/Info.plist"
short="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
minos="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"
hdiutil detach "$mnt" -quiet
trap - EXIT
rmdir "$mnt" 2>/dev/null || true

# EdDSA signature + length: `sparkle:edSignature="..." length="..."`
if [ -n "${SPARKLE_KEY_FILE:-}" ]; then
    signature="$("$sign_update" --ed-key-file "$SPARKLE_KEY_FILE" "$dmg")"
else
    signature="$("$sign_update" --account gtv "$dmg")"
fi

notes="$(scripts/release_notes.sh "$short" | python3 scripts/md2html.py)"
pubdate="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>GTV</title>
    <item>
      <title>GTV $short</title>
      <pubDate>$pubdate</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$short</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$minos</sparkle:minimumSystemVersion>
      <description><![CDATA[
$notes
      ]]></description>
      <enclosure url="$url" $signature type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF
