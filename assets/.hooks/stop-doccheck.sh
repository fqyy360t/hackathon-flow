#!/usr/bin/env bash
# Stop hook —— Claude Code / Codex 每个用户回合收尾续跑一次自检。
# 用法: stop-doccheck.sh [claude|codex]
# 来源: project-flow 的 stop-doccheck.sh，自检文案换成黑客松版。
# 依赖: jq（缺失时静默放行，不阻塞）
tool="${1:-claude}"
input="$(cat)"

continue_safe() {
  printf '%s\n' '{"continue":true}'
  exit 0
}

codex_supports_continuation() {
  local version rest major minor patch
  version="$(codex --version 2>/dev/null | awk '{print $NF}')" || return 1
  case "$version" in
    *.*.*) ;;
    *) return 1 ;;
  esac
  major="${version%%.*}"
  rest="${version#*.}"
  minor="${rest%%.*}"
  patch="${rest#*.}"
  case "${major}:${minor}:${patch}" in
    *[!0-9:]* | :* | *: | *::* ) return 1 ;;
  esac
  [ "$major" -gt 0 ] || { [ "$major" -eq 0 ] && [ "$minor" -ge 145 ]; }
}

case "$tool" in
  claude)
    docname="CLAUDE.md"
    scope_field="prompt_id"
    ;;
  codex)
    docname="AGENTS.md"
    scope_field="turn_id"
    codex_supports_continuation || continue_safe
    ;;
  *)
    continue_safe
    ;;
esac

command -v jq >/dev/null 2>&1 || continue_safe
sid="$(printf '%s' "$input" | jq -r '
  if type == "object" and (.session_id | type) == "string"
  then .session_id else empty end
' 2>/dev/null || true)"
scope="$(printf '%s' "$input" | jq -r --arg field "$scope_field" '
  if type == "object"
    and (.[$field] | type) == "string"
    and (.[$field] | length > 0)
  then .[$field] else empty end
' 2>/dev/null || true)"
active="$(printf '%s' "$input" | jq -r '
  if type == "object" and .stop_hook_active == true then "true" else "false" end
' 2>/dev/null || echo false)"
[ -n "$sid" ] && [ -n "$scope" ] || continue_safe

case "${sid}:${scope}" in
  *[!A-Za-z0-9._:-]*) continue_safe ;;
esac
case "${UID:-}" in
  '' | *[!0-9]*) continue_safe ;;
esac
key="${#sid}-${sid}-${#scope}-${scope}"
marker_root="${TMPDIR:-/tmp}/hackathon-flow-stopcheck-${UID}"
mkdir -p "$marker_root" 2>/dev/null || continue_safe
marker="$marker_root/${tool}-${key}"

if [ "$active" = "true" ]; then
  mkdir "$marker" 2>/dev/null || true
  continue_safe
fi

if ! mkdir "$marker" 2>/dev/null; then
  [ -d "$marker" ] && continue_safe
  continue_safe
fi

reason="【收工自检】先读当前路径生效的 ${docname}；若其中有业务专项收工检查，先执行该检查且不扩大本轮授权。① 状态：本轮改过的模块，flow/claims.md 里对应的断言跑了吗？没跑就写「代码已有」，不许写「完整验收」；也不许写「已完成」。② 交接：在项目根的 flow/进展.md 最上面追加一条（做了什么 / 为什么 / 产出路径 / 状态 / 问题→解决 / 未决事项 / 下一步），并把这条贴回回复里给用户看。③ 决策与坑：改过契约或范围 → 追加 flow/decisions.md；踩过坑 → 追加 flow/踩坑记录.md。④ 若已过 F 点（提交前 7 小时），本轮只许修不许加功能。以上都没涉及就回复「无需更新」。"
jq -n --arg r "$reason" '{decision:"block", reason:$r}'
