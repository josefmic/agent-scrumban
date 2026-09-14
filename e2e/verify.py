#!/usr/bin/env python3
"""Drive every definition-of-done case against the running app and print the results table."""

import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path("~/Projects/agent-scrumban")
SUPACODE = "/Applications/supacode.app/Contents/Resources/bin/supacode"
DRIVER = Path("/tmp/e2e-scrumban/ax-driver")
STATE = Path("/tmp/e2e-scrumban/fixture.json")

results = []


def build_driver():
    subprocess.run(["swiftc", "-O", "-o", str(DRIVER), str(REPO / "e2e/ax-driver.swift")], check=True)


def ax(*args):
    return subprocess.run([str(DRIVER), *args], capture_output=True, text=True).stdout.strip()


def cards():
    return json.loads(ax("cards"))


def states(key, board=None):
    board = board if board is not None else cards()
    return [label.rsplit(",", 1)[-1].strip() for label in board.get(key, [])]


def supacode(*args):
    return subprocess.run([SUPACODE, *args], capture_output=True, text=True).stdout.strip()


def fixtures():
    return json.loads(STATE.read_text())


def fixture(*args):
    return subprocess.run(["/usr/bin/python3", str(REPO / "e2e/fixtures.py"), *args],
                          capture_output=True, text=True).stdout.strip()


def settle(key, wanted, timeout=25):
    deadline = time.time() + timeout
    seen = None
    while time.time() < deadline:
        seen = states(key)
        if seen == wanted:
            return seen
        time.sleep(0.5)
    return seen


def record(case, setup, observed, how, ok):
    results.append({"case": case, "setup": setup, "observed": observed, "how": how, "ok": ok})
    print(f"{'PASS' if ok else 'FAIL'}  {case}: {observed}")


def check_states():
    board = cards()
    record("no session — worktree with no terminal at all",
           "E2E-101: fixture worktree, zero zmx sessions",
           f"card rows: {board['E2E-101']}", "accessibility tree of the running app",
           board["E2E-101"] == [])
    record("no session — session without an agent process",
           "E2E-108: zmx session whose process tree holds no agent",
           f"card rows: {board['E2E-108']}", "accessibility tree of the running app",
           board["E2E-108"] == [])
    for key, want in (("E2E-102", "idle"), ("E2E-103", "waiting for you"), ("E2E-104", "working")):
        record(f"{want} — live session",
               f"{key}: real claude process, transcript ending written for {want}",
               f"{board[key]}", "accessibility tree of the running app",
               states(key, board) == [want])
    record("two worktrees in different states at once",
           "E2E-102 idle, E2E-103 waiting, E2E-104 working in one read",
           f"{states('E2E-102', board)} {states('E2E-103', board)} {states('E2E-104', board)}",
           "one accessibility snapshot",
           [states(k, board) for k in ("E2E-102", "E2E-103", "E2E-104")]
           == [["idle"], ["waiting for you"], ["working"]])
    record("a harness that is not Claude Code reports idle",
           "E2E-110: a process the detector reads as codex, with no transcript of its own",
           f"{board['E2E-110']}", "accessibility tree of the running app",
           len(board["E2E-110"]) == 1 and board["E2E-110"][0].startswith("Codex")
           and states("E2E-110", board) == ["idle"])
    record("one worktree with three tabs, each its own state",
           "E2E-105: three claude processes, three tabs, three transcripts",
           f"{board['E2E-105']}", "accessibility tree of the running app",
           states("E2E-105", board) == ["working", "waiting for you", "idle"])


def check_real_session():
    zmx = subprocess.run(["/Applications/supacode.app/Contents/Resources/zmx/zmx", "list"],
                         capture_output=True, text=True).stdout
    sessions = [line for line in zmx.splitlines() if "ABC-1326-figma-sync" in line]
    pids = {field.split("=")[1] for line in sessions for field in line.split("\t") if field.startswith("pid=")}
    table = subprocess.run(["/bin/ps", "-axo", "pid=,ppid=,command="], capture_output=True, text=True).stdout
    agents = [line.split() for line in table.splitlines() if line.split()[2:3] == ["claude"]]
    live = [a for a in agents if a[1] in {str(int(p) + 1) for p in pids} or a[1] in pids]

    rows = states("ABC-1326")
    record("a genuine Claude Code session, never touched by the fixtures",
           f"{len(live)} live claude processes in the user's ABC-1326-figma-sync worktree",
           f"{rows}", "accessibility tree of the running app",
           len(rows) == len(live) and rows
           and all(state in {"idle", "working", "waiting for you"} for state in rows))


def check_transitions():
    fixture("state", "E2E-104", "0", "waiting")
    seen = settle("E2E-104", ["waiting for you"])
    record("a state change is picked up live",
           "E2E-104 rewritten from tool_use to end_turn while the app runs",
           f"working -> {seen}", "polled the accessibility tree until it changed",
           seen == ["waiting for you"])
    fixture("state", "E2E-104", "0", "working")
    settle("E2E-104", ["working"])

    fixture("screen", "E2E-106", "0", "working")
    running = settle("E2E-106", ["working"])
    started = time.time()
    fixture("screen", "E2E-106", "0", "parked")
    stopped = settle("E2E-106", ["idle"])
    took = time.time() - started
    record("an interrupt reaches the board on the next tick",
           "E2E-106 screen dropped its esc-to-interrupt hint, transcript untouched",
           f"working -> {stopped} in {took:.1f}s", "polled the accessibility tree",
           running == ["working"] and stopped == ["idle"] and took < 4)

    fixture("state", "E2E-105", "0", "waiting")
    fixture("state", "E2E-105", "2", "working")
    seen = settle("E2E-105", ["waiting for you", "waiting for you", "working"])
    record("three sessions stay correct while two of them change",
           "E2E-105 rows 0 and 2 rewritten, row 1 untouched",
           f"{seen}", "polled the accessibility tree",
           seen == ["waiting for you", "waiting for you", "working"])
    fixture("state", "E2E-105", "0", "working")
    fixture("state", "E2E-105", "2", "idle")
    settle("E2E-105", ["working", "waiting for you", "idle"])


def check_degradation():
    fixture("unmap", "E2E-105", "1")
    seen = settle("E2E-105", ["working", "idle", "idle"])
    record("an unresolvable tab degrades to idle, the others keep their state",
           "E2E-105 row 1 tab mapping removed from supacode-tab-sessions.log",
           f"{seen}", "polled the accessibility tree",
           seen == ["working", "idle", "idle"])
    fixture("remap", "E2E-105", "1")
    settle("E2E-105", ["working", "waiting for you", "idle"])


def check_navigation():
    known = fixtures()

    ax("press", "E2E-103")
    time.sleep(3)
    focused = supacode("worktree", "list", "--focused")
    record("clicking a card focuses that worktree in Supacode",
           "pressed the E2E-103 card",
           f"supacode worktree list --focused = {focused}", "read back from Supacode",
           focused == known["E2E-103"]["worktree"])

    worktree = known["E2E-105"]["worktree"]
    for index, session in enumerate(known["E2E-105"]["sessions"]):
        ax("press", "E2E-105", str(index))
        time.sleep(3)
        tab = supacode("tab", "list", "-w", worktree, "--focused")
        surface = supacode("surface", "list", "-w", worktree, "-t", session["tab"], "--focused")
        ok = (supacode("worktree", "list", "--focused") == worktree
              and tab == session["tab"] and surface == session["surface"])
        record(f"clicking session row {index} focuses that tab, not just the worktree",
               f"pressed row {index} ({session['want']}) of E2E-105",
               f"focused tab {tab}, surface {surface}", "read back from Supacode", ok)

    before = ax("error")
    ax("press", "E2E-107")
    time.sleep(4)
    after = json.loads(ax("error"))
    handler = ax("handler", "supacode://repo/x/worktree/new?branch=y")
    record("clicking a card with no worktree opens Supacode's new-worktree dialog",
           "pressed the E2E-107 card, which has no worktree",
           f"no error banner ({after}); supacode:// resolves to {handler}",
           "accessibility tree plus LaunchServices",
           after == [] and handler.endswith("supacode.app"))


if __name__ == "__main__":
    build_driver()
    check_states()
    check_real_session()
    check_transitions()
    check_degradation()
    check_navigation()

    Path("/tmp/e2e-scrumban/results.json").write_text(json.dumps(results, indent=2))
    failures = [r for r in results if not r["ok"]]
    print(f"\n{len(results) - len(failures)}/{len(results)} passed")
    sys.exit(1 if failures else 0)
