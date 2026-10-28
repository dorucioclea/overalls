"""Closed HTTPS fixture for the packaged user agent CLI wire flow."""

import hashlib
import json
import ssl
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path("/run/agent-cli-fixture")
VM_ID = "11111111-1111-4111-8111-111111111111"
THREAD_ID = "22222222-2222-4222-8222-222222222222"
TURN_ID = "33333333-3333-4333-8333-333333333333"
LOCK = threading.Lock()
TOKEN: str | None = None


class Handler(BaseHTTPRequestHandler):
    """Accept one bearer, then model approval and a terminal turn."""

    def log_message(self, format: str, *args: object) -> None:
        pass

    def reply(self, status: int, value: dict[str, object]) -> None:
        raw = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("cache-control", "no-store")
        self.send_header("content-length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def authorized(self) -> bool:
        global TOKEN
        token = self.headers.get("authorization", "").removeprefix("Bearer ")
        if not token.startswith("overalls_agent_") or len(token) != len("overalls_agent_") + 64:
            return False
        with LOCK:
            if TOKEN is None:
                TOKEN = token
                (ROOT / "code").write_text(hashlib.sha256(token.encode()).hexdigest())
            return token == TOKEN

    def do_GET(self) -> None:
        if not self.authorized():
            return self.reply(403, {"error": "machine_unavailable"})
        url = urlsplit(self.path)
        query = parse_qs(url.query)
        if query != {"vm_id": [VM_ID]}:
            return self.reply(400, {"error": "invalid_request"})
        if url.path == "/api/agents/v1/session":
            status = "approved" if (ROOT / "approved").exists() else "pending"
            return self.reply(200, {"status": status})
        if not (ROOT / "approved").exists():
            return self.reply(403, {"error": "machine_unavailable"})
        if url.path == "/api/agents/v1/threads":
            return self.reply(
                200,
                {"threads": [{"id": THREAD_ID, "title": "Root", "parent_thread_id": None}]},
            )
        if url.path == f"/api/agents/v1/turn/{TURN_ID}":
            status = "completed" if (ROOT / "prompt-received").exists() else "queued"
            value: dict[str, object] = {"id": TURN_ID, "status": status}
            if status == "completed":
                value["text"] = "fixture agent reply"
            return self.reply(200, value)
        return self.reply(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if not self.authorized() or not (ROOT / "approved").exists():
            return self.reply(403, {"error": "machine_unavailable"})
        if self.path != "/api/agents/v1/prompt":
            return self.reply(404, {"error": "not_found"})
        length = int(self.headers.get("content-length", "0"))
        if length < 1 or length > 70000:
            return self.reply(400, {"error": "invalid_request"})
        try:
            body: object = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeDecodeError):
            return self.reply(400, {"error": "invalid_request"})
        if not isinstance(body, dict):
            return self.reply(400, {"error": "invalid_request"})
        if (
            body.get("vm_id") != VM_ID
            or body.get("thread_id") != THREAD_ID
            or body.get("prompt") != "fixture prompt"
            or not isinstance(body.get("request_key"), str)
        ):
            return self.reply(400, {"error": "invalid_request"})
        (ROOT / "prompt-received").touch()
        return self.reply(200, {"turn_id": TURN_ID, "status": "queued"})


def main() -> None:
    ROOT.mkdir(mode=0o700, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 8443), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(sys.argv[1], sys.argv[2])
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
