---
description: Build the slices of an approved devpath spec into code and tests. Use once a design is approved and its slices are cut.
---

# Build

`devpath:build` loops Build ↔ Critique over the spec's slice list in `depends_on` order. This body has
two halves: **the orchestrator's instructions**, which is what the main session does, and **the worker
prompt**, which is what each dispatched subagent is told.

## Refuse first

Read the front matter of `devpath/<slug>/spec.md`, then of every slice file. That read is the validation
— there is no separate front-matter check anywhere in `devpath`, because a read the router needs in order
to route cannot be disconnected.

- **`git branch --show-current` returns `main`, `<base>`, or a branch with no matching spec directory**
  → **stop.** Do not guess which spec this is. Say the next act: `git checkout <slug>`.
- **The command returns empty** → **stop, and say what is actually wrong:** it returns empty with exit
  code 0 under a detached HEAD, so the truth is *you are not on a branch*, never *no spec on this
  branch*. The fix is one `git checkout -b <slug>`, and it is a human's.
- **The working tree is dirty** — `git status --porcelain` prints anything → **stop, name what is
  uncommitted, and do not dispatch.** Something is uncommitted, and that is worth surfacing rather than
  working around. **A `git stash` dance is not the answer** — it hides exactly what this stop surfaced,
  and its failure mode is losing the engineer's work silently. What the stop prints, and what it asks, is
  below.
- **`design_approved` is not `true`** → **stop.** Build runs behind gate 2. Say the next act: run
  `devpath:technical-design` and take the design through its gate.
- **Zero slice files** → **stop.** Say the next act: run `devpath:slice` against the approved design.
- **A slice's `depends_on` does not parse, or the front-matter block does not parse, or a field carries
  the wrong shape** → **stop and name the exact field and the slice.** *Malformed* stops the stage;
  *absent* is a legal state meaning *not yet*, and `wrote`, `done` and `fix_cycles` are legitimately
  absent on a new slice.
- **A slice's `depends_on` holds a slice that is not `done`** → **refuse and name the slice.** A
  structural check on a field that already exists, not a gate.
- **A `touches` path that does not resolve** → **record a deviation and carry on.** Do not refuse: a
  sibling spec may legitimately have moved or deleted the file since Slice ran, and refusing here would
  fail this spec for a condition its author did not cause and cannot meaningfully fix.

**Prefix every message a gate or refusal prints with `devpath: `.** Suggested — two enforcement layers
with overlapping symptoms are otherwise indistinguishable, and a human reading a stop should know which
plugin stopped them.

### The dirty-tree stop, where the harness offers a question tool

**This stop is the orchestrator's, and that is what makes it askable.** `## Refuse first` runs in the
main session ahead of any dispatch, which is the one seat the question tool exists in — it is absent
from a subagent and fails synchronously there.

**Print every dirty path before asking about any of them.** Per path: whether git tracks it, how it
differs from `HEAD`, and **which direction it differs in.** A tree that is *short* of the committed file
holds an older copy rather than an edit, and saying that out loud is the finding. A diffstat on its own
leaves the reader to guess, and a guess is what this stop exists to stand in the way of.

**Direction is also what says whose work it is, and it is the only thing here that does.** Nothing this
run writes moves a file backwards, so a path behind `HEAD` is not this run's — which is the case this
stop was grown from, where it was upstream's. A path ahead of `HEAD` while a slice still carries no
`done` is more likely this command's own killed run, and calling that one *upstream* sends the engineer
looking for a colleague who does not exist. **`touches` does not settle it** — it is a collision list
holding pre-existing paths only, so the new files an interrupted build leaves are invisible to it. Where
neither signal decides, print the state and say nothing about the cause.

**Write that sentence for someone who does not work in this code.** The disposition that armed the merge
this stop was grown from was written by a reader holding three file names and no diff. Whoever typed
`devpath:build` is who answers here, and *the tree is 72 lines short of the committed file* lands with
them whether or not they have ever opened that file.

**One question per path, never one for the tree.** Three files reached one box and took one disposition
that was wrong about all three of them. Paths in a single dirty tree have different right answers, and
one question forces one verdict — the box's own shape, at a new address.

**More than four dirty paths → print them all and stop, and ask nothing.** Four is the tool's own cap, so
the stop is always one call and never a queue; past four the finding is the state of the tree rather than
anything about a path in it, and a queue of clicks is how somebody clicks without reading.

**The option set follows what git knows about the path**, because the acts on offer are not the same:

| The path | The exits |
| --- | --- |
| tracked, modified | restore `HEAD`'s version, commit it here, carry it off |
| untracked | commit it here, carry it off |

> **Only one exit throws anything away, and its own description says so out loud.** Restoring `HEAD`'s
> version discards an edit and nothing holds it afterwards — that is the whole of what a click can
> destroy here. Deleting an untracked file destroys a file rather than an edit, and no click buys that:
> the human does it in their own terminal or it does not happen.

```
  Dirty tree · tolerance-config
  Nothing is dispatched. Three paths are uncommitted.

   M .claude/rules/rstk-slds2-ux-standards.md   72 lines short of HEAD
     The tree is behind the commit, so this is an older copy and not an edit. What is
     missing from it: the var(--hook, fallback) requirement and the --slds-c-* ban.

   M .claude/rules/rstk-lwc-standards.md         4 lines short of HEAD
     Same direction. The tree is behind the commit.

  ?? job                                         9 bytes, untracked, never tracked here.
```

```
  .claude/rules/rstk-slds2-ux-standards.md — what happens to it?

  ▸ Restore HEAD's version   git checkout -- the path. The 72 lines come back and the
                             tree's copy is gone, with nothing in the reflog holding it.

  ▸ Commit it here           Commits it on this branch ahead of the first dispatch, so
                             it lands on this pull request under its own message
                             instead of inside a slice.

  ▸ Carry it off             Commits it on a branch beside this one and switches back.
                             Nothing is lost and nothing rides on the spec.
```

> **The tool presents the decision. It never presents the material.** Every path prints in full above the
> prompt, direction and all, and an option's description says what the choice *does*. **A click is legal
> downstream of a read and never instead of one.**

**No option is marked as recommended.** This run can read the diff and it cannot read the engineer: *the
tree is behind the commit* is a finding, *and therefore throw the tree's copy away* is a judgment about
work that is not this run's. Marking one would be the plugin answering a question it opened because it
could not answer it. `tests/lint.sh` check 7 holds that against this file's own illustrations.

**Re-read `git status --porcelain` when the acts are done, and let it decide.** Clean → carry on into the
run. Anything left → stop and name what is left. **The rule is the tree at dispatch, never how the tree
came to be clean**, so a run that cleared it by asking and a run an engineer cleared by hand are the same
run from here on.

**Where the harness offers no such tool, the printed block is the whole handover** and the run stops
there: the engineer acts and types the command again. **Both paths leave the same tree and the same
commits**, and what differs is how many times the command was typed, which nothing downstream reads — no
field, no marker, no detection step.

**No row on `## Print what you re-derived`.** The acts print as they happen, above that report, and the
report holds what this run re-derived from the spec directory rather than what it did to the tree.

---

# The orchestrator

**The main session is the orchestrator, and it re-derives its place from the spec directory, never from
its own conversation. One subagent per slice built, one per fix pass, one per review pass — a subagent
*is* a fresh context, and it is the only kind a running skill can produce, since a session cannot reset
its own context. Every worker is fresh and none is ever resumed, including one whose pause a human
cleared.**

**Why re-derive from disk.** The measured failure of conversation-held orchestrator state is specific and
expensive: controllers that lost their place have re-dispatched entire completed sequences of work.
`devpath` already holds the right things — `done` per slice, `fix_cycles`, `## Critique findings`,
`## Deviations` — in a committed directory.

## Worker lifecycle

| Agent | Lifecycle |
| --- | --- |
| Build, per slice | fresh subagent |
| **Build, per fix pass** | **fresh** |
| **Critique, per pass** | **fresh, always** |
| Build, after a human clears a pause | **fresh. No worker is ever resumed.** |

**Suggested, with its reason**, because this line is a model property that has already moved once.

**The reason is context rot, and it is not the thing newer models fixed.** *Context anxiety* — models
wrapping up prematurely near a perceived limit — is fixed. Context rot is not going away: recall
**decreases** as tokens rise against an attention budget, performance **degrades as the window fills**,
and context windows of all sizes are subject to context pollution. **A bigger window is explicitly not
the answer, which is what would retire this line.**

**The trade-off, stated: resume buys the *reasoning* and pays for the *tool output*, and the two arrive
welded together.** On Salesforce the tool output — file reads, deploy logs, test runs — is the expensive
half. **And compaction discards the valuable half first:** specific instructions from early in the
conversation may not be preserved, and the slice brief is earliest in the transcript. So past the first
compaction a resumed Build holds the expensive half, has lost the valuable one, and has an auto-generated
lossy summary where a fresh Build would read the curated statement on disk.

**Two more reasons native to this design.** A fix pass is not an exploration — its input is a named list
of confirmed findings, so the thing resume buys is worth least exactly where its cost is highest. And a
fresh Build is what keeps the spec honest: the quality bar for the spec is *could a fresh session pick
this up from the spec alone?*, and if Build resumes, nothing on the hot route ever exercises that.

**Never resume an agent into a role that judges its own prior output.** Critique always judges; Build
never does. That governs the critic. **What governs the builder is context rot, not contamination** — two
rules, two reasons, and neither is the other's corollary. The measured failure of a resumed judge is
silent: one fix round shipped a correctness defect plus the test blessing it, and the resumed session
passed both with zero findings.

**And say it once: nothing depends on worker lifecycle for correctness, only for cost.** The ladder is
resume → return early and respawn → the human re-runs the command, and the engineer's seat is identical
at every rung.

**Where a dispatch is refused, or the session is under an instruction not to dispatch, the bottom rung is
the route, and it is available mid-run.** Finish the build pass in hand, say plainly that the remaining
slices want a fresh session, and hand back. **Say the uncritiqued state with it**: no critic ran, so
`fix_cycles` is absent on what was just built, which is the condition Integrate refuses on. **That is a
legitimate way to run Build rather than a failure**, because the seat is identical at every rung and the
line above already says so.

**A fix pass is the exception: hand back before opening it.** That pass ends in a critic dispatch this
session cannot make, and a committed fix leaves nothing to see — `fix_cycles` is already on the slice from
the pass that raised the finding and `- [x] fixed` closes the box, so the slice would read finished and
clean. **Leave the finding open**, because an open `- [ ]` under `## Critique findings` is what Integrate
refuses on.

**A session that cannot dispatch says so and stops rather than critiquing its own build inline.** That is
the contamination rule above, not the ladder, and the contamination rule is where the cost-only line does
not reach: the builder's rungs trade cost for context, and there is no rung on which the only critic
available is the agent that wrote the code.

**No named agent definitions.** Workers are the generic subagent with an inline prompt. A definition buys
nothing a prompt does not, and it is the one surface a local `.claude/agents/` file silently outranks.

## The order walk

**Mandated. Before dispatching anything, sort the spec's slices into `depends_on` order. If no order
exists, refuse, name every slice in the cycle, and stop. The next act is `devpath:slice`.**

`depends_on` is written by a model and nothing validates that the graph is acyclic, and **a two-slice
cycle is an unbounded loop in the busiest skill.** This is cheap rather than machinery: the graph is small
— N is single digits in practice — Slice wrote every slice file in one pass so the whole graph exists at
the moment the check runs, and the refusal is fixable on the spot.

**It is a refusal and not a deviation to work around**, because there is no correct order to pick.
Choosing one would be Build deciding which dependency the model did not mean.

**No new field.** A cycle is a property of `depends_on`, computed from `depends_on`.

**One rule binds every run of this skill, whatever the walk finds: `## Outcome checks` is expired before
the first dispatch of any run that will change code.** A fix pass invalidates those verdicts exactly as a
new slice does. `### The verdicts expire when the code moves` below states it once, and nothing about it
is conditional on what the walk found.

**The walk is also where a finished spec gets its second look. Sorted, and with every slice carrying
`done: true`, open `## Outcome checks` on `spec.md` by name before reporting there is nothing to do.** The
section below is what to do with what is in it.

## Cut for an unmet Outcome, then expire the section

**Mandated, and it is a heading you open by name.** The other readers are `devpath:integrate`'s own step
1, which resolves a carried-forward `won't fix` against `## Outcomes`, and a `devpath:initiate` re-entry,
which is exit 3 rather than this one. Integrate writes it and Integrate refuses on it, and the shortfall
then sits on the spec with no reader at all. A cold `devpath:build` after that refusal sorts the slices,
finds every one `done: true`, and reports there is no work — which is the run the engineer typed to clear
the refusal. A worker reading `spec.md` for Intent and Outcomes skims straight past a heading nobody sent
it to.

### The verdicts expire when the code moves

**Before the first dispatch of any run that will change code, expire `## Outcome checks` and say what
went. Every line except `- [x] won't fix`, which carries forward verbatim.** **The heading stays; the
lines under it go** — an expired section reads as *the pass has not run against this code*, which is what
README's placeholder exception already says an empty one means. The section is a verdict on the diff that
existed when Integrate ran, and you are about to make that diff wrong. Keeping it is how a later cold run
reads a stale shortfall as a live one.

**The carve-out is `skills/integrate/SKILL.md`'s, and it holds here for the reason stated there** — the
machine does not relitigate a human's decision. **The acts differ.** Integrate rewrites every line but
`won't fix` when it runs the pass; this run deletes every line but that one. One replaces a verdict and
one leaves none, and the same line survives both.

**It hangs on *any run that will change code*, not on the cut below.** A fix pass three weeks after the
refusal invalidates those verdicts exactly as a new slice does. One instruction, at one point in the run,
covering both.

**Read the section before you expire it.** The cut below is its one reader, so a run that expires first
has thrown away the shortfall it was typed to act on.

> **Never expire a `- [x] won't fix` line.** That is the ledger, and a machine deleting a human's decision
> silently is the failure the announcement exists to prevent.

**Announcing is mandatory.** Name every Outcome whose line you expired, by ID, in this run's output. A
verdict that goes without a sentence is one the engineer still believes is on the page, and no field makes
an old one look old.

### The cut

**The trigger — every slice carries `done: true`, and `## Outcome checks` holds a `- [ ] unmet` line.**
With any slice outstanding there is work already and the walk never reaches this test. Between the cut and
the build the new slice carries no `done`, so a run arriving mid-flight finds work waiting and builds it.

**No `- [ ] unmet` line, an empty section, or no section at all — say so and stop.** Three ways to arrive
here and one act out of all of them: the pass ran and every verdict is current; the pass ran, an earlier
Build expired it, and the slices that run cut are now done; or **the pass has never run**, which is every
spec's first trip past this point. **Absent and empty are the same state and always have been**, so the
second and third are not worth telling apart. Report that every slice is done and give the next act:
`devpath:integrate`. **Cutting on an empty section is cutting with no shortfall to cut against**, which is
a slice nobody can write `## What to build` for.

**Cut one slice per `- [ ] unmet` line**, never one slice for the first one found. Four unmet Outcomes are
four shortfalls, and a run that cuts for one leaves three on a section it is about to expire.

**Resolve each line's `O<n>` against `## Outcomes` before you cut for it. A line whose ID is not there is
not cut for** — name it in the announcement above and cut for the rest.

**The ID is gone because the Outcome was retired**, which is exit 3 of Integrate's refusal doing what it
was typed to do: the target was wrong, `devpath:initiate` rewrote it, and the shortfall on this line is a
verdict against a target this spec stopped asking for. **Cutting for it builds toward the thing the rework
rejected**, and `## What to build` would name an ID no reader can resolve.

**Skipped rather than refused, because this run is about to expire the line anyway.** That is the split
`skills/integrate/SKILL.md` makes at its own step 1: a stale `- [x] won't fix` is a permanent admission
riding into a pull request, so it stops the run; a stale `- [ ] unmet` is a verdict this run deletes, so it
costs a sentence. **The announcement is already the channel** for saying a line went, and a hard exit here
would stop work the rest of the section is still good for.

**If every unmet line resolves to nothing, nothing is cut** — report that every slice is done and give the
next act, `devpath:integrate`, which rewrites the section from scratch.

**The slice file is `skills/slice/SKILL.md`'s `## Write`, followed exactly** — front matter carrying
`depends_on` and `touches`, the test-first block, and exactly the four headings that section prints, with
`wrote`, `done` and `fix_cycles` absent. The schema hook in README's own hook list flags any heading
outside those four. **Go to that section by name** rather than writing the shape from memory; it is the
same argument this section makes for `## Outcome checks`.

**`## What to build` comes from the shortfall, which is the only source you have.** The `- [ ] unmet` line
says what was observed and carries the ID that resolves against `## Outcomes`, which says the target, and
`## Design` says how this spec builds things.

**The written entry — a plain bullet under the new slice's `## Deviations`, naming the Outcome by ID and
reproducing the shortfall:**

```markdown
## Deviations
- Cut for O2, unmet at Integrate: throws above 200 rows; batching is fixed at 200 and nothing chunks
  past it.
```

**The shortfall is reproduced rather than paraphrased**, exactly as `devpath:integrate` reproduces it at
its refusal — the trailing period closes this bullet's sentence and is the only thing added to the line.

**The ID rather than the Outcome's text, because this entry is permanent and the text is not.** A bullet
under `## Deviations` is never deleted, and `## Outcomes` is rewritten whenever Initiate or Design revises
the problem — so an entry quoting the statement would sit in front of the human at merge claiming a target
the spec stopped asking for. If O2 was later retired, this bullet naming a retired ID is the trace working.

**That is the shape `devpath:slice` already writes** when a reworked design supersedes a built slice: a
plain untagged bullet under `## Deviations`, nothing deleted, counted into the pull request body by
Integrate's step 4 and read at the path it gives. One convention, two writers, and
`## How long a finding and a deviation may run` below holds for both.

> **A plain bullet, never `- [ ]`.** Integrate's test 1 greps `^[[:space:]]*- \[ \]` across the whole spec
> directory, so a box here holds this spec's merge open forever. **No new tag either** — the closed set is
> `fixed`, `met`, `false positive`, `won't fix` and `excess`, and this is not a disposition.

**Then expire the section and announce, in the commit that carries the cut.** A commit holding new slices
and the old verdicts is a branch that reads as refused and rebuilt at the same time.

**Writing `spec.md` from a Build run is not new authority.** Inside this same run, Critique's slice pass
already writes `## Traps` there and the orchestrator commits it alongside the slice. This is that division
read over one more section.

**This is the orchestrator's act.** Build already re-cuts the slice layout unattended and writes the
change down as a deviation; cutting for an unmet Outcome is that authority read over the spec rather than
over one slice, and it is a decision about the whole slice list, taken before anything is dispatched. What
follows is an ordinary dispatch of an ordinary slice — so Integrate refuses again for the reason it
already refuses, until that slice is built and critiqued.

### Nothing reads the written entry to decide whether to cut

**No run branches on `## Deviations`.** The entry above is there for the human at merge, and that is the
whole of its job.

**A guard there does not work, which is why none is built.** Entries under `## Deviations` are permanent,
so a guard reading them answers *did I ever cut for this Outcome* rather than *is this unmet line stale* —
and after the first attempt those two diverge. Integrate re-runs, the Outcome is still unmet, step 3
refuses, the engineer runs Build, and Build refuses. **The outer loop would then work exactly once per
Outcome**, against this plugin's own bound: that loop is bounded by a human typing the command, every
single lap. **Expiring the verdict is what a stale verdict needs**, and a second refusal on the same
Outcome sends the engineer back here and this section cuts again.

### The limit: this cuts a slice, it never redesigns the spec

**Apply the test this skill already states — does resolving it change *what* the slice builds, or only
*how*?** Chunking a fixed 200-row batch is *how*: cut the slice. *Meeting this Outcome means going
Queueable* is *what* — an architecture decision nobody approved, and **not this exit at all.** It routes
to `devpath:technical-design`, which owns `## Design` and takes that decision behind the gate covering it.

**Say so and stop**, rather than cutting a slice that quietly redesigns the spec. Same rule as *a
criterion you cannot satisfy is not edited into one you can*, read over an Outcome instead of a criterion.

**Integrate cuts nothing.** It produces a verdict, and this section is the one route from that verdict
back into work.

## Read `fix_cycles` before opening a fix pass

**At `fix_cycles >= 3` on that slice, do not open another fix pass unasked.** Ask the engineer already in
this session — **no new human, no third gate.** The answers are the disposition grammar, *keep going*,
and *cut a new slice*.

> **The cap does not stop the work. It stops the work being unattended.**

`fix_cycles` is Critique's field and Critique's write. **Never write it here.** Build's field is `done`.

### Does the finding name work this slice was cut to do?

**That is the whole axis between *keep going* and *cut a new slice*, and it is readable from the slice
file at the moment of the trip.** Read each open finding against `## What to build`. **Inside the
behaviour the slice builds → another lap**, and five unalike defects in that behaviour are still five
defects in this slice. **Outside it → cut**, because fixing it here grows the slice past criteria a built
slice cannot re-cut — *the criteria on a built slice are not re-cut at all* — so no number of laps closes
it.

**A finding that changes the design is neither, and this is not its exit.** Apply the test this skill
already states — *what* the slice builds or only *how* — and route *what* to `devpath:technical-design`,
exactly as `## Cut for an unmet Outcome`'s own limit sends it.

### Cutting is the act `## Cut for an unmet Outcome` already describes

**Go to `## Cut for an unmet Outcome, then expire the section` by name and follow it**, including its
limit test. **Its trigger is not widened**, and this stop supplies its own instead. **The authority
reaches because the seat is the same**: that section is the orchestrator's act and so is this stop — the
capped slice keeps `done: true` and is cut around, never re-cut.

**Where that section reads off an unmet Outcome, read off the finding instead**: `## What to build` comes
from the open finding, and the new slice's `## Deviations` bullet names the slice it was cut from —
`- Cut from 01 at the fix cap: keyboard section reorder moves ±1 through a two-dimensional layout.`

**Two writes, and the second is the one that gets forgotten.** The `## Deviations` bullet, and a
disposition closing the moved finding: Integrate's test 1 greps `^[[:space:]]*- \[ \]` across the whole
spec directory, so a finding left open at the cut holds this spec's merge open forever. It closes as
**`- [x] won't fix — moved to slice NN`**, the one reason `devpath` writes for itself, in the fixed form
`skills/critique/SKILL.md` states. **No sixth tag** — `tests/lint.sh` asserts the set. And **no Outcome ID
on that line**: `lint.sh`'s handle grammar is scoped to `## Outcome checks` and never reaches a finding.

**The stop is a halt, not an end.** *Keep going* resumes on the granted lap; a disposition that leaves
nothing open walks to the next slice; *cut a new slice* cuts, writes both records, and dispatches. **An
answer that leaves another finding open asks again on what is left** — the cap is still tripped and
nothing here granted a lap. The grant is *spoken and never stored*, so a run that ended here would kill it
before it could be spent. What `## Any stop that needs a human stops the whole run` forbids is continuing
**without** an answer.

### Print every open finding, and mark no option

**Every open finding on that slice prints whole above the prompt, as `## Critique findings` holds it.**
`## Print what you re-derived` does not cover it: that prints before the first dispatch, and a cap trips
after a critique it never saw.

> **The tool presents the decision. It never presents the material.** A click is legal downstream of a
> read and never instead of one.

**No option is marked as recommended.** The run has computed no verdict here — it is stopping precisely
because it cannot decide, which is the three gates' reason rather than the dirty-tree stop's. Marking one
would be the plugin answering a question it opened because it could not answer it. `tests/lint.sh` check 7
holds that against this file's own illustrations.

**A description says what an option does to each finding, never whether it is the right one** — that is
where a mark comes back without the word check 7 greps for. This draft of *False positive* was cut for
being one: *"On 2 this would be saying the reorder bug is not real, which the `CARD_ARROW_DELTAS` reading
does not support."* **Only the options that need a choice name the findings**; the two dispositions do the
same write on any finding.

```
  01-width-follows-columns-side-by-side — the cap is reached. What happens here?

  ▸ Keep going              Another fix pass on both. 1 is a defect in the width
                            mechanism this slice was cut for. 2 is keyboard reorder,
                            absent from 01's ## What to build, so fixing it here grows
                            01 past its criteria. One lap, or say how many.

  ▸ Won't fix               Name 1 or 2 and give your reason. This session writes the
                            tag and your words onto that line.

  ▸ False positive          Name 1 or 2. Same write, and the loop stops holding on it.

  ▸ Cut a new slice         For 2. Keyboard reorder is in the design, so this is a cut
                            and not a design change. Slice 05 takes it, 01 keeps
                            done: true, a bullet under 05's ## Deviations records it,
                            and 2 closes as won't fix — moved to slice 05. 1 stays
                            open, and this stop asks again on it.
```

## Print what you re-derived, before anything else

**Mandated. The first thing this run prints is the state it re-derived from the spec directory.** It
prints before the first dispatch, and before any report that there is nothing to dispatch. **A run that
stops at `## Refuse first` prints its refusal instead.** It derived no state to print.

**The state is the directory as it stands at that point, not as the run opened it.** A run that cut a
slice for an unmet Outcome lists that slice, and a run that expired `## Outcome checks` says which lines
went.

**This section is late in the file and first in the run.** Every row but one is computed by a section
above it, which is the first point at which those are known. The exception is the pause check, which reads
the frozen test below.

**A run with nothing to dispatch prints the report too.** Every slice `done: true` with no
`- [ ] unmet` line ends in *there is nothing to do*, which is a conclusion this run reached rather than an
exemption from the report. That is the run an engineer types to clear an Integrate refusal, and a wrong
one is the failure.

**Why the run prints it.** `# The orchestrator` rests this skill on re-deriving from disk instead of from
conversation, and a run that keeps the derivation to itself reads exactly like one working off memory.
The print is how a human checks that claim in one glance.

**The seven rows:**

- **Branch and spec.** Which spec directory this run decided it is on, and that the branch matches it.
- **`design_approved`.** `true`, from `spec.md`'s front matter.
- **The order.** The `depends_on` chain the walk sorted, and that it is acyclic.
- **Each slice.** Its `done`, its `fix_cycles`, and its open findings under `## Critique findings`.
- **The pause check.** Per slice, an open box under `## Deviations` that is a pause, and which kind:
  untagged, or tagged `blocked`. Or none. The frozen test below is the grammar, and `- [ ] excess` is not
  a pause.
- **`touches`.** Which paths resolve, and which do not. `## Refuse first` had this run record a deviation
  for each one that does not.
- **What expired.** Every Outcome whose `## Outcome checks` line this run expired, by ID.

**Two of those rows can only ever print one value, and both are kept anyway.** The branch reaches this
point only by matching its spec, and `design_approved` only by reading `true`, because `## Refuse first`
stopped the run on anything else. A row reading `true` still proves the file was read, and *which spec did
you decide you were on* is the row that catches a run pointed at the wrong directory, which is the first
thing a human checks.

**The expired row is where an existing instruction lands, not new work.** `### The verdicts expire when
the code moves` already mandates the announcement and carries the reason it exists. This section is the
place in the output it goes.

**Named rows rather than a rule about what to report.** A rule produced two differently shaped tables
across two runs of one spec. A fixed list is what lets a human check the same rows every run instead of
reading each report fresh.

**The content is mandated and the shape is yours.** No table, no alignment, no fixed wording.
`devpath:integrate` names what its own run reports at the end and mandates no shape either.

**One clause bounds it. The report says what this run derived from disk, never what it is about to do.**
Drop the clause and the row list grows a preamble, which is where *next I will dispatch slice 02* lands.

## The dispatch

**Mandated. A dispatch prompt opens with a literal first line naming the slice file:**

```
devpath slice: devpath/tolerance-config/slices/01-schema.md
```

**The prefix `devpath slice: ` is fixed and the remainder of the line is the slice file's full path.**
The rest of the dispatch follows on the lines after it and the convention says nothing about those.

**Changing this is a breaking change, not a wording tweak.** It is contract surface: a repo may gate on
it, and blocks a repo pastes parse it.

**Three properties, and they are why it is a first line rather than a token anywhere in the prompt.** It
is positional, so a guard needs no search and cannot match a slice path the dispatch merely mentions in
passing — and a slice's prose routinely names other slice files, as do `depends_on` values. It survives
paraphrase, because everything after line 1 is prose a model composes and line 1 is a string it copies.
And a missing convention **fails visibly**, where a token somewhere fails by finding nothing, which is
indistinguishable from a compliant dispatch with nothing to flag.

**What else a dispatch carries — paths, not contents.** Name the slice file and the spec file and instruct
the worker to read them; **do not paste either.** That is *re-derive from disk* one level down: a pasted
spec is a copy that is stale the moment Critique appends a finding, and it is how a 42k-character dispatch
happens, of which one real session's was 99% pasted history.

**So a dispatch carries, and carries nothing else:** the fixed first line; the spec's path; what the
worker is being asked to do this pass — build the slice, fix these named findings, or critique — and the
findings themselves when it is a fix pass, because those are what Critique already wrote down and what the
pass is *for*. **A rejected commit's refusal rides along on the same footing** and for the same reason: it
is what that pass is *for*, it is the guard's own words rather than a prior worker's, and no worker can
re-derive it from disk. **The read mandate under `## Read before you write` rides along on a critic
dispatch**, and it is no exception to this list's reason either. What the list refuses is a copy of
something on disk, which goes stale the moment the file moves; a mandate about which tool opens a file is
neither a copy nor perishable, and the critic reaches this plugin by reading it rather than being handed
it. **No conversation history, no prior worker's output, no file contents.**

**Where the generalisation goes instead, because the list above is right to keep it out.** A run learns
things no one slice holds: *the fixtures in this repo are uniform in a way that lets a passing test prove
nothing* is a statement over several slices, and in your conversation it is exactly the prior worker's
output this list refuses. **It goes on disk, under `## Traps` on `spec.md`, written by the critic that
confirmed the finding it came from.** The next worker then reaches it by reading the spec, which the
dispatch already tells it to do, and **a fresh orchestrator at slice 07 reaches it the same way** — which
is what makes the bottom rung of the ladder above genuinely identical rather than nearly so.

## Any stop that needs a human stops the whole run

**Build done ⇔ every slice carries `done: true`, or the run stopped and named what stopped it — the
slice mid-run, the condition at `## Refuse first`.**

Stated once for **any** mid-run stop rather than once per trigger, because two rules with the same reason
behind them drift apart later.

> **Any stop that needs a human stops the whole `devpath:build` run. The engineer may hold the stopped
> slice and continue another on request only, guarded by a `touches` set intersection — disjoint goes,
> overlapping is refused.**

**The mechanical reason:** a fix pass takes *branch state plus open findings* as its input, and those
findings were verified against *this* branch state. Building another slice while the human decides means
the pass they then grant runs against a branch that moved underneath the thing it was asked to fix. The
same hazard applies to a pause, which is why this is stated once.

**The honest gap in the guard:** `touches` holds pre-existing paths only, so a brand-new file in the other
slice is invisible to the intersection. It cannot invalidate a finding about code that already existed.

**The backstop holds however far you run** — Integrate refuses on the open box, so the worst case is more
code and the same stuck slice, never a bad merge.

## Committing

**The worker writes code and reports. The orchestrator commits and pushes.**

Four reasons, in order of weight. **Parallelise reads, serialise writes** — git's index and branch pointer
are a shared write, and slice parallelism is a deliberately open upgrade, so worker-commits is a design
that breaks precisely when that upgrade is taken. **A failed commit needs a human, and a worker cannot
reach one.** It agrees with how the adjacent tooling in this estate already reasons about commits. And it
is immune to how a foreign guard identifies the caller.

**The second of those is a reason and not a disposition, and it is the only sentence here that reads like
one.** It says why the actor holding the commit step has to be the one who can reach a human. It does not
say that every refused commit needs one. What a refusal means, and what you do about it, is
`### A rejected commit` below.

**Nothing observable changes: one code commit per slice, plus one for a pause.** The worker writes
`done: true` and returns; commit on that return. **A pause returns too, and you commit on that return as
well** — the worker wrote its box and stopped, and what it built before stopping is on disk. **The
critic's findings write is a second commit on the same slice**, on its own return and under the same
division, and **a trap or a struck note it wrote on `spec.md` rides in that commit** rather than earning
one of its own — so *one commit per slice* is a claim about code, and it is written that way wherever it
is claimed.

**One pause cannot commit, and it is the one a refused commit wrote.** Two routes reach it and the reason
is the same on both: another plugin's hook rejects the commit itself on grounds this slice cannot satisfy
— a foreign refusal, under `## A foreign hook's refusal` in the worker prompt — or the repo's own
commit-time check rejects it twice over a defect in the slice, under `### A rejected commit` below. Either
way `git add -A` stages the same content straight back into the same refusal. The `- [ ] blocked` box
reaches disk and never reaches the branch, and **nothing else for that slice reaches it either: no code,
no `done: true`, no box.** Name every path left in the working tree when you stop, and `wrote:` is not
that list: the only thing behind this is a later `devpath:build` reaching *the working tree is dirty*,
which prints those paths and asks a human. There is no second backstop.

**Say which of those paths is the slice file, and that it holds the only copy of the pause.** That stop
offers *restore `HEAD`'s version* on a tracked modified path, and taking it there deletes the refusal and
leaves the slice reading *not started* to the next run, which walks into the same hook holding nothing
about why the last one stopped. **The exit is *commit it here*.**

**A pause commit is not a claim that the slice works.** What claims that is `done: true`, and a paused
worker writes no such field. **Nothing mechanical reads the commit either** — the frozen test below joins
the absence of `done` to an open box under `## Deviations`, Integrate refuses on that box, and neither
looks at git. So permitting the commit changes the outcome of no check in this plugin.

**What the commit buys is the work.** A pause can hold finished work: the run this rule came from had
wired a linter and replaced a styling hook that resolved to nothing before the question that stopped it
was reachable. **Uncommitted, that work is one `git checkout` from gone.** `git add -A` is here so Build's
memory is out of the loop, and a pause that kept nothing would put it back — in the one case where the
next actor is a human who did not do the work.

**Stage with `git add -A`**, and **every path the commit carries that is absent from the slice's `wrote:`
and not under `devpath/` gets its own `- [ ] excess — <the path, how it differs from the base, and what
swept it in>` under `## Deviations`, and that slot is the only place the box's shape is set.** The command
that fills the middle clause, and the order it forces, are below.

**A worker that returned without filling `wrote:` puts its own work in front of the box**, and nothing
mechanical enforces that field any more than any other write of a worker's. **The degradation is noise at
review rather than a missed catch** — the box still names the file and how it differs.

```markdown
## Deviations
- [ ] excess — docs/tolerance-notes.md, +140 -0 against `main` as this branch found it; committed
      by `git add -A`, and absent from this slice's `wrote:`
- [ ] excess — package-lock.json, +812 -4 against `main` as this branch found it; committed by
      `git add -A`, and absent from this slice's `wrote:`
- [ ] excess — .claude/rules/rstk-slds2-ux-standards.md, +0 -72 against `main` as this branch found
      it; committed by `git add -A`, and absent from this slice's `wrote:`
```

**A filename is not a finding, and the third box is why.** Those three paths are a notes file somebody
wrote, a lockfile a package manager rewrote, and a stale copy that takes 72 lines off a rules file the
base already carries. **Without the clause all three read identically**, a name and how it got swept in,
and the third one is a revert about to be merged. A box exactly like it was closed *the engineer's own
in-flight edits* by a human who held nothing else. **`+0 -72` is the finding**, and nobody in that loop
had it.

**One box per path, never one box for the commit.** The figures are per path and so is the disposition:
three files reaching one box took one decision that was wrong about all three of them. **The dirty-tree
stop above asks one question per path for exactly that reason.** It named this box as its precedent while
this box still took paths in bulk; now both are per path.

**The comparison sits before the provenance, because a grep hit is one line.** Integrate finds open
boxes with `grep -rn '^[[:space:]]*- \[ \]'`, which returns the line a box starts on and never the line
it wraps onto. Put the figures last and the refusal prints a filename and nothing else — the box this
clause replaces, at the moment somebody decides. `devpath:integrate` already says it about a bullet of
Build's: *a hit cut at the line break drops the end of the sentence.*

**The tag is mandatory, and it closes a real ambiguity rather than decorating one.** An untagged open box
under `## Deviations` is a pause: *this slice does not proceed until a human answers*. This one is a note
about files a commit swept in. Untagged, they are the same three characters in a diff, and **`done` in
the front matter does not always tell you which** — a pause commits and stages the same way, so more than
one box can be open on one slice carrying no `done: true`, where the field answers nothing. And nobody
skimming seven slice files on a pull request is joining anything anyway. **`excess` names the shortfall in
the box itself**, exactly as `- [ ] unmet` names it on an Outcome check.

**It adds no state, and nothing over a spec directory reads it.** Every existing test matches
`^[[:space:]]*- \[ \]` and still matches this one:
*Critique clean* stays section-blind, Integrate still refuses on it, and **the frozen test below still
joins on `done` rather than reading the tag** — a tag is prose a run can forget to write, `done: true` is
mechanical, and the test deciding whether a push is denied reads the mechanical one.

**Why the audit beat a filter**, because it looks like the lazier choice and is not. Both need the *same*
first comparison — what git reports changed, versus `wrote:` plus `devpath/` — and the difference between
them is exclude-it versus include-and-note-it. **The machinery costs are no longer identical**: noting a
path runs a second comparison, against the base, that a filter would never make. The conclusion survives
the extra cost. A filter's risk is dropping a file Build legitimately created, which shows up later as a
failed deploy somebody has to debug. The audit's risk is committing something
out of scope, and all the audit does about that is put the file in front of a human before merge.
**A flag is not a catch.** Closing the box edits the box, not the commit, so whether a flagged file
merges turns on whoever read it — which is why the working tree has to be clean before Build dispatches.
A clean tree at dispatch narrows the audit to what this run wrote plus whatever arrived while it ran, and
`wrote:` tells those two apart — so the file a filter would wrongly drop is committed and carries no box.
And `git add -A` cannot lose work, which takes Build's memory out of the loop.

**Who closes that box, and it is not a skill.** No later `devpath` run is looking for it — **a done slice
with an open box under `## Deviations` is not a pause and must not be read as one**, and where a pause
commit writes one the frozen test below still reads that slice correctly, because the pause box is there
beside it. **It is the human's, at review**, in the grammar: `- [x] false positive` if the file belonged
in the commit, or `- [x] won't fix — <reason>` if it did not. **Closing it replaces `excess` with the
disposition** — every checked box carries its tag as the first word, and only `fixed` and `met` mean the
code changed. What puts it in front of them is Integrate's step 3, which refuses while any box is open
and names the exits.

**The audit is also a backstop, and that is a rule rather than a side effect.**

> **A precondition on the repo comes with a backstop, never alone** — and the reason is that another
> plugin's presence depends on the **engineer**, not the repo, so it is not observable from the repo at
> all. A precondition that cannot be checked needs one.

`devpath:fit-check` asks a repo to gitignore the directories other tooling writes into. If that ignore is
missing, or a new tool starts writing somewhere nobody anticipated, `git add -A` commits the file and the
audit writes it down as excess. **`devpath` benefits from the ignore without depending on it.**

**Two costs, stated.** Under concurrent slices `git add -A` would sweep a sibling's half-finished work. It
cannot fire today and, when parallelism arrives, it fires **loudly** — slice 02's commit records slice 03's
files as excess. And the engineer's own stray edits in a shared working directory get committed into a
slice; also recorded, also visible at review.

### The direction clause, and the order it forces

**The figures come out of git, never out of a sentence the run composes.** A run that summarises a file
it did not read writes a reassuring summary, and reassurance is the failure this box exists to stop. One
command per excess path:

```sh
git diff --numstat --cached "$(git merge-base "origin/$base" HEAD)" -- <path>
```

**The two figures are the only part that varies.** Where git reports a binary file — two dashes where
the numbers go — `binary, changed` takes their place. Where the command prints nothing at all, because an
earlier slice's change to that path came back out and the staged content now matches the base's, `no net
difference` takes their place. The rest of the clause stands in both, so the base's name and *as this
branch found it* are written one way only.

**A path with nothing to report still gets its box, and the box still gets a clause.** One that stops at
the semicolon reads exactly like a box nobody compared, which is the box this clause replaces.

**No condition on the path.** A path the base does not carry reports as pure additions, which is true and
reads correctly, so there is no *does the base have this file* question to ask first and no second shape
of box to keep in step with the first.

**`<base>` is resolved rather than assumed**, by the lookup `devpath:initiate` and `devpath:learn`
already make:

```sh
base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
```

**Resolve it only when the audit has something to report**, which on most slices is never. Nothing else
in Build wants a base branch, and a lookup at the top of the stage would pay on every slice to serve a
clause that mostly does not fire.

**Where the comparison cannot be made — no remote, `gh` cannot answer, or `origin/<base>` is not in this
clone — the clause reads `direction not compared`** and the run carries on. **The missing ref arrives as
an error rather than a number**: `git merge-base` prints nothing and the diff then refuses with `fatal:
bad revision ''` rather than quietly comparing against something else, so the case is one a run can see.
**Say the state and say nothing about the cause**, exactly as the dirty-tree stop above does. An
unauthenticated `gh` and a repo with no remote fail here identically, and a box naming the wrong one
sends the reader to fix something that is not broken. **Not silence** — an uncompared box that reads
exactly like a compared one that found nothing is the box this clause replaces. Not a refusal either:
this is a reporting clause, and a run does not stop over one.

**The order is stage, compare, write, stage again, commit.** `git add -A` first, then the comparison
against the staged state, then the boxes, then a second `git add`, then the commit. **`git diff` does not
see an untracked file**, so a comparison made before staging is silent on exactly the new-file case — the
one the reader has least other evidence about. The second staging pass adds the slice file alone, which
is under `devpath/` and already exempt from the audit, so it cannot manufacture excess of its own.

**The comparison point is the merge-base, because the base's tip lies on any branch the base has moved
past.** If `main` gained forty lines in a file last week and this branch never touched that file, a
comparison against `main`'s tip reports *this commit removes forty lines* — and merging removes nothing,
because a three-way merge keeps the base's version of a file the branch did not change. **A clause that
cries wolf is a clause the reader skims**, which is the failure this box already has.

**And the merge-base needs no fetch.** It is an ancestor of both refs and is in the clone already, so a
stale `refs/remotes/origin/<base>` still resolves it correctly. Build fetches nowhere today, and a
reporting clause is not the reason to make it start.

**The figure is the branch's rather than the commit's.** Comparing against the merge-base carries every
earlier slice's change to that path as well — which is the number that decides a merge, and what *as this
branch found it* says. A path swept in on two slices gets two boxes carrying two different figures, both
open at review, and the later one is the whole of it rather than the second instalment.

**On a short-lived spec the two answers agree**, because `devpath:initiate` cuts the spec branch from
`origin/<base>`. The merge-base is the one that stays right when they do not.

### The commit message

**Suggested, with its reason. The subject line is the slice's title; the body names the slice file's path,
and may also carry the fix narrative for a finding this commit closes or the reasoning behind a deviation
this commit writes. Nothing else. Where the repo's standards rule says otherwise, the repo's rule wins and
this line retires for that repo.**

```
Tolerance comparison in the invoice's currency

devpath/tolerance-config/slices/02-validation.md
```

**A findings commit takes the same shape**, because a second shape would be a second convention to pin.
Commits on one slice therefore share a subject line, and what separates them is the diff — code in a
builder's, the slice file's `## Critique findings` in a critic's. **A pause commit shares it too**, with
the commit that finishes the slice after a human clears the box. **Intended rather than overlooked**, and
a repo that wants them distinguishable in `git log --oneline` has its own standards rule, which wins here
as above.

**Why *nothing else* became a closed set of two.** `## How long a finding and a deviation may run` below
caps what a box and a bullet may run to, and the words it displaces have to have somewhere to be. **The
commit that made the fix is the honest home for why the fix was right**: the reasoning sits next to the
diff it is about, where a reader who wants it is already looking, rather than in an append-only ledger
every later reader has to read past. **A cap with no named route out is a quota, and a quota gets gamed.**

**One clause covers both halves, because both writers commit.** `devpath:build` and `devpath:slice` are the
two that write under `## Deviations`, and each commits what it wrote. `devpath:integrate` writes nothing
there — it reads Build's bullet and prints it into the pull request body.

**A worker does not commit, so a fix narrative reaches the body through its return.** The words a fix
pass is told to keep out of the box go into what it hands back, and this is the orchestrator putting them
where they belong.

**Why the path in the body rather than a prefix or a trailer.** `git log -- devpath/<slug>/` already finds
a spec's commits, so the path is for the human reading one commit in isolation and asking *which slice was
this*. A prefix convention would be `devpath` deciding the shape of the repo's history, which is
overreach; a trailer would be a string to pin.

**No issue key, because there is no tracker.** `upstream` holds what was read and a commit is not where it
belongs.

**The push is per commit, not per run.** You cannot have a draft pull request on an unpushed branch, and
the pull request is what makes the work visible while it is in flight — a run that pushed once at the end
would leave the spec's own pull request stale for the whole build, which is the condition the draft pull
request exists to prevent. **A pause commits and stops there: no push.** The person a pause needs is the
engineer at the terminal that just stopped, holding this run's report and the slice file, and the pull
request is not in that loop — a repo that took README's first hook block denies exactly this push while a
box is open. **The pause commit reaches the remote on the next push**, once a human has cleared the box and
the slice has finished.

### A rejected commit

> **On a `done: true` return, a commit the repo's own checks reject is the slice not being finished.
> Dispatch one fresh Build worker on that slice, handed the rejection as it arrived, and attempt the
> commit again on its return. Refused a second time, write the `- [ ] blocked` box and stop the run.**

**Same species as a failing test, which is the rule this extends.** *A failed deploy or a failing test is
the slice not being finished, and you keep working* is in the worker prompt below, and a commit-time check
is a check the repo runs over code this slice just wrote: failing one means the code is not right yet,
nothing has diverged from the design, and there is nothing here for a human to decide. That paragraph
enumerates a deploy and a test rather than a commit because it is addressed to a worker, and the commit is
yours.

**And *you keep working* has no addressee at the moment a commit is refused**, which is the whole of what
this section adds. The worker returned before you committed, so continuing the slice means dispatching
another one.

**That worker could not have seen it coming, which is what makes a second one worth dispatching.** It
deployed the slice and ran its tests before it wrote `done: true`, and its green was honest: what rejects
the commit runs at commit time, over the staged set, and reaches paths the repo's own scripts do not. You
are not sending a worker back at something it skipped.

**It is not a fix pass, and nothing counts it.** No critic has run and no finding exists. `fix_cycles` is
Critique's field and Critique's write, so a refused commit increments nothing, the fix cap does not bound
this, and the retry does not spend one of the passes that cap counts. Dispatch it as a build of that slice,
with the rejection attached.

**One retry, and one is a rule rather than a cap.** The objection to a retry count under the worker's
deploy rule — that a threshold gets loosened — is why this is not written as a maximum. The second attempt
is not an allowance; it is what tells the two cases apart. A refusal a worker can fix goes green on the
retry, one it cannot comes back identical, and **there is no separate test anywhere that decides which you
are holding before the retry runs.** Adding one would have this plugin form an opinion about what a guard
it did not write meant, which is what `## A foreign hook's refusal` refuses to do, for the same reason —
and against the one refusal this rule came from it answers backwards, because the repo's own checks were
green while the commit failed.

**The critic dispatch is still owed, and it waits.** It keys on the first worker's `done: true`, and that
return has not been discharged — the commit it earned failed. The retry worker rewrites neither field, so
its return neither re-arms nor discharges it. **Commit the retry, then dispatch.**

**Refused a second time, write the `- [ ] blocked` box under `## Deviations` on that slice and stop the
run. A worker that returns unable to reproduce the refusal is the same stop**, reached without a second
commit attempt — the worker prompt below says why spending one buys nothing, and there is nothing left
for you to try with it. The refusal goes in verbatim, for the reason `## A foreign hook's refusal` gives:
the box states an obstacle this plugin has no standing to summarise. Its grammar and its one-box-per-slice
rule are set there and hold here; its resume does not, because this box names no file to read against.
**The first worker's `done: true` sits on that slice on disk and never reaches the branch either**, so
nothing downstream reads it.

## Dispatch a critic on that same return

**Mandated. A worker that returned having written `done: true` or `- [x] fixed` gets a critic before the
walk moves on: run the skill `devpath:critique` against that slice.** This is the Build ↔ Critique loop
this skill opened by claiming, and it is the orchestrator's act — a worker cannot dispatch anything.

> **This is model-driven and is not guaranteed.** There is no call syntax and no event that fires on a
> skill finishing. Claude reads this instruction and normally follows it, and nothing in the harness makes
> it certain. A repo that wants certainty adds a hook of its own; `devpath` ships none and depends on
> none.

**Dispatch before you report.** The call goes out ahead of any summary of what was built, in the turn the
worker returned. **A turn that reports the build and then ends is the observed shape of the failure the
line above names** — the sentence describing the dispatch stands in for the dispatch, and it is likeliest
where the report is long and the call is one clause at the end of it. Narration is not the act. Where both
happen in one turn, the order is dispatch, then report.

**Three returns, because the loop is build → review → fix → review.** A fix pass writes `- [x] fixed` and
never `done: true` — that field was written when the slice was built — so a condition reading `done: true`
alone would dispatch the first critic and none of the re-reviews. **And the re-review is the one the
artifact cannot catch:** by then `fix_cycles` is present, so Integrate's step 3 is satisfied, and a fixed
box is checked, so the box grep is too. A skipped re-review is the missed increment this design states
outright it cannot detect — which is why this line carries it instead of a trace.

**A pass that increments `fix_cycles` and forgets to archive is the same hole in the same place.**
`devpath:critique` moves the boxes that were already closed out of the slice file at every re-review, and a
pass that counts but does not move puts that slice back on the growth the archive step exists to stop.
Nothing mechanical can catch it: the field moved, the boxes are closed, and every check downstream is
satisfied by exactly what it reads. Named here, like the one above, rather than covered. **And there is no
check to add for it** — `fix_cycles` at 1 or more with no archive file on that slice does mean the step was
skipped, but `devpath:integrate` runs once at the end, so it would fire after every lap it could have
protected, and there is no earlier home: Build cannot fix it, and Critique is the pass that skipped.

**The third is a fix pass that disproved its finding.** `## On a fix pass` below sends a worker back
having changed nothing where the check was green before it, and that return wrote neither field — so a
condition reading only the writes leaves the finding open with nothing able to close it.

**The condition is a return that wrote one of those two, or one reporting a check it ran and what the
check did — never merely a return.** A pause returns having written nothing too, so *wrote nothing* cannot
be the test; what separates them is the report, and a pause carries no check and no result. A pause stops
the whole run: no critic, no walk. **What that return does earn is its commit**, above — keeping the work
is not the same act as judging it.

**A disproof dispatch carries the finding and not only the report.** An open box is never moved and never
deleted, so a critic that re-derives the finding rather than being handed it writes a second line beside
the first and leaves the original open — which re-arms the loop this case exists to close. The
warrant is the one a fix pass already has: the dispatch names the finding and carries it, and the critic
disposes the line that is there.

**Nothing about who writes what moves.** `false positive` is Critique's tag in Critique's seat, and a
finding carrying no disposition is the one thing a pass may triage. **The loop ends on that disposition
rather than on the cap** — the trigger is an undispositioned `- [ ]`, so closing the box stops it firing,
and termination never waits on `fix_cycles` being right.

**Run the skill; do not hand-roll a critic here.** The `Skill` tool loads `devpath:critique` into *this*
session, as the plugin's other three compositions do, and **that skill dispatches the critic** — *a fresh
subagent every pass* is its line, in its file. One critic dispatch path in this plugin, and it is not this
one. What this section owns is the call and its condition.

**A fresh critic, every pass.** *Fresh, always*, in the lifecycle table above, and the rule behind it is
that nothing is ever resumed into a role that judges its own prior output. Nothing is ever continued into
a critic.

**Nothing new carries it.** The dispatch convention above already names *critique* as one of the three
things a dispatch asks for and its fixed first line already carries the slice's path — true of the critic's
dispatch wherever it is composed, and no second convention is invented here.

**The critic is the half that needs the read mandate handed to it.** A builder is handed
`# The worker prompt`; a critic is told to run a skill and goes and reads one, and injected outranks read
— so the instruction putting a repo's scoped conventions in front of a reviewer lands weakest on the half
this loop leans on hardest. **In a critic's dispatch the two reads are the changed files and
`.claude/rules/`** — `devpath:critique` mandates the first already and gets it only by being read. Owned
in that list; what this section owns is still the call and its condition.

**The critic writes and returns; you commit its write.** Same division as the builder's. Then `fix_cycles`
and the findings decide the next act: a finding open on this slice is a fix pass, under the cap above;
nothing open walks to the next slice.

**And this is why a session skipping the dispatch is visible.** `fix_cycles` is absent until Critique's
first pass over a slice writes it, so its absence on a slice carrying `done: true` is the slice pass never
having run — which Integrate's step 3 refuses on.

## Serial, for now

**One code commit per slice on the one spec branch, walked in `depends_on` order across fresh contexts. No
slice branches.** With commits there is no merge step to own; slice branches would build an unprotected
integration branch that CI is contractually forbidden to run on, because every spec carries a draft pull
request from Initiate and CI must skip drafts; and attribution is already paid twice, in one file and one
commit per slice.

> **Say so plainly: serial execution is a starting posture, not a ceiling.** Presenting it as a principle
> would be dishonest.

Slices run in series first because the engineers are new to this way of working, not because parallelism
is worthless. Moving to slice branches later is **purely additive** — Build cuts a branch instead of a
commit and nothing else in the design changes.

**Worktrees are the engineer's business and `devpath` mandates nothing about them.**

---

# The worker prompt

What follows is what each dispatched subagent is told. Dispatch it after the fixed first line.

## Read before you write

**Mandated: use the file tools — `Read`, `Write` and `Edit` — for `devpath`'s own artifacts, and use
`Read` explicitly.** This is measured. Across 15 runs with loading instrumented by a hook rather than by
the model's own account:

| How a file was touched | Scoped rule delivered |
| --- | --- |
| `Read` | **3/3** |
| `Edit` on an existing file | **3/3** |
| `Write` on a new file | 0/2 |
| `Grep` | 0/2 |
| Bash `cat` | 0/3 |
| Bash `sed` | 0/2 |

**The read is where rule delivery happens**, so a slice worked through `cat` and `sed` is a slice worked
with the repo's scoped rules absent. This holds even if no other plugin is installed.

**Mandated, and this one reaches code: two reads first, both through `Read` — the first file you open in
a part of the tree this slice will change, and `.claude/rules/`, listed and then read.** The first is how
a repo's `paths:`-scoped conventions arrive at all, and the table above is the whole of that delivery — no
bash read delivers, whatever the command. The second covers what the first misses, because a rule you read
yourself needs nobody to hand it to you. **A session-level instruction to prefer shell tools for file work
does not reach either read.** After them the shell is yours.

**The cost is one read per part of the tree this slice changes**, plus one more after a compaction,
because a scoped ruleset is dropped there and is not re-injected until the next matching read. **The rules
the first read already delivered you pay for twice**, and that is the trade this takes: what you read
yourself survives a compaction, and picking which to skip puts a scoped rule's arrival back on a worker's
judgment. **A part of the tree with nothing in it yet is the ordinary greenfield case**, and there the
second read is the whole of the mandate.

*The instruction this was written from opens `While auto mode is active` and tells every worker to read
with `cat`, `head` and `sed -n`. It arrived mid-run rather than in a system prompt — after the first
tool results — and in one measured run it reached every worker and every critic. Expect it in your
context whether or not it is there yet.*

**A second reason for the file tools, and not about rules: `Edit` fails loudly on a stale match and a
bash replacement does not.** `Edit` refuses a string it cannot find and says so. `sed -i` and a python
`str.replace` both exit zero having matched nothing, so **the absence of an error is not evidence a patch
applied.** With a formatter in `lint-staged`, the file on disk drifts from the file you read between the
read and the write — four spaces become two, single quotes become double — and a replacement written
against what you read then matches nothing. One run lost four patches that way. Grepping afterwards is
what found them, and one missing import got as far as a wrong runtime conclusion first.

**Suggested, with its reason: prefer `Edit`, and where a bash replacement is genuinely the right tool,
grep for the result rather than trusting the exit code.** This reason reaches further than either mandate
above. One is scoped to `devpath`'s own artifacts and the other is paid in two reads; a patch that did not
land is about every file you touch, code included. **Each mandate keeps its scope — the artifacts stay on
the file tools, and bash returns to code after the two reads** — what this adds is the check.

**One more reason for the same suggestion, and it is a repo's rather than this plugin's.** Some repos deny
a bash redirect or a heredoc into a source file at the tool boundary, because it bypasses the formatters
and scanners that run on `Write` and `Edit`. There a heredoc write is a refusal and `## A foreign hook's
refusal` below handles it. **It covers nothing above** — a `sed -i` passes it, and so does every read.
**`devpath` neither ships that guard nor assumes it.**

**Suggested, with its reason: read a neighbouring file of the kind you are about to write, before writing
it.** **Its rule-loading half is the mandate above** and what stays suggested is the rest: house style,
naming and structure were always part of it, and that half stands on its own. Neither half can be
rephrased as *ensure the standard is loaded*, because an agent cannot self-report whether a rule loaded.

**The slice's `touches` is not a work list.**

> **`touches` is what this slice will collide with, not where to work.**

You are **not** instructed to touch those paths and **not** limited to them. Slice wrote them so the
contention checkpoint and the cited-paths check have something to read. This clause is prose mitigating a
real model-behaviour risk and the risk is live: tell an agent the change goes in a named file and it edits
that file even when the right change is elsewhere. On a greenfield repo `touches` is often empty anyway,
because it holds pre-existing paths only.

**You already have the repo's standard if it is unscoped.** An unscoped `.claude/rules/` file auto-loads
into every session and every non-fork subagent and is re-injected after compaction. **A scoped one you do
not have yet**, and that is what the two reads above are for. **A repo with no standards rule builds
against nothing, and that is the honest degradation** rather than a defect.

**The slice file carries a test-first line.** It reads:

> Watch a new test go red before you make it green.
> *Why: a test written before the code cannot be written to hit a coverage number — there is nothing to
> cover yet. Retires when Apex gets mutation testing.*

**It is a suggestion and not a mandate, and the reason is that a reviewer cannot verify it from a diff.**
This is not choosing to be lax; it is refusing to write a rule in a voice nothing can back. Both halves of
its rationale are statements about what is and is not possible: a test written first cannot be a coverage
artifact, and a test you never saw fail is a test you have not tested.

**Mandated: read `## Traps` on `spec.md` before you write a test, and go to that heading by name.** Every
entry is one mutation a test on this spec has to be able to fail on, written by a critic on an earlier
pass over this spec. **The heading is the instruction, not the file** — a worker reading the spec for
Intent, Outcomes and Design passes over `## Traps` without attending to it, and a spec whose traps nobody
read looks exactly like a spec that had none. **A spec with no `## Traps` section is the ordinary case**,
and finding none there costs you one read.

**Red-before-green and a trap catch different failures.** Red-before-green proves a test fails when the
code is missing. A trap names what the same test has to fail on when the code is **present and wrong**,
which is the half red-before-green cannot see.

## Deploy, then tick, then `wrote:`, then `done: true`, then return

**Mandated, in that order.**

**Deploy the slice and run its tests against the engineer's own scratch org**, kept for the life of the
spec.

```sh
sf project deploy start
```

**No `--target-org`.** `sf` resolves a default target org per project folder. The plugin holds no org
name, no username and no credential.

**With no default set, this fails with the CLI's own error and the run stops there, and that is the right
failure.** The alternative is a plugin that holds an opinion about which org this repo deploys to. **Nor
does any stage create the org** — the engineer creates their own, and the repo's CI creates the fresh one
for the whole-spec deploy. A plugin that creates an org is a plugin that names one.

**Nothing writes `done: true` before it deploys**, which is what makes a slice carrying `done: true` mean
a working slice. **The claim is the field, not the commit** — a pause commits as well, and that commit
says the work exists, never that it works.

> **It does not prove verticality and must not claim to.**

**Verticality has no mechanical gate in this design.** One pull request per spec means a slice never
deploys alone to anything real, so **what ever gets deployed is a spec, never a slice** — a fresh org per
slice would test a property nothing downstream depends on, and would cost eleven orgs for a ten-slice
spec. **Two orgs per spec, not N+1.**

> **Green is provably not done.**

A slice whose feature was a dynamic query on a nonexistent field **passed validation, passed its test, and
scored 86.7% coverage.** Deploy-time integrity verifies the dependency graph, never the feature. The gate
is real and worth having — the same feature cut horizontally fails with 5 errors and 0 components
deployed — but do not read a green deploy as a finished slice.

> **Green is provably not done.**

**Said twice on purpose, because these are two different failures. The one above is the platform's check
not checking your feature. This one is your own test not checking it.**

One method, `saveLayout(layoutId, ...)`, where `null` meant *no particular layout*. Its two callers wanted
opposite things from that: the client meant *make me a new one*, and the server read it as *update the one
that loads on arrival*. In the running org, *New layout* renamed and overwrote the existing layout instead
of sitting beside it. **The jest suite was green throughout, because it asserted what the client sent** —
`layoutId` was null, as intended — **and never what the server did with it.** Clicking *New layout* in a
real org is what found it, and the fix splits `createLayout` from a `saveLayout` that refuses a null id.

**A test that asserts what you sent is not a test of what happened.** That is what makes this one sharper
than the coverage number above: the test was written for the code, it asserted the right variable, and it
still could not have caught the bug, because it asserted the call and the bug was in what the callee did
with it. There is no percentage to explain it away and no platform to blame.

**Then tick `## Acceptance criteria`.** **Mandated: tick each `- [ ]` as you satisfy it, and never
before.** The tag is `- [x] met` — a criterion is a statement about behaviour, so it closes the way an
Outcome does rather than the way a finding does. Ticking after the run rather than before is the same rule
as *never before it is satisfied*: a criterion ticked against code that has not deployed is a criterion
you graded rather than met.

**Do not write them and do not rewrite them.** Slice wrote them from the approved design. A criterion you
cannot satisfy is not edited into one you can: either resolving it changes only *how*, in which case
re-cut and note the deviation, or it changes *what*, in which case **pause**.

**`- [x] won't fix — <reason>` is the human's decision, in the human's words, and there is no human in
this context.** You are a subagent: write `fixed` and `met`, name the criterion you could not meet, and
return. The session holding the engineer writes that line when they say it — so it is never your
unilateral way past a criterion you could not meet.

**Then fill `wrote:` on the slice file, and this step binds every return rather than only this sequence**
— a build, a fix pass, a retry after a rejected commit, and a pause. The commit audit compares the commit
against that field, and a fix commit goes through the same audit a build commit does, so a rule naming
only the first worker has every later one flagging its own work.

**It is read off git, not recalled.** The tree was clean when this slice's first worker was dispatched,
so `git status --porcelain` is the whole of what changed since. **Go down it and add the paths you wrote
yourself** — a yes or a no per path, where a list from memory drops whatever you touched first. **A file
something you ran produced is not a file you wrote**: a generator's output, a formatter's sweep, a
lockfile the package manager rewrote. Those are what the audit exists to put in front of a human, and
claiming one is how it stops. **`devpath/` stays off the field**, which the audit exempts anyway.

**It is a set and it accumulates.** Add what you wrote, delete nothing, and write no path twice — nine fix
passes over three files leave three paths, which is what keeps the field from growing with a run's length.

**Then write `done: true`, then return.** A slice is done when its acceptance criteria are ticked — that is
the predicate the field carries. Value is always `true`; absence is how you say no; nothing ever writes
`false`.

**A failed deploy or a failing test is the slice not being finished, and you keep working.** It is **not**
a deviation and **not** a pause — nothing has diverged from the design and nothing needs a human yet.
**No retry count**: a cap on deploy attempts is a threshold that gets loosened, and the real bound is
already there in the fix cap.

**A commit the repo's own checks reject is the same species, and it is how you can be dispatched onto a
slice that already reads finished.** You never see that rejection yourself: the orchestrator commits on
your return, so the refusal lands after you are gone, and `### A rejected commit` above is where it sends a
fresh worker back with the refusal attached. What follows is for that worker.

**Reproduce the refusal before you change anything, and reproduce the *check*, not the hook.** Hook scripts
routinely read git's own environment variables and do not run standalone, so invoking one proves nothing in
either direction. **Reconstruct what to run from the hook's own configuration** — the globs it matches, the
paths it passes and the flags it sets — rather than from the repo's script of the same name. The two
differ, and that difference is what produced the refusal you were handed: in the run this came from, the
repo's `lint` was green at the moment the commit-time check failed, because the hook aimed the same tool at
a wider set of files.

**The index is already staged, and you leave it alone.** A rejected commit aborts without unstaging, so
`git add -A`'s work is intact and a staged-set check reproduces faithfully with no index write from you.
**Do not stage and do not commit.** git's index is a shared write and the orchestrator owns it — the first
of the four reasons under `## Committing` — so a worker that staged would break the reason that division
exists. You fix and you verify; it re-stages on the next attempt.

**Cannot reproduce it → change nothing, say so, and return.** A commit-message policy checks a message you
never write. A signing key, an identity setting, a protected branch and a write permission are facts about
the environment that no edit to this slice moves. None of them is reachable from here and none is a
red-then-green loop, so an attempt buys nothing and leaves edits behind that nothing verified. **That
return is where the run stops**, and the orchestrator writes the box.

**You carry every obligation an ordinary build carries, and it is said again here because none of its
triggers is in front of you.** The sequence above is written for a slice built from scratch, and you
arrive at one whose criteria are already ticked. So, explicitly: **deploy the slice, run its tests, and
do not hand back red.** **Criteria already ticked stay ticked** — *do not write them and do not rewrite
them* holds here exactly as it does above. **`done: true` is already on the slice and you do not rewrite
it**: the first worker wrote it, the field says the acceptance criteria are ticked, and they still are.
**`wrote:` is the one field you add to** — the paths the first worker put there stay, and whatever you
wrote fixing the refusal joins them.

## Deviations, and the pause test

**Build records; the recording is mandatory; the stopping is the engineer's call.**

**You may re-cut the slice layout unattended, and it is recorded as a deviation.** *Stop and ask* was
rejected — it would make the slice layout more sacred than the design itself, and even the design gate
permits deviation-with-recording.

> **Build re-cuts but never redesigns. Does resolving it change *what* the slice builds, or only *how*?**
> *How* → decide it, and the change is recorded as a deviation. *What* → that is design, and you do not
> own it. **Pause.**

**Mandated: a pause writes an open box under `## Deviations` before stopping.**

```markdown
## Deviations
- [ ] The design assumes every billing schedule is monthly and derives the period from the
      contract start date. O2 implies mid-cycle proration, needing a proration basis that is not
      in the design and not derivable from what exists. This changes what is built, not how —
      needs a decision before this slice continues.
```

**Why the box and not just prose.** Without it a paused slice is **indistinguishable from one nobody
started** — neither carries `done: true`, neither has a `fix_cycles` line yet, and nothing under
`## Deviations` distinguishes them. With it: **no `done: true` plus an open box under `## Deviations` =
frozen, needs you; no `done: true` and no open box there = not started.** No new field.

**Reason in the absence of `done: true`, never in the string `done: false`** — nothing ever writes
`false`, so a check phrased against that string is a check that can never fire.

**And the section matters, not merely the box.** Slice writes `## Acceptance criteria` as open boxes at
creation, so an unbuilt slice already carries open boxes and *any open box* no longer separates frozen
from not-started. **A pause is an open box under `## Deviations`.** Same grammar, different instruction:
under `## Critique findings` an open box means *fix this*; under `## Deviations` it means *do not proceed
on this slice until a human clears it*. **A pause box is never ground on as a fix item.**

**Three boxes can appear under this heading, and the tag says which one you are looking at.** Untagged is
the pause this section writes, where a human owes an answer. **`- [ ] blocked` is a pause as well** — a
foreign guard refused a write this slice needs — and `## A foreign hook's refusal` below sets its shape.
`- [ ] excess` is the commit audit's and is not a pause at all. **The tag tells them apart wherever they
land** — which is what a human reads, where the frozen test above reads `done`.

**More than one can be open on one slice, and a pause commit is how.** `git add -A` stages what is on disk
whether the slice finished or not, so the audit can write its box on the very slice that just paused:

```markdown
## Deviations
- [ ] O2 implies mid-cycle proration and the design carries no basis for it — needs a decision
      before this slice continues.
- [ ] excess — package-lock.json, +812 -4 against `main` as this branch found it; committed by
      `git add -A`, and absent from this slice's `wrote:`
```

**The frozen test still answers *frozen* here, and still reads `done` to do it.** No `done: true` plus an
open box under `## Deviations` is the true reading of that slice — it is stopped, the push stays denied
while it is, and Integrate refuses at the end. What the tag adds is which instruction is which: untagged
is *do not proceed until a human answers*, and `excess` is *somebody should say whether that file was
fine*.

**An `- [ ] excess` box outlives the pause, and the frozen test goes on reading *frozen*.** The
`devpath:technical-design` session closes the untagged box and leaves that one for the human at merge, so
from the moment the pause clears until this stage writes `done: true` the slice carries no
`done: true` and an open box under `## Deviations` — frozen, by a test that never reads the tag.
**Mandated: after a human clears a pause, the cleared slice is the next slice this run builds.** Building
that slice is never the thing denied — the stop is always read off some *other* slice, and a repo that took
README's third hook block skips the one it is being asked to dispatch — and `done: true` at the end of that
build closes the window. Reaching for a sibling first is what turns a cleared pause into a false *frozen*,
and holding one slice to build another was already *on request only*.

**You do not close your own pause.** The `devpath:technical-design` session that resolves it writes the
disposition, in that session, before it ends. A stage that could clear the box it wrote is not a stop.

**A `- [ ] blocked` box is closed by a later `devpath:build` worker, and that is a different act rather
than this rule bending.** What that worker closes on is a change a human made outside the run — the file
they edited, or the guard they moved — established at the moment of closing, and where nothing moved the
run stops again. Answering your own question is the thing that would not be a stop.
`## A foreign hook's refusal` below carries both establishing acts.

**So an open `- [ ] blocked` box is the brief for the next dispatch rather than a bar on it.** Building the
slice a pause box sits on is never the thing denied, above, and here the box is what the worker reads the
file against. Waiting for a human to tick it waits forever: the human changes the file and nothing else.

## On a fix pass

**Mandated: write `- [x] fixed` on each finding you fixed, in the same pass that fixes it.** The dispatch
already names the findings and carries them, so you have the list you are dispositioning. **And fill
`wrote:` before you return** — your commit goes through the same audit a build commit does.

***Fixed* is a claim about work just done, which only the pass that did it can make** — the same rule as
ticking a criterion as you satisfy it and never before. Critique owns `false positive`; `won't fix` is
the human's decision, written in the seat where they are.

**That is `## Critique findings`, and under `## Deviations` the same tag claims the file instead.** A
`- [ ] blocked` box closes on what the resuming worker establishes about the file rather than on work that
worker did, so *fixed* there says the code now does what the box named. It is the one closed tag an
establishing act can earn, and `## A foreign hook's refusal` below is where it is written.

**Mandated: run the check before you change anything, and it has to fail.** What discriminates a finding
is a test or a mutation of the line it names, and never the suite. **A check that passes against the
unfixed code is the finding disproved**, not a check written wrong.

**Then fix it and run the same check green. Both runs in this pass** — a red you remember is not a run,
because the code has moved since.

**Green before the fix → change nothing and return saying which check you ran and what it did**, the route
`### A rejected commit` above already takes on a refusal you cannot reproduce.

**Where nothing can be run, `- [x] fixed` carries `unverified: <why>`.** `devpath:critique`'s
`## What no check reaches` names those slices and no runner exists for any of them. The code changed, so
*fixed* is honest; nothing proved it, so the line says so — and that is what makes **a bare `- [x] fixed`
a check that went red and then green.** No new tag, and the closed set is unchanged.

```markdown
- [x] fixed — any user could edit `Tolerance_Config__c`; unverified: no runner exists for permission sets
```

**And a disposition does not re-argue the fix.** The line above is why: a bare `- [x] fixed` already says a
check went red and then green, so the case for the fix being right is made by those two runs rather than by
prose sitting beside them. **Write the tag, and where nothing could be run the reason nothing did. Stop
there.**

**The prohibition is the lever, and `## How long a finding and a deviation may run` below is only its
backstop.** A word cap on its own tells you *compress the argument*; it never tells you the argument is no
longer owed, and a worker who believes it is owed leaves the file its cap's worth of the wrong thing.

**The displaced words are not lost. They go in your return, and the orchestrator commits them** into the
commit body, which is the honest home for why a fix was right: next to the diff that is the reason.

## How long a finding and a deviation may run

> **A box under `## Critique findings` runs to 250 words. A bullet under `## Deviations` runs to 150
> words, and every bullet on one slice file to 1,500 words. A box under `## Deviations` is exempt from
> both.**

**Mandated, and the writer is the whole of the enforcement.** Nothing in a run counts words and nothing
blocks on a count. README carries an optional job a repo may paste if it wants the numbers refused at the
pull request; the rule reads identically in a repo that pastes nothing.

**The reproduction is never what binds.** Across a field run's 114 boxes the finding and its reproduction
averaged 76 words. What 250 refuses is the box that argues its own case at length, which `## On a fix pass`
above already prohibits and this only backstops.

**1,500 is per slice file.** *Section budget* on its own reads either way, and a check has to pick one.

**The displaced words go in the commit body**, which `### The commit message` above names. **A cap with no
named route out is a quota, and a quota gets gamed.**

## How you reach a human

> **A worker can reach the orchestrator. Only the orchestrator can reach the human.**

**`devpath` names exactly one route: write it down, then return.** The artifact on disk is the question's
durable form; the return value is the signal. No live messaging, no elicitation, no prose question into
the void.

The harness prescribes this itself: *AskUserQuestion is not available inside subagents. Complete the work
with the tools provided and return findings to the orchestrator.* It is absent from a subagent and fails
synchronously.

**Say this, because the mirror image of *a check written and never wired* is *ruled out and never
checked*: live messaging is a declined available mechanism, not an assumed-absent one.** Sending a message
to the main conversation from a background subagent **works**, and returns *queued for the main
conversation's next turn* — **queued, not interrupting**, so it saves not one step over returning.

**Escalate on irreversibility, not uncertainty.** `devpath` always has a controller, so the instruction
is rule and report, never stall. That does not weaken the pause: building the wrong thing is exactly the
irreversibility case.

## A foreign hook's refusal

> **Write the refusal verbatim into a `- [ ] blocked` box under `## Deviations`, and stop the run.**

**Mandated, and *verbatim* is the load-bearing word.** Paraphrasing another plugin's reasoning is where a
dependency re-enters — the plugin would then be holding an opinion about what that guard meant, and the
next version of the guard makes the opinion wrong. **Copy the message the harness handed over and stop.**

**Nothing new is needed to detect it.** A refusal from another plugin's hook that this stage cannot satisfy
**is** the case *any stop that needs a human stops the whole run* already covers, and the harness hands the
guard's message straight to whoever made the call. Do not build a catalogue of another plugin's hooks.

**A deploy blocked by another plugin's hook is one of these.** A deploy that fails because no default org
is set is the CLI's own error, above. Neither is yours to fix. **A commit another plugin's hook rejects on
grounds this slice cannot satisfy is one of these too**, and `## Committing` carries the one thing that
case costs: that pause cannot commit itself.

**Do not route around a refusal, and do not compose the write for anyone else to run.** Name the file, the
change and the obstacle in prose, and stop. **A `sed`, a heredoc or a python rewrite aimed at the path that
was just denied is routing around the refusal**, not another way of doing the work — the guard refused the
write, and the tool it is attempted with is not what it refused. **Handing that command to a human to paste
is the same act with a longer arm.** The run this rule came from did exactly that: a one-line `sed` against
the path a hook had denied one turn earlier, which deleted the key instead of changing its value and left
invalid JSON behind a verification too malformed to catch it. Prose is not the lesser form here. It is the
form that gets read before it gets run.

**The box is a pause, and this slot is the only place its shape is set:**

```markdown
## Deviations
- [ ] blocked — sfdx-project.json needs sourceApiVersion at 67.0 and carries 66.0. The write was
      denied: <the guard's message, verbatim>
```

**`blocked` is not a new state.** It is the same open box with its obstacle named, exactly as `- [ ] unmet`
is on an Outcome check: every check still greps `^[[:space:]]*- \[ \]` and matches it, the frozen test
still joins on `done`, and nothing mechanical anywhere reads the word. What the tag buys is who clears it,
which is the whole reason this box carries one.

**A human clears it outside the run, and `devpath` names no method.** Whether they lift the guard, grant
this path an exception, or make the change themselves is theirs to choose — this plugin has no standing over
another repo's hook, and none to send an engineer at a protected file by hand. **State what the slice needs,
never how to get there:** the file, the change, and that the run stops until the file carries it.

**The slice resumes in a fresh worker, and that worker reads before it writes.** Read the file against what
the box named. **Three branches, and every one of them ends somewhere:**

**Already carries the change** → write `- [x] fixed — <what you read>` and go on building the slice.
**Here *fixed* is a claim about the file rather than about who edited it** — the code does what the box
said it needed to, and the read is what establishes that. It is the one closed tag this act can earn:
`false positive` says there was nothing there, `won't fix` says shipping without it, and neither is true
of a file that now carries the change.

**Does not, and the write goes through** — because the guard moved rather than the file → close the box
the same way, on what the write did, and go on building the slice. **This branch is why the read is not
the only thing that closes the box**: an engineer who lifted the guard or granted the path an exception
has cleared the obstacle without touching the file, and a worker that only ever closed on a read would
leave that box open with nobody left who may close it.

**Does not, and the write is denied again** → the box you already have is still the true statement of the
obstacle. **Replace the refusal on it with the new one, verbatim**, and stop the run. **One `- [ ] blocked`
box per slice, always** — appending a second one naming the same file is a second copy of one question,
and *read the file against what the box named* has no referent once there are two.

**Read first, because both shortcuts fail.** Going straight to the write puts you back at the write that was
denied. Assuming the human got it right is how a bad hand-edit reaches a commit — in the run this came from
the edit happened to be correct, and nothing here would have caught it if it had not been.

**Closing that box is not closing your own pause.** *You do not close your own pause* holds and keeps its
reason: a stage that could answer its own question is not a stop. This worker answers nothing. It confirms
a state a human changed outside the run, and it stops the run again where that state is wrong. **A guard
that moved is that same change**, made by the same human in the same place, and the write going through is
what confirms it exactly as the read confirms an edited file. **A human never ticks the box** — they change
the file or they move the guard, and this worker is what closes it.
