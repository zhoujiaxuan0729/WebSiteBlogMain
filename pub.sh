#!/data/data/com.termux/files/usr/bin/bash
# 一键发布脚本：git add + commit + push
# 用法：
#   ./pub.sh                    # 自动用时间戳做提交说明
#   ./pub.sh "写了新文章xxx"     # 自定义提交说明

set -e

cd "$(dirname "$0")"

if [ -n "$1" ]; then
  MSG="$1"
else
  MSG="update $(date +%Y-%m-%d_%H:%M)"
fi

echo "==> 检查是否有未提交的改动..."
if git diff --quiet && git diff --cached --quiet; then
  echo "没有改动，不用发布。"
  exit 0
fi

echo "==> 添加所有改动"
git add .

echo "==> 提交：$MSG"
git commit -m "$MSG"

echo "==> 推送到 GitHub"
git push

echo ""
echo "完成。GitHub Actions 会在 30 秒左右自动部署上线。"
echo "查看进度：https://github.com/你的用户名/blog/actions"
