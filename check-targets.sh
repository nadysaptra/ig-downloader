#!/bin/bash

# Configuration
TARGETS_FILE="$HOME/ig-downloader/targets.txt"
BACKUP_FILE="$HOME/ig-downloader/targets.bak"
SESSION_FILE="$HOME/.config/instaloader/session-kapuk2026" # Update username if needed
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

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
    
    # Check profile status via Instagram's public endpoint
    # (Using a standard User-Agent to avoid immediate blocks)
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "User-Agent: $USER_AGENT" \
        "https://www.instagram.com/$username/")

    if [ "$STATUS_CODE" -eq 200 ]; then
        echo "Active (200)"
        echo "$username" >> "$TEMP_FILE"
    elif [ "$STATUS_CODE" -eq 404 ]; then
        echo "NOT FOUND (404) -> Removing"
    else
        # If it's a 302 (redirect to login) or 429 (rate limited), keep it to be safe
        echo "Uncertain ($STATUS_CODE) -> Keeping for safety"
        echo "$username" >> "$TEMP_FILE"
    fi
    
    # Small sleep to mitigate aggressive rate-limiting on your ARM server
    sleep 2

done < "$TARGETS_FILE"

# Overwrite the original file with the valid targets
mv "$TEMP_FILE" "$TARGETS_FILE"

echo "----------------------------------------"
echo "Done! Updated targets saved to $TARGETS_FILE"
echo "Backup of original list saved to $BACKUP_FILE"
