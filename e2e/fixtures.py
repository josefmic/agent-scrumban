#!/usr/bin/env python3
"""Build, drive and tear down the e2e-scrumban fixtures."""

import json
import os
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

PREFIX = "e2e-scrumban-"
SUPACODE = "/Applications/supacode.app/Contents/Resources/bin/supacode"
REPO = Path("~/Projects/agent-scrumban")
REPO_ID = "%2FUsers%2Fyou%2FProjects%2Fagent-scrumban%2F"
ROOT = Path("/Users/you/.supacode/repos/agent-scrumban")
PROJECTS = Path.home() / ".claude/projects"
TAB_LOG = Path.home() / ".claude/supacode-tab-sessions.log"
WORK = Path("/tmp/e2e-scrumban")
STATE = WORK / "fixture.json"
ZMX_EXTRA = WORK / "zmx-extra"
SCREENS = WORK / "screens"

FIXTURES = [
    ("E2E-101", "E2E-101-no-session", []),
    ("E2E-102", "E2E-102-idle", ["idle"]),
    ("E2E-103", "E2E-103-waiting", ["waiting"]),
    ("E2E-104", "E2E-104-working", ["working"]),
    ("E2E-105", "E2E-105-tabs", ["working", "waiting", "idle"]),
    ("E2E-106", "E2E-106-live", ["fresh"]),
    ("E2E-108", "E2E-108-shell", ["bare"]),
    ("E2E-110", "E2E-110-codex", ["codex"]),
]


def supacode(*args, check=True):
    result = subprocess.run([SUPACODE, *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"supacode {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout.strip()


def worktree_id(path):
    return str(path).replace("/", "%2F") + "%2F"


def branch(name):
    return PREFIX + name


def path_of(name):
    return ROOT / branch(name)


def guarded(path):
    if PREFIX not in Path(path).name:
        raise RuntimeError(f"refusing to touch {path}: not a fixture")
    return Path(path)


def project_dir(path):
    return PROJECTS / "".join("-" if c in "/." else c for c in str(path))


def ensure_worktrees():
    live = set(supacode("worktree", "list").splitlines())
    for _, name, _ in FIXTURES:
        if worktree_id(path_of(name)) not in live:
            supacode("repo", "worktree-new", "--repo", REPO_ID, "--branch", branch(name),
                     "--base", "main", "--background", "--timeout", "180")


def start_host(tab, kind):
    host = subprocess.Popen(
        ["/bin/bash", str(REPO / "e2e/agent-host.sh"), tab, kind],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return host.pid


BAR = "\u2500" * 40
PARKED = f"{BAR}\n\u276f\n{BAR}\n  \u23f5\u23f5 auto mode on (shift+tab to cycle)\n"
IN_FLIGHT = PARKED.replace("to cycle)", "to cycle) \u00b7 esc to interrupt")


def session_name(tab):
    return f"supa-{tab.lower()}"


def write_screen(tab, state):
    SCREENS.mkdir(parents=True, exist_ok=True)
    (SCREENS / session_name(tab)).write_text(IN_FLIGHT if state == "working" else PARKED)


def stamp(offset):
    when = datetime.now(timezone.utc) - timedelta(seconds=offset)
    return when.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def tail(state):
    opening = [
        {"type": "user", "timestamp": stamp(900), "message": {"role": "user"}},
        {"type": "assistant", "timestamp": stamp(880), "message": {"stop_reason": "tool_use"}},
        {"type": "user", "timestamp": stamp(870), "message": {"role": "user"}},
    ]
    endings = {
        "waiting": {"type": "assistant", "timestamp": stamp(30), "message": {"stop_reason": "end_turn"}},
        "stopped": {"type": "system", "subtype": "stop_hook_summary", "timestamp": stamp(15)},
        "working": {"type": "assistant", "timestamp": stamp(30), "message": {"stop_reason": "tool_use"}},
        "fresh": {"type": "user", "timestamp": stamp(20), "message": {"role": "user"}},
        "idle": {"type": "user", "timestamp": stamp(600), "message": {"role": "user"}},
    }
    return "\n".join(json.dumps(e) for e in opening + [endings[state]]) + "\n"


def write_state(path, session, state):
    directory = project_dir(guarded(path))
    directory.mkdir(parents=True, exist_ok=True)
    (directory / f"{session}.jsonl").write_text("" if state == "silent" else tail(state))


def zmx_line(surface, pid, path):
    created = int(time.time()) - 300
    return (f"  name=supa-{surface.lower()}\tpid={pid}\tclients=1\tcreated={created}"
            f"\tstart_dir={path}\tcmd=/usr/bin/login -flp fixture /bin/bash")


def publish(fixtures):
    lines = [
        zmx_line(session["surface"], session["pid"], entry["path"])
        for entry in fixtures.values()
        for session in entry["sessions"]
    ]
    ZMX_EXTRA.write_text("\n".join(lines) + ("\n" if lines else ""))


def setup():
    WORK.mkdir(parents=True, exist_ok=True)
    ensure_worktrees()

    fixtures = {}
    mappings = []

    for key, name, slots in FIXTURES:
        path = path_of(name)
        entry = {
            "key": key,
            "branch": branch(name),
            "path": str(path),
            "worktree": worktree_id(path),
            "sessions": [],
        }

        for index, slot in enumerate(slots):
            tab = supacode("tab", "new", "-w", entry["worktree"], "--background",
                           "--title", f"{PREFIX}{key}-{index}", "--timeout", "120")
            session = {
                "tab": tab,
                "surface": tab,
                "session": str(uuid.uuid4()).lower(),
                "pid": start_host(tab, slot if slot in {"bare", "codex"} else "agent"),
                "want": slot,
            }
            entry["sessions"].append(session)
            write_screen(tab, slot)
            if slot not in {"bare", "codex"}:
                mappings.append(f"{tab} {session['session']}\n")
                write_state(path, session["session"], slot)

        fixtures[key] = entry

    with TAB_LOG.open("a") as handle:
        handle.writelines(mappings)

    publish(fixtures)
    STATE.write_text(json.dumps(fixtures, indent=2))
    print(json.dumps(fixtures, indent=2))


def retarget(key, index, state):
    fixtures = json.loads(STATE.read_text())
    entry = fixtures[key]
    session = entry["sessions"][int(index)]
    write_state(Path(entry["path"]), session["session"], state)
    write_screen(session["tab"], state)
    print(f"{key}[{index}] {session['session']} -> {state}")


def retarget_screen(key, index, state):
    fixtures = json.loads(STATE.read_text())
    session = fixtures[key]["sessions"][int(index)]
    write_screen(session["tab"], state)
    print(f"{key}[{index}] screen -> {state}")


def unmap(key, index):
    fixtures = json.loads(STATE.read_text())
    session = fixtures[key]["sessions"][int(index)]
    kept = [line for line in TAB_LOG.read_text().splitlines(keepends=True)
            if not line.upper().startswith(session["tab"])]
    TAB_LOG.write_text("".join(kept))
    print(f"{key}[{index}] tab mapping removed")


def remap(key, index):
    fixtures = json.loads(STATE.read_text())
    session = fixtures[key]["sessions"][int(index)]
    with TAB_LOG.open("a") as handle:
        handle.write(f"{session['tab']} {session['session']}\n")
    print(f"{key}[{index}] tab mapping restored")


def drop(key, index):
    fixtures = json.loads(STATE.read_text())
    session = fixtures[key]["sessions"].pop(int(index))
    stop_host(session["pid"])
    publish(fixtures)
    STATE.write_text(json.dumps(fixtures, indent=2))
    print(f"{key}[{index}] removed")


def stop_host(pid):
    try:
        os.killpg(pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass


def teardown():
    if STATE.exists():
        fixtures = json.loads(STATE.read_text())
        tabs = {s["tab"].upper() for e in fixtures.values() for s in e["sessions"]}
        for entry in fixtures.values():
            for session in entry["sessions"]:
                stop_host(session["pid"])
        if tabs:
            kept = [line for line in TAB_LOG.read_text().splitlines(keepends=True)
                    if not line.split() or line.split()[0].upper() not in tabs]
            TAB_LOG.write_text("".join(kept))

    live = set(supacode("worktree", "list").splitlines())
    for _, name, _ in FIXTURES:
        path = guarded(path_of(name))
        for tab in supacode("tab", "list", "-w", worktree_id(path), check=False).splitlines():
            supacode("tab", "close", "-w", worktree_id(path), "-t", tab, "--background", check=False)
        directory = project_dir(path)
        if directory.exists() and PREFIX in directory.name:
            for item in directory.iterdir():
                item.unlink()
            directory.rmdir()
        if worktree_id(path) in live:
            supacode("worktree", "delete", "-w", worktree_id(path), "--background", check=False)

    if SCREENS.exists():
        for screen in SCREENS.iterdir():
            screen.unlink()
        SCREENS.rmdir()

    for leftover in (STATE, ZMX_EXTRA):
        if leftover.exists():
            leftover.unlink()


if __name__ == "__main__":
    command = sys.argv[1]
    if command == "setup":
        setup()
    elif command == "state":
        retarget(sys.argv[2], sys.argv[3], sys.argv[4])
    elif command == "screen":
        retarget_screen(sys.argv[2], sys.argv[3], sys.argv[4])
    elif command == "unmap":
        unmap(sys.argv[2], sys.argv[3])
    elif command == "remap":
        remap(sys.argv[2], sys.argv[3])
    elif command == "drop":
        drop(sys.argv[2], sys.argv[3])
    elif command == "teardown":
        teardown()
    else:
        raise SystemExit(f"unknown command {command}")
