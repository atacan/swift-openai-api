#!/usr/bin/env python3
"""Capture real Chat Completions payloads with curl; never run from swift test."""

import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    resources = (
        Path(__file__).resolve().parents[1]
        / "Tests/SwiftOpenaiApiTests/Resources/ChatCompletions"
    )
    cases = json.loads((resources / "cases.json").read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", choices=[case["name"] for case in cases])
    selected = parser.parse_args().case
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
        config = 'header = "Content-Type: application/json"\n'
        if case.get("authenticated", True):
            # Pass credentials over stdin, keeping them out of argv and fixtures.
            escaped_key = api_key.replace("\\", "\\\\").replace('"', '\\"')
            config += f'header = "Authorization: Bearer {escaped_key}"\n'

        with tempfile.TemporaryDirectory() as temporary:
            payload = Path(temporary) / "response"
            result = subprocess.run(
                [
                    "curl", "--silent", "--show-error", "--max-time", "60",
                    "--config", "-", "--request", "POST",
                    "--data-binary", f"@{request}", "--output", str(payload),
                    "--write-out", "%{http_code}\\n%{content_type}",
                    "https://api.openai.com/v1/chat/completions",
                ],
                input=config, text=True, capture_output=True, check=True,
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
            elif b"data: [DONE]" not in raw:
                raise SystemExit(f"{case['name']}: incomplete SSE stream; fixture preserved.")
            if api_key.encode() in raw:
                raise SystemExit(f"{case['name']}: credential in response; fixture not saved.")
            response.write_bytes(raw)

        captures = [capture for capture in captures if capture["name"] != case["name"]]
        captures.append({
            "name": case["name"],
            "status": int(status),
            "content_type": content_type,
            "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        })
        captures_file.write_text(json.dumps(captures, indent=2) + "\n")
        print(f"{case['name']}: HTTP {status} -> {response.name}", flush=True)


if __name__ == "__main__":
    main()
