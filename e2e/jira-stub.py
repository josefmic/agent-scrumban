#!/usr/bin/env python3
"""Loopback stand-in for the handful of Jira endpoints the board reads."""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

COLUMNS = [
    ("To Do", "10000"),
    ("In Progress", "10001"),
    ("Done", "10002"),
]

ISSUES = [
    ("E2E-101", "no session", "10001"),
    ("E2E-102", "idle session", "10001"),
    ("E2E-103", "waiting for you", "10001"),
    ("E2E-104", "working", "10001"),
    ("E2E-105", "three tabs three states", "10001"),
    ("E2E-106", "live claude session", "10001"),
    ("E2E-107", "not started yet", "10000"),
    ("E2E-108", "shell tab without an agent", "10001"),
    ("E2E-110", "a harness that is not Claude Code", "10001"),
    ("ABC-1326", "a real worktree the fixtures never touch", "10001"),
]


def issue(key, summary, status):
    return {
        "key": key,
        "fields": {
            "summary": summary,
            "status": {"id": status, "name": dict((b, a) for a, b in COLUMNS)[status]},
            "issuetype": {"name": "Story"},
            "priority": {"name": "Medium"},
            "assignee": {"displayName": "E2E Fixture"},
        },
    }


def board_configuration():
    return {
        "columnConfig": {
            "columns": [{"name": n, "statuses": [{"id": i}]} for n, i in COLUMNS]
        }
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/rest/agile/1.0/board":
            return self.send({"values": [{"id": 1, "name": "E2E"}]})
        if path == "/rest/agile/1.0/board/1/configuration":
            return self.send(board_configuration())
        if path == "/rest/agile/1.0/board/1/sprint":
            return self.send({"values": []})
        if path == "/rest/agile/1.0/board/1/issue":
            return self.send({
                "issues": [issue(*i) for i in ISSUES],
                "total": len(ISSUES),
                "maxResults": 100,
                "isLast": True,
            })

        self.send_response(404)
        self.end_headers()

    def send(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8799
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
