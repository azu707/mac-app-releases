# mac-app-releases

自作 macOS アプリの配布用リポジトリ。各アプリのソースコードは private リポジトリで管理し、ここではビルド済みバイナリと [Sparkle](https://sparkle-project.org/) の appcast だけを公開する。

## 構成

```
mac-app-releases/
├── <app-slug>/appcast.xml   # GitHub Pages で配信（SUFeedURL が参照）
└── scripts/
    ├── release-xcode.sh     # Xcode ビルド → 配布前の検証 → publish.sh → ローカルインストール
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
