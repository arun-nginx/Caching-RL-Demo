from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import threading
import time
import sys

counter = 0
lock = threading.Lock()

# 240 KB artifact payload
ARTIFACT = b"DEMO ARTIFACT CONTENT\n" * 12000

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        # Clean logging
        sys.stderr.write(f"[Mock Origin] {self.address_string()} - {format % args}\n")

    def do_GET(self):
        global counter

        if self.path == "/health":
            body = b"healthy\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        with lock:
            counter += 1
            request_id = counter

        # Artificial latency to make cache misses noticeable (350ms)
        time.sleep(0.35)

        private = bool(
            self.headers.get("Authorization") or
            self.headers.get("Cookie")
        )

        if self.path.startswith("/artifactory/"):
            body = ARTIFACT
            content_type = "application/octet-stream"
        else:
            body = f"Origin handled request {request_id}\n".encode()
            content_type = "text/plain"

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Origin-Request", str(request_id))
        self.send_header(
            "Cache-Control",
            "private, no-store" if private else "public, max-age=60"
        )
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
    print(f"Mock Artifactory Origin listening on 0.0.0.0:{port}...")
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.serve_forever()
