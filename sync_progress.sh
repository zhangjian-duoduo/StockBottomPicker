#!/bin/bash
# 自动更新项目进度并同步到GitHub
# 用法: ./sync_progress.sh "提交信息"

cd "$(dirname "$0")"

MSG="${1:-更新项目进度 $(date '+%Y-%m-%d %H:%M')}"

# 添加所有更改
git add -A

# 检查是否有更改
if git diff --cached --quiet; then
    echo "没有更改需要提交"
    exit 0
fi

# 提交
git commit -m "$MSG"

# 推送到GitHub
git push origin main

echo "已同步到GitHub"
