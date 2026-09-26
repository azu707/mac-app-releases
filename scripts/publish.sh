#!/bin/bash
# ビルド済みの .app を zip 化して GitHub Release に公開し、Sparkle の appcast.xml を更新する。
#
# 使い方: scripts/publish.sh <app-slug> <path/to/App.app> [リリースノート]
#   app-slug: 配布用の識別子（小文字）。タグ名・appcast のディレクトリ・EdDSA 鍵のアカウント名に使う
#
# 前提:
#   - generate_keys --account <app-slug> で EdDSA 鍵がキーチェーンに登録済み
#   - gh コマンドでログイン済み
set -euo pipefail

SLUG="${1:?使い方: scripts/publish.sh <app-slug> <path/to/App.app> [リリースノート]}"
APP_PATH="${2:?使い方: scripts/publish.sh <app-slug> <path/to/App.app> [リリースノート]}"
NOTES="${3:-}"

REPO="azu707/mac-app-releases"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPARKLE_BIN="$("$ROOT/scripts/sparkle-tools.sh")"

plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP_PATH/Contents/Info.plist"; }
APP_NAME="$(plist CFBundleName)"
SHORT_VERSION="$(plist CFBundleShortVersionString)"
BUILD_VERSION="$(plist CFBundleVersion)"
MIN_SYSTEM="$(plist LSMinimumSystemVersion)"
TAG="$SLUG-v$SHORT_VERSION"
ZIP_NAME="$APP_NAME-$SHORT_VERSION.zip"

cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
    echo "mac-app-releases に未コミットの変更があります" >&2
    exit 1
fi
git pull --ff-only --quiet

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "リリース $TAG は既に存在します。バージョンを上げてください" >&2
    exit 1
fi

# 署名が壊れていないことを確認してから配布する
codesign --verify --deep --strict "$APP_PATH"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
ZIP_PATH="$WORK_DIR/$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# 出力例: sparkle:edSignature="..." length="..."
SIGNATURE_ATTRS="$("$SPARKLE_BIN/sign_update" --account "$SLUG" "$ZIP_PATH")"

echo "GitHub Release $TAG を作成中..."
gh release create "$TAG" "$ZIP_PATH" \
    --repo "$REPO" \
    --title "$APP_NAME $SHORT_VERSION" \
    --notes "${NOTES:-$APP_NAME $SHORT_VERSION (build $BUILD_VERSION)}"

mkdir -p "$SLUG"
python3 "$ROOT/scripts/update_appcast.py" \
    --appcast "$SLUG/appcast.xml" \
    --app-name "$APP_NAME" \
    --short-version "$SHORT_VERSION" \
    --version "$BUILD_VERSION" \
    --minimum-system-version "$MIN_SYSTEM" \
    --url "https://github.com/$REPO/releases/download/$TAG/$ZIP_NAME" \
    --signature-attrs "$SIGNATURE_ATTRS" \
    --notes "$NOTES"

git add "$SLUG/appcast.xml"
git commit --quiet -m "$APP_NAME $SHORT_VERSION"
git push --quiet

echo "公開しました: $APP_NAME $SHORT_VERSION (build $BUILD_VERSION)"
echo "appcast: https://azu707.github.io/mac-app-releases/$SLUG/appcast.xml"
