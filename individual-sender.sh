#!/bin/bash
# --- CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a; source "$SCRIPT_DIR/../.env"; set +a
else
    echo "Error: .env file not found at $SCRIPT_DIR/.env" >&2
    exit 1
fi

TOKEN=$TELEGRAM_BOT_TOKEN
CHAT_ID="$TELEGRAM_CHAT_ID"
BASE_DIR="$SCRIPT_DIR/downloads"
TARGETS_FILE="$SCRIPT_DIR/targets.txt"
DAILY_LIMIT=10
BUFFER=5
CURRENT_DATE=$(date +"%Y-%m-%d")

TOTAL_SENT_OVERALL=0

# --- ARGUMENT HANDLING ---
# If a parameter is passed, use it as a single target. Otherwise, read from the file.
if [ -n "$1" ]; then
    SINGLE_TARGET=$(echo "$1" | xargs)
    echo "🎯 Running in single-user mode for: @$SINGLE_TARGET"
else
    if [ ! -f "$TARGETS_FILE" ]; then
        echo "❌ Error: Targets file not found at $TARGETS_FILE"
        exit 1
    fi
fi

process_user() {
    local USERNAME=$1
    local folder="$BASE_DIR/$USERNAME"

    if [ ! -d "$folder" ]; then
        echo "⚠️ Folder not found for @$USERNAME at $folder. Skipping."
        return
    fi

    local SENT_FILE="$folder/sent_to_telegram.txt"
    touch "$SENT_FILE"

    # 1. Collect files not in history
    local files_to_send=()
    while IFS= read -r file; do
        local FILENAME=$(basename "$file")
        if ! grep -qx "$FILENAME" "$SENT_FILE"; then
            files_to_send+=("$file")
        fi
        [[ "${#files_to_send[@]}" -ge "$DAILY_LIMIT" ]] && break
    done < <(find "$folder" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null)

    local COUNT=${#files_to_send[@]}
    if [ "$COUNT" -eq 0 ]; then
        echo "✨ No new files to send for @$USERNAME."
        return
    fi

    echo "Found $COUNT new files for @$USERNAME. Sending individually..."

    # 2. Loop through and send files one by one
    for file in "${files_to_send[@]}"; do
        local FILENAME=$(basename "$file")
        local METHOD="sendPhoto"
        local FIELD="photo"
        
        [[ "$FILENAME" == *.mp4 ]] && METHOD="sendVideo" && FIELD="video"

        local attempt_success=false
        while [ "$attempt_success" = false ]; do
            local RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TOKEN/$METHOD" \
                -F "chat_id=$CHAT_ID" \
                -F "$FIELD=@$file")

            if [[ "$RESPONSE" == *"\"ok\":true"* ]]; then
                echo "$FILENAME" >> "$SENT_FILE"
                echo "    ✅ Sent $FILENAME successfully."
                ((TOTAL_SENT_OVERALL++))
                attempt_success=true
                sleep 2

            elif [[ "$RESPONSE" == *"\"error_code\":429"* ]]; then
                local RETRY_AFTER=$(echo "$RESPONSE" | grep -o '"retry_after":[0-9]*' | cut -d: -f2)
                RETRY_AFTER=${RETRY_AFTER:-30}
                local TOTAL_WAIT=$((RETRY_AFTER + BUFFER))
                echo "    ⚠️ Rate limited! Waiting $TOTAL_WAIT seconds..."
                sleep "$TOTAL_WAIT"

            else
                echo "    ❌ Permanent Error for file $FILENAME: $RESPONSE"
                attempt_success=true 
            fi
        done
    done
}

# --- MAIN EXECUTION CORNER ---
if [ -n "$SINGLE_TARGET" ]; then
    # Run only for the passed parameter
    process_user "$SINGLE_TARGET"
else
    # Run for everything in targets.txt loop
    while IFS= read -r USERNAME || [[ -n "$USERNAME" ]]; do
        USERNAME=$(echo "$USERNAME" | xargs)
        [[ -z "$USERNAME" || "$USERNAME" =~ ^# ]] && continue
        process_user "$USERNAME"
        sleep 5
    done < "$TARGETS_FILE"
fi

# --- FINAL SUMMARY ---
if [ "$TOTAL_SENT_OVERALL" -gt 0 ]; then
    SUMMARY="✅ *Daily Instagram Broadcast Finished (Individual Mode)*
📅 Date: ${CURRENT_DATE}
📊 Total Sent: ${TOTAL_SENT_OVERALL} videos/photos"

    # Format slightly different if it was a single user run
    [ -n "$SINGLE_TARGET" ] && SUMMARY="✅ *Target Run Finished for @$SINGLE_TARGET*
📅 Date: ${CURRENT_DATE}
📊 Total Sent: ${TOTAL_SENT_OVERALL} videos/photos"

    ENCODED_SUMMARY=$(echo "$SUMMARY" | jq -sRr @uri)

    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "text=$ENCODED_SUMMARY" \
         -d "parse_mode=Markdown" > /dev/null

    echo "Summary sent to Telegram."
else
    echo "No new Instagram files were sent."
fi
