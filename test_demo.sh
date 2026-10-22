#!/bin/bash
set -e

# Target host/port (defaults to 8085 if running locally in docker, or 8080 if on EC2 / native)
TARGET_PORT="${DEMO_PORT:-8085}"
BASE_URL="http://127.0.0.1:${TARGET_PORT}"

# Color formatting
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}======================================================${RESET}"
echo -e "${BOLD}${CYAN}   NGINX Plus Caching & Rate Limiting Demo Runner     ${RESET}"
echo -e "${BOLD}${CYAN}   Targeting: ${BASE_URL}                            ${RESET}"
echo -e "${BOLD}${CYAN}======================================================${RESET}"

# Function to check connectivity
check_health() {
    echo -n "Checking connectivity to NGINX Plus at ${BASE_URL}... "
    if curl -s -f -m 3 "${BASE_URL}/" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${RESET}\n"
    else
        echo -e "${RED}FAILED${RESET}"
        echo -e "Could not connect to ${BASE_URL}. Is NGINX Plus running?"
        echo -e "If using port 8080, run: DEMO_PORT=8080 ./test_demo.sh"
        exit 1
    fi
}

demo_a() {
    echo -e "${BOLD}${YELLOW}--- Demo A: Proxy Caching (MISS -> HIT) ---${RESET}"
    echo "Simulating repeated downloads for a new artifact..."
    JAR_URL="${BASE_URL}/artifactory/libs-release/demo-$(date +%s).jar"
    echo "Artifact URL: ${JAR_URL}"
    echo ""

    for i in 1 2 3; do
        echo -e "${BOLD}Request #${i}:${RESET}"
        curl -sS -D - -o /dev/null -w 'Total time: %{time_total}s\n\n' "$JAR_URL" | grep -E "(HTTP/|X-Cache-Status|X-Origin-Request|Total time)"
    done
    echo -e "${GREEN}Takeaway:${RESET} Notice the first request is a MISS (~0.35s), and subsequent requests are HITs (<0.01s) with identical origin request counter."
    echo ""
}

demo_b() {
    echo -e "${BOLD}${YELLOW}--- Demo B: Request Rate Limiting (5r/s + 5 burst) ---${RESET}"
    echo "1) Normal single request:"
    curl -i -s "${BASE_URL}/rate-test/" | grep -E "(HTTP/|X-Rate-Limit-Status)"
    echo ""

    echo "2) Sending burst of 30 concurrent requests (xargs -P 20)..."
    seq 1 30 | xargs -P 20 -I{} \
        curl -s -o /dev/null -w '%{http_code}\n' \
        "${BASE_URL}/rate-test/" \
        | sort | uniq -c
    echo ""
    echo -e "${GREEN}Takeaway:${RESET} Allowed burst requests pass with HTTP 200; excess requests are rejected with HTTP 429 Too Many Requests."
    echo ""
}

demo_c() {
    echo -e "${BOLD}${YELLOW}--- Demo C: Authenticated Requests Bypass Cache ---${RESET}"
    JAR_URL="${BASE_URL}/artifactory/libs-release/auth-demo-$(date +%s).jar"
    echo "Making requests with Authorization header..."
    echo ""

    for i in 1 2; do
        echo -e "${BOLD}Request #${i} with Bearer Token:${RESET}"
        curl -sS -D - -o /dev/null \
            -H "Authorization: Bearer demo-token-xyz" \
            -w 'Total time: %{time_total}s\n\n' \
            "$JAR_URL" | grep -E "(HTTP/|X-Cache-Status|X-Origin-Request|Total time)"
    done
    echo -e "${GREEN}Takeaway:${RESET} Sensitive responses bypass the shared cache (X-Cache-Status: BYPASS) and increment the origin counter each time."
    echo ""
}

demo_d() {
    echo -e "${BOLD}${YELLOW}--- Demo D: NGINX Plus Live Monitoring & API ---${RESET}"
    echo -e "Dashboard is accessible in browser at: ${BOLD}${CYAN}${BASE_URL}/dashboard.html${RESET}"
    echo ""
    echo "Querying NGINX Plus API..."
    API_VERSION=$(curl -s "${BASE_URL}/api/" | python3 -c 'import json,sys; print(max(json.load(sys.stdin)))' 2>/dev/null || echo "9")
    echo "Using API Version: ${API_VERSION}"
    echo ""

    echo -e "${BOLD}1. Cache Zone Metrics (artifact_cache):${RESET}"
    curl -s "${BASE_URL}/api/${API_VERSION}/http/caches/artifact_cache" | python3 -m json.tool || true
    echo ""

    echo -e "${BOLD}2. Upstream Health & Counters (artifact_origin):${RESET}"
    curl -s "${BASE_URL}/api/${API_VERSION}/http/upstreams/artifact_origin" | python3 -m json.tool || true
    echo ""
}

demo_e() {
    echo -e "${BOLD}${YELLOW}--- Demo E: Stale Cache on Origin Failure ---${RESET}"
    STALE_URL="${BASE_URL}/artifactory/libs-release/stale-demo-$(date +%s).jar"
    echo "1) Priming cache with an artifact..."
    curl -sS -D - -o /dev/null "$STALE_URL" | grep -E "(HTTP/|X-Cache-Status)"
    echo ""

    echo -e "To complete Demo E, stop the origin inside the container or VM:"
    echo "  docker exec -it nginx-plus-demo kill \$(cat /opt/nginx-plus-demo/origin.pid)"
    echo "Wait 65 seconds for the 60s cache TTL to expire, then run:"
    echo "  curl -sS -D - -o /dev/null \"$STALE_URL\""
    echo "You will see: HTTP/1.1 200 OK with X-Cache-Status: STALE"
    echo ""
}

run_all() {
    demo_a
    demo_b
    demo_c
    demo_d
}

check_health

case "$1" in
    a|A) demo_a ;;
    b|B) demo_b ;;
    c|C) demo_c ;;
    d|D) demo_d ;;
    e|E) demo_e ;;
    all|"") run_all ;;
    *)
        echo "Usage: $0 [a|b|c|d|e|all]"
        exit 1
        ;;
esac
