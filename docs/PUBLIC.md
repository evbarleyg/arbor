# Working in public

Everything in this repository can be read, copied and indexed by anybody, from the moment it is pushed or posted, for good.
Deleting something later takes it out of sight, not out of the world. People and agents work on Arbor from machines of
their own, with notes of their own, so this page says what stays there, and what sees to it.

## What stays out

Of every file, file name, commit message, branch name, issue, pull request and comment:

| What | Write instead |
|---|---|
| A person's name | "the maintainer", "a tester", "they". The one name there is stands in `LICENSE` |
| Anything about one person's Mac: its hardware, displays, paths, settings, the apps on it; logs, traces or pictures made on it | "a tester's Mac", and only what a reader needs to reproduce the fault. Evidence comes from GitHub's hosted Macs |
| Anything about a person's days or work: where they are, when they sleep, who they work for | Times in UTC, if a time matters at all |
| Ids of and links to working sessions | Nothing. The generic `https://claude.ai/code` in a footer is fine |
| E-mail addresses | GitHub's no-reply addresses, `example.com` |
| Paths on one particular machine (`/Users/<somebody>/…`, a sandbox's folders) | `~/…`, `/Users/you/…`, a path inside the repository. A hosted runner's `/Users/runner` is nobody's |
| Internal hosts and short links | Nothing |
| What anything costs and who pays | "free hosted runners" |
| Names of models and their makers | "an agent", "Claude Code" |
| Roles and pull-request numbers of the private phase before the first public commit | What the thing does; who, in plain words ("a reviewer", "the product owner") |
| Other repositories of the same owner | Nothing |

Commits are made under a no-reply address (`git config user.email <id>+<login>@users.noreply.github.com`), and every
branch starts from a branch of `origin`: all history here goes back to the first public commit and to nothing else.

## What sees to it

`scripts/public-check.py` reads what a branch adds: lines, file names, commit messages, authors' names, its own name; of a
tag, its name, its maker and its message. It reads each new commit by itself, merges too, because what one commit adds
and the next takes out is still in the history. It also checks where the history begins and under which addresses
the commits were made.

| When | How |
|---|---|
| When a clone is new, and whenever an agent's session starts in it | `make hooks` ends with `scripts/public-clone.py`, see below. `.claude/hooks/session-start.sh` runs it in every Claude Code session |
| Before every push, by itself | `make hooks`, once per clone, and again when the check has changed. Git then runs the check, in every worktree and on every branch, and gives up the push if it finds something or cannot tell. Of the copy `make hooks` kept and the one on the branch, the newer does the reading, so a branch from before a hole was mended is read by the mended check; the exceptions are those the pushed commit itself carries, wherever the clone stands |
| Before a push, by hand | `make public-check` |
| Before posting a pull request's body, an issue or a comment | `scripts/public-check.py --text body.md`, or pipe the text in |
| After every push, of a branch or a tag, and on every pull request | The workflow `Public check`, on Linux, in seconds |
| After every post and every edit of one: issues, pull requests, comments, reviews | The workflow `Public text` (`scripts/public-text.py`), see below |
| To see what the whole tree holds, old lines too | `scripts/public-check.py --tree`: an audit to read, not a gate |

It prints the place, the rule, what to write instead, and the line with the find between » and «. In GitHub Actions, whose
logs are as public as the rest, everything found is blanked out, in file and branch names too.

As the hook, the check also keeps `main` and `swarm/trunk` of the repository itself for whoever lands work there
(`git config arbor.mayLand true` in that clone), never deleted and only ever moving forward. A fork's branches are its owner's business.

The hook has one more job, for agents who work to a brief that is kept outside the repository. A rule that changes while they are deep in
long work does not reach them by message. Beside the file of private words lies `rules-version.txt`, whose first line is a number, a
time, and a sentence on what changed. While the number differs from `git config arbor.rulesRead`, the hook refuses every push and
prints the sentence. `scripts/public-check.py --rules` asks the same before anything else that cannot be taken back. Where there is no
such file, nothing is said.

## The clone itself

A clone is not always what it seems. A machine that is handed a prepared or cached copy, or a folder in use since before the
repository was public, can hold branches, stashes and loose commits from somewhere else, under names that look right.
`git status` shows none of it. `scripts/public-clone.py` goes by where history begins: everything here goes back to the first
public commit. It reads the whole graph once, as it is and not as `git replace` or grafts make it look, and then looks at every
ref and every stash, at what `HEAD`, `FETCH_HEAD`, `MERGE_HEAD` and their like point at (in linked worktrees too), at the reflogs
entry by entry, at commits nothing points at any more, and at objects borrowed from another repository. It also says when
commits made here would carry an address that is no no-reply address.

By itself it changes nothing: deleting is for whoever knows what the thing is. `scripts/public-clone.py --remove` then takes out
what it listed as foreign through and through, and only that: those refs, those stashes, those reflog entries. Good stashes
and your own reflog stay. It ends with `git gc --prune=now`, which also drops commits of your own that no branch, stash or
reflog holds, so nothing else may be using the clone meanwhile. A branch of yours that something foreign was merged into it
never touches: it says what to do by hand. When in doubt, a fresh clone of the public repository is always clean.

## What is posted

Nothing can read a post before it is public, so `Public text` reads it right after, and again at every edit. It reads the
whole thread each time.

- **A link to a working session becomes the generic link**, in place and without a word. Some platforms append such a
  link to every pull request they create. It is the one edit the workflow makes to anybody's text. The earlier wording stays
  in the post's edit history (the "edited" menu), where only a person with the right to can delete it, and an earlier title stays
  in the thread's "changed the title" line for good; so it is still better not to post the link in the first place.
- **Everything else is named in one comment on the thread**: which post, which line, what to write instead, never the words
  themselves. Edit the post in place. The comment changes as things are reworded and goes away when nothing is left.
- **While a pull request's own title or description holds something, its check `public-text` is red.** For comments, reviews and
  issues the comment is the only sign: a run they start counts for the newest commit on `main`, which has nothing to do with it.
- Those who work on the repository, and the apps that post for them, are held to all the rules. Anybody else is only told of
  what would give away something of their own: an address, a path with their name in it, a session.
- Once a night it reads every thread that changed in the last day, for what no event brought to it: a review on a pull
  request from a fork, where the token may only read, or a run that failed.

It is not told of commit comments, discussions, the wiki or the text of releases. `scripts/public-text.py --all --dry-run`
reads every thread there is and changes nothing.

The workflow holds a token that may edit what people wrote, and anybody can start it by posting. Its header says what
keeps that safe: nothing of a pull request is checked out, what was posted reaches it as data only, and what it quotes back
stands in a code span. It takes effect from the default branch, so a change to it works once it is on `main`.

## When it finds something

1. **Not committed, or committed and not pushed:** reword, and make the commit again (`git commit --amend`,
   `git rebase -i`). A further commit on top does not help.
2. **Pushed, on a branch of your own:** the same, then `git push --force-with-lease`. It is out of sight then, though
   whoever has the commit's id can still fetch it for a while. Say so in the pull request if it matters.
3. **On `main` or `swarm/trunk`:** reword at the tip, and tell the maintainer what it was and where. History there is
   not rewritten.
4. **It is wrong:** an honest exception gets a line in `scripts/public-check.allow`, with its reason above it. Keep it
   narrow: one rule, one file, one word if possible. A rule that cries too often is better changed, with a row in
   `scripts/test-public-check.py` for what it should have left alone.

## How the lists give nothing away

A list of forbidden words would itself be the leak, and so would a list of their hashes: the words in question are short, and
short words can be tried out one after the other until the hashes match. So there is no such list. The rules name kinds
of things, not things:

- not "these hosts are internal" but "any host this repository has not linked to before"; the public ones it needs are
  in the allow list;
- not a name but "the name in `LICENSE`", read from there when the check runs;
- not this or that sandbox's folders but "any home folder other than a hosted runner's";
- not the name of a repository but "any repository of this owner's other than this one";
- this very machine's own host name, home folder, ids, addresses, tokens and keys, read from its environment when the
  check runs, and so never written down anywhere.

Words that no kind covers go in a plain file outside the repository, one to a line, named with
`git config arbor.privateWords <path>`. They are looked for in that clone only, wherever they stand, whatever their case. A
list that git was told of and that cannot be read stops the push: the check cannot tell. `Public text` can be given such
words in a secret, `PUBLIC_CHECK_WORDS`. It looks for them only in what those who work here post, and then names the post and
nothing more: if it answered strangers, anybody could post guesses and read the list off the answers.

No check reads for sense. "The display on the left is a 27-inch one from 2019" names nobody and still describes somebody's
desk. Nor does it read pictures, or the time zone every commit's date carries (`TZ=UTC git commit` keeps that to yourself).
The table at the top is the rule; the check is the net under it.
