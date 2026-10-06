#!/bin/sh
# devpath — repo-wide rules that hold no matter which file is edited next.
#
# Seven checks, all of them rules rather than paragraphs: the retired vocabulary,
# the skill-to-skill call strings, the closed set of gate fields, every tag word
# in the disposition grammar staying unread by anything mechanical but the body
# script's count, the Outcome handle grammar, every stage naming when the stage
# is over, and no gate or layout prompt marking one of its options. What this
# file does not do is assert that a given paragraph is still on a given page,
# which a diff already catches. Checks 6 and 7 come closest and are still rules.
# Check 6 asserts a shape every file derives from its own heading, never a
# sentence written out here, and check 7 asserts the absence of one string from
# one kind of block.
#
# Exit code is the build's.

cd "$(dirname "$0")/.." || exit 1

FAIL=0

# POSIX ERE has no \b. These bracket a word with a non-word character or an
# anchor, which is portable where \b and [[:<:]] are not.
L='(^|[^[:alnum:]_])'
R='([^[:alnum:]_]|$)'

# Every file carrying prose of devpath's authoring. Nothing under tests/ is a
# subject: this file names every retired word as a literal.
PROSE=$(ls skills/*/SKILL.md README.md scripts/*.sh 2>/dev/null)
PN=$(printf '%s\n' "$PROSE" | grep -c .)

# A floor, not a census — it catches a glob that collapsed, and stays quiet when
# a skill is added. A count pinned to the exact number turns every new skill red.
if [ "$PN" -lt 10 ]; then
  echo "FAIL subject: expected at least 10 prose files, found $PN"
  printf '%s\n' "$PROSE" | sed 's/^/      /'
  exit 1
fi

report() {  # report <rule> <file> <hits>
  [ -z "$3" ] && return 0
  echo "FAIL [$1] $2"
  printf '%s\n' "$3" | sed 's/^/      /'
  FAIL=1
}

# ---------------------------------------------------------------- 1. vocabulary
#
# Ten rules over the prose files. Several retirements are scoped, and the
# scoped-out forms are mandated literals — ## Design, design_approved, the stage
# name Design, "Build records" under ## Deviations. A flat "this word does not
# appear" would fail against a compliant plugin, and a test that cannot pass gets
# deleted, which puts the list back to a wish.
#
# An allowlist is part of its rule rather than a convention around it, so adding
# to one is an edit visible in a diff.
for f in $PROSE; do
  [ -f "$f" ] || continue

  # enhancement — banned everywhere, any case. No permitted form.
  report enhancement "$f" "$(grep -niE 'enhancement' "$f")"

  # pipeline — banned everywhere, any case. Reads as CI to every engineer, and
  # an existing plugin already owns it.
  report pipeline "$f" "$(grep -niE 'pipeline' "$f")"

  # unit of work — banned everywhere. No permitted form.
  report 'unit of work' "$f" "$(grep -niE 'unit of work' "$f")"

  # unit — whole word, minus a named allowlist. The naive form fails on
  # "npm run test:unit", which fit-check looks for by name, and on "unit test",
  # which an Apex repo cannot avoid. Permitted compounds are stripped first so a
  # mixed line is still caught.
  report unit "$f" "$(
    sed -e 's/[Uu]nit tests*//g' -e 's/test:unit//g' -e 's/[Uu]nit price/PRICE/g' "$f" \
      | grep -niE "${L}unit${R}"
  )"

  # task — whole word, minus the one harness string this plugin ships: the hook
  # matcher Task|Agent in README item 5. Collides with the harness's Task tool.
  report task "$f" "$(
    sed -e 's/Task|Agent/MATCHER/g' "$f" | grep -niE "${L}task${R}"
  )"

  # record — whole word, which is the singular noun and the imperative, leaving
  # records, recorded and recording untouched so the mandated "Build records"
  # passes. The allowlist is four named phrases, each mandated elsewhere here.
  report record "$f" "$(
    sed -e 's/record what you dispatched/DISPATCHED/g' \
        -e 's/record a deviation/DEVIATION/g' \
        -e 's/record that a human said yes/CONSENT/g' \
        -e 's/on the item record/ITEM/g' "$f" \
      | grep -niE "${L}record${R}"
  )"

  # program — banned as a LEVEL in the work hierarchy: a directory, a field, a
  # slug prefix, a grouping key. Ordinary English for a body of work is
  # permitted, and so is program-agnostic. A ban on a position asserts positions.
  report 'program-as-level' "$f" "$(
    sed -e 's/program-agnostic/AGNOSTIC/g' "$f" \
      | grep -niE "(^[[:space:]]*programs?:|programs?/|devpath/programs?|program[_-]prefix|group(ing)? key.*program|program.*group(ing)? key)"
  )"

  # design — banned as a BARE SKILL NAME. In this ecosystem "design" means
  # visual design. Permitted: the stage name Design, the heading ## Design, the
  # field design_approved, and devpath:technical-design.
  report 'design-as-skill-name' "$f" "$(
    grep -nE "(devpath:design([^a-zA-Z0-9_-]|$)|skills/design/)" "$f"
  )"

  # Research — banned as a stage name, a heading or a field. Ordinary English,
  # lower case, is permitted; Survey is the stage name.
  report Research "$f" "$(
    grep -nE "(^##+[[:space:]]+Research|^[[:space:]]*research:|devpath:research|${L}Research${R})" "$f"
  )"

  # Review — same scope, same reason. Ordinary English, lower case, is
  # permitted: "one per review pass", "pull-request review". Critique is the
  # stage name.
  report Review "$f" "$(
    grep -nE "(^##+[[:space:]]+Review|^[[:space:]]*review:|devpath:review|${L}Review${R})" "$f"
  )"
done

# --------------------------------------------------------------- 2. compositions
#
# The four skill-to-skill calls, asserted as imperatives naming the skill. These
# strings are a functional contract: the namespace in them is the plugin's own
# name, so a half-rename lands here.
#
# The reason this check exists is a shipped failure. Three of the four
# compositions were imperatives and were followed; the fourth, devpath:build
# reaching devpath:critique, was described and never called, and the first real
# spec built seven slices with no critic having read any of them. Nothing noticed,
# because the only thing asserting a composition existed was the prose that
# failed to hold one.
#
# Invocation is model-driven and stays model-driven — this asserts the instruction
# is present, never that a session followed it.
COMPOSITIONS='skills/technical-design/SKILL.md:survey
skills/technical-design/SKILL.md:slice
skills/build/SKILL.md:critique
skills/integrate/SKILL.md:learn'

for c in $COMPOSITIONS; do
  f=${c%:*}
  skill=${c##*:}
  if [ ! -f "$f" ]; then
    report "$skill" "$f" "file does not exist"
    continue
  fi
  # The imperative in either voice: "run the skill" mid-sentence, "Run the
  # skill" opening one. Anything softer than a verb is not a call.
  if ! grep -qE "[Rr]un the skill \`devpath:$skill\`" "$f"; then
    report "$skill" "$f" "holds no imperative naming devpath:$skill
expected a line matching: [Rr]un the skill \`devpath:$skill\`"
  fi
done

# Every call site carries the softness callout, so per file the two counts match.
# The imperative alone can ship without the callout that tells a reader, at the
# place they act on it, that the call is not guaranteed.
for f in skills/technical-design/SKILL.md skills/build/SKILL.md skills/integrate/SKILL.md; do
  [ -f "$f" ] || continue
  CALLS=$(grep -cE '[Rr]un the skill `devpath:' "$f")
  SOFT=$(grep -c 'model-driven and is not guaranteed' "$f")
  if [ "$CALLS" -ne "$SOFT" ]; then
    report callout "$f" "$CALLS call site(s), $SOFT softness callout(s)"
  fi
done

# --------------------------------------------------------------- 3. gate fields
#
# Two gates exist and the design turns on there being two. A third field named
# anywhere under skills/ or in README is a gate somebody added in prose.
FIELDS=$(grep -rhoE '[a-z_]+_(approved|accepted)' skills/ README.md 2>/dev/null \
  | sort -u | grep -vxE 'design_approved|intent_accepted')
if [ -n "$FIELDS" ]; then
  report 'gate fields' 'skills/ and README.md' "a gate field beyond the two that exist:
$FIELDS"
fi

# ------------------------------------- 4. nothing mechanical reads a tag word
#
# skills/integrate/SKILL.md states the rule over the whole set: nothing
# mechanical branches on a tag word. This check holds the stricter form, no read
# at all, bar the one reader named below. The moment something mechanical reads
# one, that tag can become a state of its own and the frozen test has two answers. `- [ ] excess`, `- [ ] blocked` and `- [ ] verify` are each
# the same open box with its shortfall named, so every existing check matches them
# and no new check exists. That is the property, held over every word.
#
# Seven words, one check, because they fail identically and a second copy of this
# scan is how one of them goes quiet. `blocked` arrived after `excess`, and this
# check read those two alone, so the four words a disposition is actually written
# in went unscanned. `verify` came later still.
#
# `unmet` is the eighth word and is deliberately not one of them. The grammar
# has readers that key on it by design — devpath:build cuts one slice per
# `- [ ] unmet` line, and devpath:integrate carries every one into the pull
# request body whole — so it is the one tag word a program is meant to find. The
# other seven have no such reader.
#
# Two subjects. The executable files, minus this one — README's fenced json and
# sh blocks are shipped code a repo pastes, so they count as mechanical. The
# fenced lines are pulled out and then asked the same questions the files are,
# rather than a second copy of the patterns being written for them. A `#` line
# reads nothing wherever it sits, so the fences drop theirs too — latent while
# the tag list was two words, and a false report the first time a README comment
# says `grep` and `fixed` on one line.
#
# Both subjects are asked one question — is a tool reading the word — rather than
# whether the word appears. A string that only says `blocked` reads nothing, and
# `blocked` is the ordinary English word for what these hook blocks do to a push,
# so scanning for the bare word here goes red on a test that merely says it. The
# tool list is what a read looks like in a shell file, a workflow or a block a
# repo pastes.
#
# Both lists are bracketed as whole words, and the tool half is why. Unbounded,
# `sed` matches inside the word `closed`, which made tests/gate.sh's fixture line
# — a box that fixture starts closed — read as a mechanical read of a tag. Latent
# while the tag list was two words that never met it, and a defect either way.
#
# `won't fix` is scanned as the tag rather than as `won`. A bare `won` catches a
# grep for half the tag, and it also catches ordinary English in any failure
# message that says something will not happen — and a test that cannot pass gets
# deleted, which is the argument this file makes at every other floor.
#
# The cost, said out loud because it is what kills a check. This scan cannot tell
# a search pattern from a failure label, so a tag word named in a message counts.
# Over the 45 commits before this line was written, 17 non-comment lines carrying
# a tag word landed under tests/ or scripts/, 8 of them also carrying a tool word
# — and those 8 sit in 2 commits, because a commit that touches this vocabulary
# touches it several times. The fix each time is a one-word reword that reads
# better anyway: `a - [x] fixed box` becomes `a closed box`. The danger is not the
# reword. It is somebody meeting this report pointed at an echo, deciding the
# check is broken, and deleting it — so the report line says a label counts too.
#
# Blunt in that direction on purpose: a scan clever enough to tell a label from a
# search pattern is a scan that can be fooled by a pattern dressed as a label.
#
# Narrowing the subject to code that runs against a spec directory would avoid
# all of it, and it is refused on merits. A devpath test that searched for a tag
# word would not merely break the rule, it would ratify it — and the rule would
# then be dead with a green suite sitting on top. The tests are the last place to
# stop looking.
#
# One file is allowed three of the words, and it is scanned harder than the rest
# in exchange. scripts/pr-body.sh writes the parts of the pull request body that
# two runs must write identically, and README names that reader: `## Deviations`
# and `## Critique findings` are "counted into the pull request body and read at
# merge, and no run branches on what they say". It counts `fixed`,
# `false positive` and `won't fix` and copies `won't fix` lines whole, the same
# reader `unmet` already has. A count printed into the body is no state, since
# nothing acts on it, and tests/pr-body.sh holds the script's exit status equal
# over a spec carrying every tag word and one carrying none.
#
# Its awk program spreads its reads across lines with no tool word on them, so
# the tool-word pairing above would pass it whatever it read. Every non-comment
# line of it is scanned instead, the three words are blanked, and any tag word
# left over goes red. A `blocked` read added there fails here.
TAGS="fixed|met|false positive|won't fix|excess|blocked|verify"
TOOLS='grep|awk|sed|jq|case|rg|"command"'
READER=scripts/pr-body.sh
READS="fixed|false positive|won't fix"
CODE=$(ls scripts/*.sh .github/workflows/ci.yml tests/*.sh 2>/dev/null | grep -vx -e 'tests/lint.sh' -e "$READER")
MECH=$(
  awk '
    /^```(json|sh|bash)$/ { fence = 1; next }
    /^```$/               { fence = 0; next }
    fence && !/^[[:space:]]*#/ { print FILENAME ": " $0 }
  ' README.md | grep -E "${L}(${TAGS})${R}" | grep -E "${L}(${TOOLS})${R}"
  [ -n "$CODE" ] && grep -nE "${L}(${TAGS})${R}" $CODE \
    | grep -E "${L}(${TOOLS})${R}" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'
  [ -f "$READER" ] && grep -nE "${L}(${TAGS})${R}" "$READER" \
    | grep -vE '^[0-9]+:[[:space:]]*#' \
    | sed -E "s/${READS}/_/g" | grep -E "${L}(${TAGS})${R}" | sed "s|^|$READER: |"
)
if [ -n "$MECH" ]; then
  report 'no new state' 'the seven tag words' "something mechanical reads a tag word — and a tag word
inside a failure message counts, because this scan cannot tell a label from a search pattern and one
that could be told apart could be fooled by a pattern dressed as a label. Reword a label; move a read:
$MECH"
fi

# ----------------------------------------------- 5. the Outcome handle grammar
#
# An Outcome's handle is `O<n>`: its line reads `- O2 — <statement>` and every
# reference to it anywhere else is the bare token. Five rules hold that grammar,
# and they are one check rather than checks 5 and 8 through 11 — split across
# five, a later edit deletes one and leaves this file's header counting seven
# checks that are now eleven.
#
#   1. a digit after the word Outcome — the positional index, and the reason
#      `devpath:integrate` gives is that a position is a convention nothing here
#      defines
#   2. an ordinal word before it — the same index spelled out, which rule 1
#      cannot see. Two of these sat in skills/build/SKILL.md under a rule that
#      already forbade the digit form. Capital `Outcome` only, the same split
#      checks 1's Research and Review rules make: lower case is ordinary
#      English, and *there is no third outcome* is a sentence this repo writes
#   3. a `## Outcomes` illustration whose bullets carry no ID
#   4. a `met` line under a `## Outcome checks` illustration carrying anything
#      after the ID
#   5. an `unmet` or `won't fix` line under that same heading that does not read
#      tag, ID, em dash, observation. The grammar puts the ID on all three
#      verdicts and rule 4 sees only the one that ends at it — so without this,
#      the exact line this check was grown to retire goes back on the page unseen
#
# All five scan devpath's own prose rather than a spec on disk, because what
# they catch is an illustration teaching the wrong convention by example, which
# is how the last violation survived a rule that already forbade it.
#
# Rule 4 reads the heading rather than the tag, because `- [x] met` also closes
# an acceptance criterion, where the criterion's own text *is* the line. A flat
# rule over the tag would go red on a correct slice illustration, and a test that
# cannot pass gets deleted. Rule 5 reads the heading for the same reason, and
# matches `- [x] won` rather than the apostrophe: the tag sits inside a
# single-quoted awk program, and under this heading nothing else opens that way.
#
# Rules 3, 4 and 5 accept a leading indent on a line they judge as well as on one
# they pick up. README's own rule is that a box sits at column zero and that the
# checks match an indented one anyway, because a formatter that renests a list
# would otherwise turn a red gate green — anchoring only the judgment half turns
# a green one red, which is the same failure pointing the other way.
#
# Rules 3, 4 and 5 walk fences, which is the only way to tell an illustration
# from a sentence about one: `## Outcomes` in running prose is inline code, and
# grep cannot see a fence. A file with no fence at all is walked and yields
# nothing, which is scripts/contention.sh writing an empty `## Outcomes` into a
# fixture. An odd count leaves the walk inverted for the rest of the file and the
# three rules silently stop applying, so the END rule says so out loud.
ORDINALS='[Ff]irst|[Ss]econd|[Tt]hird|[Ff]ourth|[Ff]ifth|[Ss]ixth|[Ss]eventh|[Ee]ighth|[Nn]inth|[Tt]enth'

for f in $PROSE; do
  [ -f "$f" ] || continue

  report 'never numbered' "$f" "$(grep -nE "${L}Outcome[[:space:]]+[0-9]" "$f")"
  report 'never ordinal' "$f" "$(grep -nE "${L}(${ORDINALS})[[:space:]]+Outcome${R}" "$f")"

  report 'handle grammar' "$f" "$(
    awk '
      /^```/            { fence = !fence; sec = ""; next }
      !fence            { next }
      /^## /            { sec = substr($0, 4); sub(/ +$/, "", sec); next }
      sec == "Outcomes" && /^ *- / && $0 !~ /^ *- O[0-9]+ — ./ {
        print NR ": an ## Outcomes line carrying no ID — " $0
      }
      sec == "Outcome checks" && /^ *- \[x\] met/ && $0 !~ /^ *- \[x\] met O[0-9]+$/ {
        print NR ": a met line carrying more than its ID — " $0
      }
      sec == "Outcome checks" && /^ *- (\[ \] unmet|\[x\] won)/ && $0 !~ /O[0-9]+ — ./ {
        print NR ": a verdict line outside the tag, ID, observation grammar — " $0
      }
      END { if (fence) print "unbalanced fence — rules 3, 4 and 5 stopped partway" }
    ' "$f"
  )"
done

# --------------------------------- 6. every stage names when the stage is over
#
# Survey shipped the only done-condition of the eight. The other seven ended on an
# instruction about what to report, which is not a bound, and a loose bound is
# what lets a stage stop early with its later steps still pulling at it.
#
# Both halves are derived, never listed. The stage set is every skill whose front
# matter leaves it model-invocable, so a ninth stage is checked the day it lands
# and another human-invoked skill is skipped the day it lands. The name is the
# file's own `# ` heading, which already carries it. skills/technical-design/
# SKILL.md opens `# Design`.
#
# Requiring the bold `**<name> done ⇔` rather than a bare glyph is what keeps
# Design honest. That file quotes Survey's condition in italics where it prices a
# skipped Survey call, and a grep for the glyph alone would pass Design on
# somebody else's sentence. That closes the cross-file quote, which is the one
# that occurs here. A file quoting its own condition — inside a fence, or in a
# sentence forbidding it — still passes, and that case is left to the diff.
#
# The prefix has to survive on one line. Several of the sentences wrap, all of
# them after the glyph, and one that wrapped earlier would go red while being
# correct.
STAGES=0
for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue

  # Front matter is the block between the first two --- lines, so a body that
  # names the flag cannot exempt itself. tests/schema.sh reads the same flag
  # whole-file and pins the disabled set by name, so the two scopes disagree by
  # design: a body mention is invisible here and red there. Keep it that way.
  FM=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1' "$f")
  printf '%s\n' "$FM" | grep -qE '^disable-model-invocation:[[:space:]]*true' && continue

  STAGES=$((STAGES + 1))
  NAME=$(awk '/^# / { sub(/^# /, ""); print; exit }' "$f")
  if [ -z "$NAME" ]; then
    report 'when it is over' "$f" "carries no \`# \` heading to read a stage name from"
  elif ! grep -qF "**$NAME done ⇔" "$f"; then
    report 'when it is over' "$f" "names no condition for the stage being over
expected a line holding: **$NAME done ⇔"
  fi
done

# A floor, not a census, for the reason stated at the prose floor above.
if [ "$STAGES" -lt 8 ]; then
  echo "FAIL subject: expected at least 8 model-invocable skills, found $STAGES"
  FAIL=1
fi

# ------------------------------ 7. no gate or layout prompt marks one of its options
#
# Six stops put a question the run cannot answer for itself: the intent gate, the
# design gate, the slice layout, build's dirty-tree stop, build's fix cycles cap
# and build's verify ask. The verify ask is the one this check cannot see: its
# options are a bullet list with no fenced illustration, so its own prose rule is
# all that holds it. At the three gates the default *is* the judgment being asked for, so a
# marked option is the plugin answering its own gate. The cap trip joins them by
# that reason and not the dirty-tree stop's: the run has computed no verdict and
# stops because it cannot decide. At the dirty-tree stop the run has read the diff
# and still cannot know whose work it is looking at, which is the same prohibition
# reached by a different road. At the verify ask the worker could not observe the
# behaviour, which is the reason the question exists. Integrate's step 3 is the one stop that marks one,
# because there the run computed the verdict already and the human is choosing a
# disposition — so this check names four files and leaves
# skills/integrate/SKILL.md out. Six stops, four files: three of them are
# skills/build/SKILL.md's, so the file list does not move.
#
# Scoped to fenced blocks, because all four files argue the prohibition in
# prose and an unscoped grep would go red against a compliant plugin — and a
# test that cannot pass gets deleted.
#
# The subject is the illustration rather than the rule, which is check 5's
# precedent: an illustration teaching the wrong convention by example is how the
# last violation of a rule like this one survived.
#
# The walk inverts for the rest of the file on an odd fence count, exactly as
# check 5's does, so it says so out loud rather than falling silent.
PROMPTS=0
for f in skills/initiate/SKILL.md skills/technical-design/SKILL.md skills/slice/SKILL.md \
         skills/build/SKILL.md; do
  [ -f "$f" ] || continue
  PROMPTS=$((PROMPTS + 1))

  report 'no recommendation at a gate' "$f" "$(
    awk '
      /^```/ { fence = !fence; next }
      fence && /\(Recommended\)/ {
        print NR ": a prompt illustration marking an option — " $0
      }
      END { if (fence) print "unbalanced fence — this rule stopped partway" }
    ' "$f"
  )"
done

# A floor, not a census, for the reason stated at the prose floor above — with
# one difference that matters. Checks 1 and 6 derive their subjects from a glob,
# so a renamed file stays in scope; this list is written out, so a rename is
# exactly how it would go quiet while still reporting clean. Four named, four
# read.
if [ "$PROMPTS" -lt 4 ]; then
  echo "FAIL subject: expected 4 files carrying a gate or layout prompt, found $PROMPTS"
  FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "lint: vocabulary over $PN prose files, four compositions, two gate fields, seven unread tag words, the Outcome handle grammar over five rules, $STAGES stages naming when they are over, $PROMPTS prompts marking no option — clean"
fi
exit "$FAIL"
