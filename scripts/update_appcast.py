#!/usr/bin/env python3
"""Sparkle の appcast.xml に新しいバージョンの item を先頭に追加する（ファイルが無ければ作成する）。"""
import argparse
import html
import os
from email.utils import formatdate

TEMPLATE = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>{app_name}</title>
    </channel>
</rss>
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--appcast", required=True)
    parser.add_argument("--app-name", required=True)
    parser.add_argument("--short-version", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--minimum-system-version", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--signature-attrs", required=True)
    parser.add_argument("--notes", default="")
    args = parser.parse_args()

    if os.path.exists(args.appcast):
        with open(args.appcast, encoding="utf-8") as f:
            content = f.read()
    else:
        content = TEMPLATE.format(app_name=html.escape(args.app_name))

    description = ""
    if args.notes:
        notes = html.escape(args.notes).replace("\n", "<br>")
        description = f"\n            <description><![CDATA[{notes}]]></description>"

    item = f"""        <item>
            <title>{html.escape(args.short_version)}</title>
            <pubDate>{formatdate(usegmt=True)}</pubDate>
            <sparkle:version>{html.escape(args.version)}</sparkle:version>
            <sparkle:shortVersionString>{html.escape(args.short_version)}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>{html.escape(args.minimum_system_version)}</sparkle:minimumSystemVersion>{description}
            <enclosure url="{html.escape(args.url)}" type="application/octet-stream" {args.signature_attrs.strip()}/>
        </item>
"""

    # 新しい item を既存の先頭 item の前（無ければ </channel> の前）に挿入する
    marker = "        <item>" if "<item>" in content else "    </channel>"
    index = content.index(marker)
    content = content[:index] + item + content[index:]

    with open(args.appcast, "w", encoding="utf-8") as f:
        f.write(content)


if __name__ == "__main__":
    main()
