#!/bin/bash
# --- CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a; source "$SCRIPT_DIR/../.env"; set +a
else
    echo "Error: .env file not found at $SCRIPT_DIR/.env" >&2
    exit 1
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN is not defined in .env" >&2
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

if [ ! -f "$TARGETS_FILE" ]; then
    echo "❌ Error: Targets file not found at $TARGETS_FILE"
    exit 1
fi

while IFS= read -r USERNAME || [[ -n "$USERNAME" ]]; do
    USERNAME=$(echo "$USERNAME" | xargs)
    [[ -z "$USERNAME" || "$USERNAME" =~ ^# ]] && continue

    folder="$BASE_DIR/$USERNAME"
    [ -d "$folder" ] || continue

    SENT_FILE="$folder/sent_to_telegram.txt"
    touch "$SENT_FILE"

    # 1. Collect files not in history
    files_to_send=()
    while IFS= read -r file; do
        FILENAME=$(basename "$file")
        if ! grep -qx "$FILENAME" "$SENT_FILE"; then
            files_to_send+=("$file")
        fi
        [[ "${#files_to_send[@]}" -ge "$DAILY_LIMIT" ]] && break
    done < <(find "$folder" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \))

    COUNT=${#files_to_send[@]}
    if [ "$COUNT" -eq 0 ]; then 
        continue 
    fi

    # 2. Build Media Group Arguments
    CURL_ARGS=(-s -X POST "https://api.telegram.org/bot$TOKEN/sendMediaGroup" "-F" "chat_id=$CHAT_ID")
    MEDIA_JSON="["
    i=0
    for file in "${files_to_send[@]}"; do
        TYPE="photo"
        [[ "$(basename "$file")" == *.mp4 ]] && TYPE="video"
        
        CURL_ARGS+=("-F" "media$i=@$file")
        
        CAPTION=""
        if [ $i -eq 0 ]; then
            CAPTION=", \"caption\": \"📸 #Instagram: @$USERNAME\n📅 Date: $CURRENT_DATE\""
        fi
        
        MEDIA_JSON+="{\"type\":\"$TYPE\", \"media\":\"attach://media$i\"$CAPTION}"
        [[ $i -lt $((COUNT - 1)) ]] && MEDIA_JSON+=","
        ((i++))
    done
    MEDIA_JSON+="]"
    
    CURL_ARGS+=("-F" "media=$MEDIA_JSON")

    # 3. Send with Adaptive Retry + Buffer
    attempt_success=false
    while [ "$attempt_success" = false ]; do
        RESPONSE=$(curl "${CURL_ARGS[@]}")

        if [[ "$RESPONSE" == *"\"ok\":true"* ]]; then
            for file in "${files_to_send[@]}"; do 
                basename "$file" >> "$SENT_FILE"
            done
            echo "✅ Sent batch for @$USERNAME successfully ($COUNT files)."
            ((TOTAL_SENT_OVERALL += COUNT))
            attempt_success=true
            
        elif [[ "$RESPONSE" == *"\"error_code\":429"* ]]; then
            RETRY_AFTER=$(echo "$RESPONSE" | grep -o '"retry_after":[0-9]*' | cut -d: -f2)
            RETRY_AFTER=${RETRY_AFTER:-30}
            TOTAL_WAIT=$((RETRY_AFTER + BUFFER))

            echo "⚠️ Rate limited! Telegram asked for $RETRY_AFTER seconds. Waiting $TOTAL_WAIT seconds..."
            sleep "$TOTAL_WAIT"
            
        else
            echo "❌ Permanent Error for @$USERNAME: $RESPONSE"
            echo "⚠️ Files for @$USERNAME were NOT saved to history so they can be fixed and retried later."
            attempt_success=true 
        fi
    done

    sleep 5
done < "$TARGETS_FILE"

# --- Final Summary ---
if [ "$TOTAL_SENT_OVERALL" -gt 0 ]; then
    SUMMARY="✅ *Daily Instagram Broadcast Finished*
📅 Date: ${CURRENT_DATE}
📊 Total Sent: ${TOTAL_SENT_OVERALL} videos/photos"

    ENCODED_SUMMARY=$(echo "$SUMMARY" | jq -sRr @uri)

    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "text=$ENCODED_SUMMARY" \
         -d "parse_mode=Markdown" > /dev/null
    
    echo "Summary sent to Telegram."
else
    echo "No new Instagram files to send today."
fi
