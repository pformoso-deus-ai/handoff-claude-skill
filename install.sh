#!/usr/bin/env bash
#
# handoff skill installer (macOS / Linux)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.sh)"
#
# To install a specific branch, tag, or commit:
#   HANDOFF_REF=v0.1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.sh)"

set -euo pipefail

REPO="pformoso-deus-ai/handoff-claude-skill"
REF="${HANDOFF_REF:-main}"
SKILL_NAME="handoff"
SKILL_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

# Files to install: each entry is "<repo-relative source>:<skill-relative target>".
# Add entries here when the skill grows beyond a single SKILL.md.
FILES=(
  "handoff/SKILL.md:SKILL.md"
)

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required but not installed" >&2
  exit 1
fi

first_install=true
[ -f "${SKILL_DIR}/SKILL.md" ] && first_install=false

mkdir -p "${SKILL_DIR}"

base="https://raw.githubusercontent.com/${REPO}/${REF}"

for entry in "${FILES[@]}"; do
  src="${entry%%:*}"
  dst="${entry#*:}"
  target="${SKILL_DIR}/${dst}"
  target_dir="$(dirname "${target}")"
  mkdir -p "${target_dir}"

  echo "downloading ${src} -> ${target}"
  tmpfile="$(mktemp)"
  trap 'rm -f "${tmpfile}"' EXIT

  if curl -fsSL "${base}/${src}" -o "${tmpfile}"; then
    mv "${tmpfile}" "${target}"
    trap - EXIT
  else
    rm -f "${tmpfile}"
    echo "error: failed to download ${src} from ${base}" >&2
    exit 1
  fi
done

echo
echo "Installed handoff skill to ${SKILL_DIR}"

if [ "${first_install}" = true ]; then
  cat <<EOF

First-time install detected. Restart Claude Code (or close and reopen any
session) so the file watcher picks up the new skill directory. After that,
edits to the skill hot-reload mid-session.
EOF
else
  echo
  echo "Update applied. Open sessions hot-reload — no restart needed."
fi
