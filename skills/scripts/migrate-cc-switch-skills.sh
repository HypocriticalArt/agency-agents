#!/usr/bin/env bash
#
# migrate-cc-switch-skills.sh — Restructure agent docs for CC Switch skill repositories.
#
# Converts:
#   engineering/engineering-frontend-developer.md
# to:
#   engineering/frontend-developer/SKILL.md
#
# Frontmatter follows Agent Skills (name, description, license) with Agency metadata preserved.
#
# Usage (from skills/):
#   ./scripts/migrate-cc-switch-skills.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENT_DIRS=(
  academic design engineering finance game-development marketing paid-media product
  project-management sales spatial-computing specialized strategy support testing
)

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

get_field() {
  local field="$1" file="$2"
  awk -v f="$field" '
    /^---$/ { fm++; next }
    fm == 1 && $0 ~ "^" f ": " { sub("^" f ": ", ""); print; exit }
  ' "$file"
}

get_body() {
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$1"
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

yaml_quote() {
  local v="$1"
  v="${v//\'/\'\'}"
  printf "'%s'" "$v"
}

migrated=0
skipped=0

for dir in "${AGENT_DIRS[@]}"; do
  dirpath="$SKILLS_ROOT/$dir"
  [[ -d "$dirpath" ]] || continue

  while IFS= read -r -d '' file; do
    [[ "$(basename "$file")" == "SKILL.md" ]] && continue
    first_line="$(head -1 "$file")"
    [[ "$first_line" == "---" ]] || continue

    name="$(get_field "name" "$file")"
    description="$(get_field "description" "$file")"
    [[ -n "$name" && -n "$description" ]] || continue

    slug="$(slugify "$name")"
    [[ -n "$slug" ]] || continue

    parent="$(dirname "$file")"
    outdir="$parent/$slug"
    outfile="$outdir/SKILL.md"

    if [[ "$file" == "$outfile" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    color="$(get_field "color" "$file")"
    emoji="$(get_field "emoji" "$file")"
    vibe="$(get_field "vibe" "$file")"
    body="$(get_body "$file")"
    category="$(basename "$parent")"

    if $DRY_RUN; then
      printf '[dry-run] %s -> %s\n' "$file" "$outfile"
      migrated=$((migrated + 1))
      continue
    fi

    mkdir -p "$outdir"

    {
      printf '%s\n' '---'
      printf 'name: %s\n' "$slug"
      printf 'description: %s\n' "$(yaml_quote "$description")"
      printf 'license: MIT\n'
      printf 'metadata:\n'
      printf '  agency-name: %s\n' "$(yaml_quote "$name")"
      printf '  category: %s\n' "$category"
      [[ -n "$color" ]] && printf '  color: %s\n' "$color"
      [[ -n "$emoji" ]] && printf '  emoji: %s\n' "$(yaml_quote "$emoji")"
      [[ -n "$vibe" ]] && printf '  vibe: %s\n' "$(yaml_quote "$vibe")"
      printf '%s\n' '---'
      printf '%s' "$body"
      [[ -n "$body" && "$(tail -c1 <<< "$body")" != $'\n' ]] && printf '\n'
    } > "$outfile"

    rm "$file"
    migrated=$((migrated + 1))
  done < <(find "$dirpath" -name "*.md" -type f ! -name "SKILL.md" -print0)
done

printf 'Done: migrated=%s skipped=%s dry_run=%s\n' "$migrated" "$skipped" "$DRY_RUN"
