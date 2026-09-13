#!/bin/bash
# SessionStart hook: cheap staleness check for the /dream memory-
# consolidation pass. This hook never runs the consolidation itself --
# it only tells the operator when one is due, for zero LLM cost.
#
# Why SessionStart and not Stop: a Stop hook's stdout goes only to the
# debug log -- it is never shown to the operator or to Claude. Only
# UserPromptSubmit, UserPromptExpansion, SessionStart, and
# PostModelSwitch have their stdout added as visible context. This hook
# used to be a Stop hook and its reminder was never actually seen.
#
# Why there is no state file: the operator works exclusively in Claude
# Code on the web. Every cloud session runs in a fresh, ephemeral
# container -- the repo is cloned new at session start and the container
# is destroyed afterward. A gitignored runtime-state file (this hook's
# old design) never survives to the next session, so a clock kept there
# could never advance -- the reminder could never fire. Instead
# this hook derives staleness from content git actually carries: the
# newest committed /dream proposal file, and the commits logged since
# it. A project with no proposal file yet is never nagged -- see below.
#
# See .claude/commands/dream.md for the actual pipeline, and
# .claude/docs/reviewed-tools.md for where this pattern came from.

# Both gates below must be satisfied before the reminder fires. Each is
# a one-line edit if the operator wants it more or less sensitive.
STALE_AFTER_DAYS=7
MIN_COMMITS_SINCE=5

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# This is a SessionStart hook -- it must never disrupt session startup.
# No set -e: every command that can fail is checked explicitly below,
# and every exit path is an explicit "exit 0".

# Read the project timezone from the single shared constants file
# instead of hardcoding it here. This constant used to be duplicated
# in this hook and in versioning-and-archival.md, and the two copies
# drifted apart -- that is bug class 1 in bug-class-checks.md. Parse
# the value with grep/sed rather than "source"-ing the file: running
# a hook at every session start should never execute an arbitrary
# config file as code.
project_tz="Asia/Singapore"
env_file="$project_dir/.claude/project.env"
if [ -r "$env_file" ]; then
  parsed_tz="$(grep '^PROJECT_TZ=' "$env_file" 2>/dev/null | head -n 1 | sed 's/^PROJECT_TZ=//')"
  # Only accept a zone the system actually knows. An unknown name --
  # a typo like "Asia/Singapor" -- makes date fall back to UTC without
  # reporting anything, which would silently shift every timestamp by
  # the real offset. That is bug class 1: a plausible number that is
  # simply wrong. Keep the declared default instead.
  if [ -n "$parsed_tz" ] && [ -f "/usr/share/zoneinfo/$parsed_tz" ]; then
    project_tz="$parsed_tz"
  fi
fi

now_epoch=$(date +%s 2>/dev/null)
if [ -z "$now_epoch" ]; then
  exit 0
fi

# Find the newest committed /dream proposal file by filename, not
# mtime -- mtime is reset by a fresh clone and is worthless here. A
# glob (not "ls | head") plus sort -r works because the timestamp
# format is zero-padded and therefore sorts correctly as text.
shopt -s nullglob
proposals=("$project_dir"/.claude/docs/dream-proposal-*.md)
shopt -u nullglob

newest=""
if [ ${#proposals[@]} -gt 0 ]; then
  newest="$(printf '%s\n' "${proposals[@]}" | sort -r | head -n 1)"
fi

# /dream is opt-in: a project that has never run one is never nagged
# about it. If no proposal file has ever been committed, there is
# nothing to measure staleness against -- exit quietly.
if [ -z "$newest" ]; then
  exit 0
fi

event_epoch=""

# Parse the yyyy_mm_dd_hh_mm_ss timestamp out of the filename itself --
# not the file's mtime, per above.
base="${newest##*/}"
ts="${base#dream-proposal-}"
ts="${ts%.md}"

if [[ "$ts" =~ ^([0-9]{4})_([0-9]{2})_([0-9]{2})_([0-9]{2})_([0-9]{2})_([0-9]{2})$ ]]; then
  y="${BASH_REMATCH[1]}"
  m="${BASH_REMATCH[2]}"
  d="${BASH_REMATCH[3]}"
  hh="${BASH_REMATCH[4]}"
  mm="${BASH_REMATCH[5]}"
  ss="${BASH_REMATCH[6]}"
  # Parse in the same timezone the filename was written in --
  # PROJECT_TZ, read above. Parsing it as the container's local time
  # (UTC in a cloud session) would make every pass look hours newer
  # than it is. Note: "date -d" is a GNU extension. On a non-GNU date
  # this returns empty and the hook exits quietly below, which is the
  # intended safe failure.
  event_epoch=$(TZ="$project_tz" date -d "${y}-${m}-${d} ${hh}:${mm}:${ss}" +%s 2>/dev/null)
else
  # Filename doesn't match the expected pattern -- say nothing rather
  # than report something wrong.
  exit 0
fi

case "$event_epoch" in
  ''|*[!0-9]*)
    # Not a git repo, no commits, git missing, or a bad parse -- exit
    # quietly rather than report something wrong.
    exit 0
    ;;
esac

elapsed=$((now_epoch - event_epoch))
days=$((elapsed / 86400))
threshold=$((STALE_AFTER_DAYS * 86400))

if [ "$elapsed" -lt "$threshold" ]; then
  exit 0
fi

# Elapsed calendar time alone doesn't mean anything changed -- also
# require real commit activity since the last proposal. git's
# --since wants a numeric offset (e.g. +0800), not a zone name, so
# derive one from PROJECT_TZ rather than hardcoding it -- this is
# the same value used for the date -d parse above, so git reads the
# same instant the filename encodes.
tz_offset=$(TZ="$project_tz" date +%z 2>/dev/null)
if [ -z "$tz_offset" ]; then
  tz_offset="+0800"
fi
commits=$(git -C "$project_dir" log --since="${y}-${m}-${d} ${hh}:${mm}:${ss} ${tz_offset}" --oneline 2>/dev/null | wc -l | tr -d ' ')

case "$commits" in
  ''|*[!0-9]*)
    # git missing, not a repo, or a bad count -- treat as no activity.
    commits=0
    ;;
esac

if [ "$commits" -lt "$MIN_COMMITS_SINCE" ]; then
  exit 0
fi

echo "[dream-check] ${days} day(s) and ${commits} commit(s) since the last /dream pass. Consider running /dream to consolidate memory. This is a reminder only - nothing runs automatically."

exit 0
