# Credits

`devpath` depends on neither project below as a skill. A hard dependency would break a standalone install,
so the ideas are copied in, and this file carries the credit a dependency would have carried. That is the
reason the `pr` skill's own `CREDITS.md` gives for crediting `show-me`.

## Matt Pocock's `pr` skill

The pull request body's `## Summary` and `## Merge Danger` sections come from the `pr` skill in
[mattpocock-skills](https://github.com/mattpocock/skills) 1.3.1, MIT License, copyright (c) 2026 Matt
Pocock. So does the one-way door call that `devpath:critique` makes on every slice and
`devpath:integrate` gathers for the body. `pr` rates a change as a one-way or a two-way door. `devpath`
names the one-way doors only.

## Dex Horthy's `show-me`

The six views `devpath:integrate` picks from for `## Summary` (pseudocode, a call tree, a component tree,
a file tree, Mermaid and a shaped diff) come from [Dex Horthy](https://github.com/dexhorthy)'s
[`show-me`](https://github.com/humanlayer/humanlayer) skill. `pr` took the menu from it, and `devpath` took
it from `pr`.
