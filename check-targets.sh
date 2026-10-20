#!/bin/bash

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a; source "$SCRIPT_DIR/../.env"; set +a
fi

TARGETS_FILE="$SCRIPT_DIR/targets.txt"
BACKUP_FILE="$SCRIPT_DIR/targets.bak"
SESSION_FILE="$SCRIPT_DIR/config/session-${IG_USERNAME}"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Check if targets file exists
if [ ! -f "$TARGETS_FILE" ]; then
    echo "Error: Targets file not found at $TARGETS_FILE"
    exit 1
fi

# Create a backup before modifying
cp "$TARGETS_FILE" "$BACKUP_FILE"

# Temporary file to store active users
TEMP_FILE=$(mktemp)

echo "Starting Instagram target validation..."
echo "----------------------------------------"

while IFS= read -r username || [ -n "$username" ]; do
    # Skip empty lines or comments
    [[ -z "$username" || "$username" =~ ^# ]] && continue

    # Trim whitespace
    username=$(echo "$username" | tr -d '[:space:]')

    echo -n "Checking @$username... "

    # 1. Capture response headers cleanly (using direct domain format to bypass root 301)
    # Using lowercase header evaluation via tr to avoid edge engine quirks
    HEADERS=$(curl -s -I -A "$USER_AGENT" "https://www.instagram.com/$username/" | tr '[:upper:]' '[:lower:]')

    # Extract the HTTP status code explicitly
    STATUS_CODE=$(echo "$HEADERS" | grep "^http/" | awk '{print $2}' | head -n 1)

    # 2. Evaluation Ruleset
    if echo "$HEADERS" | grep -q "x-compress-hint: regular"; then
        # Meta flags dead/moved client-side fallback layouts with this specific header
        echo "NOT FOUND (Edge Flag) -> Removing"

    elif echo "$HEADERS" | grep -q "location:.*\/accounts\/login\/"; then
        # Direct fallback string check if it tries to throw a redirection payload
        echo "REDIRECTED TO LOGIN -> Removing (Changed/Removed)"

    elif [[ "$STATUS_CODE" == "404" ]]; then
        echo "NOT FOUND (404) -> Removing"

    elif [[ "$STATUS_CODE" == "429" ]] || echo "$HEADERS" | grep -q "location:.*\/challenge\/"; then
        # Keeping if your ARM node hits an intentional infrastructure limit or challenge gate
        echo "RATE LIMITED / CHALLENGE WALL -> Keeping for safety"
        echo "$username" >> "$TEMP_FILE"

    elif [[ "$STATUS_CODE" == "200" || "$STATUS_CODE" == "302" ]]; then
        echo "Active ($STATUS_CODE) -> Keeping"
        echo "$username" >> "$TEMP_FILE"

    else
        # Catch-all for gateway dropouts, connection timeouts, or temporary 5xx infrastructure errors
        echo "Uncertain ($STATUS_CODE) -> Keeping for safety"
        echo "$username" >> "$TEMP_FILE"
    fi

    # 4-second delay to preserve IP standing against rate limits
    sleep 4

done < "$TARGETS_FILE"

# Overwrite the original list with verified handles
mv "$TEMP_FILE" "$TARGETS_FILE"

echo "----------------------------------------"
echo "Done! Updated targets saved to $TARGETS_FILE"
echo "Backup of original list saved to $BACKUP_FILE"
