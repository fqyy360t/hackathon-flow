#!/bin/sh
# 一条命令装好本仓库的 git 钩子。在新机器 clone 之后跑一次。
#   sh scripts/install-hooks.sh
# 幂等：重复跑没有副作用。

set -e
cd "$(dirname "$0")/.."

if [ ! -f .githooks/pre-push ]; then
  echo "找不到 .githooks/pre-push，先确认这个文件在仓库里"
  exit 1
fi

# Windows 上被 checkout 成 CRLF 会让 sh 报 '\r: command not found'，先修
if grep -q $'\r' .githooks/pre-push 2>/dev/null; then
  echo "检测到 CRLF，转成 LF……"
  sed -i 's/\r$//' .githooks/pre-push
fi

chmod +x .githooks/pre-push
git config core.hooksPath .githooks

echo "✅ 钩子已装：core.hooksPath = $(git config core.hooksPath)"
echo "   直推 main 会被拦（紧急通道：ALLOW_MAIN_PUSH=1 git push origin main）"
