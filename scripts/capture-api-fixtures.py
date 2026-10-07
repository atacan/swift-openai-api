#!/usr/bin/env python3
"""Capture real API payloads with curl; never run from swift test."""

import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("api", choices=["chat-completions", "responses", "audio"])
    parser.add_argument(
        "--case",
        action="append",
        metavar="NAME",
        help="Capture only this scenario; may be repeated.",
    )
    args = parser.parse_args()
    directory, endpoint = {
        "chat-completions": ("ChatCompletions", "chat/completions"),
        "responses": ("Responses", "responses"),
        "audio": ("Audio", None),
    }[args.api]
    resources = (
        Path(__file__).resolve().parents[1]
        / "Tests/SwiftOpenaiApiTests/Resources"
        / directory
    )
    cases = json.loads((resources / "cases.json").read_text())
    selected = args.case
    names = {case["name"] for case in cases}
    if selected and (unknown := set(selected) - names):
        parser.error(
            f"Unknown scenarios: {', '.join(sorted(unknown))}. Available: {', '.join(sorted(names))}"
        )
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("Set OPENAI_API_KEY before capturing fixtures.")
    captures_file = resources / "captures.json"
    captures = json.loads(captures_file.read_text()) if captures_file.exists() else []
    for case in cases:
        if selected and case["name"] not in selected:
            continue
        request = resources / "Requests" / (case["name"] + ".json")
        response = resources / case["response"]
        content_type = case.get("request_content_type", "application/json")
        config = ""
        if content_type == "multipart/form-data":
            fields = json.loads(request.read_text())
            request_args = []
            for name, value in fields.items():
                if name == "file":
                    upload = resources / value
                    if not upload.is_file():
                        raise SystemExit(
                            f"{case['name']}: missing audio input {value}."
                        )
                    request_args += ["--form", f"{name}=@{upload}"]
                else:
                    values = value if isinstance(value, list) else [value]
                    field_name = name + "[]" if isinstance(value, list) else name
                    for item in values:
                        encoded = item if isinstance(item, str) else json.dumps(item)
                        request_args += ["--form-string", f"{field_name}={encoded}"]
        else:
            config += 'header = "Content-Type: application/json"\n'
            request_args = ["--data-binary", f"@{request}"]
        if case.get("authenticated", True):
            # Pass credentials over stdin, keeping them out of argv and fixtures.
            escaped_key = api_key.replace("\\", "\\\\").replace('"', '\\"')
            config += f'header = "Authorization: Bearer {escaped_key}"\n'

        with tempfile.TemporaryDirectory() as temporary:
            payload = Path(temporary) / "response"
            result = subprocess.run(
                [
                    "curl",
                    "--silent",
                    "--show-error",
                    "--max-time",
                    "60",
                    "--config",
                    "-",
                    "--request",
                    "POST",
                    *request_args,
                    "--output",
                    str(payload),
                    "--write-out",
                    "%{http_code}\\n%{content_type}",
                    f"https://api.openai.com/v1/{case.get('endpoint', endpoint)}",
                ],
                input=config,
                text=True,
                capture_output=True,
                check=True,
            )
            status, content_type = result.stdout.splitlines()
            media_type = content_type.split(";", 1)[0]
            if int(status) != case["status"] or media_type != case["content_type"]:
                # Do not print error bodies: authentication errors may echo credentials.
                raise SystemExit(
                    f"{case['name']}: expected {case['status']} {case['content_type']}, "
                    f"received {status} {content_type}; existing fixture preserved."
                )
            raw = payload.read_bytes()
            if media_type == "application/json":
                json.loads(raw)
            elif media_type == "text/event-stream":
                frames = raw.decode().replace("\r\n", "\n").split("\n\n")
                data = [
                    "\n".join(
                        line[5:].lstrip(" ")
                        for line in frame.splitlines()
                        if line.startswith("data:")
                    )
                    for frame in frames
                    if any(line.startswith("data:") for line in frame.splitlines())
                ]
                for event in data:
                    if event != "[DONE]":
                        json.loads(event)
                events = [event for event in data if event != "[DONE]"]
                complete = bool(events) and (
                    data[-1] == "[DONE]"
                    if args.api == "chat-completions"
                    else json.loads(events[-1]).get("type") == case["terminal_event"]
                )
                if args.api == "audio":
                    complete = complete and data[-1] == "[DONE]"
                if not complete:
                    raise SystemExit(
                        f"{case['name']}: incomplete SSE stream; fixture preserved."
                    )
            elif media_type.startswith("text/"):
                raw.decode("utf-8")
            if not raw:
                raise SystemExit(f"{case['name']}: empty response; fixture preserved.")
            if api_key.encode() in raw:
                raise SystemExit(
                    f"{case['name']}: credential in response; fixture not saved."
                )
            response.write_bytes(raw)

        captures = [capture for capture in captures if capture["name"] != case["name"]]
        captures.append(
            {
                "name": case["name"],
                "status": int(status),
                "content_type": content_type,
                "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            }
        )
        captures_file.write_text(json.dumps(captures, indent=2) + "\n")
        print(f"{case['name']}: HTTP {status} -> {response.name}", flush=True)


if __name__ == "__main__":
    main()
