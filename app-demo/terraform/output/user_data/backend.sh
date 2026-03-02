#!/usr/bin/env bash
set -euo pipefail

# Minimal backend bootstrap.
# This intentionally does not assume a specific app artifact; it provides a
# predictable health endpoint and keeps the VM alive for LB member testing.

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y python3
fi

cat >/opt/backend_server.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health" or self.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok\n")
            return

        self.send_response(404)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"not found\n")


HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
PY

nohup python3 /opt/backend_server.py >/var/log/backend_server.log 2>&1 &
