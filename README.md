# devpath

A Salesforce-shaped engineering workflow that takes a non-technical requirement through a structured process to merged code. The process includes eight skill-invoked stages requiring two human approvals and two optional skills.

## Before you install

> `git`, and the GitHub CLI logged in — check with `gh auth status`.

**`devpath` shells out to `gh` from its first stage, not its last.** Initiate opens the branch and the
draft pull request, Integrate reads and files against them, and the hook blocks below call `gh pr list`.
An unauthenticated `gh` therefore fails at stage one, where the failure looks like `devpath` being
broken rather than like a missing login. **Nothing else is needed** — no CI, no scratch org and no branch
protection, which is the point of the first use below.

## Install

```
claude plugin marketplace add Jonah-Stephans/devpath
claude plugin install devpath@jonah-stephans
```

## Check it worked

> Type `/devpath:` and confirm the skills appear.

**A plugin that failed to install cannot detect that it failed to install.** Any preflight or self-check
shipped *inside* a plugin is unreachable in exactly the case it exists for. This line works because it
reaches only people who are already installing.

## First use

> Run `devpath:initiate` on a real requirement. Stop at the intent gate.

One command, a real requirement, and you have a spec file, a branch and a draft pull request in minutes.
It needs no CI, no scratch org and no branch protection working yet — Initiate touches none of them.

Every stage is individually invocable, so a one-stage first use is the design working as specified. A
full end-to-end run on a small real change is the right *second* use.

## Is this repo ready?

> Run `devpath:fit-check` when the repo is new, and again if `devpath` hits issues with new repo infrastructure.

## What you can gate on

**`devpath` ships no hook enforcement and never depends on any, but it's meant to be tailored with the repo's own hooks.** A repo that enforces nothing gets identical
behaviour from `devpath`, just less attended. Everything below is a repo's own choice, pasted into the
repo's `.claude/settings.json`.

**The recommended default is one job, not a suite** — the open-box grep, scoped to the spec directories
the pull request touches, with the prose caps as an optional second half of the same job:

```bash
: "${BASE:?not a pull request build}"
MB=$(git merge-base "$BASE" HEAD) || { echo "no merge base with $BASE — checkout needs fetch-depth: 0"; exit 1; }
SPECS=$(git diff --name-only "$MB" HEAD | grep -oE '^devpath/[^/]+/' | sed 's:/$::')
if [ -n "$GITHUB_HEAD_REF" ]; then SPECS="$SPECS devpath/$GITHUB_HEAD_REF"; fi
SWEEP=; for d in $(printf '%s\n' $SPECS | sort -u); do [ -d "$d" ] && SWEEP="$SWEEP $d"; done
if [ -z "$SWEEP" ]; then echo "no spec directory in this diff — nothing to sweep"; exit 0; fi
RC=0
if grep -rn '^[[:space:]]*- \[ \]' $SWEEP; then RC=1; fi

# Optional from here down to exit. Delete it and the job is the open-box grep alone.
CHANGED=$(git -c diff.noprefix=false diff --unified=0 "$MB" HEAD -- $SWEEP | awk '
  /^\+\+\+ b\// { f = substr($0, 7); next }
  /^@@ /        { split(substr($3, 2), h, ",")
                  c = (h[2] == "" ? 1 : h[2] + 0)
                  for (i = 0; i < c; i++) print f ":" h[1] + i }' | tr '\n' ',')
FILES=$(find $SWEEP -name '*.md' -type f)
if [ -n "$FILES" ]; then
  OVER=$(awk -v changed="$CHANGED" -v findingcap=250 -v bulletcap=150 -v budget=1500 '
    function count(s) { return split(s, drop, " ") }
    function enditem() {
      if (!live) return
      if (touched && sect == "f" && w > findingcap)
        print at ": a finding box runs to " w " words, over " findingcap
      if (touched && sect == "d" && !boxed) {
        if (w > bulletcap) print at ": a deviation bullet runs to " w " words, over " bulletcap
        sum += w
      }
      live = 0
    }
    function endfile() {
      enditem()
      if (sum > budget)
        print path ": this pull request writes " sum " words of deviation bullets, over " budget
      sum = 0
    }
    BEGIN { n = split(changed, a, ","); for (i = 1; i <= n; i++) seen[a[i]] = 1 }
    FNR == 1 { endfile(); path = FILENAME; sect = "" }
    /^#/ { enditem()
           if (substr($0, 1, 3) == "## ") {
             sect = ""
             if ($0 == "## Critique findings") sect = "f"
             if ($0 == "## Deviations")        sect = "d"
           }
           next }
    substr($0, 1, 2) == "- " {
      enditem()
      live = 1; at = FILENAME ":" FNR; boxed = (substr($0, 1, 3) == "- [")
      s = substr($0, 3)
      if (substr(s, 1, 1) == "[") { p = index(s, "]"); if (p) s = substr(s, p + 1) }
      w = count(s); touched = ((FILENAME ":" FNR) in seen); next
    }
    live { w += count($0); if ((FILENAME ":" FNR) in seen) touched = 1 }
    END { endfile() }
  ' $FILES)
  if [ -n "$OVER" ]; then printf '%s\n' "$OVER"; RC=1; fi
fi
exit $RC
```

**Still one job, and still one sweep.** Every line above `RC=0` works out *which* directories to sweep,
and both halves under it read exactly those: the grep for an open box, the `awk` for an item longer than
its cap. **The first half is the recommended default and the second is optional.** Delete from the comment
down to `exit $RC` and you have the grep alone, which is what this section shipped before the caps existed.

**Both exits are captured and combined, and that is not tidiness.** GitHub Actions runs a `run:` step under
`bash -e`, so the older last line, `! grep -rn … $SWEEP`, aborted the step the moment it matched a box, and
anything appended after it never ran. A spec over its caps *and* holding an open box would report the box
alone, and the caps would look clean for exactly as long as they were being broken.

**`-c diff.noprefix=false` is load-bearing too.** The `awk` finds a file by its `+++ b/` header, and a repo
that set `diff.noprefix` gets `+++ path` — nothing then lands under a filename, nothing is counted, and the
job is green having compared nothing.

**What the second half does, in plain English.** It sweeps the same directories, finds every box under
`## Critique findings` and every bullet under `## Deviations` whose text this pull request **added or
changed**, counts the words in each one, following a bullet across the lines it wraps onto, and is red on
any that is over its cap. **A box under `## Deviations` is skipped**, and prose this pull request did not
touch is not counted.

| the item | cap | anchored outside `devpath`? |
| --- | --- | --- |
| a box under `## Critique findings` | 250 words | **yes.** An approved project's longest single finding entry, holding a severity, a recommendation and a verdict, is 267 words |
| a bullet under `## Deviations` | 150 words | **no.** `devpath`'s own distribution, and it leaves about half the observed bullets untouched |
| every bullet under `## Deviations`, per slice file | 1,500 words | **no.** The same distribution, and it bites two slice files in five |

**The numbers are the writers' rule, and this job only refuses them.** `devpath:build` and
`devpath:critique` carry them as a mandate, and no run counts words or blocks on a count, because a gate
that failed a run for prose length teaches a worker to shave words rather than think about them. This job
is a repo choosing to refuse the numbers at the pull request, exactly like every other block on this
page.

**An item runs from a `- ` at column zero to the next one**, because bullets under `## Deviations` wrap
and boxes under `## Critique findings` do not. **Any heading ends an item, and only a `## ` heading changes
which section you are in**, so a `### ` under either one does not silently switch the counting off. A per-line `wc -w` gets the second section wrong. **A
formatter that renests a list indents an item's first line, and this counter then reads it as a
continuation of the item above.** Indent the whole list and nothing is counted at all; indent one item and
its words are added to the one above it, which can report a breach against a bullet well inside its cap.
**Neither direction is safe, and an optional check is where that is affordable** — the open-box grep above
is widened for the same formatter, and it is the half a repo is told to keep.

**A box under `## Deviations` is skipped on its marker rather than on its tag word**, for the reason
*Every section above is a signal or a written trace* gives below: the marker is the signal and the words
after it are not. That draws the skipped set one item wider than the two boxes that carry a tag, taking the
untagged pause box in with them, and `devpath:build` argues that widening where it states the rule.

**Diff-scoped, and a maintainer must not "simplify" it to the whole file.** Both sections are append-only.
*Open boxes append and are never deleted*, and a bullet under `## Deviations` is never deleted either, so a
whole-file check turns a repo permanently red on prose written before the caps existed, with no legal way
to shorten it. Archiving rescues the findings half; `## Deviations` is not archived, and that omission is
deliberate. So the check has to read changed lines, and `devpath` names the technique already: `fit-check`
entry 17 is *CI can run a diff-scoped check evaluating changed lines*, observed by
`git diff --unified=0` in a `run:`.

**The section budget is what this pull request adds, not what the section holds**, for the same reason.
`devpath:build`'s mandate bounds the section; a diff-scoped job can only see the part this pull request
wrote. A section already over budget stays green until somebody adds to it.

**The archive files pass through unread, correctly.** They sit inside the spec directory, so the sweep
reaches them, and they carry no `## ` heading — so no item in them is ever in either section. Re-checking
immutable history buys nothing.

**Scope comes from the diff, never from the branch name alone.** The short version of this job read
`devpath/$GITHUB_HEAD_REF` and required a directory of that name. A lessons branch
(`devpath/lessons/<slug>`), a `ci/<name>` branch, a docs fix and a dependency bump all have no such
directory, so all four were red on a job whose only subject is an open box. Deriving the scope from the
files a pull request touches makes those four green, because there is nothing for them to sweep, and
leaves a spec's pull request swept.

**`$BASE` is the pull request's base SHA** — `github.event.pull_request.base.sha` on GitHub Actions;
substitute the one your CI sets. **The checkout needs `fetch-depth: 0`**, because a shallow clone holds no
merge base to diff against. Get either wrong and the `git merge-base` line is red with the reason printed.
**A gate that cannot work out what to sweep has to be loud about it.** Exiting 0 having swept nothing reads
exactly like a clean spec, and that is the worst thing this job can do.

**The branch-name fallback is additive, and it is guarded on a non-empty head ref.** A spec's pull request
that edits only code touches no file under `devpath/<slug>/`, so the diff alone would sweep nothing; the
fallback adds the directory the branch is named for, and the `[ -d ]` filter below drops it again when
there is no such directory. **The `[ -n "$GITHUB_HEAD_REF" ]` guard is load-bearing, not padding.** With an
empty head ref the fallback appends `devpath/`, the filter finds that on disk and keeps it, and the sweep
collapses to every spec in the repo — the unscoped sweep that fails this spec on a neighbouring spec's open
boxes. **The filter cannot stand in for the guard**, because `devpath/` is precisely a directory that
exists.

**Every path the grep is handed exists, and the `[ -d ]` filter is what makes that true.** `grep -r` on a
missing path exits 2, the leading `!` turns that into 0, and the job passes having tested nothing. It does
that for the **whole run** rather than for the missing path alone: a box matched and printed in a live
directory goes green beside it, which is the one thing this job exists to prevent. So the filter runs over
both halves rather than over the fallback alone — `git diff --name-only` names files a pull request
**deleted**, so the diff half can put a directory in the sweep that the tree no longer holds. A pull request
that retires a spec directory outright falls through to *nothing to sweep*, where green is the right answer,
and it gets there without a grep error the `!` swallowed.

**`[[:space:]]*` is what makes an indented box red.** Anchored at `^` alone, this job goes green on a spec
holding `  - [ ] excess`, because a formatter that renests a list indents the box and the anchor stops
matching. Widened, the pattern also matches a box nested under another list item. That is the intended
reading. A nested open box is still an open box, and the box grammar never writes one.

**The gap this leaves, written down rather than left as a false green nobody goes looking for:** a spec's
pull request that touches no file under its own spec directory, on a branch not named for that directory,
passes unswept. Both halves have to miss at once for that. `devpath` names the branch for the directory, so
the way there is a branch that was renamed or never took the slug, carrying a pull request that touches
only code. Integrate's step 3 refuses on the same boxes in-session, so this job is a second reader rather
than the only one.

<details>
<summary><b>The menu — eight blocks over seven properties</b></summary>

**What a repo can make hard, and what it cannot.** Eleven properties; the eight blocks below cover seven.

| Rule | Repo-enforceable? | Mechanism |
| --- | --- | --- |
| No undispositioned `- [ ]` reaches the base branch | **hard** | the open-box grep above, as a job on the pull request, scoped to the spec directories that pull request touches. **Not section-blind at push time** — `## Acceptance criteria` boxes are open by design mid-build, so block 1 is narrower |
| No box or bullet over its cap is added or changed | **hard** | the second half of the open-box job above. **Diff-scoped, and not to be widened** — both sections are append-only, so a whole-file check is permanently red on prose written before the caps and there is no legal way to shorten it |
| `fix_cycles >= 3` opens no unattended fix pass | **the rule holds; no block ships** | the grant is *spoken and never stored*, so a hook reading the field cannot tell a capped slice from a granted lap. A repo can only buy this by giving up the granted lap |
| A gate field is `true` before the next stage runs | **hard** | block 2 |
| Spec and slice files match the schema | **hard** | block 4 |
| A mid-run stop stops the whole run | **hard** | block 3 |
| A missed `fix_cycles` increment is caught | **withdrawn — there is nothing to catch** | a slice carrying `- [x] fixed` with the field at `0` is the **legal mid-cycle state**, and a missed increment is byte-identical to it on disk. **A missing line is a different thing and is caught** — Integrate's step 3 refuses on a built slice that has none |
| A lesson entry carries a resolving link | **hard** | block 5 |
| Learn runs before the merge | **hard** | blocks 6 and 7 |
| A built slice is critiqued before the walk moves on | **not hard; a block still ships** | block 8 — a reminder at the moment the act is due, rather than detection after the act is missed. It cannot deny, **it fires on every ordinary builder return by design**, and it cannot tell a deliberate hand-back from a forgotten dispatch |
| **A per-worker token budget** | **NOT AVAILABLE** | no hook input carries token counts |

**Four of those eleven rows are not hard, and four ship no block — and they are not the same four.** The
README says both rather than leaving you to notice the table is longer than the menu. Three of the
not-hard rows ship nothing at all: the `fix_cycles` cap has no honest hook, the missed-increment row is not
a rule any more, and the token budget is unavailable. The fourth ships block 8, which reminds and cannot
deny — it lowers the odds of a skipped critique and guarantees nothing. **The cap row is the one that is
hard and still ships no block**, because a push-time denial over prose length is exactly the gate
`devpath:build` refuses to be — *a gate that failed a run for prose length would teach a worker to shave
words rather than think about them*. Refusing at the pull request is a different act, and it is where the
job above sits.

**One markdown trap: the matcher is `Task|Agent`.** Where you see a backslash before the pipe in prose,
it is markdown escaping a table column separator — it is not part of the string. The blocks below carry
`"matcher": "Task|Agent"`, and that is the form that goes into `settings.json`.

**Three facts make every block readable.** A hook receives its input as **JSON on stdin**. A `PreToolUse`
hook **denies by exiting 2**, and its message goes to whoever made the call. A `PostToolUse` hook **cannot
deny**, because the write it is reacting to has already happened.

**Merge the blocks rather than repeating the `hooks` key.** Three of the eight parse the dispatch first
line `devpath slice: <path>` and are silently inert on any other dispatch.

**Blocks 1, 6 and 7 find the spec with `git branch --show-current`, which is empty under a detached
HEAD** — they go inert rather than wrong. They are hooks, running in a session where a branch is normally
checked out; the grep above is a CI job, where one normally is not.

---

**1 — Nothing pushes while a slice is stopped.** `if` is a real hook key — a permission-rule filter,
honoured on tool events, so the command runs only on a `git push`. **One over-fire, documented rather than
a surprise:** a pattern naming more than the command also runs on a call containing `$()`, backticks or
`$VAR`. The cost is bounded because the command exits 0 whenever no stop box is open — but while one *is*
open, an unrelated Bash call carrying a variable is denied too.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "if": "Bash(git push*)",
        "hooks": [
          {
            "type": "command",
            "command": "SLUG=$(git branch --show-current); [ -d \"devpath/$SLUG/slices\" ] || exit 0; for f in \"devpath/$SLUG\"/slices/*.md; do [ -f \"$f\" ] || continue; grep -q '^done: true$' \"$f\" && D=0 || D=1; H=$(awk -v d=\"$D\" '/^## Deviations/{s=(d+0);h=\"## Deviations\";next} /^## Critique findings/{s=1;h=\"## Critique findings\";next} /^## /{s=0} s&&/^[[:space:]]*- \\[ \\]/{print h;n=1;exit} END{exit !n}' \"$f\") && { echo \"devpath: $f carries an open - [ ] under $H\"; exit 2; }; done; exit 0",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**This is not the recommended grep with a hook wrapper, and the difference is the whole of the block.**
That grep runs on the pull request, where *Critique clean* — section-blind, whole spec directory — is the
right test. This one runs on **every push during a build**, and Slice writes `## Acceptance criteria` as
open boxes at creation, so section-blind here would deny the first push of every ordinary run. It is
scoped to the two sections that mean stop, and to the spec on this branch rather than all of `devpath/`.

**A third scoping, and it is Build's rule rather than this menu's.** **A done slice with an open box under
`## Deviations` is not a pause and must not be read as one** — the commit-excess box lands inside the
slice's own commit, so without this the block would deny the push of the commit that created it. The block
skips `## Deviations` on a slice carrying `done: true`, and **never skips `## Critique findings`** — a
finding left open on a finished slice is a real stop. The message names which of the two headings it found,
because the two mean different things.

**A pause commit can write that box too, and the block is right to deny that push.** `git add -A` stages
what is on disk whether the slice finished or not, so a paused slice can carry both boxes — the pause and
the audit's. No `done: true`, nothing skipped, push denied, which is what a pause wants anyway.

**That box also carries a `- [ ] excess` tag, and this block deliberately does not read it.** A block
deciding whether your push goes through reads `done: true`, because a field nothing else writes beats a
word a run can forget. The tag is for the human reading the diff, where no join ever happens.

---

**2 — A gate field is `true` before a slice is built.**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task|Agent",
        "hooks": [
          {
            "type": "command",
            "command": "SLICE=$(jq -r '.tool_input.prompt // \"\"' | head -1 | sed -n 's|^devpath slice: ||p'); [ -n \"$SLICE\" ] || exit 0; SPEC=\"${SLICE%/slices/*}/spec.md\"; grep -q '^design_approved: true$' \"$SPEC\" || { echo \"devpath: $SPEC does not carry design_approved: true\"; exit 2; }",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

---

**3 — A mid-run stop stops the whole run.**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task|Agent",
        "hooks": [
          {
            "type": "command",
            "command": "SLICE=$(jq -r '.tool_input.prompt // \"\"' | head -1 | sed -n 's|^devpath slice: ||p'); [ -n \"$SLICE\" ] || exit 0; for f in \"${SLICE%/*}\"/*.md; do [ \"$f\" = \"$SLICE\" ] && continue; grep -q '^done: true$' \"$f\" && continue; awk '/^## Deviations/{d=1;next} /^## /{d=0} d&&/^[[:space:]]*- \\[ \\]/{n++} END{exit !n}' \"$f\" && { echo \"devpath: $f is frozen and needs a human\"; exit 2; }; done; exit 0",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Two things about this block are corrections, and both are the kind that ships inert if got wrong.**

**It tests for the absence of `done: true`, never for `done: false`.** Value is always `true`, absence is
how you say no, and nothing ever writes `false` — so a block greping `^done: false` can never fire.

**And the open-box test is scoped to `## Deviations`.** Slice writes `## Acceptance criteria` as open boxes
at creation, so **every slice not yet built carries open boxes** — an unscoped grep would deny the second
dispatch of every ordinary run. What this block looks for is a stopped slice, and it reads one as the
absence of `done: true` plus an open box under `## Deviations`.

**That reading is wider than a pause, and once a pause is cleared it is wider than the truth.** The
`devpath:technical-design` session closes the pause box and **leaves the audit's tagged box open**, so
until Build finishes that slice it carries no `done: true` and an open box, and this block calls it frozen.
**Build's rule closes the window: the cleared slice is the next one it builds.** Dispatching it is never
denied, because the block skips the slice it is being asked to dispatch, and `done: true` lands at the end
of that build. Reaching for a sibling first is what trips the false stop, and holding one slice to build
another was already *on request only*.

This is the strict form: it denies while **any** other slice in the spec is frozen. Build's
disjoint-`touches` exception is deliberately not in the paste — a repo that wants it compares the two
`touches` lists in the same script, and the strict form is the one that fails safe.

---

**4 — Spec and slice files stay inside the schema.** It warns rather than denies, because `PostToolUse`
cannot deny. The blocking variant is the same script on `PreToolUse` reading `.tool_input.content`.

**Its reader is the model that made the write, so the warning goes out as
`hookSpecificOutput.additionalContext` on exit 0**, which reaches that model. Plain stdout on exit 0 reaches
a debug log, so a block that echoes its sentence warns nobody. `additionalContext` is not a denial and does
not become one — `PostToolUse` still cannot deny, and the write has already happened either way.

**The offending headings ride inside the message rather than beside it.** The JSON has to be the only thing
on stdout, so `$B` holds what the `grep` found and the message carries it — *which* heading is outside the
schema is the part the model can act on. Empty `$B` exits 0 saying nothing, and the `jq -n` building the
message takes on nothing new — `jq -r` already reads the event on the first clause.

**It ends `exit 0` whatever `jq` did.** A non-zero exit at `PostToolUse` is an error rather than a warning,
and exit 2 is fed to the model as a blocking one — so a repo that reworks the message, and is therefore
editing a `jq` program, gets no warning rather than an error on every write to a spec.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "F=$(jq -r '.tool_input.file_path // \"\"'); case \"$F\" in *devpath/*/spec.md) P=\"Intent|Outcomes|Out of scope|Open questions|Evidence|Current state|Design|Traps|Outcome checks|devpath feedback\";; *devpath/*/slices/*.md) P=\"What to build|Acceptance criteria|Deviations|Critique findings\";; *) exit 0;; esac; B=$(grep -n '^## ' \"$F\" | grep -Ev \"^[0-9]+:## ($P)$\"); [ -n \"$B\" ] || exit 0; jq -n --arg f \"$F\" --arg b \"$B\" '{hookSpecificOutput:{hookEventName:\"PostToolUse\",additionalContext:(\"devpath: \" + $f + \" carries a heading outside the schema: \" + $b)}}'; exit 0",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

It checks for headings **outside** the schema and never for missing ones, because *absent and empty mean
the same thing* makes a missing heading legal.

---

**5 — A lesson entry carries a resolving link.** Presence only. Resolution is a second call and belongs in
CI, where a network failure does not stop an engineer's edit.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "IN=$(cat); F=$(printf '%s' \"$IN\" | jq -r '.tool_input.file_path // \"\"'); case \"$F\" in *.claude/rules/*.md) ;; *) exit 0;; esac; B=$(printf '%s' \"$IN\" | jq -r '.tool_input.content // .tool_input.new_string // \"\"' | grep '^- ' | grep -cv 'https://github.com/[^ ]*/pull/[0-9]*$'); [ \"$B\" -eq 0 ] || { echo \"devpath: $B lesson entry line(s) in $F end in no pull request link\"; exit 2; }",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

---

**6 — Learn runs before the merge.** This is the one item that turns a model-driven instruction into a
guarantee, and the one with a cost: **Learn proposing nothing is a legal outcome**, and this block cannot
tell that from Learn never running. Take it only if the repo accepts *Learn always opens a pull request*.

**The trigger is the pull request leaving draft.** Initiate opens it as a draft and Integrate marks it
ready at **step 8**, one step after Learn runs at step 7 — so *out of draft* means *Integrate ran to the
end*. A spec Integrate refused at step 3 is still a draft, and ends its turns silently. **A human who
marks the pull request ready without running Integrate trips the block too**, and should: the merge is one
approval away either way.

**A branch with no pull request exits on that same read**, which is also the only `gh` call these blocks
make before they leave. `.[0].isDraft` over an empty list is `null`, and `null` is not `false` — so a
branch that never reached Initiate, and a spec whose pull request has already merged, end their turns as
quietly as a branch carrying no `spec.md`. Both blocks are `Stop` hooks, so that read runs at the end of
every turn on the branch.

**A `gh` that fails answers the same way.** Unauthenticated, offline or rate-limited, the read comes back
empty, and empty is not `false` — so the block releases rather than trapping the turn. That is the right
direction for a hook that denies, and it means **a repo where `gh` carries no credential gets no guard
rather than an inescapable one**.

**The detection is scoped to `devpath/lessons/$SLUG`.** Unscoped, `gh pr list --state open` enumerates
every open pull request in the repository and passes if any of them touches `.claude/rules/` — so a
neighbouring spec's lessons pull request releases this spec's guard, silently.

**One more limit, and it is about what a lessons pull request contains.** Blocks 6 and 7 detect one by
`gh pr diff --name-only | grep '^\.claude/rules/'`. **A lessons pull request proposing only a check
touches the repo's CI configuration and no rules file, so these blocks do not see it** — they read as
*Learn never ran* when Learn ran and proposed a check.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SLUG=$(git branch --show-current); S=\"devpath/$SLUG/spec.md\"; [ -f \"$S\" ] || exit 0; [ \"$(gh pr list --head \"$SLUG\" --json isDraft --jq '.[0].isDraft')\" = false ] || exit 0; for n in $(gh pr list --state open --head \"devpath/lessons/$SLUG\" --json number --jq '.[].number'); do gh pr diff \"$n\" --name-only | grep -q '^\\.claude/rules/' && exit 0; done; jq -n '{decision:\"block\",reason:\"devpath: the pull request for this spec is out of draft and no lessons pull request is open. Run devpath:learn before the merge.\"}'",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

---

**7 — the same thing as a warning**, for a repo that does not accept that trade. Identical condition, no
denial: it puts the sentence in front of the engineer and stops there.

**Which channel it speaks on is the whole of the difference, and each was measured.** At exit 0 a `Stop`
hook's plain stdout reaches a debug log, its stderr reaches nobody, and a JSON `systemMessage` reaches the
engineer, rendered on Claude Code 2.1.221 as `Stop says: <message>` — the routing is the hook contract,
the label is a string a release can rename. The engineer is the only reader a `Stop` hook has, and
`systemMessage` is the one warning route to them, so that is what this block emits. **`printf` writes it,
not `jq`** — nothing is interpolated into the message, so the block takes on no dependency it does not need.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SLUG=$(git branch --show-current); S=\"devpath/$SLUG/spec.md\"; [ -f \"$S\" ] || exit 0; [ \"$(gh pr list --head \"$SLUG\" --json isDraft --jq '.[0].isDraft')\" = false ] || exit 0; for n in $(gh pr list --state open --head \"devpath/lessons/$SLUG\" --json number --jq '.[].number'); do gh pr diff \"$n\" --name-only | grep -q '^\\.claude/rules/' && exit 0; done; printf '%s' '{\"systemMessage\":\"devpath: the pull request for this spec is out of draft and no lessons pull request is open. Run devpath:learn before the merge.\"}'",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

---

**8 — a built slice gets its critic.** `PostToolUse` on the dispatch, so it fires the instant a worker
returns, inside the orchestrator's turn. It reads the slice path off the fixed first line as blocks 2 and 3
do, and everything after that off disk: `done: true` with no `fix_cycles:` line is Integrate's step 3 test
2, asked at the moment the dispatch is due instead of at the merge gate. **Between a skipped dispatch and
that refusal, the walk can build every remaining slice on top of code no critic has read.**

**Its reader is the orchestrator, which is why it speaks the way block 4 does** — on exit 0, through
`hookSpecificOutput.additionalContext`, which reaches the model that made the call. That model is the only
reader worth having, because **a worker cannot dispatch anything**. It ends `exit 0` whatever `jq` did, for
block 4's reason.

**It fires on every ordinary builder return, and that is the design rather than a false positive.** At the
instant a builder returns, `done: true` is written and `fix_cycles` is legitimately absent, so the condition
is true on every normal slice. The alternative is reading the dispatch prose to tell a builder's return from
a critic's, which is parsing prose for something the front matter already says. **It is self-clearing**: the
critic's dispatch carries the same first line, and by the time that one returns `fix_cycles` is on disk, so
the block finds the field there and says nothing. There is no state to reset.

**It cannot tell a deliberate hand-back from a forgotten dispatch.** The bottom rung of Build's worker
lifecycle — finish the pass in hand, say the remaining slices want a fresh session, say the uncritiqued
state, hand back — writes the identical bytes, and Build calls that a legitimate way to run rather than a
failure. The hand-back is *spoken and never stored*, the same shape as the `fix_cycles >= 3` row above.
Here it costs nothing: `PostToolUse` cannot deny, so the run continues either way.

**Neither `SubagentStop` nor `Stop` is the event, and both are worth saying out loud.** Exit 2 on
`SubagentStop` *prevents the subagent from stopping*, so it would hold the builder open and instruct it to
do the one thing the design forbids it. A `Stop` hook can deny, and denying here would take the bottom rung
away — which is why this is a reminder and the menu ships no block that refuses.

**This block does nothing for a skipped second or later critique.** `fix_cycles` is present by then and the
fixed box is checked, so the condition is false and the block stays silent. Build states that gap outright
and carries it on an instruction alone.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Task|Agent",
        "hooks": [
          {
            "type": "command",
            "command": "SLICE=$(jq -r '.tool_input.prompt // \"\"' | head -1 | sed -n 's|^devpath slice: ||p'); [ -n \"$SLICE\" ] || exit 0; [ -f \"$SLICE\" ] || exit 0; grep -q '^done:[[:space:]]*true' \"$SLICE\" || exit 0; grep -q '^fix_cycles:' \"$SLICE\" && exit 0; jq -n --arg s \"$SLICE\" '{hookSpecificOutput:{hookEventName:\"PostToolUse\",additionalContext:(\"devpath: \" + $s + \" carries done: true and no fix_cycles: line, so the slice pass has not run on it. Dispatch the critic on it before building the next slice.\")}}'; exit 0",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**The `[ -f "$SLICE" ]` clause buys quiet rather than correctness.** Without it, a first line naming a path
that is not there still exits 0 — the `done` grep fails and the `||` takes it out — but that grep writes
*No such file or directory* to stderr on the way, and a block that says nothing should say it on both
channels.

---

**Which channel a wrapper reaches is settled by probe rather than by test.** `sh tests/*.sh` cannot ask the
harness whether it honours a block's wrapper, and a probe session can: `PreToolUse` exit 2 reaches the
caller, `PostToolUse` `additionalContext` at exit 0 reaches the model, `Stop` `systemMessage` at exit 0
reaches the engineer, and plain stdout at exit 0 reaches a debug log and nobody else. The `if` key is
settled against the official hooks reference rather than by probe.

**Two things are still unverified, and which rather than a count.** Block 6's `{"decision":"block"}` is the
shape no probe has run, and it is narrower than it was: a `Stop` hook's stdout at exit 0 *is* read as JSON,
so what is open is whether that shape denies rather than whether the wrapper is read at all. And blocks 6
and 7 were exercised against a **stubbed** `gh` — the draft read, the enumeration, the scoping and the
release were tested, the live API was not.

**The post-merge Learn runner is not on this menu.** A workflow file plus a stored credential plus a
decision to run an agent in CI is a procedure, not a paste. It is named here and not specified.

</details>

## What is on disk

<details>
<summary><b>The on-disk contract, complete</b></summary>

**This is the plugin's one complete statement of its own file format.** Each skill body states only the
fields and headings it reads or writes; this states all of them, once.

> **Where a skill body and this section disagree, this section is right.**

### Where a spec lives

**`devpath/` at the repository root. Fixed, not configurable.** Every spec is a directory holding
`spec.md` and N ≥ 1 slice files. There is no collapsed single-file form: a one-slice spec gets a directory
and two files, and that uniformity is what makes *has this been sliced?* into `ls slices/` in every case.

```
devpath/tolerance-config/
├── spec.md
├── slices/
│   ├── 01-schema.md
│   └── 02-validation.md
├── archive/
│   └── 01-schema.md
└── sketches/
    ├── config-panel.png
    └── config-panel-decision.md
```

**How you refer to a spec: by the draft pull request's number or its title.** The pull request is opened at
Initiate and lives exactly as long as the spec, and unlike anything `devpath` could invent it is centrally
allocated. `gh pr list --head <slug>` maps a number to a slug. **There is no `pr:` field** — it is
derivable from the branch, and a field nothing reads is a field to delete.

**The ref is the status.** In flight means the spec exists only on a branch; merged means it is on the base
branch, where it stays in `devpath/` with no move and no delete; abandoned means a closed pull request
whose file never got there. There is no `status:` field.

### `devpath/<slug>/spec.md`

```markdown
---
type: feature
upstream:
  - url: https://example.atlassian.net/browse/ABC-123
    read_at: 2026-08-19
    source_updated: 2026-08-14
intent_accepted: true
design_approved: true
---

# <Title>

## Intent
## Outcomes
## Out of scope
## Open questions
## Evidence
## Current state
## Design
## Traps
## Outcome checks
## devpath feedback
```

| Heading | Written by | Read by |
| --- | --- | --- |
| `## Intent` | Initiate; **Design rewrites it when its conversation revises the problem, and narrows it when one spec turns out to be two** | the intent gate — **must be non-empty**; every later stage |
| `## Outcomes` | Initiate, **one `- O<n> — <statement>` line per Outcome**; Design rewrites it when its conversation revises the problem, **keeping every ID it did not change** | the intent gate — **must be non-empty**; Survey, which clusters them into areas to dispatch and keys its findings on their IDs; the Outcomes pass; Integrate, resolving a carried-forward `won't fix` against it |
| `## Out of scope` | Initiate; **Design narrows it to one design** | Design, Build, to refuse creep. **Never gated** |
| `## Open questions` | Initiate, verbatim with its owner; the Design conversation adds | Design; `devpath:sketch`; a resumed Design |
| `## Evidence` | Initiate; Design may add, verbatim and attributed | the human at the intent gate; Design; Build |
| `## Current state` | Survey, **one `- O<n> — <finding>` bullet per Outcome, each saying what it was read off**; Design prunes it, **keeping what a finding it keeps was read off and carrying a struck note through the rewrite**; **Critique's slice pass, striking a wrong note in place on a confirmed finding whose cause it was — error left visible, never overwritten, the correction carrying what it was read off** | Design, at the prune; **Critique's slice pass, which reads the note against the file it names before it strikes it** |
| `## Design` | Design | the design gate — **never `design_approved: true` with this heading empty**; Slice, Build |
| `## Traps` | Critique's slice pass, on either of two triggers and always by the pass that confirmed the finding — a confirmed finding whose cause is a test that passed while the code was wrong; or one whose cause is still quotable from `## Design`. **One plain bullet per entry, never a box, and never naming a slice** | **every later Build worker and every later critic, sent to it by heading name**; Integrate, counting it into the pull request body; Learn |
| `## Outcome checks` | the Outcomes pass, run by `devpath:integrate`; **`devpath:build`, which expires it before the first dispatch of any run that will change code**; **`devpath:initiate`, which clears every line on a re-entry** | Integrate's refusal; **`devpath:build`, sent to it by heading name, which cuts one slice per `- [ ] unmet` line once every slice is `done: true`**; **`devpath:initiate`, which opens it by name on a re-entry and starts from the shortfalls**; the human at merge |
| `## devpath feedback` | the engineer, **optional** | Integrate, which offers to file it |

**`## Outcome checks` is a verdict on a code state, and it expires when that state changes.** Any run that
will change code expires it before its first dispatch — **every line except `- [x] won't fix`, which
carries forward verbatim, because the machine does not relitigate a human's decision.** **Say what was
expired.** A verdict nobody expired is one a later run reads as current, and no field makes an old one look
old. **The heading stays and the lines under it go**, which is *Nothing writes a placeholder* below, read
at the other end.

**Two of the three writers carve out the same line, and that is the part they share.**
`devpath:integrate` rewrites every line but `won't fix` when it runs the Outcomes pass; `devpath:build`
deletes every line but that one before it changes code. **The acts differ — Integrate replaces a verdict,
Build leaves none** — and the carve-out holds across both for the reason stated at each: the machine does
not relitigate a human's decision.

**`devpath:initiate` is the third writer and the one exception, on a re-entry only.** A rework retires
Outcomes, so a `won't fix` can outlive the Outcome it names. Initiate clears the section including those
lines and names each one it removed, and the human who asked for the rework is in the room to say it again
against the new Outcomes. **Being told is what separates that from the silent deletion the carve-out
exists to prevent.**

### `devpath/<slug>/slices/<nn>-<name>.md`

```markdown
---
depends_on:
  - devpath/tolerance-config/slices/01-schema.md
touches:
  - force-app/main/default/classes/ToleranceService.cls
wrote:
  - force-app/main/default/classes/ToleranceService.cls
  - force-app/main/default/classes/ToleranceServiceTest.cls
done: true
fix_cycles: 1
---

# <Title>

## What to build
## Acceptance criteria
## Deviations
## Critique findings
```

**That skeleton is a mid-life slice, not a new one.** `depends_on` and `touches` are Slice's, written when
the file is created. **`wrote`, `done` and `fix_cycles` are absent at creation** and appear when their
writers first write them.

- **`## What to build`** — the end-to-end behaviour this slice makes work, from the user's perspective, not
  a layer-by-layer list.
- **`## Acceptance criteria`** — Slice writes them from the design; Build ticks each one as it satisfies
  it. One `- [ ]` per criterion, closed as `- [x] met`. They count toward *Critique clean* like every other
  box in the directory.
- **`## Deviations`** — Build records; Integrate counts into the pull request body; the human sees it at
  merge. Recording is mandatory; whether to stop is the engineer's call. Slice appends one plain bullet
  here, with no tag and no box, when a re-cut changes the behaviour a built slice deployed. **Three kinds
  of open box live here and the tag separates them**: an untagged `- [ ]` is a pause, `- [ ] blocked` is a
  pause on a write a foreign hook refused, and `- [ ] excess` is the commit audit's note on files a commit
  swept in that no agent on the run wrote. **More than one can be open on one slice.**
- **`## Critique findings`** — Critique's slice pass. Open boxes append and are never deleted, and
  a closed one leaves at the next re-review, into the archive below.

**Zero-padding is not decoration** — `ls` sorts `10-` before `2-`. **The number is authoring order, never
execution order;** `depends_on` owns execution order. **`depends_on` values are full paths** of the form
`devpath/<slug>/slices/<nn>-<name>.md`; any flat form is wrong.

**`devpath/<slug>/archive/<nn>-<name>.md`** holds the closed findings `devpath:critique` moved out of that
slice. One file per slice, mirroring the slice's number and name, so the path is derivable from the slice's
with no lookup — and nothing renumbers or renames a slice, which is what keeps it derivable. It carries a
`# <nn>-<name>` heading and the box lines under it in archive order, and **no `## ` heading**: it sits
outside the two skeletons above rather than adding a section to either. **Created on first archive**, so its
absence means nothing has ever been archived on that slice, which is *Nothing writes a placeholder* below
rather than an exception to it.

**It is inside the spec directory, so every directory-wide grep already reaches it** — the open-box gate,
Integrate's step 3, and `grep -rn "won't fix" devpath/`. **It is not under `slices/`**, because `ls slices/`
is what answers *has this been sliced?* in every case, and because `scripts/contention.sh` reads every
`*.md` on a `slices/` path as a slice. Only closed boxes are ever in here: an open one stays on the slice.

**`devpath/<slug>/sketches/`** holds an artifact a later stage reads, plus its decision note. **This is
the only place a non-text file exists anywhere in `devpath`.**

**Every section above is a signal or a written trace, and the tables say which.** A signal names each
reader that branches on its contents and states the grammar those readers match — `## Traps` does both,
and so does `## Outcome checks`. A written trace names who *carries* it and states a grammar for a human's
benefit only: `## Deviations` and `## Critique findings` are counted into the pull request body and
read at merge, and **no run branches on what they say.** The box markers in them are a signal, and the
words after a marker are not — which is why nothing mechanical reads the word `excess`, and why nothing
reads a `## Deviations` entry to decide what to do next.

### The front-matter block starts at byte zero

**The block is the first thing in the file and the title sits under it.** That is where every front-matter
parser already looks, and where every markdown formatter already knows not to reformat. Below the title it
is not front matter at all — it is a thematic break and a list, and prettier renests the list, which
demotes `done`, `intent_accepted` and `design_approved` out of the top level without touching the file's
validity as YAML. **One consequence, because a reader will see it:** GitHub renders the block as a table
above the body.

### The nine fields

**Four on the spec, five on each slice.** YAML, snake case, `type` first and the gates last so a diff shows
a gate appearing at the end of the block rather than in the middle of it.

| Field | Lives on | Written at | Read by |
| --- | --- | --- | --- |
| `type` | spec | Initiate | **a human only.** `feature` \| `bug` \| `refactor` \| `config` \| `doc`. **Nothing in `devpath` branches on it today** — it is kept because a human reading a spec is a reader |
| `upstream` | spec | Initiate | a human; the sibling report. A **list**; each entry carries `url`, `read_at`, `source_updated`. Normalised at write time |
| `intent_accepted` | spec | Initiate | the router — `devpath:technical-design` refuses without it, and so do `devpath:survey` and `devpath:integrate` |
| `design_approved` | spec | Design | the router — `devpath:build` refuses without it, and so do `devpath:slice`, `devpath:critique` and `devpath:integrate` |
| `depends_on` | each slice | Slice | the cited-paths check; Build's structural refusal; the order walk |
| `touches` | each slice | Slice | the cited-paths check; the contention script; Build's mid-run-stop intersection — **three readers and no fourth** |
| `wrote` | each slice | every `devpath:build` worker | the commit audit — **one reader**. A set of paths, filled off git after the work and added to on every pass, which is what `creates:` could never be |
| `done` | each slice | Build | the router; Build's `depends_on` refusal; derived spec progress |
| `fix_cycles` | each slice | Critique | the fix cycles cap, read by `devpath:build` at its start. **Its presence** is read by Integrate's step 3 — absent on a built slice, the slice pass never ran |

> **Value is always `true`. Absence is how you say no. Nothing ever writes `false`.**

There is no such thing as a spec that was explicitly un-approved — you either have the human's yes or you
are in every spec's starting state. **A guard written against `done: false` can never fire**, which is why
block 3 above tests for the absence of `done: true`.

**`done: true` has a predicate, and it is the acceptance criteria.** A slice is done when every `- [ ]`
under its `## Acceptance criteria` is ticked. `done` is the one field whose name does not carry its own
meaning, so it is stated here: *done according to what?*

> **Every stored field is either a thing a human did or a thing a machine counted or recorded. None is a
> thing a model judged.**

**The two gates.** Gate 1, intent accepted, stores `intent_accepted: true` at the end of Initiate. Gate 2,
design approved, stores `design_approved: true` at the end of Design, before any code exists — and because
Slice sits behind it, the human approves the design *and* the slice layout at one stop. Merge is a third
human gate and `devpath` does not own it: it is branch protection.

### There is no `stage:` field, and no progress information is lost

| Question | Answered by | Field? |
| --- | --- | --- |
| Survey done? | `## Current state` is non-empty | no |
| Design done? | `## Design` is non-empty | no |
| Sliced? | files exist in `slices/` | no |
| Built? | every slice carries `done: true` | no |
| Critiqued? | every slice carrying `done: true` has a `fix_cycles:` line | no |
| Critique clean? | no `- [ ]` anywhere in the spec directory | no |
| In flight? | the spec exists only on a branch | no — git |
| Merged? | the spec is on the base branch | no — git |
| Abandoned? | a closed pull request whose file never got there | no — git |

**The cost, stated rather than smoothed: there is no single place to look.** Progress is **nine
observations — six over the files, three over git** — rather than one `head -5`. A `stage:` field would
not add this; it would duplicate it, and if `stage: built` said built while two of five slices lacked
`done: true`, the slice files would be right.

> **`fix_cycles` absent on a slice that carries code ⇔ the slice pass never ran on it.**

**That row is derived rather than stored, and it is the one worth spelling out.** Slice writes no
`fix_cycles:` line at creation, Critique writes `fix_cycles: 0` on its first pass over a slice that has
none, and nothing else ever writes the field — so the line's *presence* is the pass's own trace.
**`done: true` is the mechanical form of *carries code***, which is how the row asks the question and how
Integrate's step 3 tests it. **The two Critique rows are different questions**, and a real run answered
them differently: seven slice files, six at `done: true`, every `## Critique findings` empty, no
`fix_cycles:` line anywhere in the directory, and every downstream check clean. Integrate's step 3 refuses
on it now, and **no ninth field was needed** — which is why the row's third column says no.

### An Outcome carries an ID

```markdown
## Outcomes
- O1 — Tolerances configurable per quantity, unit price and total
- O2 — Bulk update over 200 rows completes without error
- O3 — Tolerance breaches log to the audit trail with the breaching value
```

**The line's grammar is `- O<n> — <statement>`, and a reference to an Outcome anywhere else is the bare
token `O<n>`.** Seven things point at an Outcome — `## Outcome checks`, a `won't fix` line, a Survey
finding, Build's cut entry, Slice's rework deviation and both of Build's pause illustrations. Before the
ID, each of them pointed at whatever text the Outcome happened to carry, and **Initiate and Design both
rewrite `## Outcomes` wholesale**, so a rework silently retargeted every one of them with nothing able to
tell that it had.

**Assigned once, never reused, never renumbered.** An Outcome rewritten to mean the same thing keeps its
ID; one rewritten to mean something else takes a new ID, one above the highest in the section, and the old
one is retired. `devpath:initiate`'s `### An Outcome carries an ID` is the rule, and both stages that
rewrite the section follow it.

**Retirement costs no field, and the gap is the trace.** A retired Outcome is an absent line — no
tombstone and no `false`, which is *Nothing writes a placeholder* below read over one line instead of a
section. A spec that met fifteen Outcomes first time carries O1 to O15 with none missing; one that
reworked four carries fifteen lines and a highest ID of O19. **That is how a reader tells rework from
success, and it arrives by subtraction:** nothing is stored, nothing is set, and no reader has to look
behind a flag, because a line is simply not there.

**The ID is part of the line's grammar rather than a field**, like the `- [x] met` tag below — the front
matter is unchanged and hook block 4's heading list is unchanged.

### The disposition grammar

```markdown
## Critique findings
- [x] fixed — `ToleranceService` swallowed the DML exception
- [x] false positive — null guard at line 42; the caller guarantees non-null
- [x] won't fix — hard-coded org id in the test; fixture is scratch-org-local
- [ ] bulk path still throws above 200 rows
```

```markdown
## Outcome checks
- [x] met O1
- [ ] unmet O2 — throws above 200 rows; batching is fixed at 200 and nothing chunks past it
- [x] won't fix O3 — audit-trail object is managed and read-only in this org
```

| Marker | Means |
| --- | --- |
| `- [ ]` | **still open** — Integrate refuses |
| `- [ ] unmet` / `- [ ] excess` / `- [ ] blocked` | the same open box with its own shortfall spelled out — `unmet` where a check fell short, `excess` where a commit went past the slice's scope, `blocked` where a foreign hook refused a write a slice needs. **What follows is what was observed, never the Outcome or the criterion restated** — under `## Outcome checks` the tag is followed by the Outcome's ID and then the observation. **Not new states** — every check greps `^[[:space:]]*- \[ \]`, which matches all three |
| `- [x] fixed` / `- [x] met` | the code does it. **A `met` line under `## Outcome checks` is the tag and the ID, and stops there.** **A `fixed` line under `## Critique findings` is a check that went red and then green** — where nothing could be run the line says so, carrying `unverified: <why>` after the observation. **Under `## Deviations` the same tag closes a `blocked` box on what a read established, and carries no check** |
| `- [x] false positive` | there was nothing there |
| `- [x] won't fix` | **real, not done, shipping anyway**. **Under `## Outcome checks` the tag is followed by the Outcome's ID and then the reason** |

**A box entry is one line beginning `- [` at column zero.** Nothing nests under it and nothing indents it.
That is the shape a lesson entry in `.claude/rules/` already has, and a flat line is what a per-line grep
reads. **The checks match an indented box anyway.** A formatter that renests the list would otherwise turn
a red gate green without anyone editing a spec.

> **Critique clean ⇔ no `- [ ]` remains anywhere in the spec directory.**

One grep, zero judgment, every cycle. **Section-blind, deliberately** — a box put somewhere the design
never anticipated fails loudly rather than quietly. Every box in the directory has an owner, which is the
only reason a directory-wide check is safe.

**What is still section-dependent is what Build *does* about a box.** Under `## Critique findings` an open
box means *fix this*; under `## Deviations` it means *do not proceed on this slice until a human clears
it*. **Two readings of one test** — the grep answers *is anything open*, the section answers *what do I do
about this one*.

**Inside `## Deviations` the tag says who clears it, and that is not a third reading.** An untagged box is
the pause, closed by the `devpath:technical-design` session that resolves it; `- [ ] blocked` is a pause a
human clears outside the run, closed by the `devpath:build` worker that resumes the slice on what it finds;
`- [ ] excess` is the commit audit's, closed by the human at merge. All three hold every check open until
they close.

**Every checked box carries its tag as the first word.** A bare checked box reads as *fixed in code* when
it may not have been, and **only `fixed` and `met` mean the code changed.**

**`- [x] won't fix — <reason>` is the way to ship something knowingly unresolved.** One line, loud, riding
into the pull request body in front of the human who has to approve it. No flag, no date, no waiver
machinery — a way out that costs more than compliance gets abused, and one that costs less gets used
honestly. **It accumulates**, so on the base branch `grep -rn "won't fix" devpath/` is the standing ledger
of everything the team knowingly shipped unresolved. **Pin that apostrophe as ASCII** — a typographic one
silently empties the ledger.

**`unverified: <why>` rides in the same way, under `## Outside the Test Boundaries`, one heading above the
`## Accepted Gaps` that carries the waivers.** A finding closed carrying it is one no check in the repo can
prove, so the set of them **is** the list a human has to check by hand — which is why `devpath:integrate`
gives it a heading of its own rather than a count inside the accounting. **Where
the set is empty the heading says so in a sentence**, because a section that ran and found none and a
section nobody filled are the same blank.

**`devpath` writes `fixed`, `met` and `false positive` off its own judgment. `won't fix` it writes only on
an instruction** — the human decides it and gives the reason in their own words, and the session they say
it to writes the line, under any heading. **No agent drafts the reason. No reason, no write.** Approval
plus an agent write is the same act as the human opening the file, and that is already how a yes in
conversation writes `intent_accepted: true` at the intent gate.

**The seat is what this turns on, not the run.** A worker subagent has no human in its context and so
never writes this line; the orchestrator, where the human is, does. A repo that wants an agent barred from
the write adds a hook of its own — `devpath` ships none and depends on none.

### Nothing writes a placeholder

> **A stage writes a section only when it has something to put in it. Absent and empty mean the same
> thing.**

Gating a section's presence yields the word `none` typed to satisfy a check, which is worse than nothing.
**`## Outcome checks` is the one deliberate exception** — always written, one line per Outcome, because
otherwise *nothing was wrong* and *the pass never ran* are indistinguishable.

**The exception binds the pass that writes it, not the section forever.** `devpath:build` expires those
verdicts before it changes code, and an expired section reads as *the pass has not run against this code*
— which is then the true state, and the one the next `devpath:integrate` run exists to replace. **The
heading stays and the lines under it go.** Deleting the heading would put `spec.md` outside the skeleton
above with nothing to catch it: the schema hook flags a heading that should not be there and is silent on
one that should.

**The slice pass needs no such exception, which is why the list has one entry and not two.** Its trace is
the `fix_cycles:` line on the slice, so an empty `## Critique findings` is already distinguishable from a
pass that never ran — and Integrate refuses on that absence.

</details>

## What this does not claim

<details>
<summary><b>The disclaim list and the admissions</b></summary>

**This design's house style is to name its own holes. A reader who does not find these sentences in the
built plugin has found a defect in the plugin, not in the design.**

### The outcome claim is unavailable

**`devpath` does not claim to make the work better or faster.** That claim is unmeasurable at this scale,
and a design that promises an outcome it cannot observe is making a claim it can never be held to. Across
1,650 sessions, no property of an instruction file — size, position, architecture, contradictions in
adjacent files — produced any detectable effect. At two to three engineers a 4% change is undetectable.

**Two claims are defensible, and they are what `devpath` commits to:**

- **Revealed preference** — an engineer who ran it once runs it again unprompted. Observable at N = 1, and
  the only claim that survives the maintainer not being in the room.
- **A fresh reader can act on it** — a spec on the base branch is one a stranger could act on without
  asking its author. The only **checkable** claim.

**Everything beyond those two is anecdote, and `devpath` calls it that.**

### What a solo run cannot test

**Because a green pass otherwise reads as validation.** A solo run on a non-Salesforce project cannot test:

- **both gates and the merge approval** — no second human, so *the one gate roughly ninety systems all
  kept* is exactly the one a solo run cannot exercise;
- **every repo precondition** on `devpath:fit-check`'s list;
- **the whole Salesforce half** — verticality, the deploy gate, the `Active`/`Obsolete` flow rule, the
  custom-metadata no-verification case, the LWC job, scratch orgs;
- **cross-spec contention** — one operator, one spec at a time.

**Two things even a scripted, coverage-driven pass cannot reach:** whether the slicing rule survives **real
requirements**, and whether pull-request review of a `devpath` spec produces **useful** review. Both need
a real spec from a real body of work, so both are **unvalidated by construction** until the first one runs.
A synthetic repo claiming otherwise is the dishonest version.

### Where the design knowingly does not enforce what it looks like it enforces

> **The agent writes the field that gates the agent.**
> `intent_accepted` and `design_approved` record that a human said yes; they do not enforce it.
> **The front-matter check runs only when a `devpath` skill
> runs** — a hand-edited spec on a branch nobody re-enters reaches the base branch unchecked, and nothing
> catches it but the human reviewer. **And a conversation the human refuses to have is a gate whose
> mechanism is live and whose signal is dead, which `devpath` cannot fix.**
>
> The principle that **a trust boundary needs a trusted location** is acknowledged and consciously not
> satisfied.

**The intent gate's mechanical check is nearly worthless.** Five sections, two checked for non-emptiness.
The human reading is the whole gate.

**An unanswered question can reach the base branch.** A mid-flight question is a recorded assumption, never
a gate. That is the posture, not a leak — the alternative is a gate nobody can release.

**`intent_accepted: true` can end up attached to Outcomes that were later rewritten**, and the design gate
is what covers that.

**A no-op design conversation costs one re-approval**, taken deliberately over a model judging materiality.

### What verification does and does not reach

**Verticality has no mechanical gate in this design.** The mechanism is real and the design declines to
spend it per slice: two orgs per spec, not N+1.

**Green is provably not done.** A slice whose feature was a dynamic query on a nonexistent field passed
validation, passed its test and scored 86.7% coverage.

**A green test of your own proves no more.** A suite asserted what the client sent, a null layout id, and
never what the server did with it, while the running org overwrote a layout instead of adding one.

**A slice made only of custom metadata has no behavioural verification whatsoever**, and no check is
invented for it. Nor for permission sets, layouts or screen flows — **the platform ships no runner that can
fail a build for any of them.**

**The only verifier of slice completeness is a person**, at the design gate, before code exists. **And a
fluent behaviour line can dress a bad slice** — the template narrows the lie; only the person kills it.

**One open-box check, and the section still decides what Build does about a box.**

### What is not bounded, and what is not observed

**`devpath`'s orchestrator is unbounded and cannot be bounded.** Both real token budgets found anywhere
are enforced by programs; this orchestrator is a model running a skill, and no hook input carries token
counts or context size. **Nobody in the coding-agent systems surveyed has such a bound either** — so it is
an admission, not a gap to fill.

**Survey's five-dispatch ceiling is prose, and no run is checked against it.** Unlike `fix_cycles >= 3`
there is no field to read and no arithmetic to run — the number lives in the instruction, and a session
either honours it or does not. It is written down at all because the unbounded form measured itself once,
at thirteen researchers on a thirteen-Outcome spec.

**What a test can hold is the instruction, and that is what one holds.** The four files quoting the number
are pinned to the same number and the split is pinned to adding up, because a loosened ceiling with three
stale quotations still reading five is drift a test can see. **A sixth dispatch is not**, and no test in
this repo pretends otherwise.

**The determinism split.** `fix_cycles` being an integer and `>= 3` being arithmetic is deterministic, and
so is *is a box still open* — a regex against a fixed grammar, roughly 100% accurate where prose reads at
roughly 5%. **The evaluation is not**, because the router is the checker and that is a model reading a file.
**Nor is the increment**: `fix_cycles` rises because Critique's instructions say so, and a missed increment
means the cap silently never trips. **What bounds the damage: a missed increment causes more unattended
fixing, not a bad merge.**

**Nothing is built to observe.** No metrics script, no `devpath:status`, no dashboard, zero new fields.
Observation has no remote channel by construction, and every scheduled measurement found anywhere in this
environment is dead.

**The plugin must not claim the code-health metrics measure whether `devpath` works.**

**Unattended is not opaque.** A human can navigate to a live worker from the orchestrating session, watch
it run, and navigate back. That is why `devpath` names no transcript read.

**Nothing depends on worker lifecycle for correctness, only for cost.**

**Except on a harness that will not spawn at all, where the critic's half stops being about cost.** The
builder walks down to the bottom rung and hands back, which is the cost trade working as stated. The critic
does not run, because a session judging its own build is the contamination rule and no price makes that
acceptable.

**Live messaging is a declined available mechanism, not an assumed-absent one.** Sending a message to the
main conversation from a background subagent works, and returns *queued for the main conversation's next
turn* — queued, not interrupting, so it saves not one step over returning.

**Serial slices are a starting posture, not a ceiling.** Presenting serial execution as a principle would
be dishonest.

**Two nested bounds hold the outer loop, which is why a new slice's counter starting at zero is not a bug.**

### Softness that is stated rather than hidden

**Skill-to-skill invocation is model-driven and is not guaranteed.** `devpath:technical-design` reaching
`devpath:survey` and `devpath:slice`, `devpath:build` reaching `devpath:critique`, and
`devpath:integrate` reaching `devpath:learn`, are instructions naming a skill. There is no call syntax and
no event that fires on a skill finishing. Claude reads the instruction and normally follows it, and
**nothing in the harness makes it certain.** Both ways it can fail are visible in the artifact.

**The Build → Critique edge is the one with a demonstrated failure history, and it has failed twice.** The
first time the imperative was missing. For one release `devpath:build` described a Build ↔ Critique loop and
instructed nobody to run one — three of the four compositions were imperatives, that one was implicit, and
the first real spec built seven slices, six of them to `done: true`, with an empty `## Critique findings` on
every one and a real correctness defect among them.

**The second time the imperative was in front of the session and it skipped the call anyway.** The build
turn reported three unticked criteria and a mutation result, closed on the line *Dispatching the critic
now*, and ended. No error and no rejection: the call was never emitted, and the sentence describing the act
stood in for the act. `devpath:build` names that shape now, where the report is long and the dispatch is one
clause at the end of it, and **an instruction is what that change is, so it lowers the odds and guarantees
nothing.**

**What catches either is that `fix_cycles` absent on a slice that carries code is the slice pass never
having run**, which Integrate refuses on. **That pairing is the answer almost everywhere in this design**:
an instruction a session may skip is made visible in the artifact rather than shouted louder. *Almost*,
because it answers at the merge gate — between a skipped dispatch and that refusal, the walk can build every
remaining slice on top of code no critic has read, and **an instruction cannot be the answer to an
instruction being skipped.** That is what the second failure argues for and the first did not: **block 8 on
the menu**, a reminder fired at the moment the act is due, on a channel that cannot deny. It is a third
answer rather than a guarantee, and the menu row says so.

**`devpath` has no bypass, because it never blocked anything.** Non-use is always available and always
free — which is why choosing not to use it is an adoption question, not evidence against the design.

**A plugin that failed to install cannot detect that it failed to install.**

**The adoption mechanism is a person, and it stops working at engineer four and at the first reinstall.**

**Abandonment must delete the branch, and this mandate has no mechanism.** Abandonment is a human closing a
pull request on github.com; no `devpath` skill is running, no hook event fires on one, and there is no
block to paste. **What it costs when they forget:** a branch with no pull request open against it and no
spec merged. *The ref is the status* still answers, but it stops distinguishing *abandoned* from *in flight
and quiet* — and this is the command that still tells them apart:

```
gh pr list --state closed --search "is:unmerged"
```

**A rejected design is findable but not surfaced, deliberately.** Nothing pushes it at you at the moment
someone re-proposes the same idea.

**`devpath` cannot forbid migration onto an existing repo, and does not try.** The preconditions assume a
first commit; three of them are one-time repo-wide jobs a running repo does outside `devpath`, before it
starts. A repo arriving with its own slicing rule has two rules until a human picks one.

**A repo whose promotions run through DevOps Center is out of scope, and deliberately not a precondition.**
DevOps Center names the branch and opens the pull request itself from org-side credentials, and a pull
request merged outside it leaves the work item *partially promoted* — which blocks that stage for everyone,
not only for its own work item. So one pull request per spec with auto-merge armed cannot coexist with it,
and **Integrate genuinely breaks** on that class of repo. It is not on the precondition list because the
governance is **entirely org-side** — there is no repo artifact anywhere to observe, so `devpath:fit-check`
could never check it, and **an unenforceable entry on that list is the exact defect the list exists to
prevent.**

**Survey gets more expensive as the corpus grows.** Accepted, and to be watched; the bounded-by-query rule
is what keeps the curve survivable.

### Two structural limits, recorded rather than solved

**Two specs inventing the same object for the same concept never collide.** If one creates
`RentalContractLine__c` and another `RentalLineItem__c`, **git sees no conflict, CI sees no conflict, both
scratch orgs deploy clean, both pull requests merge green. Nothing goes red anywhere.** Survey is the only
surface that catches a *concept* collision — every later surface can only catch a *path* collision — which
is why its sideways-reading instruction is load-bearing, and **the design surfaces rather than prevents.**

**A trigger derived from existing artifacts is blind on a greenfield repo.** `touches` holds pre-existing
paths only, so anything derived from it sees the brownfield case and misses the greenfield one — on a
target whose dominant act is creating. **This is a class with two known instances; check every future
derived trigger against it.**

### The one open risk this design carries and cannot close

**Every measurement available concerns whether a rule was *delivered*, never whether delivery changed
*judgment*.** The instrumented probe measured a nameable, binary instruction and found delivery and
compliance tracking together 15 out of 15 — but a canary token is trivially checkable.

**So: if presence does not move judgment behaviour, Critique carries the standards attachment alone** — the
review-only posture this design rejected. That is a risk, not a decision to make, and it is stated rather
than resolved.

### Where this design does something the surveyed systems do not

**No precedent was found for carrying one draft pull request across a whole workflow.** Nothing in roughly
120 repos does it. Every primitive is documented behaviour, so **the residual risk is unfamiliarity, not
mechanism.**

**Relevance-scoping is the one axis nobody in the surveyed systems exploited** — and the claim that it
*discards nothing* is **false**: `paths:` silently withholds a rule from an agent creating a new file, with
no signal that a rule exists and was withheld. **The cost claim stands; the coverage claim does not.** And
nobody has written down the pair *scope your rules and instruct reading so the scoping works*; the halves
have precedent and the best public instance ships the bug.

**Nothing in roughly ninety systems retrieves from a corpus of prior specs.** So Survey has no built
retrieval mechanism, and the instruction to grep is an instruction where there was silence, not a reversal.

### Reasons that must survive, or a later reader thinks something lost its rationale

**Normalising `upstream.url` at write time did not lose half its reason.** There is **no drift check and
there cannot be one** — detecting that upstream moved requires reading upstream a second time, and the
reader is architecturally unavailable rather than merely unbuilt — so the sibling report carries the
normalisation alone.

**`## devpath feedback` leaving the repo does not reintroduce the tracker.** The settled constraint is
about the **context store**; this channel is write-only, off-workflow, human-initiated and human-confirmed.
**And `Jonah-Stephans/devpath` must be public — a hard requirement, not a preference**, because that
channel files issues with an engineer's own `gh` credentials and the install commands above must work
without a token.

**A directory level per requirements set is forbidden**, because it is the deleted level returning by the
back door.

**There is no `stage:` field, and the ergonomic cost is real** — progress is nine observations rather than
one.

**You refer to a spec by its draft pull request's number or title**, and there is no `pr:` field.

**Why `devpath` puts file paths in specs when adjacent tooling forbids it** — three reasons that rule
could exist, and only one falls. **Rot** falls, because a spec in git moves with the code. **Altitude**
survives: modules are stable, and which file a module lives in is Build's business. **Anchoring survives,
and git does nothing about it** — tell an agent the change goes in a named file and it edits that file even
when the right change is elsewhere. So `creates:` is deleted, a spec-level paths field is deleted, and
`touches` is declared as *what this slice will collide with, not where to work*. **The residual cost is a
prose mitigation for a model-behaviour risk, which is weak: the anchoring risk is live.**

**The prose caps did not lose their reasons.** The table under *What you can gate on* above carries the
anchor for all three numbers, and `devpath:build`'s prohibition — *a disposition does not re-argue the fix*
— is the lever those caps only backstop: across a field run's 114 boxes, **70% of 29,129 words of findings
was fix narrative written after the fix had already landed**, so none of it can have helped the fix.
**250 caps the whole box rather than its post-fix half**, because capping a half needs a splitter and the
string that run split on is one it invented — the shipped grammar is *a box entry is one line beginning
`- [` at column zero, with nothing nested under it*. **The exemption keys on the box marker rather than on
a tag word**, because nothing mechanical reads a tag word, so *tagged* is not a line a check can draw —
which takes the untagged pause box in with the two that carry a tag, and the wider set is the better rule
anyway: a box under `## Deviations` is an item whose **marker** a run reads, since a repo taking block 1
denies a push on it and Integrate's test 1 refuses on it, where a bullet is only ever read by the human at
merge. **`## Critique findings` gets no section budget**, because a budget there caps how many defects a
critic may report, and every closed box leaving for the archive at the next re-review bounds that section
instead. **And widening the commit body to a closed set of two is not new headroom** — the field run behind
the caps wrote 43 words a commit against the approved project's 94, because here the body is a path.

**Which standard a repo uses is out of scope, and the plugin is built so the answer is swappable.** A repo
with no standards rule builds against nothing, which is the honest degradation and not a defect.

**Build's test-first line is a suggestion whose rationale names its own expiry** — it retires when Apex
gets mutation testing.

**Waivers split by gate kind** — none on `devpath`'s two gates, because you cannot route around a human
refusing to approve something, and the first request for one means the gate is wrong. Every check
`devpath` performs is fixable on the spot. **CI gates are different and they are the repo's**, with a
deliberate, dated exception route meeting four obligations.

**`devpath` ships its own conversation instructions rather than calling a third-party skill.** No
third-party plugin dependency, and a general grilling skill ends when the questions run out while this
conversation must end in an approval and a written artifact.

**The design conversation's 🟡 and ❇️ markers diverge from grilling's on purpose, and neither reason is
taste.** Colour carries the state — yellow is the question still waiting on the human, green is the answer
already on the table — so a round is scannable before a word of it is read, which is the complaint the
format answers. And a byte-identical block invites the refactor the third-party-dependency rule
forbids: an editor who finds an exact copy of grilling's format is one step from replacing it with a
call to grilling, where a distinct pair makes `devpath`'s copy self-evidently its own.

**Branch-name discovery requires an attached HEAD.** `git branch --show-current` returns empty with exit
code 0 under a detached HEAD, so `devpath` says *you are not on a branch* rather than *no spec on this
branch*. It fails safe and it fails confusingly.

**The uniform-directory cost is real**, and the reason it is worth paying is that a file's cost is the extra
cold read, and uniformity compounds across every skill, script and check.

**`checkpoint`'s mild collision with a debugger feature is recorded rather than hidden — and
`confirmation` was *not* the zero-risk alternative**, because first-party tooling ships *confirmation gate*
as a literal meaning something slightly different.

**Build may re-cut unattended and records it**, and *stop and ask* was rejected because it would make the
slice layout more sacred than the design itself.

**`devpath` names no tool bug and grants no exemption for one.**

**Nothing routes on `type` today.**

**The testing standard is a starting point to be challenged, not an adopted standard.** What is settled is
where it attaches.

**Stage names are prose-facing, skill names are invocation-facing, and only the latter has to be unique.**

**The evidence base is not the target list.** Every measurement above was taken from repos `devpath` does
not run on — it is built for greenfield second-generation package repos. **Those measurements stand and
none is retracted.**

</details>

## Licence

MIT.
