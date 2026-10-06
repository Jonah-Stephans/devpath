#!/bin/sh
# devpath — the cross-spec contention checkpoint, run against a real repository.
#
# One of the two tests here that run code rather than reading prose, with
# tests/pr-body.sh. This one needs it most:
# scripts/contention.sh exits 0 on every route by design, so a broken awk does
# not fail, it reports no collisions — forever, silently, and indistinguishably
# from a clean run. Nothing in a spec, a hook or a diff would ever show it.
#
# Three scenarios over one fixture, built up in order:
#   1. two unmerged specs touching one file and quoting one upstream — both
#      collisions reported, with the neighbour's intent
#   2. the same pair, retargeted — nothing reported
#   3. the neighbour merged to base and its branch pushed again — nothing
#      reported, which is rule 4: a merged spec is never a neighbour
#
# Exit code is the build's. The script's own exit code is asserted to be 0 in
# every scenario, because a contention report that can fail is a gate nobody
# decided to add.

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
SCRIPT="$ROOT/scripts/contention.sh"

[ -f "$SCRIPT" ] || { echo "FAIL subject: $SCRIPT does not exist"; exit 1; }

FAIL=0
SHARED=force-app/main/default/classes/Shared.cls
OTHER=force-app/main/default/classes/Other.cls
URL=https://example.test/browse/ABC-1

want() {    # want <scenario> <output> <fragment>
  printf '%s' "$2" | grep -qF "$3" || {
    echo "FAIL [$1] the report does not carry: $3"
    FAIL=1
  }
}
want_empty() {  # want_empty <scenario> <output>
  [ -z "$2" ] || {
    echo "FAIL [$1] expected no collisions, got:"
    printf '%s\n' "$2" | sed 's/^/      /'
    FAIL=1
  }
}
want_zero() {   # want_zero <scenario> <code>
  [ "$2" -eq 0 ] || {
    echo "FAIL [$1] the checkpoint exited $2, and it exits 0 on every route"
    FAIL=1
  }
}

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT INT TERM

git init -q --bare "$T/origin.git" || exit 1
git init -q "$T/work" || exit 1
cd "$T/work" || exit 1
git symbolic-ref HEAD refs/heads/main
git config user.email devpath-test@example.test
git config user.name devpath-test
git config commit.gpgsign false
git remote add origin "$T/origin.git"

# A spec directory as Slice would leave it: front matter between the first two
# --- lines, one upstream url, one slice with one touches value.
mkspec() {  # mkspec <slug> <touches> <url> <intent first sentence>
  mkdir -p "devpath/$1/slices"
  cat > "devpath/$1/spec.md" <<EOF
---
type: feature
upstream:
  - url: $3
    read_at: 2026-08-26
intent_accepted: true
---

# $1

## Intent
$4 A second sentence, which the report must cut.

## Outcomes
EOF
  cat > "devpath/$1/slices/01-one.md" <<EOF
---
touches:
  - $2
done: false
---

# One
EOF
}

save() { git add -A && git commit -qm "$1"; }

echo base > README.md
save base
git push -q -u origin main

git checkout -q -b spec-a main
mkspec spec-a "$SHARED" "$URL" "Spec A raises the tolerance ceiling."
save spec-a
git push -q origin spec-a

git checkout -q -b spec-b main
mkspec spec-b "$SHARED" "$URL" "Spec B rewrites the same service."
save spec-b
git push -q origin spec-b

# --- 1. the collision, seen from spec-a -------------------------------------
git checkout -q spec-a
OUT=$(sh "$SCRIPT" origin main 2>/dev/null); CODE=$?

want_zero collision "$CODE"
want collision "$OUT" 'touches:'
want collision "$OUT" "$SHARED"
want collision "$OUT" 'upstream:'
want collision "$OUT" "$URL"
want collision "$OUT" '  spec-a'
want collision "$OUT" '  spec-b'
# The neighbour list, and the first SENTENCE of its Intent rather than its first
# line — the awk that cuts it is the fiddliest thing in the script.
want collision "$OUT" 'in flight:'
want collision "$OUT" '  spec-b — Spec B rewrites the same service.'
printf '%s' "$OUT" | grep -qF 'which the report must cut' && {
  echo "FAIL [collision] the neighbour's intent was not cut at the first sentence"
  FAIL=1
}

# --- 2. retargeted, so there is nothing to report ---------------------------
git checkout -q spec-b
mkspec spec-b "$OTHER" https://example.test/browse/ABC-2 "Spec B rewrites the same service."
save retarget
git push -q origin spec-b

git checkout -q spec-a
OUT=$(sh "$SCRIPT" origin main 2>/dev/null); CODE=$?
want_zero clean "$CODE"
want_empty clean "$OUT"

# --- 3. rule 4: a merged spec is never a neighbour --------------------------
# spec-b lands on base, and its branch is pushed again afterwards so it is still
# unmerged and still enumerated. Its slug is on base, so it contributes nothing.
git checkout -q main
git merge -q --no-ff -m 'merge spec-b' spec-b
git push -q origin main

git checkout -q spec-b
mkspec spec-b "$SHARED" "$URL" "Spec B rewrites the same service."
save recollide
git push -q origin spec-b

git checkout -q spec-a
OUT=$(sh "$SCRIPT" origin main 2>/dev/null); CODE=$?
want_zero merged "$CODE"
want_empty merged "$OUT"

if [ "$FAIL" -eq 0 ]; then
  echo "contention: collision reported with its neighbour's intent, clean run silent, merged spec ignored — clean"
fi
exit "$FAIL"
