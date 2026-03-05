#!/usr/bin/env python3
"""Figma URLまたはNode IDからfile_keyとnode_idを抽出する。

Usage:
  python scripts/parse-figma-url.py <figma_url_or_node_id> [file_key]

Examples:
  # Full URL
  python scripts/parse-figma-url.py "https://www.figma.com/design/ABC123/MyFile?node-id=1-2&t=xxx"

  # Node ID only (file_key required)
  python scripts/parse-figma-url.py "1:2" "ABC123"
  python scripts/parse-figma-url.py "1-2" "ABC123"

Output (JSON):
  {"file_key": "ABC123", "node_id": "1:2", "figma_url": "https://www.figma.com/design/ABC123?node-id=1-2"}
"""

import json
import re
import sys
from urllib.parse import parse_qs, urlparse


def parse_figma_input(input_str: str, file_key_arg: str | None = None) -> dict:
    """Parse Figma URL or node ID into structured data."""
    input_str = input_str.strip()

    # Pattern: Full Figma URL
    url_pattern = re.compile(
        r"https?://(?:www\.)?figma\.com/(?:design|file|proto)/([a-zA-Z0-9]+)"
    )
    url_match = url_pattern.match(input_str)

    if url_match:
        file_key = url_match.group(1)
        parsed = urlparse(input_str)
        params = parse_qs(parsed.query)
        node_id_raw = params.get("node-id", [None])[0]

        if not node_id_raw:
            return {"error": "URL にnode-idパラメータがありません", "input": input_str}

        # Figma URLs use "-" but API uses ":"
        node_id = node_id_raw.replace("-", ":")
        return {
            "file_key": file_key,
            "node_id": node_id,
            "figma_url": f"https://www.figma.com/design/{file_key}?node-id={node_id_raw}",
        }

    # Pattern: Raw node ID (e.g., "1:2" or "1-2")
    node_pattern = re.compile(r"^(\d+)[:\-](\d+)$")
    node_match = node_pattern.match(input_str)

    if node_match:
        if not file_key_arg:
            return {
                "error": "Node IDのみの場合、第2引数にfile_keyが必要です",
                "input": input_str,
            }
        node_id = f"{node_match.group(1)}:{node_match.group(2)}"
        node_id_url = f"{node_match.group(1)}-{node_match.group(2)}"
        return {
            "file_key": file_key_arg,
            "node_id": node_id,
            "figma_url": f"https://www.figma.com/design/{file_key_arg}?node-id={node_id_url}",
        }

    return {
        "error": "無効な入力です。Figma URLまたはNode ID (例: 1:2) を指定してください",
        "input": input_str,
    }


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "引数が必要です。Figma URLまたはNode IDを指定してください"}, ensure_ascii=False))
        sys.exit(1)

    input_str = sys.argv[1]
    file_key_arg = sys.argv[2] if len(sys.argv) > 2 else None

    result = parse_figma_input(input_str, file_key_arg)

    print(json.dumps(result, ensure_ascii=False))
    if "error" in result:
        sys.exit(1)


if __name__ == "__main__":
    main()
