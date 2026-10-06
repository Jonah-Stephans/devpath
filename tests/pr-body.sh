#!/bin/sh
# devpath — the pull request body script, run against a real repository.
#
# scripts/pr-body.sh prints every section of the body that two runs must write
# identically, and Integrate's step 4 pipes it to `gh pr edit` with three slots
# filled. A wrong count or a dropped waiver lands in front of the approver
# looking exactly like a right one, and no later stage reads the body back. So
# every case is compared against the whole expected output with diff, never a
# fragment of it: a fragment match passes over the extra line, the lost path
# line and the misaligned column alike.
#
# Comparing whole output is also what keeps this file clear of tests/lint.sh
# check 4. That check reads tests/ too, and a fixture line holding a tag word
# beside a tool word would count as a read of the tag.
#
# Scenarios, over one fixture repository:
#   1. a spec carrying every tag word: the tree with a binary file, a wrapped
#      `unverified:` box, findings in the archive directory, an Outcome checks
#      waiver paired with its Outcome, waivers elsewhere with their path lines,
#      boxes under ## Deviations that are not counted as findings, and a slice
#      with no ## Merge Danger section
#   2. the same run again, byte for byte
#   3. a spec carrying no tag word at all, whose code diff is empty: every
#      empty-case sentence. Its exit status must equal scenario 1's, which is
#      the test of the allowlist in check 4: the script reads three tag words
#      to count and copy them, and nothing it does may turn on one
#   4. a base branch the clone does not hold
#   5. a gh that cannot read the pull request: no body at all, and a non-zero
#      exit, because the write in step 4 would fail on the same gh
#
# Exit code is the build's.

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
SCRIPT="$ROOT/scripts/pr-body.sh"

[ -f "$SCRIPT" ] || { echo "FAIL subject: $SCRIPT does not exist"; exit 1; }

FAIL=0

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT INT TERM

same() {   # same <scenario> <want file> <got file>
  diff -u "$2" "$3" > "$T/diff" || {
    echo "FAIL [$1] the output differs from the expected body:"
    sed 's/^/      /' "$T/diff"
    FAIL=1
  }
}

# gh is stubbed: the script asks it for the pull request's base branch and url.
mkdir "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/bin/sh
[ -n "$GH_FAIL" ] && exit 1
printf '%s %s\n' "${GH_BASE:-main}" https://github.example/o/r/pull/7
EOF
chmod +x "$T/bin/gh"
PATH="$T/bin:$PATH"
export PATH

run() {    # run <outfile> — the script's stdout to <outfile>, its exit code in CODE
  sh "$SCRIPT" > "$1" 2>/dev/null
  CODE=$?
}

git init -q --bare "$T/origin.git" || exit 1
git init -q "$T/work" || exit 1
cd "$T/work" || exit 1
git symbolic-ref HEAD refs/heads/main
git config user.email devpath-test@example.test
git config user.name devpath-test
git config commit.gpgsign false
git remote add origin "$T/origin.git"

save() { git add -A && git commit -qm "$1"; }

C=force-app/main/default
mkdir -p "$C/classes"
echo base > README.md
printf 'one\ntwo\n' > "$C/classes/B.cls"
save base
git push -q -u origin main

# --- 1. every tag word ------------------------------------------------------
git checkout -q -b tolerance main
echo 'base changed' > README.md
printf 'a\nb\nc\n' > "$C/classes/A.cls"
printf 'one\nTWO\nthree\n' > "$C/classes/B.cls"
mkdir -p "$C/lwc/nav" manifest
printf 'x\ny\n' > "$C/lwc/nav/nav.js"
printf '\211PNG\r\n\032\n\000\000\000' > logo.png
printf '<a>\n<b>\n</b>\n</a>\n' > manifest/destructiveChanges.xml

D=devpath/tolerance
mkdir -p "$D/slices" "$D/archive"
cat > "$D/spec.md" <<'EOF'
---
type: feature
intent_accepted: true
design_approved: true
---

# Tolerance

## Intent
Buyers set a tolerance ceiling.

## Outcomes
- O1 — A buyer can set a ceiling
- O2 — Tolerance breaches log to the audit trail
  with the breaching value

## Design
The ceiling is a field on the buyer.

## Traps
- A test over the write path must be able to fail on an inaccessible item
  sitting earlier in the list.
- A test over the retry path must be able to fail on a second callout.

## Outcome checks
- [ ] unmet O1 — the ceiling saves but the form shows the old value
- [x] won't fix O2 — audit-trail object is managed and read-only in this org
EOF
cat > "$D/slices/01-schema.md" <<'EOF'
---
depends_on:
touches:
  - force-app/main/default/classes/B.cls
done: true
fix_cycles: 2
---

# Schema

## What to build
The ceiling is stored.

## Acceptance criteria
- [x] met — the ceiling field exists
- [x] won't fix — a second currency; no org in scope uses one

## Deviations
- [x] won't fix — swept in README.md; the typo fix belongs with this change
- Built a fixed 200-row cap, where the design
  asked for none.

## Critique findings
- [x] fixed — any user could edit the ceiling through the permission set;
  unverified: no runner exists for permission sets
- [x] false positive — null guard on the write; the caller guarantees a value
- [x] fixed — a failed write reported success

## Merge Danger
- deletes: `<members>Tolerance__c.Legacy__c</members>` in `manifest/destructiveChanges.xml`. Every org this deploys to loses the stored legacy value.
EOF
cat > "$D/archive/01-schema.md" <<'EOF'
# 01-schema

- [x] fixed — the bulk path swallowed the DML exception
- [x] won't fix — hard-coded org id in the test; fixture is scratch-org-local
- [x] fixed — the ceiling accepted a negative value; unverified: no runner exists for validation rules
EOF
cat > "$D/slices/02-form.md" <<'EOF'
---
depends_on:
touches:
done: true
fix_cycles: 0
---

# Form

## What to build
The buyer sets the ceiling on a form.

## Acceptance criteria
- [x] met — the form saves

## Deviations

## Critique findings

## Merge Danger
EOF
cat > "$D/slices/03-email.md" <<'EOF'
---
depends_on:
touches:
done: true
fix_cycles: 1
---

# Email

## What to build
A breach emails the buyer.

## Acceptance criteria
- [x] met — the email arrives

## Deviations
- [ ] excess — swept in logo.png past wrote:
- [ ] blocked — the deploy hook refused manifest/destructiveChanges.xml
- [ ] verify — the toast reads well on a phone
- [x] fixed — the field exists; read off the object file

## Critique findings
- [x] fixed — the email went to the buyer twice

## Merge Danger
No one-way door found on this slice.
EOF
save tolerance

URL=https://github.example/o/r/blob/tolerance/devpath/tolerance
cat > "$T/want1" <<EOF
{{intent}}

## Summary

\`\`\`text
.
├─ README.md                        +1 -1
├─ force-app/main/default/
│  ├─ classes/
│  │  ├─ A.cls                      +3 -0
│  │  └─ B.cls                      +2 -1
│  └─ lwc/nav/nav.js                +2 -0
├─ logo.png                         binary, changed
└─ manifest/destructiveChanges.xml  +4 -0
\`\`\`

{{view}}

## Merge Danger

{{merge-danger}}

## Outside the Test Boundaries

- [x] fixed — any user could edit the ceiling through the permission set;
  unverified: no runner exists for permission sets
      devpath/tolerance/slices/01-schema.md
- [x] fixed — the ceiling accepted a negative value; unverified: no runner exists for validation rules
      devpath/tolerance/archive/01-schema.md

## Accepted Gaps

- [ ] unmet O1 — the ceiling saves but the form shows the old value
      O1 — A buyer can set a ceiling
- [x] won't fix O2 — audit-trail object is managed and read-only in this org
      O2 — Tolerance breaches log to the audit trail
      with the breaching value
- [x] won't fix — a second currency; no org in scope uses one
      devpath/tolerance/slices/01-schema.md
- [x] won't fix — swept in README.md; the typo fix belongs with this change
      devpath/tolerance/slices/01-schema.md
- [x] won't fix — hard-coded org id in the test; fixture is scratch-org-local
      devpath/tolerance/archive/01-schema.md

## Full Details

<details>
<summary>3 slices · 3 fix cycles · 5 fixed, 1 false positive, 1 won't fix · 1 one-way door recorded</summary>

| Slice | Fix cycles | Fixed | False positive | Won't fix | Deviations | One-way doors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [01-schema]($URL/slices/01-schema.md) | 2 | 4 | 1 | 1 | 2 | 1 |
| [02-form]($URL/slices/02-form.md) | 0 | 0 | 0 | 0 | 0 | — |
| [03-email]($URL/slices/03-email.md) | 1 | 1 | 0 | 0 | 4 | 0 |

[\`spec.md\`]($URL/spec.md) — 2 traps

</details>
EOF

run "$T/got1"
CODE1=$CODE
same 'every tag word' "$T/want1" "$T/got1"

# --- 2. the same branch, the same bytes -------------------------------------
run "$T/again"
cmp -s "$T/got1" "$T/again" || {
  echo "FAIL [twice] two runs over one branch printed different bodies"
  FAIL=1
}

# --- 3. no tag word, no code: every empty-case sentence ---------------------
git checkout -q -b quiet main
Q=devpath/quiet
mkdir -p "$Q/slices"
cat > "$Q/spec.md" <<'EOF'
---
type: feature
intent_accepted: true
design_approved: true
---

# Quiet

## Intent
Nothing visible changes.

## Outcomes
- O1 — The config reads the same

## Design
Leave it.

## Outcome checks
EOF
cat > "$Q/slices/01-only.md" <<'EOF'
---
depends_on:
touches:
done: true
fix_cycles: 0
---

# Only

## What to build
Nothing.

## Acceptance criteria

## Deviations

## Critique findings

## Merge Danger
No one-way door found on this slice.
EOF
save quiet

QURL=https://github.example/o/r/blob/quiet/devpath/quiet
cat > "$T/want3" <<EOF
{{intent}}

## Summary

No file outside devpath/ changed on this branch.

{{view}}

## Merge Danger

{{merge-danger}}

## Outside the Test Boundaries

Every finding fixed on this spec closed on a check that went red and then green. Nothing was closed on a change nothing could prove.

## Accepted Gaps

No \`won't fix\` and no \`- [ ] unmet\` anywhere on this spec. Nothing was shipped knowingly unresolved.

## Full Details

<details>
<summary>1 slice · 0 fix cycles · 0 fixed, 0 false positive, 0 won't fix · 0 one-way doors recorded</summary>

| Slice | Fix cycles | Fixed | False positive | Won't fix | Deviations | One-way doors |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [01-only]($QURL/slices/01-only.md) | 0 | 0 | 0 | 0 | 0 | 0 |

[\`spec.md\`]($QURL/spec.md) — \`## Traps\` empty

</details>
EOF

run "$T/got3"
same 'no tag word' "$T/want3" "$T/got3"
[ "$CODE" -eq "$CODE1" ] || {
  echo "FAIL [exit status] $CODE over a spec with no tag word, $CODE1 over one with every tag word"
  FAIL=1
}

# --- 4. a base branch this clone does not hold ------------------------------
GH_BASE=release run "$T/got4"
sed 's|^No file outside devpath/ changed on this branch\.$|Files not drawn: origin/release is not in this clone.|' \
  "$T/want3" > "$T/want4"
same 'missing base' "$T/want4" "$T/got4"

# --- 5. gh cannot read the pull request -------------------------------------
GH_FAIL=1 run "$T/got5"
[ "$CODE" -ne 0 ] || { echo "FAIL [no gh] exited 0 with no pull request to write to"; FAIL=1; }
[ -s "$T/got5" ] && { echo "FAIL [no gh] printed a body with no pull request to write to"; FAIL=1; }

if [ "$FAIL" -eq 0 ]; then
  echo "pr-body: every tag word, twice alike, every empty-case sentence, exit status blind to tags, missing base, no gh — clean"
fi
exit "$FAIL"
