#!/bin/bash
export SUPACODE_TAB_ID="$1"
case "$2" in
  agent) sleep 86400 | claude mcp serve >/dev/null 2>&1 & ;;
  codex) (exec -a codex sleep 86400) & ;;
esac
sleep 86400 &
wait
