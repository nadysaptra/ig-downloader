#!/bin/bash

# --- CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a; source "$SCRIPT_DIR/../.env"; set +a
fi

if [ -f "$SCRIPT_DIR/venv/bin/instaloader" ]; then
    INSTALOADER="$SCRIPT_DIR/venv/bin/instaloader"
else
    INSTALOADER="instaloader"
fi
SESSION_FILE="$SCRIPT_DIR/config/session-${IG_USERNAME}"
DOWNLOAD_DIR="$SCRIPT_DIR/downloads"
TARGETS_FILE="$SCRIPT_DIR/targets.txt"

if curl -s --connect-timeout 2 "http://${LOCAL_GATEWAY}" -o /dev/null 2>/dev/null; then
    export HTTP_PROXY="http://${PROXY_USER}:${PROXY_PASS}@${LOCAL_GATEWAY}"
    export HTTPS_PROXY="http://${PROXY_USER}:${PROXY_PASS}@${LOCAL_GATEWAY}"
    echo "🌐 Proxy active: $LOCAL_GATEWAY"
else
    echo "⚠️  Proxy not reachable — running without proxy"
fi
# ---------------------

echo "🔥 Stories Download started at $(date)"

while IFS= read -r TARGET || [[ -n "$TARGET" ]]; do
    TARGET=$(echo "$TARGET" | xargs)
    [[ -z "$TARGET" || "$TARGET" =~ ^# ]] && continue

    echo "⚡ Fetching stories for @$TARGET..."
    "$INSTALOADER" --sessionfile="$SESSION_FILE" \
                --login="$IG_USERNAME" \
                --stories \
                --no-posts \
                --request-timeout 300 \
                --max-connection-attempts 3 \
                --dirname-pattern="$DOWNLOAD_DIR/{target}" \
                "$TARGET"

    SLEEP_TIME=$((60 + RANDOM % 60))
    echo "⏳ Sleeping ${SLEEP_TIME}s before next target..."
    sleep "$SLEEP_TIME"
done < "$TARGETS_FILE"

echo "🏁 Stories download complete at $(date)"
