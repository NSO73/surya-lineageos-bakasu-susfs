#!/usr/bin/env bash
# Resolve the latest upstream refs and rewrite versions.env when something moved.
# Usage: scripts/check-upstreams.sh [versions.env] [changelog.md]
# Needs an authenticated gh. Last stdout line: changed=true|false
# KSU_PRERELEASE=1 (default) also accepts pre-release tags of KSU_REPO.
set -euo pipefail

VERSIONS=${1:-versions.env}
CHANGELOG=${2:-changelog.md}
KSU_PRERELEASE=${KSU_PRERELEASE:-1}

# shellcheck disable=SC1090
source "$VERSIONS"

head_of() { gh api "repos/$1/commits/$2" -q .sha; }

latest_ksu_tag() {
  local filter='[.[] | select(.draft | not)'
  [ "$KSU_PRERELEASE" = 1 ] || filter+=' | select(.prerelease | not)'
  gh api "repos/$KSU_REPO/releases?per_page=30" -q "$filter][0].tag_name"
}

declare -A NEW REPO
NEW[KERNEL_COMMIT]=$(head_of "$KERNEL_REPO" "$KERNEL_BRANCH");  REPO[KERNEL_COMMIT]=$KERNEL_REPO
NEW[KSU_TAG]=$(latest_ksu_tag);                                 REPO[KSU_TAG]=$KSU_REPO
NEW[NONGKI_COMMIT]=$(head_of "$NONGKI_REPO" "$NONGKI_BRANCH");  REPO[NONGKI_COMMIT]=$NONGKI_REPO
NEW[AK3_COMMIT]=$(head_of "$AK3_REPO" "$AK3_BRANCH");           REPO[AK3_COMMIT]=$AK3_REPO
NEW[CLANG_COMMIT]=$(head_of "$CLANG_REPO" "$CLANG_BRANCH");     REPO[CLANG_COMMIT]=$CLANG_REPO

changed=false
rows=()
for key in KERNEL_COMMIT KSU_TAG NONGKI_COMMIT AK3_COMMIT CLANG_COMMIT; do
  old=${!key}
  new=${NEW[$key]}
  if [ -z "$new" ] || [ "$new" = null ]; then
    echo "!! could not resolve $key from ${REPO[$key]}" >&2
    exit 1
  fi
  [ "$old" = "$new" ] && continue
  changed=true
  sed -i "s|^$key=.*|$key=$new|" "$VERSIONS"
  rows+=("| \`$key\` | \`${old:0:12}\` | [\`${new:0:12}\`](https://github.com/${REPO[$key]}/compare/$old...$new) |")
done

# A newer LineageOS branch means a new ROM major version: report it, never switch automatically.
newer_branches=$(gh api "repos/$KERNEL_REPO/branches?per_page=100" -q '.[].name' \
  | grep -E '^lineage-[0-9]+(\.[0-9]+)?$' | sort -V | awk -v cur="$KERNEL_BRANCH" 'f; $0 == cur { f = 1 }')

{
  if [ "$changed" = true ]; then
    echo "| Component | Before | After |"
    echo "|---|---|---|"
    printf '%s\n' "${rows[@]}"
  else
    echo "No new upstream version."
  fi
  if [ -n "$newer_branches" ]; then
    echo
    echo "> [!NOTE]"
    echo "> Newer kernel branch(es): $(echo "$newer_branches" | tr '\n' ' ')— switch \`KERNEL_BRANCH\` by hand once the ROM moves to that version."
  fi
} > "$CHANGELOG"

echo "changed=$changed"
