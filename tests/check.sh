#!/usr/bin/env bash
# Checks before a commit: compile with Lua 5.1 (the WoW limits: 200 locals,
# 60 upvalues), lint with luacheck, then run the mocked-API test harness.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== luac5.1"
for file in AltersForever/*.lua; do
    luac5.1 -p "$file"
done
echo "ok"

echo "== luacheck"
luacheck --no-color -q AltersForever

echo "== harness"
lua5.1 tests/harness.lua AltersForever
