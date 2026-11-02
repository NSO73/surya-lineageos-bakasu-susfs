#!/usr/bin/env bash
# Markdown "changes since the previous release" section for the release notes.
# Usage: release-changes.sh REPO PREV_TAG CUR_SHA
# Needs an authenticated gh. Compares the versions.env pins of both commits (read from
# GitHub, not the working tree) and lists the upstream commit subjects of what moved.
set -euo pipefail

REPO=$1
PREV=$2
CUR=$3
MAX=15

declare -A LABEL=([KERNEL]='LineageOS kernel' [KSU]='ReSukiSU / BakaSU' [NONGKI]='SUSFS (NonGKI)'
                  [AK3]='AnyKernel3' [CLANG]='Toolchain')
# Multi-purpose repos: list only commits touching what the build uses (same scope as check-upstreams.sh)
declare -A PATHS=([NONGKI]='Patches/Patch/susfs_patch_to_4.14.patch Patches/susfs_inline_hook_patches.sh')

pins() {
  gh api "repos/$REPO/contents/versions.env?ref=$1" -H 'Accept: application/vnd.github.raw' \
    | grep -E '^[A-Z0-9_]+='
}

# log_of REPO OLD NEW PATHS: "sha<TAB>subject" lines, newest first
log_of() {
  local since p
  if [ -n "$4" ]; then
    since=$(gh api "repos/$1/commits/$2" -q .commit.committer.date)
    for p in $4; do
      gh api "repos/$1/commits?sha=$3&path=$p&since=$since&per_page=100" \
        -q '.[] | [.commit.committer.date, .sha, (.commit.message | split("\n")[0])] | @tsv'
    done | sort -ru | awk -F'\t' -v old="$2" '$2 != old' | cut -f2-
  else
    gh api "repos/$1/compare/$2...$3" \
      -q '.commits | reverse | .[] | [.sha, (.commit.message | split("\n")[0])] | @tsv'
  fi
}

# print_log REPO: "- subject (sha)" bullets from stdin, capped at MAX
print_log() {
  local -a log
  mapfile -t log
  local l
  for l in "${log[@]:0:MAX}"; do
    echo "- ${l#*$'\t'} ([\`${l:0:7}\`](https://github.com/$1/commit/${l%%$'\t'*}))"
  done
  if (( ${#log[@]} > MAX )); then
    echo "- … $(( ${#log[@]} - MAX )) more in the diff"
  fi
}

declare -A OLD NEW
prev_sha=$(gh api "repos/$REPO/commits/$PREV" -q .sha)
while IFS='=' read -r k v; do OLD[$k]=$v; done < <(pins "$prev_sha")
while IFS='=' read -r k v; do NEW[$k]=$v; done < <(pins "$CUR")

echo "### Changes since [\`$PREV\`](https://github.com/$REPO/releases/tag/$PREV)"
moved=0
for c in KERNEL KSU NONGKI AK3 CLANG; do
  repo=${NEW[${c}_REPO]}
  for k in "${c}_BRANCH" "${c}_COMMIT" "${c}_TAG"; do
    old=${OLD[$k]:-}
    new=${NEW[$k]:-}
    [ -n "$new" ] && [ "$old" != "$new" ] || continue
    moved=1
    echo
    if [[ $k == *_BRANCH ]]; then
      echo "**${LABEL[$c]}**: branch \`$old\` → \`$new\`"
      continue
    fi
    echo "**${LABEL[$c]}** \`${old:0:12}\` → \`${new:0:12}\` ([diff](https://github.com/$repo/compare/$old...$new))"
    echo
    log_of "$repo" "$old" "$new" "${PATHS[$c]:-}" | print_log "$repo"
  done
done
if (( ! moved )); then
  echo
  echo "No upstream version moved."
fi

# this repo's own commits, minus the automatic bumps already described above
if [ "$prev_sha" != "$CUR" ]; then
  own=$(gh api "repos/$REPO/compare/$prev_sha...$CUR" \
    -q '.commits | reverse | .[] | select(.commit.message | startswith("Bump upstream versions") | not)
        | [.sha, (.commit.message | split("\n")[0])] | @tsv')
  if [ -n "$own" ]; then
    echo
    echo "**This repository** ([diff](https://github.com/$REPO/compare/$prev_sha...$CUR))"
    echo
    print_log "$REPO" <<< "$own"
  fi
fi
