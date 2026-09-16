#!/usr/bin/env bash
# claude[bot] レビュー検証用のサンプル (この PR はマージしない)
# 指定したキャッシュディレクトリを削除する

CACHE_DIR=$1

rm -rf $CACHE_DIR/*

for f in $(ls $HOME/Downloads/*.tmp); do
  rm $f
done

echo "done"
