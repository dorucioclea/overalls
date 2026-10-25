"""Isolated provider and canonical HTTPS Git fixture; no Marshall authority endpoints."""

import json
import os
import ssl
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:
        pass

    def authorized(self) -> bool:
        host = self.headers.get("Host", "").split(":")[0]
        if host == "api.openai.com":
            return self.headers.get("Authorization") in [
                f"Bearer synthetic-inception-openai-{i}" for i in (1, 2)
            ]
        if host == "api.anthropic.com":
            return self.headers.get("x-api-key") in [
                f"synthetic-inception-anthropic-{i}" for i in (1, 2)
            ]
        return False

    def reply(self, value: object, status: int = 200) -> None:
        raw = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def git_request(self) -> None:
        """Serve the fixture repository through Git's canonical HTTPS protocol."""
        root = sys.argv[3]
        backend = sys.argv[4]
        parsed = urlsplit(self.path)
        size = int(self.headers.get("Content-Length", "0"))
        if size < 0 or size > 4 * 1024 * 1024:
            self.send_error(400)
            return
        body = self.rfile.read(size) if size else b""
        environment = {
            **os.environ,
            "GIT_PROJECT_ROOT": root,
            "GIT_HTTP_EXPORT_ALL": "1",
            "PATH_INFO": parsed.path,
            "QUERY_STRING": parsed.query,
            "REQUEST_METHOD": self.command,
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": str(len(body)),
            "REMOTE_ADDR": self.client_address[0],
            "SERVER_NAME": "github.com",
            "SERVER_PORT": "443",
            "SERVER_PROTOCOL": "HTTP/1.1",
        }
        result = subprocess.run(
            [backend],
            input=body,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=environment,
            check=False,
            timeout=60,
        )
        if result.returncode != 0:
            self.send_error(404)
            return
        raw_headers, separator, payload = result.stdout.partition(b"\r\n\r\n")
        if not separator:
            raw_headers, separator, payload = result.stdout.partition(b"\n\n")
        if not separator:
            self.send_error(502)
            return
        status = 200
        headers: list[tuple[str, str]] = []
        for line in raw_headers.replace(b"\r\n", b"\n").splitlines():
            name, _, value = line.partition(b":")
            if not _:
                continue
            key = name.decode("ascii", "ignore")
            text = value.decode("latin1").strip()
            if key.lower() == "status":
                status = int(text.split(" ", 1)[0])
            elif key.lower() not in {"connection", "transfer-encoding", "content-length"}:
                headers.append((key, text))
        self.send_response(status)
        for key, value in headers:
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:
        if self.headers.get("Host", "").split(":")[0] == "github.com" and self.path.startswith(
            "/ghuntley/overalls"
        ):
            return self.git_request()
        if self.path == "/v1/models" and self.authorized():
            return self.reply({"data": [{"id": "fixture-model"}], "has_more": False})
        self.reply({}, 403)

    def do_POST(self) -> None:
        if self.headers.get("Host", "").split(":")[0] == "github.com" and self.path.startswith(
            "/ghuntley/overalls"
        ):
            return self.git_request()
        # @cc [owner:ghuntley,label:verification;security] inception-provider-fixture-boundary
        # Only isolated provider routes and the two fixtures' explicit keys may
        # succeed. Caller binding headers MUST NOT reach the provider. This
        # service MUST NOT replace inner Marshall authentication or accounting.
        if (
            self.path not in ("/v1/responses", "/v1/messages")
            or not self.authorized()
            or self.headers.get("x-overalls-binding")
        ):
            return self.reply({}, 403)
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 1048576:
                return self.reply({}, 400)
            value: dict[str, object] = json.loads(self.rfile.read(size))
            if not isinstance(value, dict):
                return self.reply({}, 400)
        except (ValueError, TypeError):
            return self.reply({}, 400)
        if value.get("stream"):
            events = (
                [
                    {"type": "response.output_text.delta", "delta": "synthetic-output"},
                    {
                        "type": "response.completed",
                        "response": {"usage": {"input_tokens": 3, "output_tokens": 7}},
                    },
                ]
                if self.path == "/v1/responses"
                else [
                    {
                        "type": "message_start",
                        "message": {"usage": {"input_tokens": 3, "output_tokens": 0}},
                    },
                    {"type": "message_delta", "usage": {"output_tokens": 7}},
                ]
            )
            raw = "".join("data: " + json.dumps(event) + "\n\n" for event in events).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
        else:
            self.reply(
                {"usage": {"input_tokens": 3, "output_tokens": 7}, "output": "synthetic-output"}
            )


# Bind the fixture on every address assigned to the provider node.  The native
# test gives it the public resolver addresses (1.1.1.1 and 9.9.9.9) as
# loopback-like /32 aliases so the nested guest can exercise its production
# resolver configuration without sending traffic to the real Internet.  Keep
# this listener separate from the ACME issuer's management endpoint.
server = ThreadingHTTPServer(("0.0.0.0", 443), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(sys.argv[1], sys.argv[2])
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
