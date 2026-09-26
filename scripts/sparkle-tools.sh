#!/bin/bash
# Sparkle のコマンドラインツール（sign_update, generate_keys 等）を取得し、bin ディレクトリのパスを出力する。
# 使い方: SPARKLE_BIN="$(scripts/sparkle-tools.sh)"
set -euo pipefail

SPARKLE_VERSION="${SPARKLE_VERSION:-2.10.0}"
CACHE_DIR="$HOME/Library/Caches/mac-app-releases/Sparkle-$SPARKLE_VERSION"

if [ ! -x "$CACHE_DIR/bin/sign_update" ]; then
    mkdir -p "$CACHE_DIR"
    url="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
    echo "Sparkle $SPARKLE_VERSION のツールを取得中: $url" >&2
    curl -fsSL "$url" | tar -xJ -C "$CACHE_DIR"
fi

echo "$CACHE_DIR/bin"
