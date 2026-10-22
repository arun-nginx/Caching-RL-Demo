# NGINX Plus Demo: Artifact Caching & Rate Limiting

This workspace is fully configured and running locally on your macOS system using **NGINX Plus R37** inside Docker, using your provided license credentials (`license.crt`, `license.key`, `license.jwt`).

---

## 🚀 Quick Status & Access

| Component | URL | Notes |
|---|---|---|
| **NGINX Plus Server** | `http://127.0.0.1:8085/` | Listens locally on port `8085` |
| **Live Dashboard** | `http://127.0.0.1:8085/dashboard.html` | Real-time Plus UI for caches, upstreams & health |
| **Live Plus API** | `http://127.0.0.1:8085/api/` | REST API for stats and upstream configuration |
| **Artifact Cache Route** | `http://127.0.0.1:8085/artifactory/` | Demonstrates proxy caching & auth bypass |
| **Rate Limit Route** | `http://127.0.0.1:8085/rate-test/` | Demonstrates burst protection (429 on bursts) |

> **Note on Port 8085:** Since port `8080` was already occupied by an existing Tomcat container on your machine, NGINX Plus is exposed on port **`8085`** (`8085:8080`). If you stop the conflicting container, you can switch back to `8080` anytime.

---

## 🎯 Running the Demo Scenarios

We have prepared an automated runner script `test_demo.sh` that demonstrates all test cases:

```bash
# Run all demo tests
./test_demo.sh

# Or run individual demo steps:
./test_demo.sh a    # Demo A: Cache MISS -> HIT
./test_demo.sh b    # Demo B: Rate limiting burst (429s)
./test_demo.sh c    # Demo C: Auth header bypasses cache
./test_demo.sh d    # Demo D: Live API metrics
./test_demo.sh e    # Demo E: Stale cache on origin failure instructions
```

---

## 📋 Walkthrough & Talk Track for Each Demo

### Demo A — Cache MISS → HIT
```bash
./test_demo.sh a
```
- **What happens:**
  - 1st request to a new artifact takes ~0.35s with `X-Cache-Status: MISS` and origin counter `1`.
  - 2nd and 3rd requests return in <0.005s with `X-Cache-Status: HIT` and unchanged origin counter.
- **What to say:**
  > *"The first download reaches the artifact origin. NGINX stores the response. Subsequent downloads are served directly from cache without placing any load on the origin, slashing latency by ~90%."*

---

### Demo B — Origin Burst Protection (Rate Limiting)
```bash
./test_demo.sh b
```
- **What happens:**
  - Sends a burst of 30 concurrent requests to `/rate-test/`.
  - NGINX Plus passes the initial burst capacity (HTTP 200) and immediately sheds excess requests with `HTTP 429 Too Many Requests`.
- **What to say:**
  > *"This protects downstream Artifactory capacity during CI runner spikes. Excess requests receive HTTP 429 immediately instead of causing origin thread exhaustion."*

---

### Demo C — Credentialed Downloads Bypass Shared Cache
```bash
./test_demo.sh c
```
- **What happens:**
  - Requests carrying an `Authorization: Bearer ...` header return `X-Cache-Status: BYPASS` and increment the origin counter each time.
- **What to say:**
  > *"Private packages and security-sensitive downloads must not be accidentally cached in a shared pool. Here, credentialed requests bypass shared storage completely."*

---

### Demo D — NGINX Plus Live Dashboard & API
Open in your browser:
👉 **[http://localhost:8085/dashboard.html](http://localhost:8085/dashboard.html)**

Or query the API:
```bash
./test_demo.sh d
```
- **What happens:**
  - Live inspection of `artifact_cache` (hit/miss ratio, size, memory consumption).
  - Live inspection of `artifact_origin` upstream (active health check status, latency distribution histograms, request counters).
- **What to say:**
  > *"Unlike open-source NGINX where monitoring requires external metric scrapers or log parsing, NGINX Plus provides live operational observability and active health checking out of the box."*

---

## 🛠️ Management & Files

- `Dockerfile`: Multi-stage build integrating `license.crt`, `license.key`, and `license.jwt` directly into the official `nginx-plus` package.
- `nginx.conf`: NGINX Plus configuration with `status_zone`, active `health_check`, `limit_req_zone`, `proxy_cache`, and `/api/` monitoring.
- `origin.py`: Python mock Artifactory service simulating realistic latency (350ms) and health endpoints.
- `docker-compose.yml`: Compose file for running and volume-mounting configs.

### Useful Commands:
```bash
# View live NGINX Plus container logs
docker logs -f nginx-plus-demo

# Stop container
docker stop nginx-plus-demo

# Restart container
docker start nginx-plus-demo

# Enter container shell
docker exec -it nginx-plus-demo bash
```

