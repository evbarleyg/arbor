# The repository's settings

Arbor's repository is public, and agents do most of the work in it. What can be kept in files is kept in files, where it is
reviewed and tested like code. This page is about the rest: the switches on GitHub's settings pages, which only somebody
with admin rights can see or change. It says what each should be, why, and what happens if it is left alone. Agents
neither change these nor ask for them one at a time. The whole list is one sitting of about ten minutes, **once this page is on
`main`**: two of the switches break every run if they are set before the files they go with are there, and say so.

## What files already see to

| Rule | Where |
|---|---|
| Every action is named by a commit's full id | `scripts/lint-workflows.py`, part of `make lint`; `--pin` rewrites; `--verify`, in the workflow `Public check` wherever a push touches a workflow, asks the action's own repository |
| The pins are kept current | `.github/dependabot.yml`: one pull request a week at most, against `swarm/trunk`. GitHub reads that file on `main` only, so it starts once it is there. The first pull request will jump several major versions at once: read it like any other |
| Free hosted runners only, never `self-hosted` | `scripts/lint-workflows.py` |
| Every job has a time limit | `scripts/lint-workflows.py` |
| Every workflow says what its token may do, and the top of it grants nothing that writes | `scripts/lint-workflows.py` |
| Nothing people can type is written into a command | `scripts/lint-workflows.py` |
| A workflow that holds a token that can write checks out nothing of a pull request | `scripts/lint-workflows.py` |
| Nothing private in what is pushed or posted | `docs/PUBLIC.md` |
| A Mac runs only when it can prove something new | `scripts/ci-changes.py` |

So most of the switches below are a second lock on a door that is already shut. They matter because a file can be
changed by a pull request, and a setting cannot.

## The switches

In order of what they are worth. "If left" says what the default means in practice.

### Settings → Actions → General

| Switch | Should be | Why | If left |
|---|---|---|---|
| Approval for running fork pull request workflows from contributors | **Require approval for all external contributors** | A stranger's pull request starts CI, Macs included, and runs its own version of the workflows: it can take the time limits out. Its token can only read, but it can hold all the hosted Macs for hours, as often as it likes. (`Public text` runs regardless: it is started by `pull_request_target`, which no approval holds back, and runs nothing of the pull request's) | First-time contributors need approval, anybody who has had one pull request merged does not |
| Workflow permissions | **Read repository contents and packages permissions** | What a workflow gets when it says nothing. Every workflow here says something, and the lint insists | Repositories made since 2023 have this already; older accounts may still default to read and write |
| Allow GitHub Actions to create and approve pull requests | **Off** | No workflow here needs it, and an approval by a workflow is worth nothing | Off by default |
| Actions permissions | **Allow owner's, and select non-owner's, actions**: tick "Allow actions created by GitHub", nothing else | Only `actions/*` are used. A pull request that brings in some other action then fails at once | Any action from anywhere may run |
| Require actions to be pinned to a full-length commit SHA | **On, but only after the pins are on `main` and `swarm/trunk`** | The lint's first rule, kept by GitHub itself. Set earlier, every run fails at its start. Branches from before the pins fail until they are rebased, Mac shell runs on them too | Off |
| Artifact and log retention | **14 days** | Evidence that matters is committed or judged within the day | 90 days |
| Runners (Settings → Actions → Runners) | **None** | See "never `self-hosted`" above | None |

### Settings → Rules → Rulesets

Work is landed by fast-forward push: a branch is rebased, checked, and then `main` or `swarm/trunk` is moved forward to that very
commit. GitHub marks the pull request as merged by itself. The merge button is not used, because it makes a commit of its
own under whatever address the account that presses it has on file. So the rules must not demand the button.

| Ruleset | Should be | Why | If left |
|---|---|---|---|
| `protect main` (exists: **Restrict deletions**, **Block force pushes**, on the default branch) | Add `swarm/trunk` to its targets | History there is never rewritten, and everybody's branches start from it | `swarm/trunk` can be deleted or rewritten by anybody who may push |
| The same ruleset | Do **not** add "Require a pull request before merging". "Require linear history" is fine | The first would refuse every fast-forward push | |
| A second ruleset, target `main` only, later | **Require status checks to pass**: `public-check` and the Linux job, with GitHub Actions as the expected source | A ruleset applies all its rules to all its targets, hence a second one. GitHub's pages say of branch protection that a commit which has passed may be pushed, which is what a landing is; for rulesets that is an inference, so try it with one landing. Nothing red could reach `main` then. Worth doing once the names of the jobs have settled: a required check that no longer exists blocks everything, and so does a commit that was never a pull request's head | Only care keeps red commits off `main` |
| A new one for tags, target `v*` | **Restrict updates**, **Restrict deletions** | A release's tag must go on meaning the commit it was built from | A tag can be moved |
| No ruleset for all branches | | `mac-shell-out/*` is written with force and pruned by workflows, and authors rewrite their own branches | |

### Settings → Advanced Security (Code security)

| Switch | Should be | Why | If left |
|---|---|---|---|
| Secret scanning, and **Push protection** | **On** | Free for public repositories. Refuses a push that holds a key of a known make, which `public-check` does not look for | Scanning is on for public repositories; push protection may be off |
| Private vulnerability reporting | **On** | Gives a finder somewhere to write other than a public issue | Off |
| Dependabot alerts | As it is | There are no dependencies but the actions, and GitHub raises alerts for actions only where they are named by version, not by commit. The weekly update is what keeps them mended | |
| Dependabot version updates | Nothing to switch: `.github/dependabot.yml` on `main` is the switch | | |
| Code scanning → Default setup, language **GitHub Actions** only | **On** | Reads the workflows for the faults the lint looks for and more, on Linux. Not Swift: that analysis needs a Mac for every run, so look again if GitHub adds the language by itself. It covers `main` and pull requests into it, not those from forks | Off |

### Settings → General

| Switch | Should be | Why | If left |
|---|---|---|---|
| Automatically delete head branches | **On, after `swarm/trunk` is in the ruleset above** | Fewer stale branches. `swarm/trunk` is itself the head of the pull request into `main`; a rule against deletion protects it. Whether this fires at all for a pull request that was landed by a push is not written anywhere; a nightly workflow prunes what it misses | Off |
| Allow merge commits, Allow squash merging | **Off**; "Allow rebase merging" stays on only because one of the three must | The button is not how work lands, whichever kind: rebasing by button also makes new commits, with whoever presses it as committer. Fewer kinds, fewer ways to slip | A press of the button makes a commit under the presser's address |
| Wikis, Discussions, Projects | **Off** unless used | Nothing reads what is written there for private things | Wikis and Discussions are off |

### Each account that can push: github.com → Settings → Emails

| Switch | Should be | Why |
|---|---|---|
| Keep my email addresses private | **On** | Web edits and merges are then made under the no-reply address |
| Block command line pushes that expose my email | **On** | GitHub itself refuses a push with that account's real address in a commit |

### Secrets

None are needed. One is optional: `PUBLIC_CHECK_WORDS`, words that no rule of `scripts/public-check.py` covers, one to a line, for the
workflow that reads what is posted (`docs/PUBLIC.md`). Whoever can push here can read a secret through a workflow of their own.

## What only a person can do

- Delete a revision from a post's edit history (the "edited" menu on the post). An edit takes words out of sight; the earlier
  wording stays there for anybody who looks.
- Ask GitHub Support to purge a commit that was pushed and then rewritten away. Until then whoever has its id can fetch it.

## What anybody can look at

Most of this cannot be read without admin rights. These can:

```bash
gh api repos/evbarleyg/arbor --jq '{visibility, default_branch, has_wiki, has_discussions, delete_branch_on_merge, allow_merge_commit, allow_squash_merge}'
gh api repos/evbarleyg/arbor/rules/branches/main --jq '[.[].type]'
gh api repos/evbarleyg/arbor/rules/branches/swarm%2Ftrunk --jq '[.[].type]'
gh api repos/evbarleyg/arbor/private-vulnerability-reporting
```
