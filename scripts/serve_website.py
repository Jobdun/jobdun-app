#!/usr/bin/env python3
"""Static file server for the Jobdun marketing-site build.

Binds to 0.0.0.0 so phones / other devices on the LAN can open
http://<lan-ip>:8080/ and see the site. Not a production server —
Cloudflare Pages serves build/web/ in prod and honours _headers /
_redirects; this script does neither.
"""

import http.server
import os
import socketserver
import sys

PORT = int(os.environ.get("PORT", "8080"))
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
ROOT = os.path.normpath(ROOT)

if not os.path.isdir(ROOT):
    print(f"build/web not found at {ROOT}", file=sys.stderr)
    sys.exit(1)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # Mirror the Cloudflare Pages _headers for local parity:
        # don't index admin-style, allow SPA fallback is faked by always
        # serving index.html for unknown paths (Cloudflare does this via
        # _redirects; here we just hand back 404 for missing files).
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("[serve] " + (fmt % args) + "\n")


with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    httpd.allow_reuse_address = True
    print(f"Serving {ROOT} on http://0.0.0.0:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nshutting down")
        httpd.shutdown()
