---
description: Check a built devpath spec against its Outcomes and release it to merge. Use when every slice of a spec is done and the work is ready to ship.
---

# Integrate

> **Integrate produces a verdict, never work.** It touches no code, cuts nothing, writes no slice file.

## Refuse first

**This block runs before step 1**, and *refuse first* means **before the first write**. Step 1 writes to
`spec.md` and step 2 runs a script, so a gate refusal arriving at step 3 would already have rewritten
`## Outcome checks` on an ungated spec.

- **`git branch --show-current` returns `main`, `<base>`, or a branch with no matching spec directory**
  → **stop.** Do not guess which spec this is. Say the next act: `git checkout <slug>`.
- **The command returns empty** → **stop, and say what is actually wrong:** it returns empty with exit
  code 0 under a detached HEAD, so the truth is *you are not on a branch*, never *no spec on this
  branch*. The fix is one `git checkout -b <slug>`, and it is a human's.
- **`intent_accepted` is not `true`, or `design_approved` is not `true`** → **stop, naming which.**
  Integrate sits behind **both** gates, and unlike the standalone stage skills it is a command, so
  **nothing has checked either field before it.** The route being closed is a human typing
  `/devpath:integrate` on a spec that never passed the design gate.
- **The front-matter block does not parse, or a field carries the wrong shape** → **stop and name the
  exact field.**

**Nothing about the work is refused here.** No slice count, no `done` test, no box test, no `fix_cycles`
test — all of those are step 3's, and step 3 is a verdict on the work rather than a check on the route.

**Prefix every message a gate or refusal prints with `devpath: `.** Suggested.

## The eight steps, in order

**The arming is last because it is the one irreversible act on this list.**

1. Run the Outcomes pass; write `## Outcome checks`. **Refuse on a `won't fix` line whose Outcome is
   gone from `## Outcomes`.**
2. Run the contention script again.
3. **Refuse on an open `- [ ]`, and on a slice carrying `done: true` with no `fix_cycles:` line.**
   **Print every unmet Outcome's shortfall and where each of the three exits goes, then ask once per
   unmet Outcome. Step 3 prints and stops; it starts no run.**
4. Write the pull request body with `gh pr edit <number> --body-file -`: Intent, then `## Summary`,
   `## Merge Danger`, `## Outside the Test Boundaries`, `## Accepted Gaps` and `## Full Details`.
   **`scripts/pr-body.sh` prints every part a rule decides**, and a fresh subagent writes
   `## Merge Danger`.
5. Offer to file `## devpath feedback` as an issue. **If it is empty, say the heading exists and file
   nothing.**
6. Name a signal back to the engineer, if anything written down shows one. **If step 5 is also filing, it
   is one issue, not two.**
7. Run `devpath:learn`.
8. Mark the draft pull request ready and arm auto-merge.

---

## 1 · The Outcomes pass

**One subagent per Outcome. Write `## Outcome checks` on `spec.md`, one line per Outcome, always
written.**

**Dispatch the checkers on the cheapest tier that reliably reads a diff and judges it against a written
statement; the orchestrator stays where it is.** Suggested, with its reason. **Named by the property
first, because a tier name is a model property and this one will move** — Sonnet is the current instance,
and **Haiku is excluded by decision.**

**The reason is this stage's own, and not the one `devpath:survey` gives for its researchers.** A
checker's job is bounded — one diff against one written statement — which is the cheapest kind of judgment
to get right, where a researcher's is an open-ended read. **What a cheap tier must not be handed here is
breadth, and one checker per Outcome is what leaves it none.** The stakes cut the other way and are why
the tier is suggested rather than mandated: an unmet verdict stops step 3 and reaches the reviewer in the
pull-request body, and a wrong `met` reaches nobody.

**It is the one deliberate exception to *nothing writes a placeholder*** — always written, because
otherwise *nothing was wrong* and *the pass never ran* are indistinguishable. It is not a placeholder:
every line is a real per-Outcome verdict.

```markdown
## Outcome checks
- [x] met O1
- [ ] unmet O2 — throws above 200 rows; batching is fixed at 200 and nothing chunks past it
- [x] won't fix O3 — audit-trail object is managed and read-only in this org
```

**Mandated: the tag, then the Outcome's ID, then what was observed.** A `met` line **ends at the ID** and
carries no prose at all — the ID is the reference and the statement is one heading away under
`## Outcomes`.

**`- [ ] unmet` is not a sixth state.** It is a bare `- [ ]` with the shortfall spelled out, so every
check that greps `^[[:space:]]*- \[ \]` matches it.

**What follows the ID is what the checker observed.** Never the Outcome restated, never a proposed fix. A
line that repeats the Outcome carries nothing about what fell short, and step 3 then hands the engineer a
refusal with nothing in it to act on. A live run wrote exactly that line and the engineer read *the
outcome failed*.

**The ID is what makes the restatement impossible rather than forbidden.** With the reference already on
the line there is nowhere for a restatement to go, so this stops being a rule an agent has to remember and
becomes a shape it cannot get wrong. **`tests/lint.sh` check 5 holds it** against this skill's own
illustrations, which is where the last violation of a rule like this one survived.

**That is step 6's fourth bound arriving five steps early — *report the observation, never the
diagnosis*.** One rule, cited rather than a second one invented. *Throws above 200 rows; batching is fixed
at 200 and nothing chunks past it* is the observation. *Add chunking* is Design's, and a checker holding
one diff and one sentence is the last agent in this workflow qualified to write it.

**Why one checker per Outcome, where Survey groups.** An Integrate checker reads a known diff against a
known statement, so it is cheap per agent — it has no breadth problem to bound. And grouping here would
concentrate *judgment*: one checker holding four Outcomes writes four verdicts from one reading, at the one
stage where a wrong verdict merges code. Survey's findings feed a human conversation that catches a weak
one; `## Outcome checks` is the last gate.

**Why the pass runs here and not per slice.** On slice 1 of 5 nearly every Outcome is unmet. And it
cannot key on *the last slice done* either: slices can be built in any order and in more than one
session, so two concurrent finishers both observe *everything is done*, both run the pass, and both write
`spec.md`. Integrate runs exactly once per spec by construction — one spec, one pull request — so there
is nothing to count and no condition.

***Isn't that late?* No.** You cannot check whether an Outcome was achieved before the code exists. This
is the earliest possible moment.

> **Integrate rewrites every line of `## Outcome checks` except one marked `won't fix`, which it carries
> forward verbatim and does not re-check.**

Same principle as never writing `false` on a gate field: **the machine does not relitigate a human's
decision.** It is a string check, not a judgment.

### Carrying a `won't fix` forward stops on an Outcome that is gone

**Mandated. Read `## Outcome checks` before you dispatch anything, and resolve every `- [x] won't fix`
line's `O<n>` against `## Outcomes`. If the ID is not there, stop the run** — before the checkers go out
and before this step writes.

```
devpath: `- [x] won't fix O2` names an Outcome that is not in ## Outcomes.

  O2 was retired. Carrying this line forward files a permanent admission that
  the team shipped short on something this spec no longer asks for.

  Decide before this runs again:
    the admission still stands → retarget it to the Outcome that replaced O2
    it went with the rework    → delete the line

  This run stops here. Steps 2 to 8 do not run.
```

**Steps 2 to 8 do not run.** The contention script does not run, `## Outcome checks` is not rewritten, the
pull request stays a draft, and nothing is armed. **Say that** — a builder wiring this as a warning
produces a different plugin, and it is the same reason `### This refusal is a hard exit` exists under
step 3.

**Scoped to `won't fix` and to nothing else here.** The carry-forward is the only line this step can meet
stale, because it rewrites every other one from scratch — so a stale `met O2` is gone before anybody reads
it, and a check over the whole section would fire on states that were about to correct themselves.

**`## Outcome checks` has one other reader that acts on what it finds, and the condition is asked again
where it reads.** `devpath:build` reads the `- [ ] unmet` lines to cut against, *before* it expires them,
so an unmet line naming a retired Outcome does reach a reader — and its cut resolves the ID there and
skips the line rather than cutting for it. **One condition, asked at each of the two places that could act
on a stale line**, and neither of them a check over the spec directory.

**Neither exit is this skill's to pick.** The line is a human's decision in a human's words, so nothing
here retargets it and nothing here deletes it.

**A `devpath:initiate` re-entry reads the section too and asks nothing**, because it clears every line and
names each `won't fix` it removed while the human who asked for the rework is in the room. So the
refusal's exit 3 no longer reaches this stop, and what does is a design conversation retiring an ID, or a
hand edit.

**Why this is an instruction here rather than a check over the spec directory.** Measured against a spec
directory holding one genuinely stale line, a grep resolving every `O<n>` token returned four hits: the
stale `won't fix`, a Survey finding under `## Current state` that Design prunes anyway, a slice deviation
naming a retired Outcome — **which is the trace working rather than a defect** — and `O365` out of a Jira
URL under `## Evidence`. One useful hit in four, in a check that is off for every repo that does not paste
it, firing at pull-request time when the line is already written and already in the body. **The condition
above is on for every repo, fires before the line reaches the pull request, and cannot see a Jira link.**

## 2 · The contention checkpoint

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/contention.sh"
```

**Show its output verbatim if it printed anything.** It stores nothing, stops nothing, and always exits
0. `${CLAUDE_PLUGIN_ROOT}` is required — a bare relative path resolves against the target repository,
where nothing of the plugin's exists.

## 3 · The refusal, and its three exits

**Step 3 holds two mechanical tests against a fixed grammar, and neither is a model judging.** One is a
grep; the other is a walk over the slice files.

**Test 1 — refuse while any `- [ ]` remains anywhere in the spec directory.** Same test as *Critique
clean* — one grep, section-blind, zero judgment.

```sh
grep -rn '^[[:space:]]*- \[ \]' devpath/<slug>/
```

**Leading whitespace is part of the pattern, because a formatter can indent a box.** Anchored at `^` alone
this test misses `  - [ ] excess`, and a box it misses is a merge armed on a spec it should have refused.
The widened pattern also matches a box nested under another list item. The grammar writes none, and one
written anyway is still open.

**Test 2 — refuse while any slice carrying `done: true` has no `fix_cycles:` line.** Slice writes no such
line at creation and Critique writes `fix_cycles: 0` on its first pass over a slice that has none, so the
line's presence is the slice pass's own trace: **absent on a built slice, the pass never ran on it.**
**`done: true` is the mechanical form of *carries code*** — a slice holding code and no `done: true` holds
an open box, which test 1 already refuses on, so nothing here judges whether a slice built anything.

```sh
for f in devpath/<slug>/slices/*.md; do
  grep -q '^done:[[:space:]]*true' "$f" && ! grep -q '^fix_cycles:' "$f" && echo "$f"
done
```

**Test 2's two patterns are anchored at line start, and that is the whole precision here.** Front matter
sits at byte zero and its fields start their lines, so an anchored match reads the field and never the same string
in a slice's prose — a slice that discusses `fix_cycles:` in its notes must not pass this test on the
mention.

**The next act on test 2 is `devpath:critique` over the slices this test named.** Its invocation table
routes a human-typed run with no change request on the pull request to exactly that, so a spec that missed
the pass has a specified mode waiting rather than a workaround — and that pass writes the line that clears
this refusal.

**Name the slice pass when the pull request carries a review requesting changes**, because the same table
then routes a human-typed run to the change-request pass instead. That pass triages a reviewer's comments
and need not open the slices named here, so it does not clear this refusal. **Print the slice paths either
way** — they are what the next run is for.

**Why a second test earns its place at a step that was one grep.** An empty `## Critique findings` is an
ordinary end state rather than a signal — Critique archives the boxes that were already closed at every
re-review, so what a finished slice holds is the last pass's dispositions and sometimes nothing at all.
Test 1 passes it either way, and step 4 then counts zeros on a slice no critic ever read exactly as it
does on one a critic cleared. **What tells those two apart is test 2, the `fix_cycles:` line** — the
slice pass's own trace, which is what this test was already for. *Nothing was wrong* and *the pass never
ran* are otherwise indistinguishable at every check downstream of Build. Shipping unreviewed slices is
exactly the state a human at merge wants named. **And Build reaching Critique is model-driven**: the
imperative is in `devpath:build` and nothing in the harness makes it certain, so what catches a skip is
the trace, not a louder instruction.

**The cost, said rather than smoothed: step 3 is no longer one grep.** It is a grep and a walk, and *one
grep, zero judgment* is now a claim about `- [ ]` alone.

**What to *do* about a box is section-dependent, and that is not the same as the test.** Under
`## Critique findings` an open box means *fix this*; under `## Deviations` it means *do not proceed until
a human clears it* — **a pause box is never ground on as a fix item.** An unticked `## Acceptance
criteria` box holds Integrate exactly as an open finding does, and **that is intended behaviour rather
than a false positive.**

**A tagged box under `## Deviations` holds this refusal exactly as a pause does**, and the tag names the
decision rather than whether one is owed. `- [ ] excess` is the commit audit's note on files a commit
swept in past the slice's `wrote:`, closed on the human's decision at merge: `- [x] false positive` where
the file belonged in the commit, or `- [x] won't fix — <reason>` where it did not.

**`- [ ] blocked` and `- [ ] verify` are the other tagged boxes, and their exit is not a tick here.**
`blocked` waits on a human clearing a foreign guard's refusal outside the run, and `verify` waits on the
engineer trying a criterion only a person can see. **Neither disposition above applies to them.** Offering
one here is how a merge gets armed on an obstacle nobody cleared or a behaviour nobody saw. Print the slice
path, say what the box is waiting on, and name `devpath:build` as the next act: it closes a `blocked` box
on what it finds, and it asks the engineer about a `verify` box.

**Print every unmet Outcome's block in full, all of them, before you ask about any of them.** A table of
meanings is not a handover — the engineer in the seat needs a next act, and for two of these three exits
there was nowhere to go. The question that separates them is **did we fall short of the target, or was
the target wrong?**

The shape, rather than wording to copy:

```
devpath: 11 of 15 Outcomes met. 4 unmet — this run stops here.

  Unmet · O2 — Bulk update over 200 rows completes without error
    Fell short: throws at 500 rows; the chunker walks the first batch and
    nothing advances it
    Cut for O2 once already, at slice 07: throws above 200 rows; batching is
    fixed at 200 and nothing chunks past it
    Recommended: Rebuild it. The design covers batching, the code stops at one
    batch, and that is work left.

  [one block per unmet Outcome, in ## Outcome checks order, all of them]

  Did we fall short of the target, or was the target wrong?
    work left             → Rebuild it           /devpath:build cuts a slice for it
    target was wrong      → Rewrite the Outcome  /devpath:initiate rewrites it; both gates drop
    right, shipping short → Won't fix            tell me: won't fix O2 — <your reason>

Type every won't fix reason here. Then /devpath:initiate if any Outcome was
rewritten, otherwise /devpath:build.
```

**Neither line is composed here. Both are quoted, punctuation included.** The `Unmet ·` line is
`## Outcomes`'s own line, ID and all, and *Fell short* reproduces what the `- [ ] unmet` line says after
its ID. **Reproducing it means reproducing it:** the illustration above wraps the line to fit and changes
nothing else about it, semicolon included.

**The prior-attempt line is the one composed thing in the block, and only its prefix is.** What follows
the colon is the bullet's shortfall, punctuation included, on the same rule as the two lines above. **The
two shortfalls are written in different runs and often differ**, which is the whole reason the older one
is worth printing.

**The ID and the statement print together, because the human answering has only the ID to give back.**
`won't fix O2` is what they type, and a block printing the handle alone would ask them to decide against
one. **The ID is a handle, never a position** — O2 is the second line only until an Outcome is retired,
and a positional index is a convention nothing in `devpath` defines.

**The handover names one order, because `devpath:build` cannot know which exit you chose for which
Outcome.** It cuts a slice for every Outcome still marked unmet at the moment it runs. So: type any
`won't fix` reasons in this session. **If any Outcome was rewritten, `/devpath:initiate` is the only next
act** — it rewrites `## Outcomes` and drops both gates, so Build waits behind them. Otherwise
`/devpath:build`.

**The hazard that ordering closes is now *finish typing before you build***, where it used to be *decide
before you build*. The deciding happened at the prompt. What can still arrive too late is a reason nobody
typed, and the spec then carries a slice nobody wanted.

**Exit 1 — `Rebuild it`, `/devpath:build`.** There is work left. Build cuts a slice for that Outcome,
builds it, and writes down which Outcome it was cut for.

**Exit 2 — `Won't fix`, the ledger.** The Outcome was right and the spec ships without it: `grep -rn "won't fix"
devpath/`, forever. How that line gets written is below.

**Exit 3 — `Rewrite the Outcome`, `/devpath:initiate`.** The Outcome was never what we wanted. Its text
lives in `## Outcomes`, which Initiate owns and overwrites, and Initiate's re-entry table already handles
this exact re-run. **Say the consequence in one blunt sentence: a rewrite sends the spec back behind both
gates, and the slices survive on purpose.** **The expense is the point** — it is what stops a rewrite
being the cheap way past a hard Outcome. Same rule as *a criterion you cannot satisfy is not edited into
one you can* in `devpath:build`, one level up and about an Outcome instead.

**Why these three names, and why not *rework it*.** *Rework it* and *Rebuild it* are the same word wearing
different hats — both read as *do the work again*, where the whole point of the distinction is that one
changes code and the other changes what we asked for. **`Rewrite the Outcome` names the artifact that
changes.** *Fix the Outcome* collides with `Won't fix` in the same list of options, and *Restate the
Outcome* collides with step 1, where restating the Outcome on a verdict line is the forbidden thing.

**Exits 1 and 3 belong in a fresh session. Exit 2 is this session's next turn.** Say both, because they
are not the same shape. `/devpath:build` and `/devpath:initiate` are commands and a command starts a run,
and everything either one needs is on the branch — `## Outcome checks`, the slice files, `## Deviations` —
so a fresh session pays full price and loses nothing. A session still holding eleven `met` verdicts talking
itself into carrying on past this refusal is conversation-held state deciding it knows where it is, which
is the failure `devpath:build` opens by naming as measured. **A `won't fix` line is not a command and does
not start a run**: the engineer says it to the session they are already talking to, which writes the line.
That is the whole of the section below, and printing it as a fourth command is the mistake this paragraph
exists to prevent.

**Say what the next run costs, as a property rather than an apology.** One sentence, here at the refusal:
every line closed as `won't fix` carries forward verbatim, every other Outcome is checked again, and
`devpath:build` expires this section before it changes any code — so no verdict is ever older than the run
that printed it.

**Naming all three is load-bearing:** without it, the way to ship something knowingly unresolved is
invisible to anyone who has not read the design. **And the third exit exists to protect the ledger** —
without it a wrong Outcome walks out through `won't fix` and files a false admission. The ledger's entire
value is that a hit means something.

**Build cuts the slice, never Integrate.** Nothing new is built to make this work: Build already holds
re-cut authority; the new slice is an ordinary slice with the next number, `depends_on` by the normal
rule and `done` absent, so Integrate then refuses for the reason it already refuses. This is not the
routing trap — routing a finding to one of five existing slices is attribution, with N destinations and
judgment about code the model did not write. **Cutting a new slice asks *is there work left*: one
destination, no attribution.**

### A prior attempt on the same Outcome prints, and nothing branches on it

An Outcome cut for once already, built, and still unmet is evidence that the target is wrong rather than
merely hard — and **it is the one signal the engineer is least likely to be holding in their head.**

The fact already has a fixed written form. `devpath:build` writes it under the new slice's
`## Deviations`:

```markdown
## Deviations
- Cut for O2, unmet at Integrate: throws above 200 rows; batching is fixed at 200 and nothing chunks
  past it.
```

> **Mandated: grep the slice files for `- Cut for O<n>, unmet at Integrate:`. For every hit, print
> `Cut for O<n> once already, at slice <NN>:` — the number from the file the hit came from — and then the
> bullet's own shortfall, whole, in that Outcome's printed block above the prompt. The ladder below stays
> blind to it.**

**`grep` returns the matching line and the bullet wraps.** Read the entry rather than the match: Build's
bullet runs to its trailing period, and a hit cut at the line break drops the end of the sentence.

**This costs no exception.** `devpath:build` says **no run branches on `## Deviations`**, and nothing here
branches: no act changes, no option moves, no artifact differs. What changes is what prints. And the entry
reaches the reader it was written for — Build says it is there for the human at merge, and this is the
most human-facing moment in the plugin.

**Step 3 already walks the slice files** for test 2, so the read is free.

**The grep reads no tag**, because Build mandates that this bullet carries none. Matching a plain prefix
adds no state, because nothing mechanical branches on a tag word.

### The ask, where the harness offers a question tool

**The printed block is the message; the prompt is what follows it.** Where the harness offers a tool that
puts a question to the human with named options, step 3 asks **one question per unmet Outcome**, and the
three exits are its three options, named as acts:

| Exit | Option | Where it goes |
| --- | --- | --- |
| there is work left | `Rebuild it` | `/devpath:build` |
| the Outcome was wrong | `Rewrite the Outcome` | `/devpath:initiate` |
| right, shipping short | `Won't fix` | the ledger |

**Where the harness offers no such tool, the printed block is the whole handover** and the engineer types
the answer, exactly as the shape above prints it. **Both paths carry the same information and leave the
same artifacts, so nothing downstream can tell which one ran** — no field, no marker, no branch. Same
posture as `devpath:survey`'s tier rule, which degrades to a no-op on a single-tier harness and probes for
nothing. **There is no detection step, because a detection step is itself the branch this forbids.**

> **The tool presents the decision. It never presents the material.** The Outcomes, the shortfalls, the
> prior attempts and the recommendation are printed in full, in the message, and the prompt follows them.
> **A click is legal downstream of a read and never instead of one.** An option's description says what
> the choice *does*; it never carries the thing being judged.

**Every unmet block prints before the first call, all of them.** Where the tool caps how many questions
one call carries, more unmet Outcomes than that cap means more than one call, **in `## Outcome checks`
order** so nothing is silently dropped. Printing per batch instead would have the human answering about
the first four Outcomes before reading about the fifth, which breaks *a click is legal downstream of a
read* for every Outcome past the cap. **Step 3 writes nothing at all** — the only write any exit produces
is Exit 2's line, and that waits on a typed reason on a later turn either way.

**Step 3 prints and stops. It starts no run.** It now holds every disposition at once and the `Skill` tool
is already a dependency, so a builder will be tempted. The reason exits 1 and 3 belong in a fresh session
is the session's spent context, which is a fact about the context rather than about how the choice was
collected — so it survives the prompt untouched.

**The free-text answer the tool always offers stays legal at every question, and the run reads it for
intent.** Someone may want to ask about O3 rather than dispose of it, and an over-literal rule would either
refuse the question or quietly write a disposition nobody picked. **One bound, and it is narrow.** Three
writes in this plugin hold a human's decision — `intent_accepted: true`, `design_approved: true`, and a
`- [x] won't fix O<n> — <reason>` line — and every stored field is either something a human did or
something a machine counted, never something a model judged. **On those three, where the reading is not
unambiguous, confirm rather than write.** Everywhere else — routing to Build, answering a question — the
judgment is unbounded.

### The recommendation is the orchestrator's, never the checker's

**Mandated: exactly one option carries `(Recommended)`, and its description says why.**

Step 1 requires the unmet line to carry the observation and **never the diagnosis**, and the reason it
gives is that *a checker holding one diff and one sentence is the last agent in this workflow qualified to
write it*. **That is a statement about the checker, not about the stage.** One checker holds one Outcome
and one diff. The orchestrator here holds every observation at once, plus `## Outcomes`,
`## Out of scope`, `## Evidence` and the slice files.

> **The checker reports only what it saw. The orchestrator forms the recommendation, from all of them
> plus the spec.** Step 1's rule is untouched, and the judgment lands in the one seat with the context to
> make it.

**The ladder, checked in order.** Neither exception below is the common case, and the common case is
`Rebuild it`.

**Recommend `Rewrite the Outcome` where the shortfall is a defect in the Outcome rather than in the
code:**

- **It names something that does not exist.** *No audit-trail object exists in this org; the Outcome
  assumes a subsystem the design never had.* No diff fixes a premise.
- **It is not checkable as written.** The checker could form no verdict — *"the UI feels responsive" has
  no observable form*. `## Outcomes` is always a translation of the Evidence, and a bad translation
  surfaces here.
- **Two Outcomes contradict.** *O2 requires synchronous completion; O9 requires the batch size that forces
  async.* Building cannot resolve it; a human has to say which is wanted.

**Recommend `Won't fix` only where the cause is outside anything this spec can change:**

- **Environmental.** *The managed package's object is read-only in this org.* Nothing to build, and the
  Outcome is not wrong either.
- **Scope.** *Closing this needs the batch-framework migration, which `## Out of scope` names.* A human
  drew that line at the intent gate; admitting the gap is honest, and quietly relitigating scope is not.

**Everything else is `Rebuild it`**, which will be most of them — not by hope, but because both exception
bands are narrow and factual.

**Say why, every time.** A marked option with an invisible rationale is a nudge. A marked option that says
*the audit-trail object does not exist in this org, so no diff satisfies this as written* is a claim the
human can disagree with, which is the difference between informing and steering.

```
  O3 — Tolerance breaches log to the audit trail with the breaching value
  Fell short: no audit-trail object exists in this org or in this repo.

  ▸ Rewrite the Outcome (Recommended)   O3 assumes a subsystem nothing here has,
                                        so no diff satisfies it as written.
                                        /devpath:initiate rewrites it — both gates
                                        drop, and the slices survive.

  ▸ Rebuild it                          Cuts a slice for O3 anyway. Take this if
                                        the subsystem is meant to exist and the
                                        design missed it.

  ▸ Won't fix                           Ship without O3. I will ask you for the
                                        reason in your own words.
```

```
  O7 — Bulk update over 200 rows completes without error
  Fell short: throws above 200 rows; batching is fixed at 200 and nothing chunks past it.

  ▸ Rebuild it (Recommended)            The design covers batching and the code
                                        stops at one batch. That is work left.
                                        /devpath:build cuts a slice for O7 and
                                        writes down which Outcome it was cut for.

  ▸ Rewrite the Outcome                 O7 was never what we wanted.
                                        /devpath:initiate rewrites it — both gates
                                        drop, and the slices survive.

  ▸ Won't fix                           O7 was right and we ship without it. I will
                                        ask you for the reason in your own words,
                                        and write nothing without one.
```

**The option descriptions are also where the expense lives.** The obvious objection to a clickable rewrite
is that the design's most expensive exit now costs one click. The expense is downstream and unchanged;
what the description does is put it **in front of** the click rather than in a paragraph the engineer
would have had to already know.

**The recommendation prints in the block as well**, as the one line the shape above shows, so the two
paths carry the same information.

**Frequency is a signal about the Outcomes, never about the recommender.** If `Won't fix` starts being
recommended often, the reading is that Outcomes are being written against things this repo cannot change
— an Initiate problem surfacing five stages late. **Do not tune the ladder to make that go away.**

**A gate carries no recommendation, and neither does the slice layout.** This is a disposition, where the
run computed the verdict already and the human is choosing what to do about it. At a gate the default *is*
the judgment being asked for, so `devpath:initiate`, `devpath:technical-design` and `devpath:slice` mark
no option, and `tests/lint.sh` check 7 holds them to it.

### Exit 2's reason is the human's, typed in the seat that can ask for it

> **`- [x] won't fix O<n> — <reason>` on an unmet Outcome is the human's decision, in the human's words.
> The session they say it to writes the line. No agent drafts the reason, and no reason means no write.**

**A click may pick the exit. Only typing may supply the reason.** Selecting `Won't fix` is followed by a
prompt, and then the turn ends. **More than one `Won't fix` is one prompt naming every ID.**

```
  You chose won't fix for O3 and O7. Please give the reason for each, in your
  own words — it rides into the pull request in front of the approver.
```

The next turn writes `- [x] won't fix O<n> — <their words>` onto `## Outcome checks`, one line per ID it
gave a reason for. **An ID with no reason gets no line**, and the run says which are still open — the rule
above read per Outcome rather than per turn. **That is the intent gate's own shape** — a question ends the
turn, and the answer writes the field. Approval plus an agent write is the same act as the human opening
the file, and this plugin already runs on it at the gate that matters most.

**The seat is what makes the ask legal at all.** A worker can reach the orchestrator; only the
orchestrator can reach the human, and every one of these steps runs in the orchestrator seat.
`devpath:build` states the same rule one level down, where the tool is absent from a subagent and fails
synchronously.

> **The run never drafts the reason, least of all when it recommended the exit.** A recommendation is
> exactly the moment drafting starts to feel helpful, and a reason an agent wrote is a waiver signed by
> the applicant.

**Presenting `won't fix` as a named option is not what would make it cheap. Drafting the reason would be**,
and nothing here does.

**Re-running `devpath:integrate` cannot produce the line**, because step 1 rewrites `## Outcome checks`
and would write the same Outcome unmet again. **Step 1's carry-forward rule is the other half of the
mechanism**, and it only makes sense against a line written between the two runs.

**What must not change, because it is the whole deterrent.** The reason is the human's own words, it rides
into the pull-request body at step 4 in front of the approver, and the line accumulates in
`grep -rn "won't fix" devpath/` forever. **No reason, no write** — a blank after the dash is the waiver
machinery this grammar refuses, reached by omission.

**Do not close this with a field.** The three exits are deliberately unstored: a stored exit would put
the ledger's loudest entry behind a flag rather than in front of the reviewer.

### This refusal is a hard exit

**Steps 4 to 8 do not run.** The pull request stays a draft, the feedback offer is not made, Learn does
not run, and nothing is armed. **Say that**, because a builder wiring step 3 as a return and a builder
wiring it as a warning produce two different plugins, and only one of them keeps *Integrate produces a
verdict, never work* true.

### Two nested bounds

A new slice's `fix_cycles` starts at zero while the spec has already been round the loop. **That is not a
bug**, and the reason is worth carrying because the first thing a reader does about it is "fix" it with a
field.

> **The inner loop — Build fixing Critique's findings — is bounded by the cap. The outer loop — Integrate
> refusing, Build cutting a new slice — is bounded by a human typing the command, every single lap.**

Runaway automation has nowhere to live. **No spec-level counter, no aggregation, no new field.**

## 4 · Write the pull request body

So the human reviewer is not re-finding what was already caught. **The decisions ride in full, and the
material they were taken against rides as a count and a path.** A decision is what the reviewer is being
asked to ratify, so it has to be on the page. The material is already committed in the spec directory and
already inside this pull request's own diff, so a path reaches it.

**Mandated, and the body reaches the command on standard input:**

```sh
gh pr edit <number> --body-file -
```

**Standard input rather than an argument**, the same as the two `gh pr create` calls this workflow already
makes. The body is assembled rather than typed and carries a human's own sentences over many lines, so it
is unbounded in length and full of characters a shell would read. Neither survives argv.

**GitHub refuses a body over 65,536 characters, and the number is GitHub's rather than `devpath`'s.** One
measured spec of eight slices held roughly 455 KB under `## Critique findings` and `## Deviations` alone,
seven times the limit. **The purpose above is no better served by 455 KB than by the write being
refused.**

**One shape at every scale: no size test, no threshold, no fallback branch.** A body that reads one way on
a two-slice spec and another way on an eight-slice one is the failure this replaces, and a shape that
appears only above some line is a shape nobody has read before the run that needs it.

### The body, in this order

1. **Intent**, verbatim, as `devpath:initiate` opened this body.
2. **`## Summary`.** A file tree of every changed file outside `devpath/` with git's figures, which says
   where the change is. Then one view of what it does.
3. **`## Merge Danger`.** Every change that reverting the merge does not undo.
4. **`## Outside the Test Boundaries`.** Every finding closed `fixed` carrying `unverified:`. No check in
   this repo proved these, so this is the list a human checks by hand.
5. **`## Accepted Gaps`.** Every `won't fix` and `- [ ] unmet` line in the spec directory, whole. These
   are the decisions the reviewer is asked to ratify.
6. **`## Full Details`**, collapsed. One row per slice counting fix cycles, dispositions, deviations and
   one-way doors, linked to the slice file. It is last because it serves somebody auditing `devpath`
   rather than reading the code.

### The script writes every part a rule decides

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/pr-body.sh"
```

Run it on the spec's branch. It prints the body with three slot lines for the parts a rule cannot write,
and two runs over one branch print the same bytes. **Replace each slot line with its part,
change nothing else, and pipe the result to the command above.** `${CLAUDE_PLUGIN_ROOT}` is required for
the reason step 2 gives.

| Slot | What replaces it |
| --- | --- |
| `{{intent}}` | the `## Intent` section of `spec.md`, verbatim |
| `{{view}}` | the view below |
| `{{merge-danger}}` | the Merge Danger subagent's return, pasted as returned |

**On a non-zero exit, stop and show what it printed to stderr.** It exits 1 when `gh` cannot read this
pull request, and the write would fail on the same `gh`.

### The view

**Pick the smallest view that shows what the change does.** The tree above it already shows where. Six
views: pseudocode, a call tree, a component tree, a file tree, Mermaid, and a shaped diff. A shaped diff of
a component change:

```diff
 <salesforceNavigator>
+  editMode, draft canvas held until Save / Cancel
   <layoutSwitcher>              (always visible)
+  <editAffordance>              (top right)
   <navigatorSection> ×n
+    header controls             only in edit mode
```

### Merge Danger

**Dispatch a fresh subagent and paste what it returns.** Hand it:

- every slice's `## Merge Danger` section
- the diff against the merge-base, outside `devpath/`
- `## Intent` and `## Outcomes` from `spec.md`
- the repo's `.claude/rules/`
- the one-way door definition in `devpath:critique`, under *Rewrite `## Merge Danger` on the slice file*

**The editorial judgment is the subagent's.** It may group the critics' doors, drop one it judges
overcautious, or add one no critic recorded. Each critic read one slice, and a door can open across two.

It returns a tree rooted at the merge, one branch per door, each naming the slice and one clause on what
is lost:

```text
merge → deploy
├─ deletes Navigator_Layout__c.Legacy_Json__c      slice 06
│    stored legacy JSON gone in every org
└─ sends email from LayoutShareService.cls        slice 07
     a sent email can't be recalled
```

A door no critic recorded names its path where the slice would go. **With no door, the section is the one
sentence `No one-way door found on this spec.`** It never rates a change as two-way or as small in reach.

## 5 · Offer to file `## devpath feedback`

The engineer writes `## devpath feedback` on `spec.md` at the moment of friction — optional, ungated,
absence normal. Read it, show a draft issue, and **on confirmation** run:

```sh
gh issue create --repo Jonah-Stephans/devpath
```

**Using the engineer's own credentials.** No credential is stored anywhere.

**If the section is empty, name the heading in one sentence and file nothing.** That single sentence is
the only prompt this channel has, and it is the whole of it — **no draft, no suggested content, no second
ask**, because an agent proposing the engineer's own feedback turns a mirror into a critic.

> **Say why this is not the tracker returning.** The settled constraint is about the **context store**:
> nothing in the machinery reads or writes a tracker, and no gate is blocked on one. This channel is
> **write-only, off-workflow, human-initiated and human-confirmed.**

## 6 · Name the signal back

**Only when what is written down actually shows something.** Report the observation, never the diagnosis.

> *"Build re-cut 3 of 4 slices on this spec — that's a signal about the cutting rule. File it?"*

**Four bounds, and the fourth is the one that matters:**

1. **Fires only here**, once per spec. Never mid-run.
2. **Fires only when the written trace shows something.** No deviation, no fix cycles, no re-cut ⇒ **say
   nothing.** That is most specs, and silence in the common case is what stops this becoming noise the
   engineer learns to dismiss.
3. **Draft it; the human confirms and sends**, with their own `gh`. Never file unilaterally.
4. **Report the observation, never the diagnosis.** *"Build re-cut 3 of 4 slices"* is data; *"the cutting
   rule is wrong"* is a conclusion only the maintainer draws. **An agent editorialising about the design
   off a single spec is the actual failure mode**, and restricting this to naming what the fields already
   say makes it a mirror rather than a critic.

**Zero new fields; every input already exists.** What is readable here is a re-cut written under
`## Deviations`, a slice that hit the cap in `fix_cycles`, and an accepted intent on a spec that died —
`intent_accepted: true` plus a closed-unmerged pull request. A recorded assumption that turned out wrong
is **not detectable here**: what is written down holds the assumption, and whether it was wrong is
learned weeks later.

**Steps 5 and 6 both file on the same repo, so when both fire it is one issue, not two.** **Keep the two
contributions separate inside the body** — the engineer's words as they wrote them, this step's
observation as data — because merging the voices breaks bound 4.

## 7 · Learn

**Run the skill `devpath:learn` against this spec, before step 8 arms the merge.**

> **This is model-driven and is not guaranteed.** There is no call syntax and no event that fires on a
> skill finishing. Claude reads this instruction and normally follows it, and nothing in the harness makes
> it certain. **Do not write *cannot be forgotten*** — that is a guarantee this design does not have. A
> repo that wants it guaranteed adds a `Stop` hook of its own; `devpath` ships none and depends on none.

**It runs before the arming, and the order is deliberate.** Arming auto-merge is irreversible: on a pull
request already carrying its approval, a required check that finishes fast can merge it while a later
step is still running. **Nothing is lost by running Learn first** — its two available inputs are
`devpath`'s own files, `## Critique findings` with the archive Critique moved its closed boxes to,
and `## Deviations`, and both are complete before this command started. Learn reads nothing the ready
transition produces.

## 8 · Mark ready, then arm auto-merge

**Mandated. Two commands, and one this skill must never use.**

```sh
gh pr ready <number>
```

Then arm auto-merge. GraphQL identifies a pull request by node id rather than by number, so resolve the
id first:

```sh
pr_id=$(gh pr view <number> --json id -q .id)

gh api graphql -f query='
  mutation($pr: ID!) {
    enablePullRequestAutoMerge(input: {pullRequestId: $pr}) {
      pullRequest { number autoMergeRequest { enabledAt } }
    }
  }' -F pr="$pr_id"
```

**Read `autoMergeRequest.enabledAt` back and report it.** A non-null value is the only evidence the
setting took, and a silently ineffective arming is indistinguishable from a working one until a spec
merges without CI.

> **`devpath` never runs `gh pr merge --auto`, anywhere, for any purpose.**

**Why, and it is the sharpest rule in this body.** `gh pr merge --auto` calls the auto-merge mutation only
when the pull request is *not already immediately mergeable* — so on a `CLEAN`, `HAS_HOOKS` or `UNSTABLE`
pull request **it performs a real merge.** On a repo whose base branch is unprotected, the pull request is
`CLEAN` the moment it leaves draft, and **step 8 is the first moment CI runs on this pull request at
all** — so `--auto` merges it immediately with no review and no CI. **The one deploy in a spec's life that
can fail on a dangling reference is skipped by the command meant to schedule it**, and a repo missing
branch protection would get a worse outcome from `devpath` than from doing nothing.

**The mutation cannot merge.** It sets a setting; the merge happens later, when GitHub's own conditions
are met, or never. **Do not use a command that might do the thing to arrange for the thing.**

**`devpath` passes no merge method and takes the repo's default.** The plugin holds no opinion about a
repo's history, the same posture as holding no org name. One consequence, so Build is not misread:
whether one code commit per slice survives to the base branch depends on that default, and Build's
per-slice argument is about attribution **on the branch and in the pull request**, never a requirement on
the base branch.

**Confirm both commands on first use rather than assume them.** They are documented GitHub behaviour that
this plugin has not yet exercised, and the confirmation costs one pull request on a scratch repo.

## What step 8 releases, and what Integrate does not own

**Marking the pull request ready is what releases the whole-spec deploy against a fresh org** — one fresh
org, the whole spec as one payload, an explicit test level. That is the **second** of the two orgs a spec
costs; the first is the engineer's own scratch org that Build deployed each slice into. This one is
different in the two ways that matter: it is the whole spec as one payload, and the org holds none of it
already, so references resolve against org state ∪ payload rather than against an org carrying an earlier
deploy of the same spec.

**`devpath` does not run it.** It is the repo's own deploy gate, and CI not running on draft pull
requests is what puts it here rather than earlier. What `devpath` contributes is the timing and the
precondition — never the workflow.

**Nobody owns integration order.** Arrival order: mark ready, arm auto-merge, a reviewer approves, GitHub
merges. **This body contains no ordering, no *Update branch* step and no merge-queue assumption.** Two
specs ready at once both merge, in whatever order they finished — and two specs each green alone can break
the base branch together with no textual conflict, which the repo's own post-merge workflow catches and
somebody fixes forward.

## Stop

**Integrate done ⇔ step 8 has run, step 1 or step 3 refused, or `## Refuse first` stopped the run
before step 1.**

Report what was written, what was filed, and that auto-merge is armed. **Human actions per spec from here:
one approval, which branch protection already required.** Nobody clicks Merge.
