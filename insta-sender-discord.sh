#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
BOT_TOKEN="MTUyNjI1OTM4MzQ5Mzk4NDM3Ng.Gyon8q.dyAZPba4kEV64AK2YRbCYVmTKx1aH1A4RSfaD4"
GUILD_ID="1526258089710584053"
IG_DOWNLOAD_DIR="./downloads"

# Tracking database
SENT_LOG="./sent_to_discord_ig.txt"
touch "$SENT_LOG"

# Maximum items allowed in a single Discord message batch
MAX_BATCH_ITEMS=10

# Capture target username if passed as a command argument (e.g., ./script.sh fbyana)
TARGET_USER="$1"

# ==========================================
# FUNCTIONS
# ==========================================
get_or_create_channel() {
    local username="$1"

    # Strip leading @ if present
    username="${username#@}"

    # 1. Format username:
    # - Lowercase
    # - Replace dots (.) with _dot_
    # - Replace hyphens (-) with underscores (_)
    local clean_username
    clean_username=$(echo "$username" | tr '[:upper:]' '[:lower:]' | sed 's/\./_dot_/g' | tr '-' '_')

    # Prepend prefix
    local channel_name="ig-${clean_username}"

    # Fetch current server channels
    local channels_json
    channels_json=$(curl -s -H "Authorization: Bot $BOT_TOKEN" \
        "https://discord.com/api/v10/guilds/$GUILD_ID/channels")

    # Safe parsing via python3 passing variables through environment
    local channel_id
    channel_id=$(TARGET_NAME="$channel_name" python3 -c '
import sys, json, os
target = os.environ.get("TARGET_NAME")
try:
    data = json.load(sys.stdin)
    match = next((c["id"] for c in data if c.get("name") == target), "")
    print(match)
except Exception:
    print("")
' <<< "$channels_json")

    # Auto-create channel if it doesn't exist
    if [ -z "$channel_id" ]; then
        echo "Channel #$channel_name not found. Auto-creating..." >&2

        # Safely construct JSON payload using Python
        local create_payload
        create_payload=$(NAME="$channel_name" PARENT="$CATEGORY_ID" python3 -c '
import os, json
name = os.environ.get("NAME")
parent = os.environ.get("PARENT")
payload = {"name": name, "type": 0}
if parent:
    payload["parent_id"] = parent
print(json.dumps(payload))
')

        local create_response
        create_response=$(curl -s -X POST \
            -H "Authorization: Bot $BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$create_payload" \
            "https://discord.com/api/v10/guilds/$GUILD_ID/channels")

        channel_id=$(python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get("id", ""))
except Exception:
    print("")
' <<< "$create_response")

        echo "Created channel ID: $channel_id" >&2
    else
        echo "Found existing channel ID: $channel_id" >&2
    fi

    # Output ONLY the raw ID to stdout
    echo "$channel_id"
}

# ==========================================
# MAIN EXECUTION LOOP
# ==========================================
shopt -s nullglob nocaseglob

# Files larger than 10MB (10,485,760 bytes) will be marked sent and skipped
MAX_ALLOWED_FILE_BYTES=10485760
# Set max cumulative batch payload to 9.5MB (9,961,472 bytes) for Discord POST API
MAX_BATCH_PAYLOAD_BYTES=9961472

if [ ! -d "$IG_DOWNLOAD_DIR" ]; then
    echo "Base download directory $IG_DOWNLOAD_DIR does not exist!"
    exit 1
fi

if [ -n "$TARGET_USER" ]; then
    USER_FOLDERS=("$IG_DOWNLOAD_DIR/$TARGET_USER")
    echo "Running in TEST mode for Instagram username: @$TARGET_USER"
else
    USER_FOLDERS=("$IG_DOWNLOAD_DIR"/*)
fi

for user_dir in "${USER_FOLDERS[@]}"; do
    if [ -d "$user_dir" ]; then
        username=$(basename "$user_dir")

        file_args=()
        local_sent_queue=()
        batch_count=0
        current_batch_bytes=0

        echo "----------------------------------------"
        echo "Scanning files for Instagram user: @$username"

        # Scan ALL media files recursively
        while IFS= read -r -d '' file; do
            case "$file" in
                *.jpg|*.jpeg|*.png|*.webp|*.mp4|*.mov|*.mkv) ;;
                *) continue ;;
            esac

            # Skip if already logged as sent
            if grep -Fxq "$file" "$SENT_LOG" 2>/dev/null; then
                continue
            fi

            orig_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)

            # If file exceeds 10MB, log it to SENT_LOG immediately and skip sending
            if [ "$orig_size" -gt "$MAX_ALLOWED_FILE_BYTES" ]; then
                orig_human=$(du -h "$file" | cut -f1)
                echo "  └── [SKIP 10MB+] $(basename "$file") is $orig_human (>10MB). Marking as sent without uploading."
                echo "$file" >> "$SENT_LOG"
                continue
            fi

            item_bytes=$orig_size

            # Prevent total batch payload from crossing max POST size
            if [ $((current_batch_bytes + item_bytes)) -gt "$MAX_BATCH_PAYLOAD_BYTES" ] && [ $batch_count -gt 0 ]; then
                break
            fi

            if [ $batch_count -lt $MAX_BATCH_ITEMS ]; then
                file_args+=("-F" "files[$batch_count]=@$file")
                local_sent_queue+=("$file") # Queue original path into sent log
                ((batch_count++))
                current_batch_bytes=$((current_batch_bytes + item_bytes))
            else
                break
            fi
        done < <(find "$user_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mov" \) -print0)

        # Send batch if items exist
        if [ ${#file_args[@]} -gt 0 ]; then
            channel_id=$(get_or_create_channel "$username" | tail -n 1)

            if [ -n "$channel_id" ]; then
                total_batch_human=$(numfmt --to=iec-i --suffix=B "$current_batch_bytes" 2>/dev/null || echo "${current_batch_bytes} bytes")
                echo "Sending batch of $batch_count item(s) (Total Payload: $total_batch_human) to Discord channel..."
                caption="📦 **New Instagram Batch Update from @$username**"

                response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
                    -H "Authorization: Bot $BOT_TOKEN" \
                    "${file_args[@]}" \
                    -F "payload_json={\"content\": \"$caption\"}" \
                    "https://discord.com/api/v10/channels/$channel_id/messages")

                if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
                    for logged_item in "${local_sent_queue[@]}"; do
                        echo "$logged_item" >> "$SENT_LOG"
                    done
                    echo "Batch delivery complete for @$username."
                else
                    echo "Error sending batch to Discord. HTTP Status: $response"
                fi
            fi
        else
            echo "No new updates found for @$username."
        fi
    elif [ -n "$TARGET_USER" ]; then
        echo "Error: Directory for user '$TARGET_USER' does not exist."
    fi
done

echo "----------------------------------------"
echo "Daily sender batch run complete."
