#!/usr/bin/env python3
"""Checks how scripts/parity.py reads real-window evidence, and that the real-window suite's claims are in order.

`make check` runs it. Exit code 1 when a row comes out wrong.
"""

import importlib.util
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import parity  # noqa: E402

spec = importlib.util.spec_from_file_location("suite_parity", os.path.join(HERE, "mac-shell", "suite-parity.py"))
suite_parity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite_parity)

rows = []


def row(what, got, expected):
    rows.append((what, got, expected))


def evidence_of(files):
    with tempfile.TemporaryDirectory() as folder:
        for name, text in files.items():
            with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                handle.write(text)
        try:
            return parity.read_evidence(os.path.join(folder, "*-latest.txt"))
        except SystemExit as stop:
            return str(stop.code)


def section(name, time, *lines):
    return "\n".join([f"# {name} {time} on macOS 26.6.2, commit abc1234", *lines]) + "\n"


def check_evidence():
    e2e = "\n".join([
        "# arbor-e2e", "▸ good  (dock 1 left)", "  ✔ a", "  ✔ b", "▸ bad", "  ✔ a", "  ✘ b — why", "▸ again", "  ✔ a",
        "== a heading", "  ✘ preparation that belongs to no step", "▸ again", "  ✔ b", "▸ nothing under it", "",
        "5 passed, 2 failed", "", "--- arbor.log (last 40 lines) ---", "INFO  back: back to n2",
    ]) + "\n"
    row("a ✘ fails its step, a step with nothing under it did not run, a heading ends a step",
        evidence_of({"e2e-latest.txt": e2e})[0], {"good": True, "bad": False, "again": True})
    whole = section("10-edges", "2026-10-14T09:12Z", "▸ a", "  ✔ x", "▸ quit", "  ✔ y", "", "2 passed, 0 failed")
    row("a section that finished", evidence_of({"suite-10-edges-latest.txt": whole})[0], {"a": True, "quit": True})
    cut = section("30-seams", "2026-10-14T09:14Z", "▸ b", "  ✔ x", "▸ c", "  ✔ as far as it got")
    row("the last step of a section that was killed did not run",
        evidence_of({"suite-30-seams-latest.txt": cut})[0], {"b": True})
    early = section("40-keys", "2026-10-14T09:10Z", "▸ d", "  ✔ x", "  ✘ the script ended early, with exit code 143",
                    "", "1 passed, 1 failed")
    row("a step the script ended in has failed", evidence_of({"suite-40-keys-latest.txt": early})[0], {"d": False})
    again = section("50-more", "2026-10-14T09:11Z", "▸ quit", "  ✘ y", "", "0 passed, 1 failed")
    row("a claim made in two sections has to hold in both",
        evidence_of({"suite-10-edges-latest.txt": whole, "suite-50-more-latest.txt": again})[0], {"a": True, "quit": False})
    row("one entry for the suite's sections, after the others",
        evidence_of({"e2e-latest.txt": e2e, "suite-10-edges-latest.txt": whole, "suite-30-seams-latest.txt": cut})[1],
        ["arbor-e2e", "the real-window suite, 2 sections, the newest 2026-10-14T09:14Z on macOS 26.6.2, commit abc1234"])
    row("no evidence at all", evidence_of({}), ({}, []))
    row("a rehearsal's output is refused",
        "no evidence" in evidence_of({"suite-10-edges-latest.txt": "# 10-edges: a REHEARSAL against stand-ins\n▸ a\n  ✔ x\n"}),
        True)


def check_relisting():
    proofs, titles = {"T01": ["a", "b"], "T02": ["b"]}, {"a", "b", "c"}

    def relist(item, steps):
        return suite_parity.relist(item, proofs, titles, steps)[0]

    row("all of an item's claims hold: they are listed after the other runners' steps",
        relist({"id": "T01", "e2e": ["dock the first window"]}, {"a": True, "b": True}), ["dock the first window", "a", "b"])
    row("one failed: none is listed", relist({"id": "T01", "e2e": ["a", "b"]}, {"a": True, "b": False}), [])
    row("one has not run: none is listed", relist({"id": "T01"}, {"a": True}), [])
    row("a claim that no longer proves the item is taken off", relist({"id": "T02", "e2e": ["c", "b"]}, {"b": True}), ["b"])
    row("an item the suite says nothing about keeps its list", relist({"id": "T03", "e2e": ["x"]}, {}), ["x"])

    with tempfile.NamedTemporaryFile("w", suffix=".sh", encoding="utf-8", delete=False) as handle:
        handle.write('claim "one"\nproves T01 A02\ncheck "x" true\n  claim "two"\n  proves T01\nclaim "three"\ncheck "y" true\n')
    found = suite_parity.claims_in([handle.name])
    os.unlink(handle.name)
    row("claims and what they prove are read from a script",
        found, ({"T01": ["one", "two"], "A02": ["one"]}, ["one", "two", "three"]))


def check_the_suite():
    proofs, titles = suite_parity.claims_in(suite_parity.scripts())
    row("the suite: no claim is made twice", sorted({t for t in titles if titles.count(t) > 1}), [])
    row("the suite: no title ends in a way parity.py would cut off",
        [t for t in titles if parity.STEP_LINE.match(f"▸ {t}").group(1) != t], [])
    with open(parity.PARITY, encoding="utf-8") as handle:
        ids = {item["id"] for item in json.load(handle)["features"]}
    row("the suite: `proves` names only items parity.json has", sorted(set(proofs) - ids), [])
    row("the suite: parity.py finds every claim as it is written", sorted(set(titles) - parity.known_steps()), [])


def main():
    check_evidence()
    check_relisting()
    check_the_suite()
    wrong = 0
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}: expected {expected!r}, got {got!r}")
    print(f"{len(rows) - wrong} of {len(rows)} situations with real-window evidence came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
