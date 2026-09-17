---
description: Cut an approved devpath design into slice files. Use to run the slice stage on its own, to re-cut a layout that was rejected, or to cut only what a reworked design adds on a spec whose slices are already built.
---

# Slice

Slice cuts an approved design into N ≥ 1 slice files under `devpath/<slug>/slices/`. It runs inside
`devpath:technical-design`, in the same session that just wrote the design, and it runs alone against an
approved design.

**Slice is never a subagent.** It would have to be handed the spec file, which recreates the problem that
reading the repo while cutting exists to solve — and it must be able to be conversational, which a
subagent cannot be. A `Skill` call loads these instructions into the calling session, which is exactly
what leaves Slice in the session that can talk.

## Refuse first

Read the front matter of `devpath/<slug>/spec.md`. That read is the validation; there is no separate
front-matter check anywhere in `devpath`.

- **`git branch --show-current` returns `main`, `<base>`, or a branch with no matching spec directory**
  → **stop.** Do not guess which spec this is. Say the next act: `git checkout <slug>`, or run
  `devpath:initiate` if the spec does not exist yet.
- **The command returns empty** → **stop, and say what is actually wrong:** it returns empty with exit
  code 0 under a detached HEAD, so the truth is *you are not on a branch*, never *no spec on this
  branch*. The fix is one `git checkout -b <slug>`, and it is a human's.
- **`design_approved` is not `true`** → **stop and say so.** Do not slice. Say the next act: run
  `devpath:technical-design` and take the design through its gate.
- **`## Design` is empty** → **stop.** There is nothing to cut.
- **The front-matter block does not parse, or a field carries the wrong shape** → **stop and name the
  exact field.** *Malformed* stops the stage; *absent* is a legal state meaning *not yet*.

**Prefix every message this skill prints when it stops with `devpath: `.** Suggested.

**Reaching this skill from `devpath:technical-design` satisfies the gate by route rather than by
exception.** The command writes `design_approved: true` when the human approves, and only then calls
Slice — so the field is there and this refusal never fires. It fires on the route that needs it: a human
typing `/devpath:slice` on a spec whose design was never approved.

## Read

`## Design`, `## Outcomes`, `## Out of scope`. Then read the repo while deciding how to cut.

**Reading the code while cutting is the point, not diligence.** It is what surfaces work that reshapes
the code so the change becomes easy — a slicing insight, not a design one, and a Slice that read only the
spec cannot have it.

## How to cut

Three rules, three different jobs.

| Rule | Governs |
| --- | --- |
| Split **only** where a reviewer could meaningfully reject one slice while approving its neighbour | **How many** — a floor. Do not split finer than reviewability |
| Cut **a narrow but complete route through every layer the change requires, verifiable on its own; never a horizontal slice of one layer** | **Which direction** |
| Sized so **the real (`-w`) diff fits one fresh context**, and edits into oversized shared files are surgical and generated | **Artifact count** |

**All three are adopted, they can disagree, and the disagreement resolves rather than being a defect.**
Splitting for reviewability yields independent slices. Splitting for size yields **dependent** slices —
unless the pieces share no references at all, as in a version bump cut by metadata type, in which case
they are independent. **`depends_on` is exactly what records the difference.**

**The third rule measures the *real* diff.** In an SFDX repo the file set is decoupled from the work by
three to five orders of magnitude — 325 real lines can sit inside 26.4 MB of files — so *sized to one
context* must never be read as *the file set fits one context*.

### The direction rule is a cutting instruction, never a self-test

**Use the direction rule above to decide how to cut. Do not turn it around and apply it as a test to the
layout you just produced.**

As a test it is self-referential: nothing fixes what *the change* is, so *the layers the change requires*
are whatever the slice ended up touching, and completeness is satisfied by construction. The chain that
actually holds is different — **you cut and write the behaviour line, the human sees the layout and can
change it, the gate stores the approval, and nothing else checks.** What the behaviour line buys is not
self-grading: it is **a claim a different party can check.** You can require that a behaviour sentence
exists; you can never require that it is complete.

**A change complete in one layer is vertical.** A recurring permission-set-only change is in bounds — it
is not a *piece* of anything. That case is exactly where the second clause misfires if it is read as a
test.

### The worked pair

- **In bounds:** *users in the Warehouse role can see Lot Number on the item record.*
- **Out of bounds:** *adds a method to `ToleranceService`.*

**Honest weakness, stated: a fluent behaviour line can dress a bad slice.** *"Tolerance checking is
available to the invoice matcher"* reads like behaviour and names no user. The template narrows the lie;
only the person at the gate kills it.

### Slice partitions; it never invents

The decision *to* reshape the code first belongs to Design. A slice that does the reshaping is a
legitimate slice and sorts first in dependency order.

**If the design cannot be sliced as written, refuse and say why**, sending the work back to Design. That
is cheap and fixable on the spot — say which part of `## Design` cannot be cut and what would make it
cuttable.

### Wide refactors

For one mechanical change whose blast radius fans across the codebase, use expand–migrate–contract.
**Expand** — add the new form beside the old; nothing breaks. **Migrate** — move references in batches
sized by blast radius, each batch its own slice, each safe because the old form still exists.
**Contract** — delete the old form last, blocked by every batch. `type: refactor` is where it lands.

**A mass rename is one slice, not many dependent ones** — the N = 1 case.

A once-per-repo format conversion is repo work rather than a spec: it fits no context at any cut.

## Write

**One file per slice at `devpath/<slug>/slices/<nn>-<name>.md`, zero-padded.** Zero-padding is not
decoration — `ls` sorts `10-` before `2-`. **The number is authoring order, never execution order;**
`depends_on` owns execution order, and a reader who takes the number as an ordering claim has two sources
of truth for one fact.

```markdown
---
depends_on:
touches:
---

# <Title>

> Watch a new test go red before you make it green.
> *Why: a test written before the code cannot be written to hit a coverage number — there is nothing to
> cover yet. Retires when Apex gets mutation testing.*

## What to build
## Acceptance criteria
## Deviations
## Critique findings
```

**Write the test-first block into every slice file.** It sits between the title line and the first `## `
heading, so it adds no `## ` heading and leaves a schema check that flags headings outside the schema
unaffected. It is one copy per slice file — a five-slice spec carries it five times — which is the cost of
a template that is generated rather than referenced. It is **Build's suggestion living in Slice's
output**: Slice writes it, and `devpath:build` names it as the thing the slice file carries.

**`wrote`, `done` and `fix_cycles` are absent at creation.** Mandated. `wrote` is every `devpath:build`
worker's, filled off git before that worker returns and read by the commit audit; `done: true` is Build's,
written when the acceptance criteria are ticked; `fix_cycles` is Critique's, written on its first pass over
the slice. A slice created carrying `fix_cycles: 1` would spend a lap of the fix cycles cap before anything
was fixed.

### `## What to build`

**The end-to-end behaviour this slice makes work, from the user's perspective — not a layer-by-layer
list.** One sentence. This is the load-bearing artifact of the whole file.

### `## Acceptance criteria`

**Mandated. One `- [ ]` per criterion, drawn from `## Design` and from the Outcomes this slice serves.**
Not from the code, which does not exist yet. **The floor is one criterion**, and one is legal, exactly as
a set of one slice is.

**A criterion is a claim a different party can check.** Same test as the behaviour line, one altitude
down. `- [ ] A Warehouse-role user sees Lot Number on the item's detail page` is one;
`- [ ] the service method is implemented` is not.

**They are not a second behaviour statement.** `## What to build` is the one sentence saying what the
slice makes work; the criteria are the checkable consequences of that sentence. Where the two would read
identically, write the criterion and let the overlap stand.

**Slice writes them and Build ticks them — never the other way round.** The session that just designed
the thing is the one that knows what *done* would look like, and the criteria are part of the layout the
human sees at the design gate. **Build writing its own acceptance criteria is Build grading itself**,
which is the failure the direction rule above already names.

This is not a second exception to *nothing writes a placeholder*: Slice always has something to put here,
because a slice with no checkable consequence is a slice with no behaviour statement either — and that is
the cut being wrong rather than the heading being empty.

### `depends_on` and `touches`

**`depends_on` holds full paths to other slice files**, of the form
`devpath/<slug>/slices/<nn>-<name>.md`. Not ordinals, not slugs, and no flat form. It means *this slice
cannot start until that slice is done*, which is a statement about slices. Slice writes every slice file
it cuts in one pass, and on a re-cut the slices it cuts around are already on disk, so every cited path
resolves and the check validates the whole graph with no new machinery.

**`touches` holds paths to pre-existing files the slice will modify.** Two readers: the cited-paths check
and the contention checkpoint.

> **`touches` is what this slice will collide with, not where to work.**

That clause is load-bearing and it is prose, which is the honest weakness: telling an agent the change
goes in a named file makes it edit that file even when the right change is elsewhere. Build is explicitly
not instructed to touch those paths and not limited to them.

**There is no `creates:` field.** `touches` is safe on every count — the files exist so the check really
works, and it describes code that already exists, so it does not decide Build's file layout. `creates:`
would name files that do not exist yet, so **it reads as checked while nothing checks it**, and it decides
Build's business. Every shared-file collision worth catching is a collision on a pre-existing file, and
the edge case resolves without it: if slice 2 modifies a file slice 1 *creates*, slice 2 already
`depends_on` slice 1.

**`wrote` is not that field under another name.** It is filled *after* the work, off
`git status --porcelain`, about files that are on disk — so it predicts nothing and decides no layout.
**One is a prediction and the other is a reading**, and `skills/build/SKILL.md` sets its rule.

**Two consequences of `touches` being pre-existing-only.** On a greenfield repo, whose dominant act is
creating metadata, `touches` is often empty — so any future trigger derived from it is blind exactly where
`devpath` runs. And two specs inventing the same new object appear in no field anywhere.

**The cited-paths check runs here, as you write, and it refuses.** A `depends_on` path that does not
resolve is Slice's own error — Slice wrote every slice file in one pass — and is fixable in the same
breath. A `touches` path that does not resolve at the moment it is written is wrong by definition, because
`touches` holds pre-existing paths only. **Refuse on either, and name the slice and the path.**

## Re-cutting a directory that already holds slices

Everything above cuts an empty directory. This is the run where the directory is not empty, and what is
already on disk decides what you may do to it.

**It is reachable today, by two routes.** `devpath:technical-design` re-entered on an approved design
withdraws the gate and **keeps the slice files on purpose**, then re-slices once the design settles. And
`/devpath:slice` alone, on a spec whose design is still approved, lands here with every slice on disk.

`/devpath:initiate` on a spec that has been building for a week is the first route one step back. It
deletes both gates, so this skill's own refusal fires until Design re-approves, and Design is what
re-slices.

**Read `devpath/<slug>/slices/` before you cut, front matter included.** `done: true` is the whole test.
It is Build's write and Build writes it only once the slice's acceptance criteria are ticked against code
that deployed.

### A slice carrying `done: true` is cut around, never re-cut

**Mandated.** Read the built slices and the new `## Design`, and cut only what the design needs that no
built slice already covers. New slices take the next numbers. Nothing is renumbered and nothing is
deleted: the number is authoring order, and renumbering breaks every `depends_on` path, every
`## Deviations` entry that names a slice, and the `devpath/<slug>/archive/<nn>-<name>.md` that mirrors a
slice's number and name so `devpath:critique` can derive it.

**The one write this skill makes to a built slice file is the `## Deviations` sentence below, and it
appends.**

This is *Slice partitions; it never invents* applied to a directory that already holds work. The built
slices are a partition somebody already shipped, and the delta is what is left.

**Show the layout with the built slices listed and marked**, so the human sees what was left alone. **It
is put to the human exactly as `## Stop` puts an ordinary layout, and it marks no option either.**

```
devpath: 6 slices on this spec already carry done: true. Not touching them.

  Built, untouched
    01-layout-schema           done
    ...
    06-layout-render           done

  Cut for the reworked design
    07-chunked-bulk-writer     depends on 04-bulk-batcher
    08-chunk-failure-reporting depends on 07-chunked-bulk-writer

Layout is 2 new slices. Nothing built is re-cut.
```

**What overwriting one costs, so the rule reads as arithmetic rather than taste.** Nothing writes
`done: true` before it deploys, so a built slice rewritten back to its birth state is a slice
`devpath:build` builds and **deploys a second time**, and a slice `devpath:critique` grades again from
zero. Writing a new file beside it instead leaves two slices describing one behaviour, and the second one
builds it again.

**A slice carrying no `done: true` is re-cut in place, normally.** Rewrite `## What to build`, restructure
the criteria, and the file keeps its number and its name. The guard above is about deployed work rather
than about slice files. At N = 1 there is no delta to cut and in place is the only cut there is.

**The re-cut rewrites `## What to build` and `## Acceptance criteria`, and leaves the rest of the file
alone.** `## Deviations`, `## Critique findings` and every front-matter field another stage wrote ride
through untouched, because a slice carrying no `done: true` is not the same thing as an untouched slice.
The slice's archive file is not in this file at all, so a re-cut never reaches it.
`devpath:build` pauses by writing an open box under `## Deviations` and committing what is on disk, so the
file can hold a pause and a `- [ ] excess` note from the commit audit, with committed code behind them.

**An untagged pause box is closed by the `devpath:technical-design` session that resolves it, ticked in
the disposition grammar.** The frozen test joins no `done: true` to an open box there. Drop that box in a
rewrite and the slice reads *not started* to the next `devpath:build`, with the question that stopped it
gone. A `- [ ] excess` box stays open for the human at merge. A `- [ ] blocked` box is a pause on a write a
foreign hook refused, and the `devpath:build` worker that resumes the slice closes it, so it reaches merge
closed rather than open.

### A design that contradicts a built slice stops and asks

Where the new `## Design` says something different about code a built slice already deployed, there is
nothing to cut around. Cutting quietly leaves two slices making opposite claims about one behaviour, and
rewriting the built one is the case above.

**Stop and ask, in the human's terms rather than the machine's.** A new slice gets cut either way, so the
question is not about slicing at all. It is what happens to the behaviour the built slice deployed.

```
devpath: the new design changes something slice 04 already built.

  04-bulk-batcher   built and deployed: fixed 200-row batch, no chunking
  the design now says: chunk at any size

  Either way a new slice gets cut. Which is it?
    rework it - the new slice changes 04's behaviour
    keep 04   - 04's behaviour is right, and the design needs another pass
```

**The human is in the session for this**, which is what makes an ask legal where every other stop in this
file names a next act instead. `devpath:technical-design` calls Slice in its own session and never as a
subagent.

**Neither exit is yours to pick.** The ask is the instruction; the answer is the human's.

**Rework it** → cut a new slice whose `touches` covers the same files, and append one plain bullet to the
built slice's `## Deviations` — a `- ` at column zero and then the sentence: *04 built a fixed 200-row cap;
O2 was reworked and 07 changes that behaviour.* No tag and no box, and nothing on 04 is deleted. `done: true` stays, because 04 genuinely did
deploy. Integrate's step 4 counts this slice's deviations into the pull request body and gives the
path, so the human at merge is sent to both slices.

**The Outcome is named by ID, and this is the sharpest place in `devpath` where that matters.** This
sentence is written *during* the rework, onto a slice that keeps it forever, about an Outcome the same
rework is about to change — so a quoted statement here is stale before the commit lands. Under
`devpath:initiate`'s `### An Outcome carries an ID`, a reworked meaning takes a new ID and O2 is retired,
which leaves this sentence naming a retired ID **on purpose**: it says what 04 was built against, which is
exactly what the human at merge needs and exactly what the current `## Outcomes` no longer holds.

**Keep 04** → the design is what went too far, and it goes back to `devpath:technical-design`, whose
re-entry on an approved design **withdraws the gate as its own mandated act** and re-slices once the new
design settles. Inside a design session, that withdrawal is this session applying its own rule. Run alone,
**say the next act and stop**. `design_approved` is Design's field in both directions. Editing
`## Design` with the gate still set is the failure withdrawal exists to stop, which is *a second run
rewriting `## Design` under an approval a human gave to a different design*.

**Why the conflict goes to Design rather than resolving here.** Slice partitions and never invents, and
`devpath:build` re-cuts but never redesigns. A built slice contradicting the new design is a design
question wearing a slicing hat, and Design is the stage with a human in the room.

### A tick Build wrote is cleared on one ground only

`- [x] met` is Build's write and it lands only after a deploy: *a criterion ticked against code that has
not deployed is a criterion you graded rather than met.* Slice writes criteria and Build ticks them, and a
tick already on the page is a verification somebody did.

**Un-tick a criterion whose tick was earned against something that no longer exists** — an interim file
the slice no longer produces, a design statement the conversation has since retired — **and say which ones
and why.** Carrying one of those forward claims a verification that never happened, and nothing downstream
catches it: Integrate re-checks Outcomes and never slice criteria, so a stale tick reaches merge looking
exactly like an earned one.

**That is the only ground.** A criterion still true of what is on disk keeps its tick, however the re-cut
reworded the file around it.

This arises only on a slice carrying no `done: true`, because the criteria on a built slice are not
re-cut at all.

## Checkpoint

Run the cross-spec contention script from the repository root and **show its output verbatim if it printed
anything.**

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/contention.sh"
```

`${CLAUDE_PLUGIN_ROOT}` is required — a bare relative path resolves against the target repository, where
nothing of the plugin's exists. It takes an optional remote and base branch, defaulting to `origin` and
`main`; pass the resolved base branch when it is not `main`.

**It stores nothing and stops nothing, and it always exits 0.** Empty output is the normal result. It
prints file collisions across specs, specs sharing an `upstream` entry, and the names and intents of the
in-flight neighbours it found.

**Do not summarise it.** Show it as printed. A collision is one value appearing under two or more distinct
slugs, and what a reader does about it is talk to the other engineer.

## Stop

**Slice done ⇔ every slice the design needs exists with its `depends_on` edges resolving, or the run
stopped — on a named conflict with a built slice, or at `## Refuse first` — and named the condition.**

**Show the layout and stop.** The slice list, each slice's one-sentence behaviour line, and the
`depends_on` edges between them.

**Then ask.** Where the harness offers a tool that puts a question with named options, put the layout to
the human through it. Where it does not, the printed layout is the whole handover and the engineer answers
in prose. **Both paths leave the same files and store nothing either way, so no reader can tell which
one ran** — no field, no marker, no detection step.

```
  Layout · tolerance-config
  [the slice list, the behaviour lines and the depends_on edges are printed above]

  Read the layout against the design. Is this the right cut?

  ▸ Accept the layout   Commits the slice files and pushes, so the design and the
                        layout land on the draft pull request together.

  ▸ Re-cut it           Say what to change and I will re-cut in this session.
                        The design approval stands.
```

> **The tool presents the decision. It never presents the material.** The slice list prints in full above
> the prompt, and an option's description says what the choice *does*. **A click is legal downstream of a
> read and never instead of one.**

**No option is marked as recommended**, for the same reason neither gate marks one: this run produced the
layout and is asking whether the cut is right, so marking *Accept* is the run grading its own work.
`tests/lint.sh` check 7 holds it against this file's own illustrations.

**Nothing is stored, on either answer.** Two gate fields exist and this asks for neither. Accepting lets
`## Stop` finish; re-cutting is conversational in this same session, as it already is.

**Picking *Re-cut it* is followed by a prompt for what to change**, and then the turn ends. A free-text
answer that already says what to change skips that round.

**This is the one place both routes into Slice reach the ask** — a `devpath:technical-design` run at its
step 6, and a standalone `devpath:slice` run. The standalone one is the cold recovery after a session died
between the approval and the cut, and it is the last run that should be left scrolling.

**Commit the slice files.** When Slice was reached by `devpath:technical-design`, that command pushes
once the layout settles, so the human sees the design and the layout together on the draft pull request.
Run alone, commit and push here.

**The human may reject the layout, and that does not withdraw the design approval.** One verdict sending
the whole thing back was rejected, and the design is not what was rejected. **Re-cut conversationally in
this same session**, with everything still in context. The cold fallback is `devpath:slice` alone against
the approved design.

**A `devpath:technical-design` run never ends with `design_approved: true` and zero slice files.** That
is a postcondition on the command, and it is why this skill is separately invocable: a session that dies
after the approval and before the cut leaves an approved design with no slices, and running
`devpath:slice` recovers it.
