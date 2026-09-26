# mac-app-releases

自作 macOS アプリの配布用リポジトリ。各アプリのソースコードは private リポジトリで管理し、ここではビルド済みバイナリと [Sparkle](https://sparkle-project.org/) の appcast だけを公開する。

## 構成

```
mac-app-releases/
├── <app-slug>/appcast.xml   # GitHub Pages で配信（SUFeedURL が参照）
└── scripts/
    ├── publish.sh           # zip 化 → EdDSA 署名 → GitHub Release 作成 → appcast 更新・push
    ├── update_appcast.py    # appcast.xml への item 追加
    └── sparkle-tools.sh     # Sparkle CLI ツールの取得（~/Library/Caches にキャッシュ）
```

- バイナリ: GitHub Releases（タグ `<app-slug>-v<version>`）
- appcast: `https://azu707.github.io/mac-app-releases/<app-slug>/appcast.xml`

## 配布中のアプリ

| アプリ | slug | appcast |
|---|---|---|
| TextProcessor | `textprocessor` | [appcast.xml](https://azu707.github.io/mac-app-releases/textprocessor/appcast.xml) |

## 新しいアプリを追加する手順

1. EdDSA 鍵を生成する（アプリごとに別の鍵）

   ```bash
   "$(scripts/sparkle-tools.sh)/generate_keys" --account <app-slug>
   ```

   秘密鍵をエクスポートしてパスワードマネージャーに保管する（紛失すると既存アプリへ更新を配信できなくなる）。

   ```bash
   "$(scripts/sparkle-tools.sh)/generate_keys" --account <app-slug> -x <app-slug>-private-key.txt
   ```

2. アプリに Sparkle（SPM: `https://github.com/sparkle-project/Sparkle`）を追加し、Info.plist に以下を設定する

   - `SUFeedURL`: `https://azu707.github.io/mac-app-releases/<app-slug>/appcast.xml`
   - `SUPublicEDKey`: 手順 1 で表示された公開鍵
   - 署名は Apple Development（Personal Team）に固定する。署名 ID が変わると Sparkle が更新を拒否する

3. リリース時はバージョン（`CFBundleShortVersionString`）と単調増加するビルド番号（`CFBundleVersion`）を付けてビルドし、公開する

   ```bash
   scripts/publish.sh <app-slug> path/to/App.app "リリースノート"
   ```

## 別の Mac でリリース作業をする場合

普段リリースしない Mac では不要。

1. アプリのソースリポジトリと本リポジトリを `~/repos` に clone する
2. パスワードマネージャーに保管した秘密鍵をファイルに書き出し、キーチェーンに取り込む（取り込んだらファイルは削除する）

   ```bash
   "$(scripts/sparkle-tools.sh)/generate_keys" --account <app-slug> -f <app-slug>-private-key.txt
   ```

3. Xcode に Apple ID でサインインしておく（Personal Team で署名するため）
