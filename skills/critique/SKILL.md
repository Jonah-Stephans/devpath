---
description: Critique the code of a built devpath slice. Use after a slice is built, or when a reviewer has requested changes on the spec's pull request.
---

# Critique

Critique has **three passes with three subjects. Do not merge them.**

| Pass | Subject | Runs | Writes |
| --- | --- | --- | --- |
| **The slice pass** | that slice's code | when a slice is built, inside `devpath:build`, or `devpath:critique` alone | `## Critique findings` on **that slice file**; `## Traps`, and a strike through a wrong `## Current state` note, on **`spec.md`** |
| **The Outcomes pass** | the spec's Outcomes | **once, at the start of `devpath:integrate`** | `## Outcome checks` on **`spec.md`** |
| **The change-request pass** | a human reviewer's comments on the pull request | when a reviewer requests changes and the engineer re-runs `devpath:critique` | as the slice pass — triaged findings into the fix loop |

## Refuse first

Read the front matter of `devpath/<slug>/spec.md`. That read is the validation.

- **`git branch --show-current` returns `main`, `<base>`, or a branch with no matching spec directory**
  → **stop.** Do not guess which spec this is. Say the next act: `git checkout <slug>`.
- **The command returns empty** → **stop, and say what is actually wrong:** it returns empty with exit
  code 0 under a detached HEAD, so the truth is *you are not on a branch*, never *no spec on this
  branch*. The fix is one `git checkout -b <slug>`, and it is a human's.
- **`design_approved` is not `true`** → **stop.** This stage runs behind gate 2. Say the next act: run
  `devpath:technical-design` and take the design through its gate.
- **The front-matter block does not parse, or a field carries the wrong shape** → **stop and name the
  exact field.** *Malformed* stops the stage; *absent* is a legal state meaning *not yet*.

**Prefix every message this skill prints when it stops with `devpath: `.** Suggested.

## Which pass is this?

**Work it out from the invocation, not from a field.** There is no field for this and there should not be.

| Invocation | Which pass |
| --- | --- |
| dispatched by `devpath:build` | **the slice pass**, on the slice the dispatch names |
| `devpath:integrate` | **the Outcomes pass.** This skill never runs it — it belongs to Integrate's first step |
| typed by a human, and the spec's pull request carries a review requesting changes | **the change-request pass.** Show the triage list and wait |
| typed by a human, and it does not | **the slice pass**, over the slices that carry code |

**Resolve the pull request with `gh pr list --head <slug>`** — one branch and one draft pull request per
spec means the number is derivable, and there is no `pr:` field to read. **If `gh` is unavailable the
change-request pass is unavailable**: say so, and run the slice pass. Do not guess.

## The slice pass

**A fresh subagent every pass.** Two independent supports: a resumed judge that had prescribed the fix
reported *"passed both with zero findings"* on work containing a real defect, and separating the agent
doing the work from the agent judging it is a strong lever. **Priced at about 3% of the cost of the build
it critiques**, so a fresh critic every pass costs effectively nothing. **If a dispatch is refused, or this
session is under an instruction not to dispatch, the slice pass is unavailable**: say so, write nothing, and
hand back — the next act is re-running this skill where a subagent can be had. **Do not critique inline
instead.** No exception for a session that did not build the slice, because the session that cannot dispatch
is usually the one that did, and asking it to sort those two apart hands the judgment to the agent this rule
exists to distrust. **`fix_cycles` staying absent is the right outcome and not a gap** — Integrate refuses on
an absent line on a slice carrying code, and on the finding a Build that cannot dispatch leaves open rather
than fixing, so an uncritiqued slice cannot reach a merge unseen.

**Read the changed files, not only the diff.** Mandated. A diff without the surrounding file is a worse
review on quality grounds alone — **and without this, scoped rules do nothing**, because a review
conducted through `git diff` in Bash loads no scoped rule at all.

**Check the diff against the repo's standards rule and emit a finding per violation.** That is the whole
instruction. **The instruction, never the list** — this skill carries the instruction to read the repo's
standard, and never a copy of the standard itself. A copy would stop working on a repo in another
language, would need a plugin release to change, and would be the copy that rots.

### Triage first

**Real / false positive / won't fix.** Hand only confirmed items onward.

**Real means a run came back the way the finding says, wherever a run is what settles it — never that the
call path reads that way.** On the spec this rule comes from, arguments closed 55 findings of which 11
changed nothing — revert each fix and all 564 tests stay green. An argument is how you choose what to run,
never what confirms it.

**A claim about the whole suite is paid for by whoever makes it.** *Nothing catches this* is not
establishable from one file, so it costs one run of everything: mutate the line, run the suite, put it
back. **Too expensive to run is too expensive to claim** — no threshold is written here, because the price
rides on the claim rather than on the repo.

**Everything else is one check in one file, and the table says who owns the run.** All three rows are real
and all three go onward; what differs is which pass discharges the check.

| The finding | Who runs it | What travels |
| --- | --- | --- |
| provable with no test code written | **you, in this pass** — mutate the line and run the tests that exist, which is an experiment rather than a fix | a disposition |
| provable, but proving it needs test code written | **the fix pass, before it changes anything** — writing that test is the fix's own deliverable | the finding, and **the run is owed rather than waived** |
| not provable at all — the slices `## What no check reaches` names | **nobody, and the line says so** | the finding, named as unprovable; the fix closes it carrying `unverified:` |

**Row 3 is the one that was missing, and it asks a different question from the section it names.**
`## What no check reaches` answers *this slice's behaviour cannot be verified, so route it to the verifiers
that remain*. This row answers *the finding is real, the fix will be made, and nothing can prove the fix* —
which is what `devpath:build` writes `unverified:` for. Neither knew the other existed, and naming the
section here is what stops them colliding.

**Critique owns *false positive*** — a factual claim it can verify. ***Won't fix* needs the human** — a
judgment about what is worth doing.

> **`- [x] won't fix — <reason>` is the human's decision, in the human's words, under any heading. The
> session they say it to writes the line. `devpath` writes `fixed`, `met` and `false positive` off its own
> judgment; this one it writes only on an instruction, and only with the reason it was handed.**

That is one rule rather than three, and **the seat is what it turns on rather than the run.** A worker
subagent has no human in its context, so it never writes this line — it hands the finding back
undispositioned and returns. The orchestrator is where a human is, and it is the same seat the fix cap
below already sends you to.

**No agent drafts the reason, and no reason means no write.** The reason is the whole deterrent: it rides
into the pull-request body in front of the approver and lands in `grep -rn "won't fix" devpath/` forever.
A reason an agent wrote is a waiver signed by the applicant.

**One reason `devpath` writes for itself, and it is a fixed form: `- [x] won't fix — moved to slice NN`**,
on a finding cut away to a new slice at the fix cycles cap. Its only variable is a slice number the run
just made, the same spec directory verifies it, and it asserts nothing about the code — so it cannot carry
the class of error a drafted reason carries. **Give the agent latitude to phrase it and the prohibition
above is back.**

**What that costs, said plainly: the one route past a real-but-not-done finding is the human saying so, in
their own words, in the session.** The alternatives are mid-run human input, which is ruled out, or a
stored permission, which the cap below refuses.

**Critique does not fix its own findings** — the reviewer becoming the author is the thing a fresh critic
exists to prevent. **And no per-finding fixer subagents:** each has no view of the whole change, and the
documented failure is fixing one finding and breaking a sibling route. The fix goes to a fresh Build
context whose input is the branch state plus the findings, **never the tail of the original build.**

### Write `## Critique findings` on the slice file

**Open boxes append and are never deleted, and a closed one leaves at the next re-review**, into the
archive below. One direction, and nothing comes back. A `won't fix` from cycle 1 must still reach
Integrate, and the archive is inside the spec directory, so it does.

```markdown
## Critique findings
- [x] fixed — a failed tolerance write reported success
- [x] false positive — null guard at line 42; the caller guarantees non-null
- [x] won't fix — hard-coded org id in the test; fixture is scratch-org-local
- [ ] bulk path still throws above 200 rows
```

**A finding is raised as what would be observed, never as what is wrong with the mechanism** — the line
goes in front of the human approving the pull request, and *two rows where the user owns one* tells them
what *the create-adoption guard is redundant* does not. **Raised, so the text carries through the tag:**
closing a box replaces the tag rather than the line.

**A reference names what it points at, never where it sits.** *The open finding above* resolves only
while the target is open and the ordering holds — a live run watched its own pointers go stale and wrote
down why. Name the behaviour the other finding is about and the sentence resolves wherever either line
ends up. `## Traps` refuses a pointer of that shape already: an entry **never names a slice**. Archiving
does not create this defect — it makes it impossible to ignore — and **no finding IDs and no pointer
grammar are added for it**, because the archive's path is derivable from the slice's, so a worker that
knows which finding it wants has one file to open. That deliberate second read is the trade. **Nothing
migrates:** a spec already on disk keeps its references as written.

**A disposition is a different act and this does not bind it.** `won't fix` is the human's words and no
agent may shape them. **`false positive` replaces the raised text** — what was raised is the thing that
turned out to be wrong, so the line says what cleared it instead.

**Every checked box carries its tag as the first word.** A bare checked box reads as *fixed in code* when
it may not have been, and **only `fixed` and `met` mean the code changed.** Pin that apostrophe in
`won't fix` as ASCII — a typographic one silently empties the standing ledger that
`grep -rn "won't fix" devpath/` gives you on the base branch.

**Three writers, deliberately:** this skill writes `- [x] false positive`; **the fix-pass worker writes
`- [x] fixed` in the pass that fixes it**; and `- [x] won't fix` is the human's decision, spoken into the
orchestrator seat and written there. *Fixed* is a claim about work just done, so only the pass that did it
can make it.

**A box entry is one line beginning `- [` at column zero**, with nothing nested under it. The grep matches
an indented box anyway, so a formatter that renests the list cannot make a dirty spec read clean.

> ***Critique clean* ⇔ no `- [ ]` remains anywhere in the spec directory.**

One grep, zero judgment, every cycle. It names no heading, deliberately — a box put somewhere the design
never anticipated fails loudly rather than quietly.

**What is still section-dependent is what to *do* about a box, and that is not the same as the test.**
Under `## Critique findings` an open box means **fix this**. Under `## Deviations` it means **do not
proceed on this slice until a human clears it** — **a pause box is never ground on as a fix item.** Two
readings of one test: the grep answers *is anything open*, the section answers *what do I do about this
one*.

**Two boxes under `## Deviations` carry a tag, and neither is yours.** `- [ ] excess` is the commit audit's
note on files a commit swept in that no agent wrote, and review is exactly where it gets closed — by
the human, in front of the diff. `- [ ] blocked` is a pause — a foreign guard refused a write the slice
needs — and the `devpath:build` worker that resumes the slice closes it. **Leave both as you found them**:
neither is a finding to fix, and neither is yours to close.

**A box you write runs to 250 words.** Mandated. The half that has to fit is what would be observed and
enough of the reproduction that the next reader can get to it — across a field run's 114 boxes that half
averaged 76 words, so the cap is not what binds it. **What it refuses is the box that argues its own case
at length.**

**The overflow route is the commit body**, which `devpath:build`'s `### The commit message` names. **A cap
with no named route out is a quota, and a quota gets gamed.** Nothing in a run counts words and nothing
blocks on a count; the writer is the whole of the enforcement, here as everywhere.

**No budget on the section as a whole, deliberately.** A budget there would cap how many defects you may
report. Bounding the file is the archive's job below.

### Archive the closed findings

**Mandated. Every closed box that was under `## Critique findings` when you opened the slice file moves to
`devpath/<slug>/archive/<nn>-<name>.md`.** The slice file keeps what is live: the open findings, plus
whatever this pass itself just dispositioned.

**The rule keys on `- [x]` and reads no tag word.** Every closed box goes: no exception, and nothing on the
line for you to weigh. It is also the only form that holds on the boxes this grammar did not anticipate. A
field run wrote 114 closed boxes and 27 of them carried a tag from outside the closed set `devpath`
defines — 26 read `- [x] verified` — so a mechanism that read the tag would have had to decide what a
quarter of that run's own artifact meant.

```markdown
## Critique findings
- [x] fixed — a failed tolerance write reported success
- [x] false positive — null guard at line 42; the caller guarantees non-null
- [x] fixed — the bulk path swallowed the DML exception
- [ ] two rows are created where the user owns one
```

**That leaves the slice file holding one line**, with the three closed ones now in
`archive/04-tolerance-service.md`:

```markdown
## Critique findings
- [ ] two rows are created where the user owns one
```

```markdown
# 04-tolerance-service

- [x] fixed — a failed tolerance write reported success
- [x] false positive — null guard at line 42; the caller guarantees non-null
- [x] fixed — the bulk path swallowed the DML exception
```

**One file per slice, mirroring the slice's number and name**, so the path is derivable from the slice's
with no lookup — `devpath:slice` renumbers nothing and renames nothing, which is what keeps it derivable
for the life of the spec. **A `# <nn>-<name>` heading and the box lines under it, in archive order.** No
`## ` heading: this file sits outside the spec and slice schemas rather than adding a section to either.
**Created on first archive**, so its absence means nothing has ever been archived on that slice, which is
*nothing writes a placeholder* holding rather than an exception to it.

**Open boxes never move.** A closed finding you dispute is archived with the rest and then **raised again
as a new open box** — that is what re-arms the loop, and the raising grammar above is how the new line is
written.

**A disposition three passes back is one grep away, and two of them are decisions rather than work.**
`- [x] won't fix` is a human's call on a defect that is real, and `- [x] false positive` is a claim an
earlier pass verified — so a finding matching either has been answered, and the slice file stopped
carrying the answer one pass after it was written:

```sh
grep -n "won't fix\|false positive" devpath/<slug>/archive/<nn>-<name>.md
```

**Two tags rather than the file, because the file is what the archive exists to keep out of a context**,
and a grep for two tags is a handful of lines at any size. **`- [x] fixed` is deliberately not one of
them:** re-deriving a finding a fix pass closed means the fix regressed, which is a new finding rather
than a repeat. **Nothing branches on the tag** — the two lines go in front of you, exactly as Integrate's
step 4 counts them and the standing `grep -rn "won't fix" devpath/` lists them for a human.

**Raise it anyway where the code says so, and name the earlier answer on the line.** Code changes under a
`false positive`, and a `won't fix` is the human's to revisit. What this stops is the same defect reaching
them a third time reading as new.

**Every pass archives, including a `devpath:critique` run a human typed.** A pass always leaves the slice
holding only what is live. Making it conditional on which `fix_cycles` row fired below would turn one act
into two and hand a critic a branch to get wrong — and *read-only* is not a property this skill has, since
a standalone run already writes findings, `fix_cycles`, `## Traps` and a strike through a wrong
`## Current state` note.

**What this buys `fix_cycles`.** With the closed set cleared at every re-review, a `- [x] fixed` box on the
page can only have come from a fix pass since the last one, which is what row 2 of the table below always
needed it to mean. **Nothing in that table moves.** What changes is that its third row is reachable rather
than theoretical: a pass opening a slice that carries a `fix_cycles:` line and no `fixed` box is looking at
an engineer running this skill again, or at a fix pass that disproved its finding and wrote no box, and it
writes nothing. A disproof that used to spend a lap of the cap now costs none.

**Why the re-review and not the tick.** A fix pass removing the box as it ticked it breaks the count in the
other direction. Row 2 fires because **the next critic sees a `- [x] fixed` box** — take the box away at
the tick and row 2 never matches, the field freezes at 0, and the fix cycles cap never trips. **A stub left
behind fails the same way, less obviously:** a one-line stub still carrying the tag matches row 2 forever,
and one that drops the tag to avoid that leaves `devpath:integrate` step 4 nothing to count, which is the
thing the stub was bought for. **Whole line, no stub.**

**Where the file sits, and the two placements it is not.** Inside `devpath/<slug>/`, so it lands on the base
branch under squash, rebase and merge alike, stays inside the open-box gate's sweep, and keeps
`grep -rn "won't fix" devpath/` whole. **Not under `slices/`:** `scripts/contention.sh` walks the working
tree with `"devpath/$HERE/slices"/*.md`, one level deep, and remote branches with
`case "$f" in */slices/*.md)`, whose `*` crosses `/` — so an archive in there is invisible to contention on
your own branch and read as a slice on everyone else's. **And not a suffix on the slice's own name**, which
is worse: both globs take it. `ls slices/` is also what answers *has this been sliced?* in every case, and a
second kind of file in there ends that. **README's schema hook is not a reason either way** — measured, not
assumed: it flags a heading that should not be there and is silent on a file carrying none, under `slices/`
or anywhere else. What it does hold is the heading rule above, wherever this file sits: give it a `## `
heading and the hook objects. **`devpath/<slug>/sketches/` is the precedent** — a sibling directory holding
a different kind of artifact.

**`## Deviations` is not archived, and the omission is deliberate.** It is named in the same breath as this
section wherever the two are counted, and it grows the same way — but no pass verifies an entry and settles
it, so there is no non-arbitrary moment to hang an archive on. Said here rather than left to read as an
oversight.

### Traps

**Mandated: read `## Traps` on `spec.md` before you review the tests, and go to the heading by name.**
Every entry is one mutation a test on this spec has to be able to fail on. **A test that cannot fail on
what an entry names is a finding**, and it is the ordinary kind — you are checking the code against
something this spec wrote down, exactly as you check it against the repo's standards rule.

**Mandated: write a trap on either of two triggers.** Each one is binary, and **the pass that confirmed
the finding writes both** — the only pass that can, which is the same rule that puts `- [x] fixed` on the
worker that fixed it.

| The trigger | What makes it binary |
| --- | --- |
| **Trigger 1.** A confirmed finding whose cause is **a test that passed while the code was wrong** | it survived triage, and the test covering that code was green when you found it |
| **Trigger 2.** A confirmed finding whose cause is **still quotable from `## Design`** | the sentence the defect came out of is under that heading, and you can point at it |

**Both triggers name a defect the next worker cannot see in what they read.** On trigger 1 the test
passes, it covers the code, and nothing in that slice states what it must be able to fail on. On trigger 2
the sentence that produced the defect sits under `## Design` reading as current as the rest of the
heading, so the next worker to build from it writes the defect back. Neither survives in the slice it was
raised on, and a fresh critic on the next slice reads the slice.

**Trigger 2 is a quote or it did not fire, and the quote goes in the entry.** Point at the sentence under
`## Design` the finding came out of. If you cannot, there is no trap — nothing here asks you to weigh how
much the design contributed, and the trigger holds no word for you to judge.

**One finding, one entry.** A finding that trips both triggers earns one trap carrying both — the
mutation, and the sentence it came out of.

**Both triggers fire on what this pass confirmed, and that is what makes them once-only.** Triage is
something a pass does, so a finding already carrying a disposition was triaged by an earlier pass and is
not yours to confirm again. **And neither trigger reads `## Critique findings` anyway** — the subject is
the list you built this pass, which is what leaves archiving the closed boxes invisible to both.

**A quote that no longer resolves is still the entry doing its job.** `## Traps` survives a design
withdrawal — `devpath:technical-design` deletes `design_approved` and rewrites `## Design` with this
section untouched — so a finding confirmed here can be paused by Build, sent back through the design gate,
and answered by a sentence that is no longer on the page. **The mutation is the entry and the quote is why
it was written.** A quote you cannot find under `## Design` is provenance, not a broken reference: it
holds where the code and the tests it names are still there, exactly as an entry outlives the slice
numbering it was written against.

**A trap quotes `## Design` and does nothing else to it.** `devpath:technical-design` owns that heading,
and this section carries no mechanism that touches it.

**A trap is written off a finding, never hunted for.** Both triggers are facts about a finding already
confirmed on this slice, and nothing here sends you looking for a class of defect. That would be this
skill writing a check instead of reading the repo's standard, which is the line the section above draws.

**Mandated: reach the mutation before you write the entry**, which is the whole-suite claim above and
costs the run. **Reachable:** you can state the sequence of acts, against the code as it stands, that gets
to the branch and makes it observable. **And green:** where a test already fails on it, there is nothing
here for the next worker to write.

**Reachable is stated and not run, which is why it is the half to be hard on.** The run above settles
green alone, and green is the same colour whether no test covers the mutation or nothing can reach it.
Driving a sequence to a branch is test code and critics do not write test code, so nothing here can make
you prove it. A mutation nothing can reach still loads into every later worker, where it reads as a live
gap. An entry written here on 31 August said collapsing one guard moved the client's checked entry; a
lockout landing on 1 September closed the pairing that guard arbitrated, and collapsing it now moves
nothing. **An entry gets its one run when it is written**, and nothing goes back.

**Write the mutation, as a target.** An entry states what a test here must be able to fail on, which is
something the next worker can go and write. A prohibition — *fixtures should not all look alike* — hands
that worker the shape to avoid and nothing to build.

```markdown
## Traps
- A test over which item a write lands on must be able to fail on an inaccessible item sitting earlier in
  the list. Every fixture here grants access to every id, so a test that finds the right item and a test
  that takes the first one are the same green.
- A test over the retry path must be able to fail on a second callout arriving under an idempotency key
  already used. `## Design` reads *"the queueable re-enqueues itself on a partial failure"*, and
  re-enqueueing without carrying that key forward is the defect that came out of it.
```

**No box.** Every `- [ ]` in a spec directory is *Critique clean*'s subject and Integrate's refusal, and a
trap has nothing to close. **A plain bullet, one per trap.**

**An entry is about the code and its tests, and never names a slice.** A design can be withdrawn and
re-sliced under a `## Traps` section that survives both, so an entry keyed to slice 05 outlives the
numbering it was written against — where the code and the tests it names are still there.

**One meaning, one place: `## Critique findings` holds the instances, `## Traps` holds what outlives
them.** An entry that is a copy of the finding it came from is the duplication this schema avoids
everywhere else, and the finding is already inside this pull request's own diff anyway.

**Two bounds, and both are the price of the section rather than a footnote to it.** Every entry loads into
every later worker and every later critic — the multiplier `devpath:learn` states about unscoped rules,
paid **per worker** rather than per session. So: the section is per-spec and **dies with the spec**, where
no other spec's workers ever load it; and an entry that **restates a default** — *write thorough tests* —
pays that per-worker cost to change nothing, **as does a second copy of a trap already there.**

### A wrong `## Current state` note

**Mandated on one trigger: a confirmed finding whose cause is a wrong `## Current state` note on
`spec.md`.** Survey writes every finding with what it was read off, so the check is the ordinary kind: go
to what the note names — the file and the line it quotes, or the grep it ran — and see whether the repo
says what the note says.

**Strike the note in place and put the correction after it. Leave the error visible, and never overwrite
it.** Edit the bullet that is already there: no second bullet, and **no box** — there is nothing here for
anyone to close.

**The correction carries what it was read off**, in Survey's shape — the file, and what you read there.
The corrected note is the one the next worker inherits, so a correction nobody can check leaves that
worker exactly where the wrong note left them.

```markdown
## Current state
- O1 — ~~The flex item is the `.rstk-nav-section` `<article>` inside `navigatorSection`'s shadow
  root. Read off `navigatorSection.html`, `<article class="rstk-nav-section">`.~~ Struck at
  Critique: the flex item is the `<c-navigator-section>` host. Read off `navigator.html`,
  `<c-navigator-section>` inside the flex container — the `<article>` is the shadow root's own
  child, which the parent's layout never reaches.
```

**Why the wrong note stays on the page.** It is the one thing that explains the code the next worker is
about to read: a class sitting on an element nothing lays out reads as an oversight until you can see the
note it came from. An overwrite also costs the next critic the difference between a note nobody has
questioned and a note that was wrong and got corrected.

**This is not new authority.** The slice pass already writes `## Traps` on `spec.md`, and who commits that
write is settled under `## Stop` without reference to the caller — a dispatched critic writes and returns,
and the session that dispatched it commits on that return. That is what makes the strike work identically
inside `devpath:build` and under `devpath:critique` alone.

**The critic does not edit `## Design`.** A design premise the correction invalidates is superseded, not
rewritten: that heading is gated material, and correcting it is a stop rather than a subagent's write.
Where the premise is still quotable from `## Design`, it is trigger 2 above and the trap is already owed —
**this section adds no trigger and widens neither.**

## The fix cycles cap

> **The cap does not stop the work. It stops the work being unattended.**

**A cycle is a fix and its re-review.** The initial pass is a review, not a cycle — nothing was fixed, so
there was no round trip. The sequence is build → review → **fix → review** → **fix → review**, one bold
pair per cycle, so `fix_cycles: N` counts fix attempts and nothing else. That also makes `fix_cycles: 0`
mean something true — *reviewed once, needed nothing.*

**The threshold is `skills/build/SKILL.md`'s**, written once in the seat that reads it.

**The trigger is an undispositioned `- [ ]`**, identical to *Critique clean*. A finding already marked
`won't fix` or `false positive` does not hold the loop open.

### When to write `fix_cycles`, and what to write

**Mandated. `fix_cycles` is written here and by nothing else.** Build never touches it — Build's field is
`done`. Three cases, each observable from the slice file alone:

| The slice's state when Critique opens it | What to write |
| --- | --- |
| no `fix_cycles:` line at all | **`fix_cycles: 0`.** This is the review after the build, and a review is not a cycle |
| a `fix_cycles:` line, and `## Critique findings` holds at least one `- [x] fixed` | **one more than you read.** A fix happened and this pass is its re-review |
| a `fix_cycles:` line and nothing fixed since | **nothing.** Re-reading a slice no fix touched is not a cycle |

**The third row is what makes `devpath:critique` safe to run alone.** Without it an engineer re-running
Critique to look again spends a lap of the cap on a pass in which nothing was fixed, and the cap starts
counting attention rather than fix attempts.

Slice writes no `fix_cycles:` line at creation, which is why the first row exists at all: the line is
absent until this skill's first pass writes it, and it is absent for exactly one pass.

### When the cap trips

**Ask the engineer already in that session. No new human, no third gate.** The answers are the disposition
grammar, *keep going*, and *cut a new slice* — which `skills/build/SKILL.md` asks and performs.

**The grant is spoken and never stored.** Default **one lap per "go"**, with an optional count — *cycle up
to three more times*. Storing it would be a new field and, worse, a standing permission sitting on disk
long after the conversation that granted it. It lives in the session and dies with it.

**Only *keep going* needs no write at all.** A disposition is the human's — their words, onto the line,
written by this session. *Cut a new slice* is the cut plus two writes, and none of them is the human's to
phrase; `skills/build/SKILL.md` states all three. Either way the next `devpath:critique` run opens a slice
whose finding is already dispositioned.

**`fix_cycles` keeps counting through granted laps**, so a slice that ends at 7 is honestly recorded as one
that fought. **Nothing caps how many times a human may grant** — any limit there would be the first thing
in this design constraining what a human may choose.

**A cap trip stops the whole `devpath:build` run.** It is not a gate: a gate is three things at once —
the run stops, a stored field records that a human said yes, and the router refuses the next stage without
it. A cap trip is the first only.

## The change-request pass

**A reviewer requesting changes on the pull request re-enters as the same fix pass**, and it is
**engineer-initiated** rather than fired from a GitHub event. The output under discussion *is* the code
being reviewed, so a misread comment spends exactly the attention this design is trying to earn.

**The one difference from the internal loop: show a triage list first and wait.** The internal loop does
not, and the difference is entirely in the input. Findings from a bot or from Critique itself are
mechanical. A human comment may be **a defect, a nit, a wrong suggestion, or a question wanting an answer
rather than a code change** — four readings, and this skill cannot pick between them without asking.

> **The agent drafts replies; the human posts them.**

**That is a rule, not a preference, and its reason is social rather than technical.** It keeps an agent
from arguing in a pull-request thread with the senior engineer reviewing the team's first agent-written
code. It is also the line most likely to be dropped as friction by someone reading only the mechanics,
which is why it is written as a rule.

**Everything else applies unchanged**: a fresh critic, the disposition grammar, `fix_cycles` and the
fix cycles cap, and Build doing the fixing.

## What no check reaches

**A slice made only of custom metadata has no behavioural verification whatsoever.** No runner exists for
it and the deploy validates shape only. The same holds for permission sets, layouts and screen flows.

> **Say that outright rather than inventing a check.**

An invented check is the pattern this design has measured ten separate times — a check written and never
wired. If a slice's behaviour cannot be verified, the finding is *this cannot be verified here*, and the
verifiers that remain are the deploy gate for *will it deploy*, the human at the design gate for *is the
slice complete*, and the pull-request reviewer for *is the diff readable*.

## Stop

**Critique done ⇔ this pass has written its findings and archived the closed boxes it opened the file on,
or it stopped and named what stopped it — the slice on a tripped cap, the condition at `## Refuse first`.**

Write the findings, move the boxes that were already closed into the archive, write any trap this pass
earned, strike any `## Current state` note this pass found a confirmed finding's cause in, write
`fix_cycles` if this pass is one of the three cases above, and return.

**Who commits that write is your role and never which skill called this one.** **A dispatched critic
writes and returns; the session that dispatched it commits on that return.** **The session holding this
skill commits** — whether `devpath:build` loaded it here or a human typed it, that session is the one that
can.

**One rule and not two paths**, because a critic is a subagent in every pass above: *write and return* is
what a critic always does. Two writers on one branch pointer is the thing being avoided, and **a failed
commit needs a human a subagent cannot reach** — both are properties of the worker, not of the caller.

On a cap trip, stop the run and say which slice tripped it and what the answers are.

Do not fix anything here. Do not tick a box you did not verify.
