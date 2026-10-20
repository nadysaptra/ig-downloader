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
DL_LIMIT=10

if curl -s --connect-timeout 2 "http://${LOCAL_GATEWAY}" -o /dev/null 2>/dev/null; then
    export HTTP_PROXY="http://${PROXY_USER}:${PROXY_PASS}@${LOCAL_GATEWAY}"
    export HTTPS_PROXY="http://${PROXY_USER}:${PROXY_PASS}@${LOCAL_GATEWAY}"
    echo "🌐 Proxy active: $LOCAL_GATEWAY"
else
    echo "⚠️  Proxy not reachable — running without proxy"
fi
# ---------------------

echo "📸 Posts / Reels / Highlights Download started at $(date)"

while IFS= read -r TARGET || [[ -n "$TARGET" ]]; do
    TARGET=$(echo "$TARGET" | xargs)
    [[ -z "$TARGET" || "$TARGET" =~ ^# ]] && continue

    echo "📂 Processing @$TARGET (Posts / Reels / Highlights)..."
    "$INSTALOADER" --sessionfile="$SESSION_FILE" \
                --login="$IG_USERNAME" \
                --highlights \
                --reels \
                --fast-update \
                --count=$DL_LIMIT \
                --dirname-pattern="$DOWNLOAD_DIR/{target}" \
                "$TARGET"

    echo "✅ Finished @$TARGET. Sleeping 60s..."
    sleep 60
done < "$TARGETS_FILE"

echo "🏁 All tasks completed at $(date)"
