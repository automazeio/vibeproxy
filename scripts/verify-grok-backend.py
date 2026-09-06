#!/usr/bin/env python3
"""Check model registration offline with a synthetic account; never calls xAI."""
import json
import pathlib
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

binary = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="vibeproxy-grok-") as temporary:
    root = pathlib.Path(temporary)
    auth = root / "auth"
    auth.mkdir()
    (auth / "xai-test.json").write_text(json.dumps({
        "type": "xai", "auth_kind": "oauth",
        "access_token": "synthetic-test-token", "email": "test@example.com",
        "expired": "2099-01-01T00:00:00Z"
    }))
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    config = root / "config.yaml"
    config.write_text(f'host: "127.0.0.1"\nport: {port}\nauth-dir: {json.dumps(str(auth))}\napi-keys: ["local-test-key"]\n')
    with (root / "backend.log").open("w+") as log:
        process = subprocess.Popen([str(binary), "--config", str(config), "-local-model"], stdout=log, stderr=log, cwd=root)
        try:
            request = urllib.request.Request(f"http://127.0.0.1:{port}/v1/models", headers={"Authorization": "Bearer local-test-key"})
            deadline = time.monotonic() + 30
            while True:
                try:
                    with urllib.request.urlopen(request, timeout=2) as response:
                        models = {model["id"] for model in json.load(response)["data"]}
                    if {"grok-4.6", "grok-build-0.1"} <= models:
                        print("PASS: stock backend registers grok-4.6 and grok-build-0.1 with an offline synthetic xAI account")
                        break
                except (urllib.error.URLError, TimeoutError):
                    pass
                if process.poll() is not None or time.monotonic() >= deadline:
                    log.flush()
                    log.seek(0)
                    raise RuntimeError("Backend model discovery failed:\n" + log.read())
                time.sleep(0.2)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
