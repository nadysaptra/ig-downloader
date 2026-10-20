#!/bin/bash

# --- CONFIGURATION ---
IG_USERNAME="kapuk2026"
SESSION_FILE="config/session-kapuk2026"
BASE_DIR="$HOME/ig-downloader"
DOWNLOAD_DIR="$BASE_DIR/downloads"
TARGETS_FILE="$BASE_DIR/targets.txt"
DL_LIMIT=10

PROXY_USER="tcebfiji"
PROXY_PASS="zmnglapu85ev"
LOCAL_GATEWAY="127.0.0.1:8118"

export HTTP_PROXY="http://${PROXY_USER}:${PROXY_PASS}@${LOCAL_GATEWAY}"
export HTTPS_PROXY="http://${PROXY_USER}:${PROXY_PASS}@${LOCAL_GATEWAY}"
# ---------------------

echo "🚀 Instagram Download started at $(date)"
echo "🌐 Outbound traffic routed through HAProxy rotation gateway (Port 8118)"

# ---------------------

echo "🚀 Instagram Download started at $(date)"

# --- PASS 1: STORIES ONLY (High Priority) ---
echo "🔥 Phase 1: Downloading Stories first..."
while IFS= read -r TARGET || [[ -n "$TARGET" ]]; do
    TARGET=$(echo "$TARGET" | xargs)
    [[ -z "$TARGET" || "$TARGET" =~ ^# ]] && continue

    echo "⚡ High Priority: @$TARGET Stories..."
    instaloader --sessionfile="$BASE_DIR/$SESSION_FILE" \
                --login="$IG_USERNAME" \
                --stories --no-posts \
                --dirname-pattern="$DOWNLOAD_DIR/{target}" \
                "$TARGET"
    
    # Short sleep to avoid being flagged during rapid metadata requests
    sleep 5 
done < "$TARGETS_FILE"

echo "⏳ Stories secured. Resting for 60s before Phase 2..."
sleep 60

# --- PASS 2: POSTS & HIGHLIGHTS ---
echo "📂 Phase 2: Downloading remaining media..."
while IFS= read -r TARGET || [[ -n "$TARGET" ]]; do
    TARGET=$(echo "$TARGET" | xargs)
    [[ -z "$TARGET" || "$TARGET" =~ ^# ]] && continue

    echo "📸 Processing @$TARGET (Posts/Highlights)..."
    instaloader --sessionfile="$BASE_DIR/$SESSION_FILE" \
                --login="$IG_USERNAME" \
                --highlights \
                --fast-update \
                --count=$DL_LIMIT \
                --dirname-pattern="$DOWNLOAD_DIR/{target}" \
                "$TARGET"

    echo "✅ Finished @$TARGET. Sleeping 60s..."
    sleep 60
done < "$TARGETS_FILE"

echo "🏁 All tasks completed at $(date)"
