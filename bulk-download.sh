#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a; source "$SCRIPT_DIR/../.env"; set +a
fi

if [ -f "$SCRIPT_DIR/venv/bin/gallery-dl" ]; then
    GALLERY_DL="$SCRIPT_DIR/venv/bin/gallery-dl"
else
    GALLERY_DL="gallery-dl"
fi

# File paths
TARGETS_FILE="$SCRIPT_DIR/targets.txt"
CONFIG_FILE="$SCRIPT_DIR/config/config.json"
COOKIES_FILE="$SCRIPT_DIR/cookies.txt"
OUTPUT_DIR="$SCRIPT_DIR/downloads"

# Check if targets.txt exists
if [ ! -f "$TARGETS_FILE" ]; then
    echo "Error: $TARGETS_FILE not found!"
    exit 1
fi

# Check if working cookies file exists
if [ ! -f "$COOKIES_FILE" ]; then
    echo "Error: Working cookies file not found at $COOKIES_FILE"
    exit 1
fi

# Create downloads directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clear gallery-dl cache to force fresh cookie/config usage
echo "Clearing gallery-dl session cache..."
"$GALLERY_DL" --clear-cache instagram >/dev/null 2>&1

echo "=========================================="
echo " Starting Instagram Bulk Downloader"
echo "=========================================="

# Build base arguments array
G_FLAGS=()
if [ -f "$CONFIG_FILE" ]; then
    G_FLAGS+=("--config" "$CONFIG_FILE")
fi

# Read each line from targets.txt, ignoring empty lines and comments
while IFS= read -r username || [ -n "$username" ]; do
    username=$(echo "$username" | xargs)

    if [ -z "$username" ] || [[ "$username" =~ ^# ]]; then
        continue
    fi

    username="${username#@}"

    user_dir="$OUTPUT_DIR/$username"
    mkdir -p "$user_dir"

    echo ""
    echo "------------------------------------------"
    echo " Downloading profile: $username"
    echo " Destination: $user_dir"
    echo "------------------------------------------"

    "$GALLERY_DL" "${G_FLAGS[@]}" \
        --cookies "$COOKIES_FILE" \
        --directory "$user_dir" \
        --download-archive "$user_dir/archive.sqlite" \
        --sleep 2-4 \
        "https://www.instagram.com/$username/"

    sleep 5
done < "$TARGETS_FILE"

echo ""
echo "=========================================="
echo " Bulk Download Finished!"
echo "=========================================="
