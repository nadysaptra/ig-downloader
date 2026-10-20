#!/usr/bin/env bash

# Resolve absolute path of the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
gallery-dl --clear-cache instagram >/dev/null 2>&1

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
    # Trim whitespace
    username=$(echo "$username" | xargs)

    # Skip empty lines or commented lines starting with #
    if [ -z "$username" ] || [[ "$username" =~ ^# ]]; then
        continue
    fi

    # Strip leading @ if present
    username="${username#@}"

    user_dir="$OUTPUT_DIR/$username"
    mkdir -p "$user_dir"

    echo ""
    echo "------------------------------------------"
    echo " Downloading profile: $username"
    echo " Destination: $user_dir"
    echo "------------------------------------------"

    gallery-dl "${G_FLAGS[@]}" \
        --cookies "$COOKIES_FILE" \
        --directory "$user_dir" \
        --download-archive "$user_dir/archive.sqlite" \
        --sleep 2-4 \
        "https://www.instagram.com/$username/"

    # Delay between user profiles to mitigate account flags
    sleep 5
done < "$TARGETS_FILE"

echo ""
echo "=========================================="
echo " Bulk Download Finished!"
echo "=========================================="
