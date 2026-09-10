#!/bin/bash
cd "$(dirname "$0")" || exit 1
bash scripts/upload-appstore.sh
result=$?
if [[ $result -ne 0 ]]; then
  echo "アップロード処理を完了できませんでした（終了コード: $result）。上の内容を確認してください。"
fi
read -r -p 'Enterキーで閉じます…'
exit "$result"
