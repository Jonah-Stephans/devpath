---
description: Run the design conversation on an accepted devpath spec. Use once a spec's intent is accepted and before any code exists.
---

# Design

`devpath:technical-design` runs three stages in one session: Survey if it is needed, then the design
conversation, then Slice. It ends at the design gate.

> **Stage names are prose-facing, skill names are invocation-facing, and only the latter has to be
> unique.**

The stage is **Design**. The invocation is **`devpath:technical-design`**. That is not a mistake:
*design* in this ecosystem means visual design, so the bare skill name was retired while the stage name,
the `## Design` heading and the `design_approved` field all stand. `devpath:fit-check` is the existing
precedent for a hyphenated skill name with no stage behind it.

**This skill is a thin composer.** Survey's logic lives in `skills/survey/SKILL.md` and the cutting rules
live in `skills/slice/SKILL.md`; this body calls both rather than restating either. Inlining them would
put two copies of each in the tree and one of the two would rot.

## Refuse first

Read the front matter of `devpath/<slug>/spec.md`. That read is the validation.

- **`git branch --show-current` returns `main`, `<base>`, or a branch with no matching spec directory**
  → **stop.** Do not guess which spec this is. Say the next act: `git checkout <slug>`, or run
  `devpath:initiate` if the spec does not exist yet.
- **The command returns empty** → **stop, and say what is actually wrong:** it returns empty with exit
  code 0 under a detached HEAD, so the truth is *you are not on a branch*, never *no spec on this
  branch*. The fix is one `git checkout -b <slug>`, and it is a human's.
- **`intent_accepted` is not `true`** → **stop.** This stage runs behind gate 1. Say the next act: run
  `devpath:initiate` and take the spec through the intent gate.
- **The front-matter block does not parse, or a field carries the wrong shape** → **stop and name the
  exact field.** *Malformed* stops the stage; *absent* is a legal state meaning *not yet*.

**Prefix every message this skill prints when it stops with `devpath: `.** Suggested.

### Re-entry on an approved design withdraws the gate, and says so

**Mandated.** Re-entered on a spec that already carries `design_approved: true`, this skill
**announces that the design gate is returning to unapproved** and carries on. Say it in substance: *this
moves the design back to unapproved — you will approve the new version when we are done.*

**Withdrawal is a deletion of the field, never a `false`.** Delete `design_approved` and nothing else.

| Deleted | Survives untouched |
| --- | --- |
| `design_approved` only | everything else, including `intent_accepted`, the slice files, `## Critique findings`, the archive of the closed ones, `## Deviations` and `## Traps` |

**The slices survive on purpose.** They are work, `design_approved` is absent so nothing acts on them, and
this skill re-slices when the design settles. Deleting them would be throwing away an artifact the human
never asked to have thrown away. **The draft pull request survives, always.**

Why the deletion happens at all: *value is always `true`, absence is how you say no*, and stages overwrite
superseded sections. Without the withdrawal, a second run rewrites `## Design` under an approval a human
gave to a **different** design, and `devpath:build` proceeds on it. The design gate has no downstream
cover — the next human is at merge, after the code is written.

**One accepted cost, stated now rather than discovered later: a no-op design conversation costs one
re-approval.** Open this skill to rework something, talk, and conclude the original was right — the
approval is already gone, so you re-approve a design you had approved. That is deliberate, because the
alternative is the agent judging whether the design changed *enough* to matter, which is a model judging
materiality against a schema whose whole property is that nothing is.

**The hole that stays:** a hand-edited `## Design` still bypasses this.

## Read

**Read the spec *directory* on start, not only `spec.md`.** The directory can hold a sketch and its
decision note that a resumed session needs.

## 1 · Survey

**If `## Current state` is empty, run the skill `devpath:survey` against this spec.** It clusters the
Outcomes into areas, fans out one subagent per area to a ceiling of five, discards them, and writes
`## Current state`.

> **This is model-driven and is not guaranteed.** There is no call syntax and no event that fires on a
> skill finishing. Claude reads this instruction and normally follows it, and nothing in the harness makes
> it certain. A repo that wants certainty adds a hook of its own; `devpath` ships none and depends on
> none.

**What the softness costs, stated rather than left to be discovered:** a run that skips this call produces
a design written without `## Current state`, which is visible in the artifact — *Survey done ⇔ non-empty*
is the on-disk test.

**The `Skill` tool loads the named skill's instructions into *this* session. It does not spawn a
subagent**, and that is the whole reason this composition is legal. **Survey ends holding conclusions, so
Design can run in the same session** — the design conversation wants the findings live, and a subagent
would end holding them somewhere this conversation cannot reach.

**The only subagents anywhere in this command are Survey's researchers** — clustered by area and capped at
five for the whole stage, which Survey itself mandates. Nothing else here fans out.

## 2 · The design conversation

**This is the only conversation in `devpath`.** These instructions are inlined here on purpose: a file
the skill is *told* to read is a link that can be dropped, and inlined they have the same immunity the
front-matter read has — the skill body is what the stage runs, so there is nothing to disconnect. Do not
call a third-party conversation skill; a general skill of that kind ends when the questions run out, and
this conversation must end in an approval and a written artifact.

**Mandated, all of it:**

- **Build a tree of decisions**; decisions branch into the decisions hanging off them.
- **Ask, in one round, every question whose prerequisites are already settled. Number them.**
- **Every question carries the agent's recommended answer.** Then wait.
- **A question that depends on another open question belongs to a later round.**
- **Finding facts is the agent's job, never the human's** — and do not block on it.
- **The decisions are the human's.**
- **Done when no question with settled prerequisites remains.**
- **The tree is rooted at the problem; the design questions are its children.** That is what stops a
  solution-shaped session from answering problem questions in solution terms — the problem questions
  *are* round 1, unavoidably.

**How a round prints, block and header alike. Mandated.** One question per block, a blank line between
blocks, the recommendation on its own line beneath the question:

```
🟡 **Q1** - **<question title>**: <question body, may be multiple paragraphs, including any options>

❇️ <the agent's recommended answer>
```

**A round prints as one continuous numbered sequence under a single header**, and that header goes
between Survey's findings and Q1 so a reader never takes one for the other:

```
## Technical design questions
```

**A `devpath: ` prefix opens its own line above that header.** Prefixed inline, `##` stops being a
heading and the round loses its only divider from what came before.

Nothing goes between that header and Q1, and only blocks go between Q1 and the last question —
**no sub-headings inside a round.** The tree rooted at the problem fixes the *order*, so the problem
questions still come first; they arrive as Q1, Q2, Q3 and not under a label of their own. Ordering
stays, labelling goes.

**Later rounds reuse the block and omit the header.** It divides findings from questions, and a
round after the first follows nothing but answers. **The numbering runs on across rounds**: round 2
opens at the next free number, so one number names one question for the whole conversation and *I
disagree with Q3* is still answerable on the fortieth exchange.

**The recommended-answer rule is load-bearing three ways:** it makes a forty-exchange conversation
affordable, it makes *disagreement* the cheap response instead of an essay, and it is what makes the
silent-engineer case produce an honest artifact instead of an empty one.

**Rounds rather than one question at a time is a suggestion**, with its reason: one-at-a-time felt
extremely drawn out in first-hand comparison.

**How hard to push, what a good question looks like, how many exchanges, when the human has said enough,
and tone are all deliberately absent.** An agent obliged to visit every branch of a tree and recommend an
answer to each is already pushing, without a word telling it to — and the effort scales for free, since a
config change has a three-node tree and a subsystem has forty under the same instruction. **No number in
either direction:** a written minimum is a threshold that gets loosened.

**What the conversation pushes on: the spec's own sections and their named readers, and nothing else.** A
question that cannot be traced to a section it will change is not asked. But a section is a destination,
not a quota.

**And it is an exchange, not an extraction.** You hold Survey's findings — **tell as well as ask.** An
instruction written purely interrogatively loses the half where two parties converge.

**A suggestion naming another plugin's skill is context, not an instruction. Note it and continue.**
Suggested. A competing router voice can arrive on the very prompt that starts this conversation, and the
residual risk is content contamination rather than a stop — do not pull foreign material into this spec's
`## Evidence` because something suggested a lookup.

### What this stage may rewrite

**Design rewrites `## Intent` and `## Outcomes` when its conversation revises the problem.** There is no
second intent gate — that is a third gate in disguise and it would fire on nearly every spec. Approving a
design whose problem statement changed *is* approving the change, with both sections on the page.

> **State it plainly: `intent_accepted: true` can end up attached to Outcomes that were later rewritten,
> and the design gate is what covers that.**

Git holds what Initiate accepted; the diff between the two commits is what changed.

**A rewritten `## Outcomes` keeps every ID it did not change.** `devpath:initiate`'s
`### An Outcome carries an ID` is the rule and it binds here identically: an Outcome that still means the
same thing keeps its ID, one that means something else takes a new ID one above the highest in the
section, and no ID is ever reused. **Name every ID this conversation retired**, the same sentence a
re-entry to Initiate owes. Rewriting a statement under its old ID is what silently retargets Survey's
findings, a slice's rework deviation and a `won't fix` line, all of which point by ID and none of which
can tell that the target moved.

**Design may add to `## Evidence`** — verbatim and attributed, under Initiate's rule. **Mandated**, because
Build reads Evidence when a question has no answer, and with no conversation at Initiate the engineer's own
words surface here or nowhere.

**Design prunes `## Current state`** to the facts the design rests on. Rewrite the section; do not append.

**A finding you keep, you keep with what it was read off** — the file Survey named and what it quoted
or grepped there, carried through the rewrite. Cut the finding as hard as the design needs; that half
is not the part to cut. **A finding that arrived without it is not disqualified** — it is the one to
go and read the file for yourself before the design rests on it.

**Hold each kept finding against the file it names before you keep it.** The pruned section is what
`## Design` then rests on, and from there the claim travels as a premise: Slice and Build never open
`## Current state`, and the next reader of it is a critic looking at code already built on it. A note
naming the wrong element costs one file read at the prune and a slice's fix cycles after it.

**A struck note stays struck.** Where the design still rests on a finding Critique struck and corrected,
carry both halves through the rewrite as they stand — **never the corrected half alone.** The visible
error is what explains code already on the branch, and this section is rewritten whole by every re-entry,
so the rewrite is the one place that erasure can happen.

### A re-entry starts from the design already on the page

**Mandated. Read the existing `## Design` before the conversation opens, and open the conversation on what
the rework changed.** Default to carrying every decision the rework did not touch forward as written. The
gate is already withdrawn, the human approves again, and the section is still rewritten whole. There is no
mode that edits one decision in place.

**Without this the anchoring one stage earlier buys nothing.** `devpath:initiate` opens its re-entry on the
shortfalls and hands the result to a stage that may rewrite `## Intent` and `## Outcomes` again, so a
design conversation starting from a blank page puts the drift straight back.

**This is a live run written down rather than a behaviour invented for the page.** On
`navigator-test-system-mode`, 2026-08-27, a re-entered Design replaced `## Current state` and nothing else,
re-scanned rather than trusting the inventory that had just failed, and reported the Outcomes as deltas
against the ones already written. It was already possible. Writing it down is what makes it hold across
sessions.

**The accepted cost is `devpath:initiate`'s and it is unchanged here: this bounds drift by conversation,
not by mechanism.**

### The spec boundary, when one spec turns out to be two

**Design narrows `## Intent` and `## Out of scope` to one design.** That is the whole of the answer:
**there is no *split* operation and no new noun.** It is an ordinary edit on the spec branch, and somebody
runs `devpath:initiate` again for the remainder — new slug, new branch, new draft pull request, **its own
intent gate.** Because the remainder is a fresh Initiate, no spec ever inherits a copied gate field.

**The second Initiate carries the same `upstream` entry when there is one.** Mandated. Both specs came
from the same requirement; the narrowing changed the spec boundary, not what was asked for. **Say that
when you narrow**, so whoever runs the second Initiate knows to carry it.

### Name the test entry point

**Mandated, and it is the weakest mandate in this plugin — say so.**

> **Name the entry point the tests will drive for the behaviour this spec delivers, and confirm it.**
> Prefer one that already exists. Prefer one that survives a refactor of what sits behind it. Prefer one
> over several for the same path. If the design needs a new entry point, say so and say why.

**Why it earns a mandate.** A test pointed at a method has an obvious thing to assert. A test pointed at a
trigger cannot be called at all — you insert a row, re-query, and hope you are looking at the right field,
so frequently nobody asserts anything. One repo in this design's evidence base accumulated **161,386 lines
of test code across 560 classes that cannot report a failure**, with 46% of test classes containing no
assertion. **Naming the entry point does not make anyone write assertions; it stops handing them a place
where writing one is a chore.**

**And the enforcement is stated rather than implied: nothing checks this.** CI cannot — a trigger-driven
test deploys, runs, passes and satisfies coverage. Critique catches the *symptom* through the repo's
standards rule; it never reads the entry point `## Design` named.

**Scope: name the entry point. Do not name the tests.**

### The altitude stop

**Suggested, and its teeth are the gate.**

> Before writing the design, ask whether any decision here binds a spec that does not exist yet. If so,
> **name it and stop.** Two exits, and the human picks: decide it here, or take it up a level and write
> the question down.

No new gate, no new field, no new artifact. The existing design gate carries it, because the design and
the escalation are on the same page the human is already reading. When the human decides it here, the
decision lands explicit and reasoned in the spec and is promoted nowhere.

**Stated limit: a Design that does not notice is not caught.**

### The UX branch

**Suggested.** Some designs touch a surface a user sees, and shared understanding of a surface is hard
without something physical.

> **The trigger: would two competent engineers picture the same screen?** If yes, nothing physical is
> needed. If no, something physical earns the detour.

**This cannot create overhead, and the reason is mechanical rather than hopeful: the branch can only hang
off a question the conversation already has.** *Add a field to a grid* — two engineers picture the same
grid with one more column, no disagreement exists, no question exists, and the conversation never reaches
the branch. *Take a payment from a sales order header* — modal or subtab, one step or three, method before
amount or after — that divergence **is** a question, unavoidably, because the design cannot be written
without resolving it.

**A new surface has no anchor, so recommend the artifact.** Both worked examples above anchor to a screen
that already exists, and the anchor is what makes *yes, two competent engineers picture the same screen*
checkable at all; asserted about a screen nobody has seen, it costs nothing to say and is rarely true.
**This moves what the branch recommends, never how often the branch is reached, so the overhead argument
above stands whole.**

**Stated limit: a Design that raises no question about the screen never reaches the branch, and so never
consults this default.**

**Nothing about this can block the gate.** If the engineer says *I know what I want, here it is*, write
the answer down and proceed to approval. **Suggest the route; never require the artifact.**

**Match the artifact to the question.** This is the whole of what `devpath` says about craft:

| The question | What answers it |
| --- | --- |
| *Is this like something we already have?* | a screenshot of the closest existing screen |
| *What should this do* — steps, affordances, error states | a cheap sketch; HTML is fine, nobody is judging pixels |
| *What should this look like* — density, fidelity, native feel | **only the real runtime** |

**One negative finding: prefer the real runtime over a facsimile of it; the more distinctive the target
platform's chrome, the less a facsimile is worth.** Its failure mode is worse than nothing — feedback
lands on the facsimile's inaccuracies instead of on the design.

`devpath:sketch` owns the plumbing when something physical is wanted; it is pointed at this slug and runs
in a parallel session.

### When it stops

**The agent never decides the conversation is over. It decides when it has earned the right to ask.**

**Suggested test** — nothing observes whether it was honestly applied:

> Could a fresh session, with no memory of this conversation, pick up the next stage from this file alone?

**Write once, at the end, not per exchange.** Writing per exchange burns tokens re-deriving a document
nobody has agreed to, and it invites the human to review prose instead of answering the question. **One
flush condition:** write before anything that could lose the thread.

## 3 · The design gate

**The order is mandated and it decides whether the artifact is coherent:**

1. The conversation ends; `## Design` and the revised sections are written **once**.
2. **Commit, and push.** The human is about to approve a design, and a pushed diff on the draft pull
   request is what they approve against — readable and inline-commentable, at zero approval cost.
3. **The human approves the design.**
4. **`design_approved: true` is written, and committed.** Value is always `true`; absence is how you say
   no; nothing ever writes `false`. **The commit is this step's** — `devpath:slice` commits the slice
   files rather than `spec.md`, and `devpath:build` refuses on a dirty tree, so a field left on disk here
   stops Build two acts later. **It holds that one field and no prose**, so *the Design commit* that
   `devpath:survey`'s write is read against is still step 2's.
5. **Run the skill `devpath:slice` against this spec** — which now finds the field, so its refusal is
   satisfied by the route rather than excepted from it.
6. The layout is shown and put to the human by `devpath:slice`'s own `## Stop`. The human may reject it,
   and it is re-cut in this session.

> **This is model-driven and is not guaranteed.** Same softness as the Survey call above, for the same
> reason. A run that skips this call reaches the design gate with zero slice files, which
> `devpath:build` refuses on — visible in the spec directory rather than silent.

**Slice runs in this session and is never a subagent**, which is what leaves it able to be
conversational when the layout comes back for a re-cut.

**Two divergences, and there is no third outcome.**

- **Human satisfied, artifact thin** → the spec is still written, but **`design_approved` is not, and the
  empty heading is named.** Not a judgment — *this heading has nothing under it*. **Mandated: never
  `design_approved: true` with an empty `## Design` or zero slice files.** Read that as a postcondition on
  this command rather than an instant-by-instant invariant: the field is written at step 4 and Slice runs
  at step 5.
- **Artifact complete, human not ready** → nothing is written, the run ends, the file stays on disk. The
  next run reads the front matter, sees the gate field absent, and **resumes the conversation.**

**Every conversation ends in *approved* or *not yet, come back*.** No waiver, no override, no *approve
anyway*. A run ending unapproved is the design working.

**How the yes is captured: the material in full, and then the ask.** `## Design` and the revised sections
print whole, and the go/no-go follows them. **Where the harness offers a tool that puts a question with
named options, use it. Where it does not, ask in one sentence and end the turn.** Both paths write the
same field off the same reading, and **nothing downstream can tell which one ran** — no field, no marker,
no detection step. Same posture as the tier rule in the `devpath:survey` call above.

> **The tool presents the decision. It never presents the material.** A click is legal downstream of a
> read and never instead of one.

```
  Design gate · tolerance-config
  [## Design and the revised sections are printed above, in full]

  Read the design against the problem. Is this what to build?

  ▸ Approve the design   Writes design_approved: true. devpath:slice then cuts
                         the layout and shows it to you before anything commits.

  ▸ Not yet              Writes nothing. Say what is wrong and the conversation
                         continues.
```

> **Mandated: a gate prompt marks no option as recommended and names no default.** At a gate the default
> *is* the judgment being asked for, so marking one is the plugin answering its own gate.
> `tests/lint.sh` check 7 holds it against this file's own illustrations.

**The cheap response this gate wants is disagreement in the engineer's own words**, so the free-text
answer stays legal and the run reads it for intent. A yes writes `design_approved: true`; anything else
writes nothing, and **where the reading is not unambiguous, confirm rather than write.**

**What the human is actually being asked to do, and it is worth saying to them:**

> **The only verifier of slice completeness is a person, at the design gate, before code exists.**

A pull-request reviewer reading a diff afterwards was never doing that job — no diff in any language says
whether a change was *wanted*. Verticality has no mechanical gate in this design, so this reading is it.

## Clearing a pause

**An untagged pause box under a slice's `## Deviations` is cleared by the `devpath:technical-design`
session that resolves it, before that session ends.** Build writes the box and stops; this is where it
gets closed. Resolve the question, tick the box in the disposition grammar, and say which slice it
unblocks — leaving it open means `devpath:build` will refuse the slice again on the next run.

**Commit the tick before this session ends.** The next act is `devpath:build` on the slice this just
unblocked, and `devpath:build` refuses on a dirty tree — so a disposition left on disk stops the run it
was written to release. Every stage that writes commits before it hands on, and this is that stage
handing on.

**The pause you clear is the untagged box, and the tagged ones are not yours.** `devpath:build`'s
`## Deviations, and the pause test` lists all four and who closes each.

**Ticking a `blocked` box here clears nothing.** Nothing said in this session moves another repo's hook, so
the next `devpath:build` walks into the same refusal and pauses again, and nothing bounds how many times.
**And a `devpath:build` worker closing that box is not a stage closing its own pause** — it closes on a
change a human made outside the run, and it stops the run again where nothing moved.

**The slice you are clearing can carry more than one box**, because the pause commit staged whatever was on
disk: close the untagged one, and **leave a tagged box alone.**

**`devpath:build`'s untagged pause box is deliberately not one of the stops that asks through a question
tool, and it stays prose.** The intent gate, the design gate, the slice layout and Integrate's refusal each end a
turn on a fixed set of exits, which is what an option list is for. **A pause has no fixed set** — Build
writes the question it got stuck on, and what it wants back is the answer in the engineer's own words. A
builder reading *four stops* must not wire a fifth here. **`- [ ] verify` is the box that does have a fixed
set**, three answers to *did it work*, and `devpath:build` asks it in its own seat.

**A tagged box left open still reads as *frozen*, so name the slice as the next one to build.** The frozen
test joins the absence of `done: true` to an open box under `## Deviations` and never reads the tag, so the
slice you just unblocked keeps answering *frozen* until `devpath:build` finishes it. Building it is never
denied. Building a sibling ahead of it is.

## Stop

**Design done ⇔ the design gate has been answered and, on `true`, the slice files exist and are
pushed — or `## Refuse first` stopped the run and named the condition.**

**Push once the layout settles**, so the human sees the design and the slice layout together on the draft
pull request.

**Rejecting the layout does not withdraw the design approval.** One verdict sending the whole thing back
was rejected, and the design is not what was rejected — re-cut here, in this session, with everything
still in context.

Then stop. The next act is `devpath:build`.
