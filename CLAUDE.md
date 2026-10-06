# devpath

A Claude Code plugin: ten skills under `skills/`, two shipped executables under `scripts/`
(`contention.sh` and `pr-body.sh`), six tests under `tests/`. The product is prose — the skills are
instructions an agent reads at run time — so a defect here is usually a wrong sentence and a
fix is usually an edit to one.

## Branch off `origin/main`

Fetch, then cut a fresh branch for the issue you are working. Never commit on whatever branch
happens to be checked out.

## Prose standard

Apply `/writing-for-agents` and `/unslop` to every line of prose you add or edit. This repo
documents no prose standard of its own, so those two skills are the axis review will use.

## Run the tests before you push

```sh
for t in tests/*.sh; do sh "$t"; done
```

That is what CI runs. `tests/schema.sh` needs `python3`.

Each test's header comment states what it holds and why. Read the header of any test you make
fail — the checks are added to often enough that a list written out here would be wrong within
the week.

Two that catch people, because neither is local to the line you are editing:

- **An allowlist is part of an assertion.** `lint.sh` keys exact phrases to specific files. If
  a rephrase is genuinely right, edit the assertion in the same change, so the diff shows it.
- **The spec and slice schemas are written in three places and `schema.sh` checks they agree.**
  Edit one copy and you edit all three.

## Cite evidence by quote, not by line number

Line numbers here go stale on any merge that inserts a line above them, and they have been
refreshed by hand twice across 36 issues. Quote the sentence you mean. If you give a number,
pin it to a commit — and note that a pinned commit on a squashed or unmerged branch resolves
on GitHub but not in a bare clone.
