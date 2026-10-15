#!/usr/bin/env python3
"""Holds public-clone.py to a table of situations, each a small clone made for the purpose.

Where it finds something, `--remove` is run, then whatever it left to be done by hand, as printed, and it must find nothing
afterwards: a way out that does not lead out is worse than none. And what is good must still be there: a tool that tidies away a
person's stashes along with the foreign branch is worse than the foreign branch.

`make lint` runs this. Exit code 1 when a row comes out wrong.
"""

import contextlib
import importlib.util
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile

import side_by_side

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(HERE, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


clone = load("public-clone")
made = load("test-public-check")  # for its small repositories
GOOD, BAD = made.GOOD, made.BAD
# Each situation makes a repository of its own: they are played side by side.
table = side_by_side.Table()
row = table.row


def look(repository, *arguments, cwd=None):
    """Exit code and output."""
    saved, clone.check.ROOT_COMMIT = dict(os.environ), repository.root
    os.environ.clear()
    os.environ.update(repository.environment)
    output = io.StringIO()
    try:
        with contextlib.redirect_stdout(output):
            code = clone.main(arguments, cwd=cwd or repository.path)
    except SystemExit as left:  # it gives its verdict back; one that walks out with it, 0 above all, must not end this test as well
        code = f"it left by sys.exit({left.code})"
    finally:
        os.environ.clear()
        os.environ.update(saved)
    return code, output.getvalue()


def by_hand(repository, output):
    """Runs what it left for a person, as a person would paste it."""
    for command in re.findall(r"^    (\S.*)$", output.split("For you to do by hand:")[-1], re.MULTILINE) if "For you to do by hand:" in output else []:
        command = command.replace("# bring what is yours over as patches you have read, onto a branch from origin's; then: ", "")
        subprocess.run(command, shell=True, cwd=repository.path, env=repository.environment, capture_output=True, check=False)


def fresh(folder):
    repository = made.Repository(folder)
    repository.git("config", "user.email", GOOD)
    repository.git("config", "user.name", "someone")
    repository.git("push", "--quiet", "origin", "main:swarm/trunk")
    repository.git("fetch", "--quiet", "origin")
    return repository


@table.later
def situation(what, expected, prepare, mentions=(), still=None):
    """Code before; what of `mentions` was not said; the code after --remove and the rest by hand (None where nothing was found);
    and, where `still` is given, whether what is good is still there."""
    with tempfile.TemporaryDirectory() as folder:
        try:
            repository = fresh(folder)
            prepare(repository)
            code, output = look(repository)
            missing = [words for words in mentions if words not in output]
            after = None
            if code == 1:
                _, removed = look(repository, "--remove")
                by_hand(repository, removed)
                after = look(repository)[0]
            row(what, (code, missing, after) + ((still(repository),) if still else ()), expected)
        except Exception as error:  # a git that behaves otherwise, say: that is this row red, and the others still have their say
            row(what, f"{type(error).__name__}: {error}", expected)


def elsewhere(r, name="swarm/trunk", back="fix/something", **who):
    """A branch with history of its own, as a cached copy of another repository would leave it."""
    r.git("checkout", "--quiet", "--orphan", name)
    r.commit("history from somewhere else", **who)
    r.commit("more of it", **who)
    if back:
        r.git("checkout", "--quiet", back)


FOUND, CLEAN = (1, [], 0), (0, [], None)


def main():
    situation("a fresh clone", CLEAN, lambda r: None)

    situation("a local branch from somewhere else, under a name that looks right", FOUND, elsewhere,
              ["refs/heads/swarm/trunk: 2 commits", "scripts/public-clone.py --remove", "MUST NOT BE PUSHED", "fresh clone"])
    situation("the same, checked out", FOUND + ("HEAD",), lambda r: elsewhere(r, back=None), ["HEAD stands on history"],
              still=lambda r: r.git("rev-parse", "--abbrev-ref", "HEAD"))

    def detached(r):
        elsewhere(r)
        r.git("checkout", "--quiet", "--detach", "swarm/trunk")
        r.git("branch", "-D", "swarm/trunk")
    situation("no name at all: HEAD itself stands on it", FOUND, detached, ["HEAD stands on history"])

    def deleted(r):
        elsewhere(r)
        r.git("branch", "-D", "swarm/trunk")
    situation("the branch is deleted, and the reflogs remember it", FOUND, deleted, ["entries of the reflogs remember"])

    def forgotten(r):
        deleted(r)
        r.git("reflog", "expire", "--expire=now", "--all")
    situation("the reflogs have forgotten it, and the commits are still there", FOUND, forgotten, ["2 commits that nothing points at"])

    def other_refs(r):
        elsewhere(r, name="other")
        for ref in ("refs/tags/v0", "refs/remotes/origin/old", "refs/remotes/archive/main", "refs/original/x", "refs/notes/y", "refs/bisect/bad"):
            r.git("update-ref", ref, "other")
        r.git("tag", "--annotate", "--message", "a tag with a message", "v1", "other")
        r.git("tag", "--annotate", "--message", "a tag of that tag", "v2", "v1")
    situation("tags, a tag of a tag, remote-tracking refs and refs of other kinds", FOUND, other_refs,
              ["refs/tags/v0", "refs/tags/v1", "refs/tags/v2", "refs/remotes/origin/old", "refs/remotes/archive/main", "refs/original/x", "refs/notes/y", "refs/bisect/bad"])

    def old_folder(r):
        # In use since before: origin's own branches, as this clone remembers them, are from somewhere else.
        elsewhere(r, name="other", back=None)
        for ref in ("refs/remotes/origin/swarm/trunk", "refs/remotes/origin/main", "refs/heads/main"):
            r.git("update-ref", ref, "other")
    situation("origin's trunk itself, as this clone remembers it, with HEAD on it", FOUND + (True,), old_folder,
              still=lambda r: r.git("rev-parse", "HEAD") == r.root)

    def tag_of_a_file(r):
        r.git("tag", "a-file", r.git("hash-object", "-w", "LICENSE"))
    situation("a tag of a file: nobody can tell where that is from", FOUND, tag_of_a_file, ["refs/tags/a-file points at no commit"])

    def fetched(r):
        elsewhere(r, name="other")
        other = os.path.join(os.path.dirname(r.path), "other.git")
        subprocess.run(["git", "init", "--quiet", "--bare", other], check=True, env=r.environment)
        r.git("push", "--quiet", other, "other")
        r.git("branch", "-D", "other")
        r.git("reflog", "expire", "--expire=now", "--all")
        r.git("gc", "--quiet", "--prune=now")
        r.git("fetch", "--quiet", other, "other")
    situation("fetched from somewhere else without giving it a name", FOUND, fetched, ["FETCH_HEAD points at history"])

    situation("a name a shell would trip over", FOUND, lambda r: elsewhere(r, name="it's;odd$(name)&x"))

    def many(r):
        elsewhere(r, name="other")
        for number in range(40):
            r.git("update-ref", f"refs/heads/old/{number}", "other")
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        many(repository)
        code, output = look(repository)
        row("a great many: the list is cut short, the way out is still said", (code, len(output) < 3000, "and 3" in output, "--remove" in output), (1, True, True, True))
        row("and all of them go", (look(repository, "--remove")[0], look(repository)[0]), (0, 0))

    # What is half done.
    def merging(r):
        elsewhere(r, name="other", back=None)
        r.write("secret.txt", "x")
        r.commit("a file of its own")
        r.git("checkout", "--quiet", "fix/something")
        r.git("merge", "--quiet", "--allow-unrelated-histories", "--no-commit", "other")
    situation("a merge with it that is half done: called off, and nothing of it stays in the index", FOUND + ("",), merging, ["MERGE_HEAD: a merge is half done"],
              still=lambda r: r.git("status", "--porcelain"))

    def picking(r):
        elsewhere(r, name="other", back=None)
        r.write("LICENSE", "another\n")
        r.commit("a change that will not fit")
        r.git("checkout", "--quiet", "fix/something")
        r.write("LICENSE", "mine\n")
        r.commit("fix: the same line, otherwise")
        subprocess.run(["git", "cherry-pick", "other"], cwd=r.path, env=r.environment, capture_output=True, check=False)
    situation("a cherry-pick from it that has stopped", FOUND + ("",), picking, ["CHERRY_PICK_HEAD: a cherry-pick is half done"], still=lambda r: r.git("status", "--porcelain"))

    # Part public, part not: never touched.
    def merged(r):
        r.write("mine.txt", "mine")
        r.commit("fix: mine")
        elsewhere(r, name="other")
        r.git("merge", "--quiet", "--allow-unrelated-histories", "--no-edit", "other")
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        merged(repository)
        code, output = look(repository)
        row("merged into a branch that is otherwise sound: said, and said to be a person's to sort out",
            (code, "refs/heads/fix/something: part of its history" in output, "patches you have read" in output), (1, True, True))
        code, _ = look(repository, "--remove")
        row("--remove leaves that branch alone, and says that something is left",
            (code, repository.git("rev-parse", "--verify", "--quiet", "refs/heads/fix/something") != "", repository.git("for-each-ref", "refs/heads/other")), (1, True, ""))

    # Linked worktrees, which is how people work here.
    def linked(r, name="linked", *arguments):
        path = os.path.join(os.path.dirname(r.path), name)
        r.git("worktree", "add", "--quiet", *arguments, path, *(() if "-b" in arguments else ("other",)))
        return path

    def worktree_detached(r):
        elsewhere(r, name="other")
        linked(r, "linked", "--detach")
        r.git("branch", "-D", "other")
    situation("a linked worktree stands on it, detached: that one is moved, this one is not", FOUND + ("fix/something",), worktree_detached,
              ["worktrees/linked/HEAD stands on history"], still=lambda r: r.git("rev-parse", "--abbrev-ref", "HEAD"))

    def worktree_on_branch(r):
        elsewhere(r, name="other")
        linked(r)
    situation("the branch is checked out in a linked worktree", FOUND, worktree_on_branch, ["worktrees/linked/HEAD stands on history", "refs/heads/other"])

    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        elsewhere(repository)
        path = os.path.join(folder, "second")
        repository.git("worktree", "add", "--quiet", "-b", "fix/second", path, "origin/main")
        code, output = look(repository, cwd=path)
        row("run from a linked worktree, where .git is a file", (code, "refs/heads/swarm/trunk" in output, look(repository, "--remove", cwd=path)[0]), (1, True, 0))

    # What makes history look other than it is.
    def replaced(r):
        elsewhere(r)
        r.git("replace", "--graft", r.git("rev-list", "--max-parents=0", "swarm/trunk"), r.root)
    situation("`git replace` makes it look sound", FOUND, replaced, ["refs/heads/swarm/trunk: 2 commits", "refs/replace/"])

    def old_history_attached(r):
        # The usual recipe for seeing old history behind the first public commit.
        r.write("mine.txt", "mine")
        r.commit("fix: mine")
        elsewhere(r, name="other")
        r.git("replace", "--graft", r.root, "other")
    situation("`git replace` hangs old history behind the first public commit: one's own branches are still sound, and stay", FOUND + (True,), old_history_attached,
              ["refs/replace/", "refs/heads/other"], still=lambda r: r.git("log", "--format=%s", "-1", "fix/something") == "fix: mine")

    def grafted(r):
        elsewhere(r)
        with open(os.path.join(r.path, ".git", "info", "grafts"), "w", encoding="utf-8") as handle:
            handle.write(f"{r.git('rev-list', '--max-parents=0', 'swarm/trunk')} {r.root}\n")
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        grafted(repository)
        code, output = look(repository)
        by_hand(repository, output)
        row("a file of grafts: named, and once it is gone the rest shows", (code, "file of grafts" in output, "refs/heads/swarm/trunk: 2 commits" in look(repository)[1]), (1, True, True))

    def borrowed(r):
        other = os.path.join(os.path.dirname(r.path), "lender.git")
        subprocess.run(["git", "clone", "--quiet", "--bare", r.path, other], check=True, env=r.environment, capture_output=True)
        with open(os.path.join(r.path, ".git", "objects", "info", "alternates"), "w", encoding="utf-8") as handle:
            handle.write(os.path.join(other, "objects") + "\n")
    situation("objects borrowed from another repository", FOUND, borrowed, ["borrows objects"])

    def lying_about(r):
        os.makedirs(os.path.join(r.path, ".git", "modules", "x"))
        r.write(".git/old.bundle", "x")
    situation("a submodule's repository and a bundle inside .git", FOUND, lying_about, ["modules", "old.bundle"])

    def kept_pack(r):
        elsewhere(r)
        r.git("repack", "-a", "-d", "--quiet")
        [pack] = [name for name in os.listdir(os.path.join(r.path, ".git", "objects", "pack")) if name.endswith(".pack")]
        r.write(f".git/objects/pack/{pack[:-5]}.keep", "")
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        kept_pack(repository)
        row("a pack marked to be kept, from which git drops nothing: it says why, and what to do instead", "packs marked to be kept" in look(repository)[1], True)

    # What is good, and must survive the removal of what is not.
    def with_good_things(r):
        for number in (1, 2, 3):
            r.write("x.txt", f"stash {number}")
            r.git("stash", "--include-untracked", "--quiet")
        r.write("y.txt", "y")
        r.commit("fix: reset away, but still in the reflog")
        r.kept = r.git("rev-parse", "HEAD")
        r.git("reset", "--quiet", "--hard", "HEAD~1")
        elsewhere(r, back=None)
        r.write("z.txt", "z")
        r.git("stash", "--include-untracked", "--quiet")
        r.git("checkout", "--quiet", "fix/something")
        r.write("x.txt", "stash 4")
        r.git("stash", "--include-untracked", "--quiet")

    def good_things(r):
        stashes = [r.git("show", f"stash@{{{number}}}^3:x.txt") for number in range(len(r.git("stash", "list").splitlines()))]
        return stashes, r.git("cat-file", "-t", r.kept)
    situation("good stashes above and below a foreign one, and a commit of one's own that only the reflog holds: all still there",
              FOUND + ((["stash 4", "stash 3", "stash 2", "stash 1"], "commit"),), with_good_things, ["stash@{1}: a stash made on history"], still=good_things)

    # What is meant to be as it is.
    def output_branch(r, address=clone.OUTPUT_AUTHOR, subject="mac-shell: output of x.sh", more=0, ref="refs/remotes/origin/mac-shell-out/a.b"):
        r.git("checkout", "--quiet", "--orphan", "out")
        r.commit(subject, address=address)
        for _ in range(more):
            r.commit("more")
        r.git("update-ref", ref, "out")
        r.git("checkout", "--quiet", "fix/something")
        r.git("branch", "-D", "out")
    situation("the output of a Mac shell run, fetched, and an earlier one in the reflogs", CLEAN, output_branch)
    situation("what an agent that may not delete branches put in its place", CLEAN, lambda r: output_branch(r, GOOD, "mac-shell: output fetched"))
    situation("history of somebody else's under such a name", FOUND, lambda r: output_branch(r, GOOD, "the first commit"), ["refs/remotes/origin/mac-shell-out/a.b"])

    # Known by where it lies: what the public repository itself has there is public already, whoever made it and whatever it says.
    def at(address, prepare, remote="origin"):
        def prepared(r):
            r.git("remote", "set-url", remote, address) if remote == "origin" else r.git("remote", "add", remote, address)
            prepare(r)
        return prepared
    public, there = "https://github.com/evbarleyg/arbor", "refs/remotes/origin/mac-shell-out/a.b"
    stub = lambda r, **more: output_branch(r, GOOD, "the output has been fetched", **more)
    for address in (public, public + ".git", "git@github.com:evbarleyg/arbor.git", "ssh://git@github.com/evbarleyg/arbor", "https://someone@GitHub.com/evbarleyg/arbor/",
                    "ssh://git@ssh.github.com:443/evbarleyg/arbor.git"):
        situation(f"a commit of somebody's on an output branch of the public repository's: {address}", CLEAN, at(address, stub))
    for address in ("https://evil.net/github.com/evbarleyg/arbor", "https://notgithub.com/evbarleyg/arbor", "https://github.com/evbarleyg/arbor-fork", "https://github.com/evbarleyg/old-barn",
                    "/tmp/github.com/evbarleyg/arbor", "https://github.com.evil.net/evbarleyg/arbor", "https://not.github.com/evbarleyg/arbor",
                    "https://evil.net/x@github.com/evbarleyg/arbor", "https://evil.net#@github.com/evbarleyg/arbor", "https://evil.net?@github.com/evbarleyg/arbor",
                    "https://evil.net\\@github.com/evbarleyg/arbor", "http://github.com/evbarleyg/arbor"):
        situation(f"on a remote whose address only looks like it: {address}", FOUND, at(address, stub), [there])
    situation("on another remote's, beside the public one", FOUND, at(public, lambda r: (r.git("remote", "add", "fork", "https://github.com/someone/arbor"), stub(r, ref="refs/remotes/fork/mac-shell-out/a.b"))),
              ["refs/remotes/fork/mac-shell-out/a.b"])
    situation("on a remote that only pushes to the public repository, and fetches from elsewhere", FOUND,
              at("https://github.com/someone/arbor", lambda r: (r.git("remote", "set-url", "--push", "origin", public), stub(r))), [there])
    situation("without a reflog to go by", CLEAN, at(public, lambda r: (stub(r), os.remove(os.path.join(r.path, ".git", "logs", *there.split("/"))))))
    situation("beside a remote whose address holds a space", CLEAN, at(public, lambda r: (r.git("remote", "add", "disk", "../a disk/arbor.git"), stub(r))))
    situation("beside a remote without an address", CLEAN, at(public, lambda r: (r.git("config", "remote.odd.fetch", "+refs/heads/*:refs/remotes/odd/*"), stub(r))))
    situation("in a partial clone", CLEAN, at(public, lambda r: (r.git("config", "remote.origin.promisor", "true"), r.git("config", "remote.origin.partialclonefilter", "blob:none"), stub(r))))
    # By configuration, as an older git or a hand leaves it: a newer git's `remote add` refuses a name that lies within another's.
    situation("where another remote's branches lie among the public one's", FOUND,
              at(public, lambda r: (r.git("config", "remote.origin/mac-shell-out.url", "https://github.com/someone/arbor"), stub(r, ref="refs/remotes/origin/mac-shell-out/main"))),
              ["refs/remotes/origin/mac-shell-out/main"])
    situation("the address rewritten to the public one, and away from it", CLEAN, at("gh:evbarleyg/arbor", lambda r: (r.git("config", "url.https://github.com/.insteadOf", "gh:"), stub(r))))
    situation("away from it", FOUND, at(public, lambda r: (r.git("config", "url.https://mirror.example.com/.insteadOf", "https://github.com/"), stub(r))), [there])

    def pruned(r):
        stub(r)
        r.pruned = r.git("rev-parse", there)
        r.git("update-ref", "-d", there)
    situation("once the branch is pruned nothing vouches for it any more: a leftover like any other", FOUND, at(public, pruned), ["1 commits that nothing points at any more"])
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        at(public, pruned)(repository)
        known, clone.KNOWN_OUTPUTS = clone.KNOWN_OUTPUTS, {repository.pruned}
        row("but for the one that is known by its id", look(repository)[0], 0)
        clone.KNOWN_OUTPUTS = known
    row("which is a whole id", [len(sha) for sha in clone.KNOWN_OUTPUTS], [40])
    situation("the public repository under another name", CLEAN, at(public, lambda r: stub(r, ref="refs/remotes/upstream/mac-shell-out/a.b"), remote="upstream"))
    situation("on any other branch of the public repository's", FOUND, at(public, lambda r: stub(r, ref="refs/remotes/origin/fix/a.b")), ["refs/remotes/origin/fix/a.b"])
    situation("on a branch whose name only begins like it", FOUND, at(public, lambda r: stub(r, ref="refs/remotes/origin/mac-shell-outing/a.b")), ["refs/remotes/origin/mac-shell-outing/a.b"])
    situation("on a local branch, a tag, of that name", FOUND, at(public, lambda r: (stub(r, ref="refs/heads/mac-shell-out/a.b"), stub(r, ref="refs/tags/origin/mac-shell-out/a.b"))),
              ["refs/heads/mac-shell-out/a.b", "refs/tags/origin/mac-shell-out/a.b"])
    situation("more than one commit there: that is a history", FOUND, at(public, lambda r: stub(r, more=1)), [there + ": 2 commits"])
    situation("something built on it elsewhere", FOUND, at(public, lambda r: (stub(r), r.git("checkout", "--quiet", "-b", "feat/on-it", there), r.commit("more"), r.git("checkout", "--quiet", "fix/something"))),
              ["refs/heads/feat/on-it: 2 commits"])

    def older_stub(r):
        r.environment.update(GIT_AUTHOR_DATE="2001-01-01T00:00:00Z", GIT_COMMITTER_DATE="2001-01-01T00:00:00Z")
        stub(r)
        del r.environment["GIT_AUTHOR_DATE"], r.environment["GIT_COMMITTER_DATE"]
    situation("one from before the repository was public", FOUND, at(public, older_stub), [there])

    def pointed_at_from_elsewhere(r):
        stub(r)
        sha = r.git("rev-parse", there)
        r.write(".git/FETCH_HEAD", f"{sha}\tnot-for-merge\tbranch 'mac-shell-out/a.b' of {public}\n")
        r.git("checkout", "--quiet", "--detach", sha)
        r.git("checkout", "--quiet", "fix/something")
    situation("what else points at it: FETCH_HEAD, HEAD's reflog", CLEAN, at(public, pointed_at_from_elsewhere))

    def replaced(r):
        stub(r)
        r.git("config", "core.logAllRefUpdates", "always")
        first = r.git("rev-parse", there)
        r.git("update-ref", "-d", there)
        r.git("update-ref", "--create-reflog", there, first)
        output_branch(r)
    situation("one that the next run's output has replaced: the branch's own reflog knows where it lay", CLEAN, at(public, replaced))
    situation("commits built on such a commit", FOUND, lambda r: output_branch(r, more=2, ref="refs/heads/feat/looks-fine"), ["refs/heads/feat/looks-fine: 3 commits"])

    def merged_output(r):
        output_branch(r)
        r.git("merge", "--quiet", "--allow-unrelated-histories", "--no-edit", "origin/mac-shell-out/a.b")
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        merged_output(repository)
        row("such a commit merged into a working branch", "refs/heads/fix/something: part of its history" in look(repository)[1], True)

    def older_output(r):
        r.environment.update(GIT_AUTHOR_DATE="2001-01-01T00:00:00Z", GIT_COMMITTER_DATE="2001-01-01T00:00:00Z")
        output_branch(r)
        del r.environment["GIT_AUTHOR_DATE"], r.environment["GIT_COMMITTER_DATE"]
    situation("the output of a run from before the repository was public", FOUND, older_output, ["refs/remotes/origin/mac-shell-out/a.b"])

    def own_stash(r):
        r.write("x.txt", "x")
        r.git("stash", "--include-untracked", "--quiet")
    situation("a stash with untracked files, which git keeps in a commit without parents", CLEAN, own_stash)

    def dropped_stash(r):
        own_stash(r)
        r.git("stash", "drop", "--quiet")
    situation("the same after it was dropped", CLEAN, dropped_stash)

    def built_on_untracked(r):
        r.git("checkout", "--quiet", "--orphan", "odd")
        r.commit(f"untracked files on main: {r.root[:7]} the first public commit")
        r.commit("more")
        r.git("checkout", "--quiet", "fix/something")
    situation("commits built on something that calls itself that", FOUND, built_on_untracked, ["refs/heads/odd: 2 commits"])

    def amended(r):
        r.write("x.txt", "x")
        r.commit()
        r.git("commit", "--quiet", "--amend", "--message", "fix: better")
        r.git("reflog", "expire", "--expire=now", "--all")
    situation("one's own commits that nothing points at any more", CLEAN, amended)

    def unborn(r):
        r.git("checkout", "--quiet", "--orphan", "nothing-yet")
    situation("HEAD on a branch that has no commit yet", CLEAN, unborn)

    # Addresses.
    with tempfile.TemporaryDirectory() as folder:
        repository = made.Repository(folder)
        code, output = look(repository)
        row("no address is set", (code, "no no-reply address" in output, "MUST NOT" in output, "--remove" in output), (1, True, False, False))
        repository.git("config", "user.name", "someone")
        repository.git("config", "user.email", BAD)
        code, output = look(repository)
        row("a person's own address is set, and is not repeated", (code, "no no-reply address" in output, BAD in output), (1, True, False))
        repository.git("config", "user.email", GOOD)
        row("a no-reply address is set", look(repository)[0], 0)
        repository.environment["GIT_COMMITTER_EMAIL"] = BAD
        row("the environment says otherwise", look(repository)[0], 1)

    # Where it cannot tell.
    def shallow(r):
        r.commit()
        r.git("push", "--quiet", "origin", "fix/something")
        copy = r.path + "-shallow"
        subprocess.run(["git", "clone", "--quiet", "--depth", "1", "--branch", "fix/something", "file://" + r.origin, copy], check=True, env=r.environment, capture_output=True)
        r.path = copy
    situation("a shallow clone", (2, [], None), shallow, ["git fetch --unshallow origin"])

    def another(r):
        r.root = "0123456789" * 4
    situation("a clone of some other repository altogether", (2, [], None), another, ["is not in this clone at all"])

    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        elsewhere(repository)
        row("an argument it does not know: nothing is removed", (look(repository, "--remove-all")[0], look(repository, "--remove", "-n")[0], look(repository)[0]), (2, 2, 1))

    # The two scripts that run it.
    with tempfile.TemporaryDirectory() as folder:
        repository = fresh(folder)
        install = os.path.join(HERE, "git-hooks", "install.sh")
        run = lambda *command, cwd=repository.path, **more: subprocess.run(command, cwd=cwd, env=dict(repository.environment, **more), capture_output=True, text=True, check=False)
        repository.git("config", "core.hooksPath", "elsewhere")
        done = run(install)
        row("make hooks: where the hook cannot be installed the clone is looked through all the same, and nothing says the hook is in",
            (done.returncode, "public-clone:" in done.stdout, "THE HOOK IS IN" in done.stdout), (1, True, False))
        outside = os.path.join(folder, "no-repository")
        os.makedirs(outside)
        done = run(install, cwd=outside)
        row("make hooks: outside a repository it installs nothing", (done.returncode != 0, os.listdir(outside)), (True, []))
        # In a repository made for the purpose, with copies of the scripts: what the real checkout is like is none of this test's business.
        repository.git("config", "--unset", "core.hooksPath")
        for name in (".claude/hooks/session-start.sh", "scripts/git-hooks/install.sh", "scripts/git-hooks/pre-push", "scripts/public-check.py", "scripts/public-check.allow", "scripts/public-clone.py"):
            os.makedirs(os.path.dirname(os.path.join(repository.path, name)), exist_ok=True)
            shutil.copy(os.path.join(os.path.dirname(HERE), name), os.path.join(repository.path, name))
        done = run(os.path.join(repository.path, ".claude", "hooks", "session-start.sh"), CLAUDE_PROJECT_DIR=os.path.join(repository.path, "docs"))
        row("the session's hook: started in a folder below the top, it finds its way, and never fails the session",
            (done.returncode, "git now runs" in done.stdout, "public-clone:" in done.stdout), (0, True, True))
        done = run(os.path.join(repository.path, ".claude", "hooks", "session-start.sh"), CLAUDE_PROJECT_DIR=outside)
        row("the session's hook: started outside any repository it says nothing, and does not fail", (done.returncode, done.stdout), (0, ""))

    wrong, rows = 0, table.finish(exactly=88)
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}: expected {expected!r}, got {got!r}")
    print(f"{len(rows) - wrong} of {len(rows)} public-clone situations came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
