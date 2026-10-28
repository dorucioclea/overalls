"""Isolated provider fixtures; real Marshall remains the control authority."""

import json
import ssl
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Literal
from urllib.parse import urlsplit

Effect = Literal["responses", "messages", "count_tokens"]
effects: dict[Effect, int] = {"responses": 0, "messages": 0, "count_tokens": 0}
effects_lock = threading.Lock()


def object_fields(value: object) -> dict[str, object] | None:
    if not isinstance(value, dict):
        return None
    result: dict[str, object] = {}
    for key, field in value.items():
        if not isinstance(key, str):
            return None
        result[key] = field
    return result


SERVER_TOOL_MODES = ("artifacts", "thread-tool")
BASE_TOOLS = ["exec_command", "read_file", "web_search", "web_fetch"]
SERVER_TOOLS = {"thread", "attachment", "artifact", "message_board"}
STAGED_DIRECTORY = "/tmp/overalls-artifact"
SCRIPTED_PROMPTS = {
    "artifacts": [
        "Publish artifact fixture",
        "Publish stale artifact fixture",
        "Publish staged artifact fixture",
        "Publish restarted artifact fixture",
    ],
    "thread-tool": ["Use thread tool fixture"],
}


def tool_output(item: dict[str, object]) -> dict[str, object] | None:
    raw = item.get("output")
    if not isinstance(raw, str):
        return None
    try:
        return object_fields(json.loads(raw))
    except ValueError:
        return None


def call(call_id: str, name: str, arguments: dict[str, object]) -> dict[str, object]:
    return {
        "type": "function_call",
        "call_id": call_id,
        "name": name,
        "arguments": json.dumps(arguments),
    }


def reply_message() -> dict[str, object]:
    return {
        "type": "message",
        "role": "assistant",
        "content": [{"type": "output_text", "text": "fixture agent reply"}],
    }


def published_artifact(messages: list[dict[str, object]]) -> str | None:
    """The artifact id from the earliest successful publish in this thread."""
    for item in messages:
        if item.get("type") != "function_call_output":
            continue
        result = tool_output(item)
        if result is not None and result.get("version") == 1:
            artifact = result.get("artifact_id")
            if isinstance(artifact, str):
                return artifact
    return None


def scripted(
    prompt: str, outputs: list[dict[str, object]], messages: list[dict[str, object]]
) -> list[dict[str, object]] | None:
    """@cc [owner:ghuntley,label:verification;security] provider-server-tool-script
    The artifact and thread modes MUST drive only the fixed server-tool calls
    for their fixed prompts and MUST accept each next step only after the exact
    expected typed result (or typed refusal) of the previous call. Any other
    result refuses the request with the closed tool_output code.
    """
    results = [tool_output(item) for item in outputs]
    if any(result is None for result in results):
        return None
    done = [result for result in results if result is not None]
    if prompt == "Publish artifact fixture":
        if not done:
            return [
                call(
                    "fleet-artifact-publish",
                    "artifact",
                    {
                        "operation": "publish",
                        "base_version": 0,
                        "title": "Fleet artifact",
                        "content": "<!doctype html><title>Fleet artifact</title>"
                        "<p>fleet artifact v1</p>",
                    },
                )
            ]
        if (
            len(done) == 1
            and done[0].get("version") == 1
            and isinstance(done[0].get("artifact_id"), str)
        ):
            return [reply_message()]
        return None
    if prompt == "Publish restarted artifact fixture":
        # Queued while server tools are paused, then executed after every
        # Marshall replica restarts.
        if not done:
            return [
                call(
                    "fleet-artifact-restarted",
                    "artifact",
                    {
                        "operation": "publish",
                        "base_version": 0,
                        "title": "Restarted artifact",
                        "content": "<p>restarted artifact</p>",
                    },
                )
            ]
        if len(done) == 1 and done[0].get("version") == 1:
            return [reply_message()]
        return None
    artifact = published_artifact(messages)
    if artifact is None:
        return None
    if prompt == "Publish stale artifact fixture":
        if not done:
            return [
                call(
                    "fleet-artifact-stale",
                    "artifact",
                    {
                        "operation": "publish",
                        "artifact_id": artifact,
                        "base_version": 0,
                        "content": "<p>stale</p>",
                    },
                )
            ]
        if (
            len(done) == 1
            and done[0].get("reason") == "stale_base_version"
            and done[0].get("current_version") == 1
        ):
            return [reply_message()]
        return None
    if prompt == "Publish staged artifact fixture":
        if not done:
            return [
                call(
                    "fleet-artifact-stage-files",
                    "exec_command",
                    {
                        "cmd": f"mkdir -p {STAGED_DIRECTORY} && head -c 3145728 /dev/zero "
                        f"| tr '\\0' a >{STAGED_DIRECTORY}/large.txt && printf "
                        f"'<!doctype html><title>Staged</title><p>staged artifact</p>' "
                        f">{STAGED_DIRECTORY}/index.html"
                    },
                )
            ]
        if len(done) == 1:
            return [
                call(
                    "fleet-artifact-staged",
                    "artifact",
                    {
                        "operation": "publish",
                        "artifact_id": artifact,
                        "base_version": 1,
                        "content_path": f"{STAGED_DIRECTORY}/index.html",
                        "files": {"large.txt": {"source_path": f"{STAGED_DIRECTORY}/large.txt"}},
                    },
                )
            ]
        if len(done) == 2 and done[1].get("version") == 2:
            return [reply_message()]
        return None
    return None


def thread_script(outputs: list[dict[str, object]]) -> list[dict[str, object]] | None:
    """Search, then read, subscribe to and replay the first visible thread.

    Results follow the ADR-0252 thread tool: every success is `{"items": [...]}`.
    """
    results = [tool_output(item) for item in outputs]
    if any(result is None for result in results):
        return None
    done = [result for result in results if result is not None]
    if not done:
        return [call("fleet-thread-search", "thread", {"operation": "search"})]
    items = [object_list(result.get("items")) for result in done]
    if any(item is None for item in items):
        return None
    found = [item for item in items if item is not None]
    first = found[0][0] if found[0] else None
    target = None if first is None else first.get("id")
    if not isinstance(target, str):
        return None
    steps: list[dict[str, object]] = [
        {"operation": "read", "thread_id": target},
        {"operation": "subscribe", "thread_id": target},
        {"operation": "replay", "thread_id": target, "cursor": 0},
    ]
    if len(done) <= len(steps):
        return [call(f"fleet-thread-{len(done)}", "thread", steps[len(done) - 1])]
    if len(done) == len(steps) + 1:
        return [reply_message()]
    return None


def object_list(value: object) -> list[dict[str, object]] | None:
    if not isinstance(value, list):
        return None
    result: list[dict[str, object]] = []
    for item in value:
        fields = object_fields(item)
        if fields is None:
            return None
        result.append(fields)
    return result


class Handler(BaseHTTPRequestHandler):
    """@cc [owner:ghuntley,label:verification;security] fleet-provider-catalog-boundary
    Normal fleet checks admit authenticated model discovery only. The agent
    fleet admits deterministic Responses/tool exchanges. The explicit coding-clis
    mode admits bounded Responses and Messages exchanges and loopback-only effect
    counters. All inference requires synthetic upstream credentials. Only the explicit
    executor-loss mode may request the disposable effect helper, and its retry
    answer requires the exact successful tool result. No mode forwards requests
    or logs headers, credentials, prompts or tool output.
    """

    def log_message(self, format: str, *args: object) -> None:
        pass

    def do_GET(self) -> None:
        if (
            len(sys.argv) == 4
            and sys.argv[3] == "coding-clis"
            and self.path == "/fixture/stats"
            and self.client_address[0] == "127.0.0.1"
        ):
            with effects_lock:
                value: dict[str, object] = {key: count for key, count in effects.items()}
            return self.reply(200, value)
        expected = {
            "api.openai.com": ("Authorization", "Bearer synthetic-openai-private"),
            "api.anthropic.com": ("x-api-key", "synthetic-anthropic-private"),
        }.get(self.headers.get("Host", ""))
        status = 404
        if expected and urlsplit(self.path).path == "/v1/models":
            status = 200 if self.headers.get(expected[0]) == expected[1] else 403
        value = {"data": [{"id": "fixture-model"}], "has_more": False} if status == 200 else {}
        raw = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self) -> None:
        if len(sys.argv) == 4 and sys.argv[3] == "coding-clis":
            return self.coding_cli_post()
        if len(sys.argv) != 4 or sys.argv[3] not in ("agent", "executor-loss", *SERVER_TOOL_MODES):
            return self.reject("mode", 404)
        if (
            self.headers.get("Host") != "api.openai.com"
            or urlsplit(self.path).path != "/v1/responses"
            or self.headers.get("Authorization") != "Bearer synthetic-openai-private"
        ):
            return self.reject("identity", 403)
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > 262_144:
                return self.reject("body_size")
            request = object_fields(json.loads(self.rfile.read(length)))
        except (ValueError, UnicodeDecodeError):
            return self.reject("body_json")
        if (
            request is None
            or request.get("model") != "gpt-6-sol"
            or request.get("stream") is not True
        ):
            return self.reject("envelope")
        messages = object_list(request.get("input"))
        tools = object_list(request.get("tools"))
        if messages is None or tools is None or request.get("store") is not False:
            return self.reject("input")
        names = [item.get("name") for item in tools]
        # Marshall-owned server tools follow the four guest tools; the
        # server-tool modes additionally require the tool they exercise.
        extra = names[len(BASE_TOOLS) :]
        if (
            names[: len(BASE_TOOLS)] != BASE_TOOLS
            or not all(isinstance(name, str) and name in SERVER_TOOLS for name in extra)
            or len(set(extra)) != len(extra)
            or (sys.argv[3] == "artifacts" and "artifact" not in extra)
            or (sys.argv[3] == "thread-tool" and "thread" not in extra)
        ):
            return self.reject("tools")
        prompts = [item.get("content") for item in messages if item.get("role") == "user"]
        allowed_prompts = [
            "Read this machine's hostname",
            "Read guest context and skills $review",
            "Try child agent",
            "Search example topic",
            "Fetch local content",
        ]
        if sys.argv[3] == "executor-loss":
            allowed_prompts += ["Perform interruptible effect", "Explicitly retry effect"]
        allowed_prompts += SCRIPTED_PROMPTS.get(sys.argv[3], [])
        if not prompts or prompts[-1] not in allowed_prompts:
            return self.reject("prompt")
        last_prompt_index = max(
            index for index, item in enumerate(messages) if item.get("role") == "user"
        )
        tool_messages = [
            item
            for item in messages[last_prompt_index + 1 :]
            if item.get("type") == "function_call_output"
        ]
        if sys.argv[3] in SERVER_TOOL_MODES and prompts[-1] in SCRIPTED_PROMPTS[sys.argv[3]]:
            planned = (
                thread_script(tool_messages)
                if sys.argv[3] == "thread-tool"
                else scripted(str(prompts[-1]), tool_messages, messages)
            )
            if planned is None:
                return self.reject("tool_output")
            output: list[dict[str, object]] = planned
        elif prompts[-1] in ("Perform interruptible effect", "Explicitly retry effect"):
            if tool_messages:
                if prompts[-1] != "Explicitly retry effect" or len(tool_messages) != 1:
                    return self.reject("tool_output")
                raw_result = tool_messages[0].get("output")
                if not isinstance(raw_result, str):
                    return self.reject("tool_output")
                try:
                    result: object = json.loads(raw_result)
                except (TypeError, ValueError):
                    return self.reject("tool_output")
                if result != {
                    "status": "completed",
                    "exit_code": 0,
                    "stdout": "explicit retry effect complete\n",
                    "stderr": "",
                }:
                    return self.reject("tool_output")
                output = [
                    {
                        "type": "message",
                        "role": "assistant",
                        "content": [{"type": "output_text", "text": "fixture agent reply"}],
                    }
                ]
            else:
                action = "effect" if prompts[-1] == "Perform interruptible effect" else "retry"
                output = [
                    {
                        "type": "function_call",
                        "call_id": "executor-loss-" + action,
                        "name": "exec_command",
                        "arguments": json.dumps({"cmd": "fleet-executor-loss " + action}),
                    }
                ]
        elif prompts[-1] == "Try child agent":
            output = [
                {
                    "type": "function_call",
                    "call_id": "forbidden-child",
                    "name": "spawn_child_agent",
                    "arguments": '{"title":"child","prompt":"work"}',
                }
            ]
        elif prompts[-1] == "Read guest context and skills $review" and not tool_messages:
            # Context and skill collection is a Marshall-owned pre-model step;
            # this read_file is only the final guest tool round trip proving the
            # model turn ran after the real inventory was attached.
            output = [
                {
                    "type": "function_call",
                    "call_id": "fleet-read-context-marker",
                    "name": "read_file",
                    "arguments": '{"path":"/workspace/AGENTS.md"}',
                }
            ]
        elif prompts[-1] == "Read guest context and skills $review" and len(tool_messages) == 1:
            result = tool_messages[0].get("output")
            if not isinstance(result, str) or "project context fixture" not in result:
                return self.reject("tool_output")
            output = [
                {
                    "type": "message",
                    "role": "assistant",
                    "content": [{"type": "output_text", "text": "fixture agent reply"}],
                }
            ]
        elif prompts[-1] == "Fetch local content" and not tool_messages:
            output = [
                {
                    "type": "function_call",
                    "call_id": "fleet-local-server",
                    "name": "exec_command",
                    "arguments": json.dumps(
                        {
                            "cmd": "mkdir -p /tmp/overalls-fetch && printf '<h1>Guest local content</h1>' >/tmp/overalls-fetch/index.html; python3 -m http.server 8765 --bind 127.0.0.1 --directory /tmp/overalls-fetch </dev/null >/dev/null 2>&1 & sleep 1"
                        }
                    ),
                }
            ]
        elif prompts[-1] == "Fetch local content" and len(tool_messages) == 1:
            output = [
                {
                    "type": "function_call",
                    "call_id": "fleet-web-fetch",
                    "name": "web_fetch",
                    "arguments": '{"url":"http://127.0.0.1:8765/","format":"markdown"}',
                }
            ]
        elif prompts[-1] == "Search example topic" and not tool_messages:
            output = [
                {
                    "type": "function_call",
                    "call_id": "fleet-web-search",
                    "name": "web_search",
                    "arguments": '{"query":"example topic"}',
                }
            ]
        elif tool_messages:
            tool_outputs = [item.get("output") for item in tool_messages]
            if not any(
                isinstance(value, str)
                and (
                    "contents" in value
                    or "example.org/2" in value
                    or "Guest local content" in value
                )
                for value in tool_outputs
            ):
                return self.reject("tool_output")
            output = [
                {
                    "type": "message",
                    "role": "assistant",
                    "content": [{"type": "output_text", "text": "fixture agent reply"}],
                }
            ]
        else:
            output = [
                {"type": "reasoning", "encrypted_content": "synthetic-reasoning"},
                {
                    "type": "function_call",
                    "call_id": "fleet-read-hostname",
                    "name": "read_file",
                    "arguments": '{"path":"/etc/hostname"}',
                },
            ]
        events = [
            {
                "type": "response.output_item.done",
                "output_index": index,
                "item": item,
            }
            for index, item in enumerate(output)
        ]
        events.append(
            {
                "type": "response.completed",
                "response": {
                    "status": "completed",
                    "output": [],
                    "usage": {"input_tokens": 5, "output_tokens": 7},
                },
            }
        )
        raw = b"".join(("data: " + json.dumps(event) + "\n\n").encode() for event in events)
        self.send_response(200)
        # Ziggy collects only `text/event-stream` bodies as Responses streams.
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def coding_cli_post(self) -> None:
        """@cc [owner:ghuntley,label:verification;security] coding-cli-provider-effects
        Coding-CLI responses MUST require the provider's synthetic credential,
        exact native route, and a bounded parsed request. Accepted Codex requests
        MUST use fixture-model, streaming Responses and store=false. Accepted
        Anthropic requests MUST use fixture models and beta=true; only completed
        validation may increment the finite per-API counter. Stats MUST contain
        counters only and remain loopback-only.
        """
        host = self.headers.get("Host")
        if host == "api.openai.com":
            if (
                self.path != "/v1/responses"
                or self.headers.get("Authorization") != "Bearer synthetic-openai-private"
                or self.headers.get("x-api-key") is not None
            ):
                return self.reject("identity", 403)
            effect: Effect = "responses"
        elif host == "api.anthropic.com":
            if (
                self.path not in ("/v1/messages?beta=true", "/v1/messages/count_tokens?beta=true")
                or self.headers.get("x-api-key") != "synthetic-anthropic-private"
                or self.headers.get("Authorization") is not None
                or self.headers.get("anthropic-version") != "2023-06-01"
            ):
                return self.reject("identity", 403)
            effect = "count_tokens" if "/count_tokens?" in self.path else "messages"
        else:
            return self.reject("identity", 403)
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > 262_144:
                return self.reject("body_size")
            request = object_fields(json.loads(self.rfile.read(length)))
        except (ValueError, UnicodeDecodeError):
            return self.reject("body_json")
        if request is None:
            return self.reject("envelope")
        if effect == "responses":
            if (
                request.get("model") != "fixture-model"
                or request.get("stream") is not True
                or request.get("store") is not False
                or object_list(request.get("input")) is None
            ):
                return self.reject("envelope")
        else:
            model = request.get("model")
            if (
                not isinstance(model, str)
                or not model.startswith("fixture-")
                or not object_list(request.get("messages"))
            ):
                return self.reject("envelope")
            if effect == "messages" and request.get("stream") is not True:
                return self.reject("envelope")
        with effects_lock:
            effects[effect] += 1
        if effect == "responses":
            return self.codex_response()
        if effect == "count_tokens":
            return self.reply(200, {"input_tokens": 5})
        model = request.get("model")
        if not isinstance(model, str):
            return self.reject("envelope")
        return self.claude_response(model, request.get("stream") is True)

    def codex_response(self) -> None:
        text = "fixture codex reply"
        item: dict[str, object] = {
            "id": "fixture-codex-message",
            "type": "message",
            "role": "assistant",
            "status": "completed",
            "content": [{"type": "output_text", "text": text, "annotations": []}],
        }
        response: dict[str, object] = {
            "id": "fixture-codex-response",
            "object": "response",
            "created_at": 1,
            "model": "fixture-model",
            "status": "completed",
            "output": [item],
            "usage": {
                "input_tokens": 5,
                "output_tokens": 7,
                "total_tokens": 12,
                "input_tokens_details": {"cached_tokens": 0},
                "output_tokens_details": {"reasoning_tokens": 0},
            },
        }
        events: list[dict[str, object]] = [
            {
                "type": "response.created",
                "response": {**response, "status": "in_progress", "output": []},
            },
            {
                "type": "response.output_item.added",
                "output_index": 0,
                "item": {**item, "status": "in_progress", "content": []},
            },
            {
                "type": "response.content_part.added",
                "item_id": item["id"],
                "output_index": 0,
                "content_index": 0,
                "part": {"type": "output_text", "text": "", "annotations": []},
            },
            {
                "type": "response.output_text.delta",
                "item_id": item["id"],
                "output_index": 0,
                "content_index": 0,
                "delta": text,
            },
            {
                "type": "response.output_text.done",
                "item_id": item["id"],
                "output_index": 0,
                "content_index": 0,
                "text": text,
            },
            {"type": "response.output_item.done", "output_index": 0, "item": item},
            {"type": "response.completed", "response": response},
        ]
        self.event_stream(events)

    def claude_response(self, model: str, stream: bool) -> None:
        text = "fixture claude reply"
        message: dict[str, object] = {
            "id": "fixture-claude-message",
            "type": "message",
            "role": "assistant",
            "model": model,
            "content": [{"type": "text", "text": text}],
            "stop_reason": "end_turn",
            "stop_sequence": None,
            "usage": {"input_tokens": 5, "output_tokens": 7},
        }
        if not stream:
            return self.reply(200, message)
        events: list[dict[str, object]] = [
            {
                "type": "message_start",
                "message": {
                    **message,
                    "content": [],
                    "stop_reason": None,
                    "usage": {"input_tokens": 5, "output_tokens": 0},
                },
            },
            {
                "type": "content_block_start",
                "index": 0,
                "content_block": {"type": "text", "text": ""},
            },
            {
                "type": "content_block_delta",
                "index": 0,
                "delta": {"type": "text_delta", "text": text},
            },
            {"type": "content_block_stop", "index": 0},
            {
                "type": "message_delta",
                "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                "usage": {"output_tokens": 7},
            },
            {"type": "message_stop"},
        ]
        self.event_stream(events)

    def event_stream(self, events: list[dict[str, object]]) -> None:
        raw = b"".join(
            ("event: " + str(event["type"]) + "\ndata: " + json.dumps(event) + "\n\n").encode()
            for event in events
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("x-request-id", "fixture-request")
        self.end_headers()
        self.wfile.write(raw)

    def reject(
        self,
        reason: Literal[
            "mode",
            "identity",
            "body_size",
            "body_json",
            "envelope",
            "input",
            "tools",
            "prompt",
            "tool_output",
        ],
        status: int = 400,
    ) -> None:
        """@cc [owner:ghuntley,label:verification;security] provider-closed-refusal
        Refusals MUST report only the finite validation-stage code and HTTP
        status. Neither request-derived values nor exception text may be logged.
        """
        print(
            json.dumps({"event": "fixture_provider_refused", "reason": reason, "status": status}),
            flush=True,
        )
        self.reply(status, {})

    def reply(self, status: int, value: dict[str, object]) -> None:
        raw = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", 443), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(sys.argv[1], sys.argv[2])
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
