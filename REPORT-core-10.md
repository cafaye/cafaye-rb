# REPORT-core-10 — declaring the gate in `cafaye-rb`

Packet core-10, branch `worker/core-10-cafaye-rb`. Nothing outside this worktree
was written; `core` is read-only from here and every finding about it is below
rather than in a commit against it.

---

## The finding, first

**`cafaye-rb`'s gate is red without a checkout of `core` beside it, and nobody
had written that down.** Copy this repository to a directory with no `core`
sibling — which is exactly what `actions/checkout@v4` produces on a GitHub
runner — and the suite is:

```
1) Failure: ManifestTest#test_it_carries_every_field_core_requires_and_nothing_else
   the manifest carries a field core's schema does not define.
   Expected ["description", "consumes", "dependencies"] to be empty.

1) Error:   CoreSpecsTest#test_the_attribute_list_here_is_core_s:
            NoMethodError: undefined method 'fetch' for nil
            test/contract/core_specs_test.rb:74

228 runs, 650 assertions, 1 failures, 1 errors, 0 skips
```

That is the identity defect wearing a different coat. `test/contract/` resolves
core as `../../../core` from `test/contract`, which is a **sibling of the
repository root** and not a file in this repository. Sixteen of those tests fall
back to a pinned copy in `test/fixtures/core_envelope.rb` and still assert — that
is a deliberate and good decision by the packet that wrote them, and their own
header says why. These two do not, so they are the two that need the real thing,
and nothing anywhere in the repository said so.

**The consequence is that `.github/workflows/ci.yml` does not currently gate this
repository.** The workflow has one `actions/checkout@v4` (this repository) and
then `run: ./bin/prime`. On a runner, `core` is not there, so `bin/prime` exits
nonzero. `test/contract/core_specs_test.rb` claims otherwise in a comment — *"CI
checks the two newest Ruby versions, one of which clones core so the real
comparison runs there too"* — and no step in the workflow clones it.

I have **not** fixed this. Fixing CI would be modifying the gate's behaviour,
which this packet does not do, and the red is more useful to the manager than a
green I invented. It is declared as `external.requirements[4]`, `kind:
filesystem`, with the exact failure above as its `unmet`.

### The second finding, also a core defect

**core's `harness/gate_check.py` cannot read a one-line `run:` step.** Its
`RUN_KEY` is

```python
RUN_KEY = re.compile(r"^(?P<indent>\s*)run:\s*(?P<block>[|>][-+]?)?\s*$")
```

which matches `run:` bare, `run: |` and `run: >-`, and **not** `run: ./bin/prime`.
The comment three lines below it says `# `run: <command>` on one line.` — the
branch that comment describes is unreachable. Both directions are demonstrated:

| Direction | Result |
| --- | --- |
| cafaye-rb's workflow as committed, `run: ./bin/prime` | `FAIL gate.ci-disagrees: .github/workflows/ci.yml never runs ./bin/prime` — a **false red** on a workflow that plainly runs the gate |
| A workflow whose only mention of the gate is a *comment* inside an unrelated block-scalar step | `OK … 0 failure(s)` — a **false green** over a repository whose CI never runs its gate |

The second one is the dangerous half and it is the same shape as everything this
packet exists to remove: the check that was supposed to catch CI drift cannot
see the most common way a CI step is written. It went unnoticed because core's
own conforming fixture happens to use `run: |`, which is the one spelling the
regex accepts.

**What I did about it, and why.** I changed one step in this repository's
workflow from `run: ./bin/prime` to `run: |` + `./bin/prime`. The command is
byte-identical and `bin/prime` is untouched — this is not a behaviour change and
not a loosened anything. It is here because the alternative was to either edit a
correct declaration into something the checker can read, or delete a correct `ci`
block, and both of those trade a real check for a green. It also *restores* the
check: before this change, cafaye-rb's gate step was structurally invisible to
`gate.ci-disagrees`, so deleting it from CI would have gone unnoticed. Once core
fixes the regex, the accommodation is unnecessary but harmless.

The fix belongs in core, in a different packet, and I have not touched it.

### One smaller note, same theme

`gate.floor` fires on **both** proofs when a `.rb` file leaves the repository:
removing `test/contract/manifest_test.rb` took the suite to 213 (floor 220) *and*
rubocop to 43 files (floor 44). The lint floor is doing a second job nobody
asked of it. It is harmless — a deletion should be deliberate — but it is worth
knowing before someone lowers it.

---

## What is in the repository

| File | What it is |
| --- | --- |
| `gate.yml` | the declaration, true of this repository, with the judgement calls written down |
| `test/gate_declaration_self_test.sh` | 22 cases: 1 control, 2 warning cases, 19 breakages |
| `.github/workflows/ci.yml` | one step's spelling changed, so the CI check can read it |
| `CHANGELOG.md`, `AGENTS.md` | the entry and the description of the repository as it now is |

### The declaration

```yaml
version: 1
name: cafaye-rb
gate:
  command: [bin/prime]
  miseTask: prime
  entrypoint: bin/prime
  timeoutSeconds: 900
  proof: [suite, lint, audit, database]      # five proofs, four of them with floors where countable
external:
  selfContained: false
  requirements: [toolchain, network ×2, database, filesystem]
ci:
  workflow: .github/workflows/ci.yml
  invokes: [./bin/prime]
```

**`miseTask: prime` needed no rename.** `mise.toml` already says
`[tasks.prime] run = "./bin/prime"`, so it resolves to the entrypoint. core had to
rename a task named `test`; this repository never had the problem.

**Every number was measured here, not copied.** Baseline and final runs agree:

```
228 runs, 652 assertions, 0 failures, 0 errors, 0 skips
coverage: 96.06% of 762 lines, 78.07% of 187 branches (floor 95%)
44 files inspected, no offenses detected
No vulnerabilities found
database ready: postgres://localhost/cafaye_test
```

| Proof | Pattern | Floor | Why this floor |
| --- | --- | --- | --- |
| `suite` | `^([0-9]+) runs, [0-9]+ assertions, 0 failures, 0 errors, 0 skips$` | 220 | 228 less a deliberate margin of 8. The margin exists because the suite grows and nothing here forces the floor up. 8 is small enough that losing any real tier trips it (the outbox tier is 48 tests, the contract tier 32) and large enough that consolidating a handful of tests does not. |
| `lint` | `^([0-9]+) files inspected, no offenses detected$` | 44 | today's file count. Checked stable between a git worktree and a plain directory copy — a count that moved with the checkout would make this proof a coin flip. |
| `audit` | `^No vulnerabilities found$` | — | reports nothing countable, which is the case the schema allows `minimum` to be omitted for. |
| `database` | `^database ready: ` | — | **deliberately not a URL.** `CAFAYE_TEST_DATABASE_URL` is a developer's to set and theirs may carry a password, so the pattern asserts the prefix and nothing more. A connection string written into a declaration is a secret at rest in every CI log that reports on it. |

Pinning `0 failures, 0 errors, 0 skips` rather than only counting runs is
load-bearing, and the self-test proves it with a control (§ below). Minitest 6
prints all five counters unconditionally (`lib/minitest.rb:981`), so this pins a
real line and not a formatting accident. And the suite has no `skip` anywhere —
I grepped — so `0 skips` is a real property of this repository, not a hope.

### The requirements, each demonstrated rather than reasoned about

`selfContained: false`, and every `unmet` is what the gate **actually printed**
when I took the thing away. A requirement whose failure mode I cannot describe is
one I deleted.

| Kind | Requirement | How it was shown to be real |
| --- | --- | --- |
| `toolchain` | ruby 4.0.1 + bundler 4.0.18, pinned | `env PATH=<empty> bash bin/prime` → `bin/prime: ruby not found on PATH — run 'mise install' in this worktree`, exit 127 |
| `network` | rubygems.org, once, cold — the 63 gems | empty gem home, network forbidden → `Could not find jwt-3.3.0, pg-1.6.3, minitest-6.0.6, …`, exit 7 |
| `network` | github.com/rubysec/ruby-advisory-db, **on every run** | `bundler-audit check --update` fetches it every time. Fetch blocked with a warm cache → `failed to update "/…/ruby-advisory-db"`, **exit 1**. An air-gapped runner is not stale here, it is red |
| `database` | PostgreSQL at `postgres://localhost/cafaye_test` | URL pointed at a port nothing listens on → `PG::ConnectionBad`, exit 1 |
| `filesystem` | core's checkout beside the repository, or `CORE_PATH` | copy to a directory with no core sibling → the failure at the top of this report |

The two network entries are separate on purpose: different host, different time,
different failure, and folding them into one line would have hidden that the
second one is not a cold-checkout cost.

**What is deliberately NOT declared:** no credential. `postgres://localhost/cafaye_test`
carries no password and CI sets `POSTGRES_HOST_AUTH_METHOD: trust`. Declaring a
credential here would be a requirement with nothing behind it.

**What `bin/prime` does correctly, and I verified rather than assumed:** it runs
`rake db:prepare`, which calls `prepare!` → `reset_schema!` → `create_tables!`, so
the outbox tables are created from this repository's own `db/outbox_events.sql` on
every run. This is the answer to identity's *1430 green tests against an empty
schema*, and it is the opposite of the finding above: the schema load is real,
and what was undeclared was a different thing.

**And here is the exact edge of what the `database` proof can see.** After that
green gate run, I asked the database whether `outbox_events` existed. It did not:

```
$ psql "postgres://localhost/cafaye_test" -c '\dt'      # only `probe` is there
$ bundle exec rake db:prepare && …                        # and the table is back
```

`test/outbox_publisher_test.rb:477` drops the table on purpose, to prove that a
publisher which cannot even claim a batch raises rather than marking rows, and it
never puts it back. Nothing is broken — the next test in that class calls
`reset_schema!` in its own `setup`, and the next gate run calls `db:prepare`, so
the gate is self-healing and reliably green. But it is the cleanest illustration
available of what `database ready:` means: it proves `rake db:prepare` ran and
connected. It does not prove the database is in a usable state afterwards, and it
would not have noticed if the suite had left it unusable. Anyone tempted to read
that proof as "the database is fine" is reading more into it than it says.

---

## The gate, with real counts

`bash`, `set -o pipefail`, `${PIPESTATUS[0]}` — not `$?` after a pipe:

```
$ bash -c 'set -o pipefail; mise run prime 2>&1 | tee …; echo "PRIME_EXIT=${PIPESTATUS[0]}"'
…
228 runs, 652 assertions, 0 failures, 0 errors, 0 skips
coverage: 96.06% of 762 lines, 78.07% of 187 branches (floor 95%)
44 files inspected, no offenses detected
No vulnerabilities found
database ready: postgres://localhost/cafaye_test
== prime ok (cafaye 0.1.0)
PRIME_EXIT=0
```

**228 passed, 0 skipped, 0 failures, 0 errors.** I am reporting the skip count
because the number is the load-bearing one here: `gate.proof` pins `0 skips`, and
without a test that skips itself there is nothing hiding inside this green. The
baseline run before I touched anything reported the same 228 / 652 / 0 / 0 / 0,
so nothing was added to or removed from the suite by this packet.

The checker, both phases:

```
$ python3 core/harness/gate_check.py .              → OK, 0 failure(s), 4 warning(s), exit 0
$ python3 core/harness/gate_check.py --prove .     → OK, 0 failure(s), 4 warning(s), exit 0
```

**4 warnings, and they are the correct answer, not a caveat to explain away.** All
four are `gate.requirement-unproven`: the toolchain, the two networks, and the
core checkout are each satisfied by a bare command on PATH, and the checker
deliberately does not run it, because "is rubygems reachable from *this* machine"
is not a question a declaration-checker can settle. It prints them and leaves the
exit code alone. There is no skipped check hiding in that green.

---

## The red proofs

```
$ bash test/gate_declaration_self_test.sh
PASS: gate_declaration_self_test — 22 passed, 0 skipped, 22 run.
      2 of those 22 passed are warning cases: they printed their finding and still exited 0.
```

**22 passed, 0 skipped.** A control runs first, because nineteen reds against a
repository nobody checked prove nothing. Each breakage asserts the *named*
finding, not "something went red", and each gets a fresh copy so one cannot mask
the next.

| # | Breakage | Caught by |
| --- | --- | --- |
| 1 | *(the control)* the unmodified declaration | `OK`, exit 0 |
| 2 | the four requirements this checker cannot settle here | `gate.requirement-unproven`, **still exit 0** |
| 3 | no `gate.yml` at all | `gate.declaration-missing` |
| 4 | `command` names a file that is not here | `gate.command-missing` |
| 5 | **`entrypoint` names a file that does not exist** | `gate.entrypoint-missing` |
| 6 | `entrypoint` is not executable | `gate.entrypoint-not-executable` |
| 7 | **`mise.toml`'s task resolves to a different file** | `gate.task-unresolvable` |
| 8 | **`ci.workflow` names a workflow not in the repository** | `gate.ci-missing` |
| 9 | **`ci` workflow that does not invoke the gate** | `gate.ci-disagrees` |
| 10 | a requirement satisfied by a file not in this repository | `gate.requirement-path-missing` |
| 11 | claims `selfContained: true` with five requirements under it | `gate.schema` |
| 12 | a proof pattern that does not compile | `gate.schema` |
| 13 | mise tasks and no `miseTask` named | `gate.task-undeclared`, still exit 0 |
| 14 | **a gate that exits 0 having run nothing** | `gate.proof-missing` |
| 15 | **a gate that runs a FAILING suite and exits 0 anyway** | `gate.proof-missing` |
| 16 | *(control for 15)* the same broken repo with the proof loosened | **`OK`, exit 0 — correctly false green** |
| 17 | a suite that quietly lost its contract tier, otherwise green | `gate.floor` |
| 18 | a test that starts skipping itself | `gate.proof-missing` |
| 19 | the linter dropped from the gate | `gate.proof-missing` |
| 20 | the audit dropped from the gate | `gate.proof-missing` |
| 21 | the database step dropped from the gate | `gate.proof-missing` |
| 22 | the floor set to 400 over a suite of 228 | `gate.floor` |

The four the packet names are 5, 7, 8/9 and 15. Breakage 3 was also built for it.

**Breakages 15 and 16 are the reason this packet is worth doing**, so here is the
whole evidence for them, from one run each:

```
# 15 — bin/prime runs `bundle exec rake test || true` over a failing test
FAIL gate.proof-missing: proof 'suite' never appeared; the gate's output contains
  no line matching '^([0-9]+) runs, [0-9]+ assertions, 0 failures, 0 errors, 0 skips$'
  gate's own log:  228 runs, 652 assertions, 1 failures, 0 errors, 0 skips
                   == prime ok (cafaye 0.1.0)

# 16 — the SAME repository, same failing suite, proof relaxed to '^([0-9]+) runs, '
OK … 0 failure(s), 4 warning(s)          exit 0
```

`gate.nonzero` does not fire in 15, because that gate's exit code really is 0 —
it printed `prime ok` over a red suite, which is the fleet's recorded defect
verbatim. The only thing standing between that and a green badge is
`0 failures, 0 errors` inside the pattern, and 16 proves that by removing exactly
those four words and watching the false green come back.

**Breakage 17 is the identity-shaped one.** Removing
`test/contract/manifest_test.rb` leaves the gate **green** — 213 runs, 0 failures,
0 errors, 96.06% coverage, `prime ok`, exit 0 — and `gate.floor` is the only thing
that says anything:

```
FAIL gate.floor: proof 'suite' reported 213 and the declaration's floor is 220
FAIL gate.floor: proof 'lint'  reported 43  and the declaration's floor is 44
```

Nothing about the gate is broken. The suite is just smaller and still says `ok`,
which is precisely the defect the floor exists to catch.

---

## What I could not verify

Mandatory section, and it is not empty.

1. **I did not run this repository's gate on a real CI runner.** I have no GitHub
   Actions runner, so "the gate is red on CI for want of a `core` checkout" is
   inferred from two things I did measure — the isolated local copy is red
   identically, and the workflow's only checkout step is this repository. The
   *mechanism* is verified; the *job* is not. A runner with a `core` directory at
   `/home/runner/work/cafaye-rb/core` would go green, and I could not test that.

2. **I could not verify the cold-checkout path at all.** Every gate run here was
   warm: the 63 gems were installed, the advisory database was cached, and the
   `cafaye_test` database existed. I demonstrated the *failure* modes of the
   network and database requirements by removing each deliberately (empty gem home
   with the network forbidden, a dead port, a dead proxy), but I never timed a
   genuinely cold `bundle install`, so `timeoutSeconds: 900` is reasoned from the
   warm 65s and from what a native `pg` build costs — not measured. **If someone
   knows a cold prime's real duration, that number should replace my guess.** It is
   the one field in `gate.yml` I could not earn.

3. **The advisory-database requirement is demonstrated only for the *failure*.**
   I proved that a blocked fetch with a warm cache exits 1, and that an empty
   advisory-db directory triggers a clone. I did not verify that github.com is the
   only host the gate reaches — a `bundle install` that decides to re-resolve, or
   a rubygems mirror configured on someone's machine, would change the list.

4. **I did not prove the tests touched the database.** `gate.proof` is a line of
   output. `database ready:` proves `rake db:prepare` ran and connected; it does
   not prove any test issued a query. Making that strong is a collect-then-run set
   diff and it is owed in `caf` as `caf gate`, by another worker. A future reader
   who wants this specific proof should know it does not exist here.

5. **The suite floor's upward ratchet is not enforced.** I set 220 against a suite
   that reports 228 and wrote the margin into the file, but nothing in this
   repository fails when the suite grows. core enforces the other direction with
   `test_the_gate_floor_is_not_below_the_suite_core_claims`; the equivalent here is
   **owed** and I did not add it, because adding a test to the gate is a change to
   what this repository's gate does, which is the one thing this packet was told
   not to do unilaterally. **This is the most likely way `gate.yml` goes stale**,
   and the manager should decide whether to add that test in a later packet.

6. **`self_test.sh` is not in CI.** The declaration's self-test
   (`test/gate_declaration_self_test.sh`) takes 90 seconds — measured, and much
   shorter than I assumed while writing it, because every copy shares one
   installed bundle — and `.github/workflows/ci.yml` does not run it. Adding that
   step is the same CI change I was told not to make. **Nineteen breakages will
   therefore only fail if somebody runs the script by hand.** core's own precedent
   is a CI step of its own (`gate_self_test.sh` is deliberately not inside
   `bin/prime`, and core's CI runs it); cafaye-rb does not have that step, and at
   90 seconds the cost of adding it is small — that gap is the first thing to
   close.

7. **The `lint` floor of 44 is coupled to RuboCop's file discovery.** I checked it
   is stable across a git worktree and a `.git`-less copy, and it does not move
   with the checkout. I did not check every Ruby version in CI's matrix
   (3.2 and 4.0), and a different RuboCop version under a different lockfile
   resolution could inspect a different number of files. **A false red on the CI
   matrix is the shape of this risk.**

8. **I did not check that `gate.yml` stays in step with `mise.toml`.** The checker
   compares the task's `run` to `gate.entrypoint`, which is the direction that
   matters, but nothing compares `mise.toml`'s `[tasks.prime] description` to
   anything. Renaming the task is caught; rewriting its description is not.

9. **The checker defect is unfixed.** My accommodation in `.github/workflows/ci.yml`
   is local to this repository. The other repositories with a one-line `run:` gate
   step — `caf`, `courier`, `darkroom`, `muse`, `parlor` all have one-line `run:`
   steps — will hit the same false red, and the false-green direction is still open
   everywhere. **I counted the one-line steps in eight fleet workflows and did not
   fix any of them, because none of them is my worktree.**

10. **I did not verify the claim in `core_specs_test.rb`'s header** — *"CI checks
    the two newest Ruby versions, one of which clones core so the real comparison
    runs there too"* — against any actual run. The workflow I read does not do it.
    That comment is now known to be false, and correcting it is a change to a
    test file this packet was not asked to touch.