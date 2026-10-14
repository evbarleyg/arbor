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
| Before every push, by itself | `make hooks`, once per clone. Git then runs the check, in every worktree and on every branch, older ones too, and gives up the push if it finds something or cannot tell |
| Before a push, by hand | `make public-check` |
| Before posting a pull request's body, an issue or a comment | `scripts/public-check.py --text body.md`, or pipe the text in |
| After every push, of a branch or a tag, and on every pull request | The workflow `Public check`, on Linux, in seconds |
| To see what the whole tree holds, old lines too | `scripts/public-check.py --tree`: an audit to read, not a gate |

It prints the place, the rule, what to write instead, and the line with the find between » and «. In GitHub Actions, whose
logs are as public as the rest, everything found is blanked out, in file and branch names too.

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
list that git was told of and that cannot be read stops the push: the check cannot tell. A workflow can be given
such words in `$PUBLIC_CHECK_WORDS`, from a secret.

No check reads for sense. "The display on the left is a 27-inch one from 2019" names nobody and still describes somebody's
desk. Nor does it read pictures, or the time zone every commit's date carries (`TZ=UTC git commit` keeps that to yourself).
The table at the top is the rule; the check is the net under it.
