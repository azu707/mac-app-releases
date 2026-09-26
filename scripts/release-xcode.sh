#!/bin/bash
# Xcode プロジェクトをビルドし、検証してから publish.sh で配布する。リリースした Mac にはそのままインストールする。
#
# 使い方（アプリのプロジェクトディレクトリで実行する）:
#   release-xcode.sh --scheme <scheme> --slug <app-slug> [オプション] <version> [リリースノート]
#
# オプション:
#   --app-name <name.app>  ビルド成果物の名前（既定: <scheme>.app）
#   --build-only           ビルドと検証だけ行い、公開・インストールしない（version は省略可）
#   --no-install           公開後にこの Mac の /Applications へインストールしない
#
# 環境変数:
#   ALLOW_DIRTY=1  未コミットの変更があってもリリースする
set -euo pipefail

usage() {
    sed -n '4,13p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

SCHEME=""
SLUG=""
APP_NAME=""
BUILD_ONLY=""
INSTALL=1
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        --scheme) SCHEME="$2"; shift 2 ;;
        --slug) SLUG="$2"; shift 2 ;;
        --app-name) APP_NAME="$2"; shift 2 ;;
        --build-only) BUILD_ONLY=1; shift ;;
        --no-install) INSTALL=""; shift ;;
        -h|--help) usage ;;
        -*) echo "不明なオプション: $1" >&2; usage ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

[ -n "$SCHEME" ] && [ -n "$SLUG" ] || usage
APP_NAME="${APP_NAME:-$SCHEME.app}"
VERSION="${POSITIONAL[0]:-}"
NOTES="${POSITIONAL[1]:-}"
if [ -z "$VERSION" ]; then
    [ -n "$BUILD_ONLY" ] || usage
    VERSION="0.0.0"
fi

RELEASES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$BUILD_ONLY" ] && [ -z "${ALLOW_DIRTY:-}" ] && [ -n "$(git status --porcelain)" ]; then
    echo "未コミットの変更があります。コミットしてから実行してください（ALLOW_DIRTY=1 で無視）" >&2
    exit 1
fi

# Sparkle は CFBundleVersion で新旧を判定するため、単調増加する日時をビルド番号にする
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
BUILD_DIR="build"
APP_PATH="$PWD/$BUILD_DIR/Build/Products/Release/$APP_NAME"

rm -rf "$APP_PATH"
# Xcode の既定ではコードカバレッジ計測が Release ビルドにも入るため明示的に無効化する
xcodebuild -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    ENABLE_CODE_COVERAGE=NO \
    CLANG_COVERAGE_MAPPING=NO \
    build

# --- 配布前の検証 ---
fail() { echo "検証エラー: $1" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP_PATH/Contents/Info.plist" 2>/dev/null; }

codesign --verify --deep --strict "$APP_PATH" || fail "署名の検証に失敗しました"
TEAM_ID="$(codesign -dv "$APP_PATH" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
[ -n "$TEAM_ID" ] && [ "$TEAM_ID" != "not set" ] \
    || fail "アドホック署名です。DEVELOPMENT_TEAM を設定して Apple Development で署名してください"
[ ! -e "$APP_PATH/Contents/embedded.provisionprofile" ] \
    || fail "プロビジョニングプロファイルが埋め込まれています。登録外の Mac で起動できない可能性があります"
LOAD_COMMANDS="$(otool -l "$APP_PATH/Contents/MacOS/$(plist CFBundleExecutable)")"
[[ "$LOAD_COMMANDS" != *__llvm_prf* ]] || fail "コードカバレッジ計測が含まれています"
FEED_URL="$(plist SUFeedURL)" || fail "Info.plist に SUFeedURL がありません"
[ "$FEED_URL" = "https://azu707.github.io/mac-app-releases/$SLUG/appcast.xml" ] \
    || fail "SUFeedURL が slug と一致しません: $FEED_URL"
plist SUPublicEDKey >/dev/null || fail "Info.plist に SUPublicEDKey がありません"
[ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ] || fail "Sparkle.framework が同梱されていません"
echo "検証OK: $APP_NAME $VERSION (build $BUILD_NUMBER, team $TEAM_ID)"

if [ -n "$BUILD_ONLY" ]; then
    echo "ビルドのみ: $APP_PATH"
    exit 0
fi

"$RELEASES_ROOT/scripts/publish.sh" "$SLUG" "$APP_PATH" \
    "${NOTES:-${APP_NAME%.app} $VERSION ($(git rev-parse --short HEAD))}"

[ -n "$INSTALL" ] || exit 0

# この Mac にはそのままインストールする（他の Mac は Sparkle で更新される）
BUNDLE_NAME="${APP_NAME%.app}"
osascript -e "quit app \"$BUNDLE_NAME\"" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME"
ditto "$APP_PATH" "/Applications/$APP_NAME"
if plist NSServices >/dev/null; then
    /System/Library/CoreServices/pbs -update
fi
open "/Applications/$APP_NAME"
echo "$APP_NAME $VERSION を /Applications にインストールしました"
