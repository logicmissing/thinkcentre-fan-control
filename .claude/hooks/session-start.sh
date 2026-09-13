#!/bin/bash
# Orientation check for Claude Code on the web.
#
# This project cannot be built or tested in a cloud session: it is a
# Windows-only .NET 8 app (WinForms, WMI, and a ring-0 driver), and the
# cloud container is Linux. So this hook does NOT install anything or
# run a build. It reports what IS true about the container, so a session
# does not spend a turn discovering it.
#
# See CLAUDE.md Section 1 for the full "what you can and cannot do here"
# statement.
set -euo pipefail

# Only run in remote (Claude Code on the web) sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "== thinkcentre-fan-control: session start check =="

if [ -d "$project_dir/.claude/rules" ]; then
  rule_count=$(find "$project_dir/.claude/rules" -name '*.md' | wc -l | tr -d ' ')
  echo "Loaded $rule_count rule file(s) from .claude/rules/."
else
  echo "WARNING: .claude/rules/ is missing."
fi

if [ -f "$project_dir/CLAUDE.md" ]; then
  echo "CLAUDE.md present - read it before changing code."
else
  echo "WARNING: CLAUDE.md is missing at the repo root."
fi

# The build toolchain. Report the real answer instead of assuming one.
if command -v dotnet >/dev/null 2>&1; then
  echo "dotnet SDK: $(dotnet --version 2>/dev/null || echo 'present, version unknown')"
  echo "NOTE: 'dotnet build' on the full solution still fails here. Tcfc.Tray and"
  echo "      Tcfc.Capture are Windows-only (WinForms/WMI). Tcfc.Core and Tcfc.Tests"
  echo "      may build, but every hardware path needs a real ThinkCentre."
else
  echo "dotnet SDK: NOT installed in this container."
  echo "      Nothing in this repo can be built or tested from this session."
  echo "      Code changes here are unverified until they are built and run on"
  echo "      Windows. Say so when handing work back - see"
  echo "      .claude/rules/coding-conventions.md, 'Done means it ran'."
fi

echo "Hardware truth lives in docs/research/ and docs/specs/ - grep it, do not guess."
