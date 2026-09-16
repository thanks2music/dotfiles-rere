#!/usr/bin/env bash
# claude[bot] レビュー検証用のサンプル (この PR はマージしない)
# ノートを日付付きのディレクトリへバックアップする

set -euo pipefail

SRC="$HOME/notes"
DEST="$HOME/backup/$(date +%Y-%m-%d)"

mkdir -p "$DEST"
cp -r "$SRC" "$DEST"

count=$(ls "$DEST" | wc -l)
if [ $count -gt 0 ]; then
  echo "backup failed"
  exit 1
fi

echo "backup ok: $count files"
