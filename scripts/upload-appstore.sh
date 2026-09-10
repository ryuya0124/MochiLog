#!/bin/bash
# Upload the current committed branch to App Store Connect through GitHub Actions.
# Prerequisites: GitHub CLI (gh), gh auth login, and configured repository secrets.
# Usage: bash scripts/upload-appstore.sh [build-number]
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")/.."
command -v gh >/dev/null || { echo 'GitHub CLI (gh) が必要です。brew install gh を実行してください。'; exit 1; }
gh auth status >/dev/null 2>&1 || { echo '先に gh auth login を実行してください。'; exit 1; }
if [[ -n "$(git status --porcelain)" ]]; then
  echo '未コミットの変更があります。アップロードしたい変更をコミットしてから再実行してください。'
  exit 1
fi
branch=$(git symbolic-ref --quiet --short HEAD) || { echo 'ブランチをチェックアウトしてください。'; exit 1; }

if [[ -n "${1:-}" ]]; then
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || { echo 'ビルド番号は正の整数にしてください。'; exit 1; }
fi
# Only committed changes are pushed. No force push or automatic staging.
git push origin "HEAD:refs/heads/$branch"
sha=$(git rev-parse HEAD)
previous=$(gh run list --workflow ios.yml --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId // 0')
if [[ -n "${1:-}" ]]; then
  gh workflow run ios.yml --ref "$branch" -f upload_to_testflight=true -f "build_number=$1"
else
  gh workflow run ios.yml --ref "$branch" -f upload_to_testflight=true
fi
echo 'アップロード処理を開始しました。実行IDを取得しています…'
run_id=''
for ((attempt=0; attempt<30; attempt++)); do
  run_id=$(gh run list --workflow ios.yml --branch "$branch" --event workflow_dispatch --limit 10 --json databaseId,headSha --jq ".[] | select(.headSha == \"$sha\" and .databaseId > $previous) | .databaseId" | head -1)
  [[ -n "$run_id" ]] && break
  sleep 2
done
[[ -n "$run_id" ]] || { echo '開始済みですが実行IDを取得できませんでした。GitHub Actionsで状況を確認してください。'; exit 1; }
echo "https://github.com/$(gh repo view --json nameWithOwner --jq .nameWithOwner)/actions/runs/$run_id"
gh run watch "$run_id" --interval 30 --exit-status
echo 'App Store Connectへのアップロード完了。Apple側の処理後にビルドを選択できます。審査提出は別途必要です。'
