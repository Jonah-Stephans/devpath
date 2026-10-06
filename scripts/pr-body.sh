#!/bin/sh
# devpath — the pull request body, every part of it that two correct runs must
# write identically. devpath:integrate's step 4 runs it on the spec's branch,
# replaces the three slot lines with the parts a model writes, and pipes the
# result to `gh pr edit`:
#
#   {{intent}}         ## Intent from spec.md, verbatim
#   {{view}}           the one view picked to show what the change does
#   {{merge-danger}}   the Merge Danger subagent's tree, as returned
#
# Stdout is the body. Run twice over one branch, it prints the same bytes: every
# list is sorted in the C locale, and nothing here fetches.
#
# The base branch is the pull request's own, read through gh. The repository's
# default is the near miss: a pull request into a release branch, drawn against
# main, would show every file that branch is behind on as this branch's work.
# Where gh cannot read the pull request this prints nothing and exits 1, because
# the `gh pr edit` the body is for would fail on the same gh.
#
# The file tree is read against the merge-base, never the base's tip, which on a
# branch the base has moved past reports lines this branch never removed. It
# leaves out devpath/: the spec directory is committed on this branch, and on a
# fix-heavy spec its slice files would be the largest change in the tree. Full
# Details links to every one of them.
#
# Every read of the spec directory takes the archive directory too, because a
# closed finding leaves the slice file for devpath/<slug>/archive/<nn>-<name>.md
# at the next re-review. A box is read whole, with the indented lines wrapped
# under it, since the clause a section keys on can sit on a continuation line.
#
# This file reads three tag words, fixed, false positive and won't fix, and
# only to count them or copy their lines into the body. Nothing it does turns
# on one: tests/lint.sh check 4 allows exactly those three here, and
# tests/pr-body.sh holds the exit status equal over a spec carrying every tag
# word and a spec carrying none.

cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null \
  || { echo "devpath: not inside a git repository" >&2; exit 1; }

SLUG=$(git branch --show-current)
D="devpath/$SLUG"
if [ -z "$SLUG" ] || [ ! -f "$D/spec.md" ]; then
  echo "devpath: no spec directory for branch '$SLUG'" >&2
  exit 1
fi

PR=$(gh pr view --json baseRefName,url -q '.baseRefName + " " + .url' 2>/dev/null)
BASE=${PR%% *}
URL=${PR#* }
if [ -z "$BASE" ] || [ -z "$URL" ] || [ "$BASE" = "$PR" ]; then
  echo "devpath: gh could not read the pull request for branch '$SLUG'" >&2
  exit 1
fi
BLOB="${URL%/pull/*}/blob/$SLUG/$D"

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT INT TERM

# --- ## Summary: the file tree ----------------------------------------------
echo '{{intent}}'
echo
echo '## Summary'
echo

MB=$(git merge-base "origin/$BASE" HEAD 2>/dev/null)
if [ -z "$MB" ]; then
  echo "Files not drawn: origin/$BASE is not in this clone."
else
  # --no-renames keeps one plain path per row; a rename is a deletion and an
  # addition, each under its own path.
  git -c core.quotePath=false diff --numstat --no-renames "$MB" HEAD -- . ':(exclude)devpath/' \
    | awk -F '\t' '{ print $3 "\t" $1 "\t" $2 }' | LC_ALL=C sort > "$T/numstat"
  if [ -s "$T/numstat" ]; then
    echo '```text'
    awk -F '\t' '
      function pad(n,   s) { s = ""; while (n-- > 0) s = s " "; return s }
      {
        # git prints two dashes in place of the figures for a binary file
        f = ($2 == "-") ? "binary, changed" : "+" $2 " -" $3
        n = split($1, p, "/")
        parent = ""
        for (i = 1; i <= n; i++) {
          key = (i == 1) ? p[i] : parent "/" p[i]
          if (!(key in seen)) {
            seen[key] = 1
            name[key] = p[i]
            nk[parent]++
            kid[parent, nk[parent]] = key
          }
          if (i < n) isdir[key] = 1
          parent = key
        }
        figure[key] = f
      }
      # A directory holding exactly one entry is drawn on its parent line, so
      # force-app/main/default/ takes one line rather than three.
      function draw(node, pre, depth,   i, c, last, label) {
        for (i = 1; i <= nk[node]; i++) {
          c = kid[node, i]
          last = (i == nk[node])
          label = name[c]
          while ((c in isdir) && nk[c] == 1) { c = kid[c, 1]; label = label "/" name[c] }
          if (c in isdir) label = label "/"
          nl++
          left[nl] = pre (last ? "└─ " : "├─ ") label
          # display width, counted apart from length(), which a byte-counting
          # awk gets wrong on the box-drawing characters
          width[nl] = 3 * depth + 3 + length(label)
          fig[nl] = (c in isdir) ? "" : figure[c]
          if (fig[nl] != "" && width[nl] > max) max = width[nl]
          if (c in isdir) draw(c, pre (last ? "   " : "│  "), depth + 1)
        }
      }
      END {
        print "."
        draw("", "", 0)
        for (i = 1; i <= nl; i++) {
          if (fig[i] == "") print left[i]
          else print left[i] pad(max - width[i] + 2) fig[i]
        }
      }
    ' "$T/numstat"
    echo '```'
  else
    echo 'No file outside devpath/ changed on this branch.'
  fi
fi

echo
echo '{{view}}'
echo
echo '## Merge Danger'
echo
echo '{{merge-danger}}'
echo

# --- the spec directory, in one fixed order ---------------------------------
# spec.md, then each slice followed by its archive file.
{
  for f in "$D"/slices/*.md; do [ -f "$f" ] && printf '%s\t1\t%s\n' "${f##*/}" "$f"; done
  for f in "$D"/archive/*.md; do [ -f "$f" ] && printf '%s\t2\t%s\n' "${f##*/}" "$f"; done
} | LC_ALL=C sort | cut -f3 > "$T/files"

PROG=$(cat <<'AWK'
function pl(n, one, many) { return n " " (n == 1 ? one : many) }
# the box opens on this disposition: the tag, then a non-word character or the
# end of the line
function tagged(t, w,   c) {
  if (index(t, "- [x] " w) != 1) return 0
  c = substr(t, 7 + length(w), 1)
  return c == "" || c !~ /[A-Za-z0-9_]/
}
function flush(   t) {
  if (ent == "") return
  t = first
  sub(/^[ \t]*/, "", t)
  if (tagged(t, "fixed") && index(ent, "unverified:"))
    outside = outside ent "\n      " entfile "\n"
  if (tagged(t, "won't fix") || index(t, "- [ ] unmet") == 1) {
    ng++
    gtext[ng] = ent
    gid[ng] = ""
    gpath[ng] = entfile
    if (kind == "spec" && entsec == "Outcome checks" && match(t, / O[0-9]+ /)) {
      gid[ng] = substr(t, RSTART + 1, RLENGTH - 2)
      gpath[ng] = ""
    }
  }
  # ## Critique findings on a slice, and every box in its archive file
  if (kind == "archive" || (kind == "slice" && entsec == "Critique findings")) {
    if (tagged(t, "fixed")) nfx[sl]++
    else if (tagged(t, "false positive")) nfp[sl]++
    else if (tagged(t, "won't fix")) nwf[sl]++
  }
  ent = ""
}
FNR == 1 {
  flush()
  sec = ""; infm = 0; cur = ""
  if (FILENAME == D "/spec.md") kind = "spec"
  else if (index(FILENAME, D "/slices/") == 1) kind = "slice"
  else kind = "archive"
  sl = FILENAME
  sub(/^.*\//, "", sl)
  sub(/\.md$/, "", sl)
  if (kind == "slice") slices[++ns] = sl
  if ($0 == "---") { infm = 1; next }
}
infm {
  if ($0 == "---") infm = 0
  else if (kind == "slice" && $0 ~ /^fix_cycles:/) { v = $0; gsub(/[^0-9]/, "", v); fc[sl] = v }
  next
}
/^## / {
  flush()
  cur = ""
  sec = substr($0, 4)
  sub(/[ \t]+$/, "", sec)
  if (kind == "slice" && sec == "Merge Danger") hasmd[sl] = 1
  next
}
/^[ \t]*- / {
  flush()
  if ($0 ~ /^[ \t]*- \[[ x]\] /) { ent = $0; first = $0; entsec = sec; entfile = FILENAME }
  if (kind == "slice" && sec == "Deviations") ndev[sl]++
  if (kind == "slice" && sec == "Merge Danger") ndoor[sl]++
  if (kind == "spec" && sec == "Traps") ntraps++
  cur = ""
  if (kind == "spec" && sec == "Outcomes" && match($0, /^[ \t]*- O[0-9]+ /)) {
    t = $0
    sub(/^[ \t]*- /, "", t)
    cur = t
    sub(/ .*$/, "", cur)
    outcome[cur] = "      " t
  }
  next
}
/^[ \t]+[^ \t]/ {
  t = $0
  sub(/^[ \t]+/, "", t)
  if (ent != "") ent = ent "\n" $0
  if (cur != "") outcome[cur] = outcome[cur] "\n      " t
  next
}
{ flush(); cur = "" }
END {
  flush()

  print "## Outside the Test Boundaries"
  print ""
  if (outside == "") print OUT_NONE
  else printf "%s", outside
  print ""

  print "## Accepted Gaps"
  print ""
  if (ng == 0) print GAPS_NONE
  for (i = 1; i <= ng; i++) {
    print gtext[i]
    if (gid[i] != "" && (gid[i] in outcome)) print outcome[gid[i]]
    else if (gpath[i] != "") print "      " gpath[i]
  }
  print ""

  for (i = 1; i <= ns; i++) {
    s = slices[i]
    tfc += fc[s]; tfx += nfx[s]; tfp += nfp[s]; twf += nwf[s]; tdoor += ndoor[s]
  }
  print "## Full Details"
  print ""
  print "<details>"
  print "<summary>" pl(ns, "slice", "slices") " · " pl(tfc, "fix cycle", "fix cycles") " · " \
    (tfx + 0) " fixed, " (tfp + 0) " false positive, " (twf + 0) " won't fix · " \
    pl(tdoor + 0, "one-way door", "one-way doors") " recorded</summary>"
  print ""
  print "| Slice | Fix cycles | Fixed | False positive | Won't fix | Deviations | One-way doors |"
  print "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
  for (i = 1; i <= ns; i++) {
    s = slices[i]
    # a dash where the slice carries no fix_cycles: line, or no ## Merge
    # Danger section, so a slice no critic asked differs from one with none
    print "| [" s "](" BLOB "/slices/" s ".md) | " ((s in fc) ? fc[s] : "—") " | " \
      (nfx[s] + 0) " | " (nfp[s] + 0) " | " (nwf[s] + 0) " | " (ndev[s] + 0) " | " \
      ((s in hasmd) ? ndoor[s] + 0 : "—") " |"
  }
  print ""
  print "[`spec.md`](" BLOB "/spec.md) — " (ntraps ? pl(ntraps, "trap", "traps") : "`## Traps` empty")
  print ""
  print "</details>"
}
AWK
)

OUT_NONE='Every finding fixed on this spec closed on a check that went red and then green. Nothing was closed on a change nothing could prove.'
GAPS_NONE="No \`won't fix\` and no \`- [ ] unmet\` anywhere on this spec. Nothing was shipped knowingly unresolved."

awk -v D="$D" -v BLOB="$BLOB" -v OUT_NONE="$OUT_NONE" -v GAPS_NONE="$GAPS_NONE" \
  "$PROG" "$D/spec.md" $(cat "$T/files")
