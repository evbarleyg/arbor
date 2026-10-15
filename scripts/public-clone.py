#!/usr/bin/env python3
"""Looks through this clone for history that is not the public repository's, and can take it out.

A clone is not always what it seems. A machine that is handed a prepared or cached copy, or a folder that has been in use since
before the repository was public, can hold branches, stashes and loose commits from somewhere else, under names that
look right. `git status` shows none of it. One `git push`, one merge, one cherry-pick from the wrong name, and it is public.
scripts/public-check.py would refuse that push; this finds the stuff before anybody trips over it.

It goes by where history begins. Everything here goes back to the first public commit; whatever goes back to another
beginning is foreign. It reads the whole graph once, as it is and not as `git replace` or a file of grafts makes it look, and
then looks at

  names     every branch, tag, remote-tracking ref and other ref, each stash, and what HEAD, FETCH_HEAD, MERGE_HEAD and their like point
            at, here and in linked worktrees;
  memories  the reflogs, entry by entry, which keep what a deleted branch pointed at;
  leftovers commits that nothing points at any more, which stay in the clone until git tidies up;
  the rest  objects borrowed from another repository, replace refs and grafts, repositories and bundles lying inside .git.

Two kinds of commit are meant to have no history, and are let be as long as nothing is built on them: the output of a Mac shell run, and the
commit `git stash --include-untracked` keeps untracked files in. Both must be younger than the first public commit. An output is known by who
made it (the workflow), by how it begins ("mac-shell: "), or by where it lies: on a branch `mac-shell-out/*` of a remote that fetches from the
public repository, going by the clone's record of that remote and that record's reflog. Whoever put it there, it is public already. (The record
does not say which address it was fetched from: one commit without parents, younger than the first public commit, fetched under that name before the
remote's address was changed, passes.) The record goes when the branch is pruned, and what it vouched for is then a leftover like any other.

It also says when commits made here would carry an address that is no no-reply address.

Without an argument it changes nothing. With --remove it takes out what it listed as foreign through and through, and only that: those
refs, those stashes, those reflog entries; worktrees that stand on them are moved to origin's trunk; operations that are
half done with them are called off. Then it has git drop every object nothing points at (`git gc --prune=now`). That last step is not
choosy: commits of your own that no branch, stash or reflog holds go too, so no other git command may be running in the
clone meanwhile. What is part public and part foreign (a branch of yours that something foreign was merged into) it never touches:
it says what to do by hand. When in doubt, a fresh clone of the public repository is always clean.

It does not look into the index or at files in the working tree.

Usage: scripts/public-clone.py [--remove]    `make hooks` runs it, and so does the hook that starts an agent's session (.claude/hooks)
Exit code 0 when the clone is clean, 1 when something was found (with --remove: is left), 2 when it could not tell.
scripts/test-public-clone.py holds it to a table of situations; `make lint` runs that.
"""

import glob
import importlib.util
import os
import re
import shlex
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("public_check", os.path.join(HERE, "public-check.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)

OUTPUT_AUTHOR = "mac-shell@users.noreply.github.com"
OUTPUT_SUBJECT = "mac-shell: "
OUTPUT_BRANCHES = "mac-shell-out/"
# Put over two outputs on the public repository before anybody had written down how such a commit begins, and fetched by many clones since.
KNOWN_OUTPUTS = {"2df081ad58dc8bfb59b89b8eb29babd5bfbf0f11"}
# The whole of the address git fetches from. (public-check.py's own pattern is looser: there a wrong match only makes it stricter.)
PUBLIC_ADDRESS = re.compile(r"(https://([^/@?#\\]*@)?|(ssh://)?git@)(ssh\.)?github\.com(:\d+)?[:/]+evbarleyg/arbor(\.git)?/?", re.IGNORECASE)
UNTRACKED_SUBJECT = "untracked files on "
# What each stands for, and how the operation it belongs to is called off; None: the file is only a note, and can go.
PSEUDO = {"FETCH_HEAD": None, "ORIG_HEAD": None, "AUTO_MERGE": None, "MERGE_HEAD": ("merge", "--abort"), "CHERRY_PICK_HEAD": ("cherry-pick", "--abort"),
          "REVERT_HEAD": ("revert", "--abort"), "BISECT_HEAD": ("bisect", "reset")}
PER_WORKTREE = ("refs/bisect", "refs/worktree", "refs/rewritten")
PUBLIC, FOREIGN, MIXED, LONE = "public", "foreign", "mixed", "lone"
LISTED_AT_MOST = 12
NOT_PUBLIC = "does not go back to the first public commit"


class Found:
    """One thing that was found. `remove` takes it out, or is None where that is for a person; `by_hand` says how."""

    def __init__(self, what, remove=None, by_hand=None, is_history=True):
        self.what, self.remove, self.by_hand, self.is_history = what, remove, by_hand, is_history


class Clone:
    def __init__(self, top):
        self.top = top
        self.common = os.path.realpath(os.path.join(top, self.git("rev-parse", "--git-common-dir").strip()))
        self.parents, self.kinds, self.untracked, self.outputs = {}, {}, set(), set()
        # Each worktree: the folder git keeps its HEAD in, and where it is.
        self.worktrees = [(self.common, os.path.dirname(self.common) if os.path.basename(self.common) == ".git" else None)]
        for folder in sorted(glob.glob(os.path.join(self.common, "worktrees", "*"))):
            try:
                with open(os.path.join(folder, "gitdir"), encoding="utf-8") as handle:
                    where = os.path.dirname(handle.read().strip())
            except OSError:
                where = None
            self.worktrees.append((folder, where if where and os.path.isdir(where) else None))

    def git(self, *arguments, where=None, **more):
        return check.git(*arguments, cwd=where or self.top, **more)

    def read_graph(self, tips):
        """Every commit the tips lead back to, with its parents, in one go; and what the ones without parents are."""
        listed = self.git("rev-list", "--parents", "--stdin", said="".join(f"{tip}\n" for tip in sorted(tips)))
        for line in listed.splitlines():
            sha, *parents = line.split()
            self.parents[sha] = parents
        roots = [sha for sha, parents in self.parents.items() if not parents]
        born = int(self.git("log", "--no-walk", "--format=%ct", check.ROOT_COMMIT).strip())
        described = self.git("log", "--no-walk=unsorted", "--stdin", "--format=%H%x00%ae%x00%ct%x00%s", said="".join(f"{root}\n" for root in roots))
        for line in described.splitlines():
            sha, address, made, subject = line.split("\0", 3)
            is_output = address == OUTPUT_AUTHOR or subject.startswith(OUTPUT_SUBJECT) or sha in self.outputs
            if subject.startswith(UNTRACKED_SUBJECT):
                self.untracked.add(sha)
            self.kinds[sha] = PUBLIC if sha == check.ROOT_COMMIT else LONE if (is_output or sha in self.untracked) and int(made) >= born else FOREIGN

    def kind(self, tip):
        """Where a commit's history begins: at the first public commit, elsewhere, both, or with itself where that is as it should be."""
        stack = [tip]
        while stack:
            sha = stack[-1]
            if sha in self.kinds:
                stack.pop()
                continue
            unknown = [parent for parent in self.parents[sha] if parent not in self.kinds]
            if unknown:
                stack += unknown
                continue
            parents = self.parents[sha]
            if len(parents) == 3 and parents[2] in self.untracked and self.kinds[parents[2]] == LONE:
                parents = parents[:2]  # a stash, and the untracked files that go with it
            # Whatever is built on a commit that is meant to stand alone has a beginning it should not have.
            kinds = {FOREIGN if self.kinds[parent] == LONE else self.kinds[parent] for parent in parents}
            self.kinds[sha] = kinds.pop() if len(kinds) == 1 else MIXED
            stack.pop()
        return self.kinds[tip]

    def is_fine(self, sha):
        return self.kind(sha) in (PUBLIC, LONE)


def look(top):
    """Everything that was found, in the order to remove it in."""
    clone = Clone(top)
    git, quoted = clone.git, shlex.quote
    if git("rev-parse", "--is-shallow-repository").strip() == "true":
        raise check.Unclear("this clone is shallow, so nobody can tell where its history begins: git fetch --unshallow origin")
    if git("cat-file", "-e", check.ROOT_COMMIT + "^{commit}", check=False)[0] != 0:
        raise check.Unclear(f"the first public commit, {check.ROOT_COMMIT[:8]}, is not in this clone at all: is it a clone of this repository? git fetch origin")
    found = []

    # What makes history look other than it is, or hides where objects come from. Named first: all else depends on it.
    alternates = os.path.join(clone.common, "objects", "info", "alternates")
    if os.path.exists(alternates) or os.environ.get("GIT_ALTERNATE_OBJECT_DIRECTORIES"):
        found.append(Found("this clone borrows objects from another repository on this disk, so nobody can tell what is its own",
                           by_hand=f"git repack -a -d && rm {quoted(alternates)}   # and unset GIT_ALTERNATE_OBJECT_DIRECTORIES"))
    grafts = os.path.join(clone.common, "info", "grafts")
    if os.path.exists(grafts):
        found.append(Found("a file of grafts makes history look other than it is", by_hand=f"rm {quoted(grafts)}"))
    for inside, what in [("modules", "a repository of its own lies inside .git (a submodule's)"), ("*.bundle", "a bundle of commits lies inside .git")]:
        for path in sorted(glob.glob(os.path.join(clone.common, inside))):
            found.append(Found(f"{what}, which this does not look into: {os.path.relpath(path, clone.common)}", by_hand=f"rm -rf {quoted(path)}   # if it is not this repository's"))

    # Everything that points at a commit: what it is called, the commit, and how to be rid of it.
    def commit_of(name, where=None):
        code, sha = git("rev-parse", "--quiet", "--verify", name + "^{commit}", where=where, check=False)
        return sha.strip() if code == 0 else None

    refs, odd = {}, []
    for folder, where in clone.worktrees:
        own = [] if folder == clone.common else list(PER_WORKTREE)  # which only that worktree can see
        if folder != clone.common and not where:
            continue
        for line in git("for-each-ref", "--format=%(refname) %(objecttype) %(objectname)", *own, where=where).splitlines():
            ref, kind, sha = line.split()
            sha = sha if kind == "commit" else commit_of(ref, where)
            if ref.startswith("refs/replace/"):
                odd.append(Found(f"{ref} makes history look other than it is", lambda ref=ref: git("update-ref", "-d", ref)))
            elif sha is None:
                odd.append(Found(f"{ref} points at no commit, so nobody can tell where it is from", by_hand=f"git update-ref -d {quoted(ref)}"))
            elif ref != "refs/stash":
                refs[(ref, where if own else None)] = sha
    heads, pseudo = [], []
    for folder, where in clone.worktrees:
        name = "" if folder == clone.common else os.path.relpath(folder, clone.common) + "/"
        for file in ["HEAD", *PSEUDO]:
            try:
                with open(os.path.join(folder, file), encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
            except OSError:
                continue
            shas = [sha for sha in re.findall(r"^([0-9a-f]{40,64})\b", text, re.MULTILINE) if commit_of(sha)]
            on_branch = re.match(r"^ref: (refs/heads/\S+)", text)
            if file == "HEAD":
                heads.append((name + file, where, on_branch.group(1) if on_branch else None, shas))
            elif shas:
                pseudo.append((name + file, where, os.path.join(folder, file), PSEUDO[file], shas))
    remembered = []  # (where to say it, "ref@{n}", commit)
    for folder, where in clone.worktrees:
        if folder == clone.common or where:
            selection = ["--all", "HEAD"] if folder == clone.common else ["HEAD"]
            for line in git("log", "--walk-reflogs", "--format=%gD %H", *selection, "--", where=where, check=False)[1].splitlines():
                entry, sha = line.rsplit(" ", 1)
                remembered.append((where, entry, sha))
    fsck = git("fsck", "--unreachable", "--no-reflogs", "--no-progress", "--connectivity-only", check=False)[1]
    loose = re.findall(r"^unreachable commit ([0-9a-f]+)$", fsck, re.MULTILINE)

    remotes = git("remote").splitlines()
    theirs = tuple(f"refs/remotes/{name}/{OUTPUT_BRANCHES}" for name in remotes if PUBLIC_ADDRESS.fullmatch(git("remote", "get-url", name, check=False)[1].strip())
                   and not any(other.startswith(name + "/") for other in remotes))  # whose branches would lie among this one's
    clone.outputs = KNOWN_OUTPUTS | {sha for (ref, _), sha in refs.items() if ref.startswith(theirs)} | {sha for _, entry, sha in remembered if entry.startswith(theirs)}
    clone.read_graph({check.ROOT_COMMIT, *refs.values(), *loose, *(sha for _, _, sha in remembered),
                      *(sha for _, _, _, shas in heads for sha in shas), *(sha for *_, shas in pseudo for sha in shas)})
    found += odd

    safe = next((ref for ref in ("refs/remotes/origin/swarm/trunk", "refs/remotes/origin/main") if (ref, None) in refs and clone.kind(refs[(ref, None)]) == PUBLIC),
                check.ROOT_COMMIT)
    foreign_refs = {ref for (ref, _), sha in refs.items() if clone.kind(sha) == FOREIGN}

    for name, where, path, call_off, shas in pseudo:
        if not all(clone.is_fine(sha) for sha in shas):
            if call_off and where:
                found.append(Found(f"{name}: a {call_off[0]} is half done with history that {NOT_PUBLIC}", lambda where=where, call_off=call_off: git(*call_off, where=where)))
            else:
                found.append(Found(f"{name} points at history that {NOT_PUBLIC}", lambda path=path: os.remove(path)))
    for name, where, branch, shas in heads:
        if branch in foreign_refs or not all(clone.is_fine(sha) for sha in shas):
            if any(clone.kind(sha) == MIXED for sha in shas):
                found.append(Found(f"{name} stands on history that is part public, part not", by_hand=f"git -C {quoted(where or top)} checkout --detach {safe}"))
            elif where:
                found.append(Found(f"{name} stands on history that {NOT_PUBLIC}" + (f" ({branch})" if branch else ""),
                                   lambda where=where: git("checkout", "--quiet", "--detach", safe, where=where)))
    for (ref, where), sha in sorted(refs.items(), key=lambda item: item[0][0]):
        if clone.kind(sha) == FOREIGN:
            count = git("rev-list", "--count", sha, "--").strip()
            found.append(Found(f"{ref}: {count} commits, none of which goes back to the first public commit", lambda ref=ref, where=where: git("update-ref", "-d", ref, where=where)))
        elif clone.kind(sha) == MIXED:
            found.append(Found(f"{ref}: part of its history goes back to the first public commit and part does not: something foreign was merged in",
                               by_hand=f"# bring what is yours over as patches you have read, onto a branch from origin's; then: git update-ref -d {quoted(ref)}"))
    # Highest number first: taking out an entry renumbers the ones above it.
    number = lambda entry: int(re.search(r"@\{(\d+)\}$", entry[1]).group(1))
    unfit = sorted((entry for entry in remembered if not clone.is_fine(entry[2])), key=number, reverse=True)
    for where, entry, _ in [entry for entry in unfit if entry[1].startswith(("refs/stash@", "stash@"))]:
        found.append(Found(f"{entry}: a stash made on history that {NOT_PUBLIC}", lambda where=where, entry=entry: git("stash", "drop", "--quiet", entry, where=where)))
    others = [entry for entry in unfit if not entry[1].startswith(("refs/stash@", "stash@"))]
    if others:
        def forget():
            for where, entry, _ in others:
                # Rewriting: the entry above also notes where it came from, and git keeps alive what a reflog so much as mentions.
                git("reflog", "delete", "--rewrite", entry, where=where, check=False)  # (a ref's own log has gone with the ref)
        found.append(Found(f"{len(others)} entries of the reflogs remember history that {NOT_PUBLIC}", forget))
    strays = [sha for sha in loose if not clone.is_fine(sha)]
    if strays or foreign_refs or unfit:
        what = f"{len(strays)} commits that nothing points at any more do not go back to the first public commit" if strays \
            else "once the names are gone the commits are still in the clone, until git tidies up"
        found.append(Found(what, lambda: git("gc", "--quiet", "--prune=now")))
        if git("config", "--get-regexp", r"^remote\..*\.promisor$", check=False)[1].strip() or glob.glob(os.path.join(clone.common, "objects", "pack", "*.keep")):
            found.append(Found("this is a partial clone, or has packs marked to be kept: git never drops objects from those", by_hand="# make a fresh clone, and bring your work over as patches"))

    for who in ("GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT"):
        code, ident = git("var", who, check=False)
        address = re.search(r"<([^>]*)>", ident)
        if code != 0 or not address or not check.NO_REPLY.match(address.group(1)):
            found.append(Found("commits made here would carry an address that is no no-reply address, or one git makes up from this machine's names", is_history=False,
                               by_hand="git config user.name <login> && git config user.email <id>+<login>@users.noreply.github.com   # and unset GIT_AUTHOR_EMAIL, GIT_COMMITTER_EMAIL"))
            break
    return found


def say(found):
    print("public-clone: THIS CLONE HOLDS WHAT MUST NOT BE PUSHED, MERGED OR COPIED FROM. Found:" if any(one.is_history for one in found) else "public-clone: found:")
    for one in found[:LISTED_AT_MOST]:
        print(f"  ✘ {one.what}")
    if len(found) > LISTED_AT_MOST:
        print(f"  ✘ and {len(found) - LISTED_AT_MOST} more")
    if any(one.remove for one in found):
        print("To take out what is foreign through and through, and only that, having looked at what it is:\n    scripts/public-clone.py --remove\n"
              "It ends with `git gc --prune=now`, which also drops commits of your own that no branch, stash or reflog holds: nothing else may be using the clone meanwhile.")
    by_hand = [one.by_hand for one in found if one.by_hand]
    if by_hand:
        print("For you to do by hand:")
        for how in by_hand[:LISTED_AT_MOST]:
            print(f"    {how}")
    print("When in doubt, a fresh clone of the public repository is always clean. Branch only from a branch of origin: git checkout -b <name> origin/swarm/trunk")


def main(arguments=(), cwd=None):
    if [argument for argument in arguments if argument != "--remove"]:
        print(__doc__)
        return 2
    try:
        top = check.git("rev-parse", "--show-toplevel", cwd=cwd).strip()
        found = look(top)
        if "--remove" in arguments and any(one.remove for one in found):
            for one in found:
                if one.remove:
                    try:
                        one.remove()
                        print(f"removed: {one.what}")
                    except (check.Unclear, OSError) as error:
                        print(f"COULD NOT remove: {one.what}: {error}")
            found = look(top)
    except check.Unclear as error:
        print(f"public-clone: cannot tell: {error}")
        return 2
    if not found:
        print("public-clone: all history in this clone goes back to the first public commit")
        return 0
    say(found)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
