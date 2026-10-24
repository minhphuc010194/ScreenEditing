#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

swift build -c release

APP_DIR="${ROOT_DIR}/build/ScreenEditing.app"
ZIP_PATH="${ROOT_DIR}/build/ScreenEditing.app.zip"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${ROOT_DIR}/build/Presentify.app" "${APP_DIR}" "${ZIP_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp -f "${ROOT_DIR}/.build/release/Presentify" "${MACOS_DIR}/ScreenEditing"
chmod +x "${MACOS_DIR}/ScreenEditing"
cp -f "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp -f "${ROOT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
cp -f "${ROOT_DIR}/Resources/AppIcon.png" "${RESOURCES_DIR}/AppIcon.png"

ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "Built macOS app bundle at: ${APP_DIR}"
echo "Built release zip archive at: ${ZIP_PATH}"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/ScreenEditing.app"
    ditto "${APP_DIR}" "/Applications/ScreenEditing.app"
    echo "Installed macOS app bundle to: /Applications/ScreenEditing.app"
fi
