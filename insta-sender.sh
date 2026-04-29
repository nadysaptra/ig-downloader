#!/bin/bash
# --- CONFIGURATION ---
TOKEN="8692402692:AAH4OQSBCBsLibx8PscUa1EMfUN7aEM6Ysw"
CHAT_ID="-1003984616468"
BASE_DIR="$HOME/ig-downloader/downloads"
TARGETS_FILE="$HOME/ig-downloader/targets.txt"
DAILY_LIMIT=5
BUFFER=5  # Your safety buffer
CURRENT_DATE=$(date +"%Y-%m-%d")

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
    done < <(find "$folder" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.jpg" -o -iname "*.png" \))

    if [ "${#files_to_send[@]}" -eq 0 ]; then continue; fi

    # 2. Build Media Group
    CURL_CMD="curl -s -X POST https://api.telegram.org/bot$TOKEN/sendMediaGroup -F chat_id=$CHAT_ID"
    MEDIA_JSON="["
    i=0
    for file in "${files_to_send[@]}"; do
        TYPE="photo"; [[ "$(basename "$file")" == *.mp4 ]] && TYPE="video"
        CURL_CMD+=" -F media$i=@$file"
        CAPTION=""
        if [ $i -eq 0 ]; then 
            CAPTION=", \"caption\": \"📸 #Instagram: @$USERNAME\n📅 $CURRENT_DATE\", \"parse_mode\": \"Markdown\""
        fi
        MEDIA_JSON+="{\"type\":\"$TYPE\", \"media\":\"attach://media$i\"$CAPTION}"
        [[ $i -lt $((${#files_to_send[@]} - 1)) ]] && MEDIA_JSON+=","
        ((i++))
    done
    MEDIA_JSON+="]"

    # 3. Send with Adaptive Retry + Buffer
    attempt_success=false
    while [ "$attempt_success" = false ]; do
        RESPONSE=$(eval "$CURL_CMD -F media='$MEDIA_JSON'")
        
        if [[ "$RESPONSE" == *"\"ok\":true"* ]]; then
            # Record filenames to history ONLY on success
            for file in "${files_to_send[@]}"; do basename "$file" >> "$SENT_FILE"; done
            echo "✅ Sent batch for @$USERNAME"
            attempt_success=true
        elif [[ "$RESPONSE" == *"\"error_code\":429"* ]]; then
            # Extract retry_after value
            RETRY_AFTER=$(echo "$RESPONSE" | grep -oP '"retry_after":\K[0-9]+')
            RETRY_AFTER=${RETRY_AFTER:-30}
            
            # Apply your 5-second buffer logic
            TOTAL_WAIT=$((RETRY_AFTER + BUFFER))
            
            echo "⚠️ Rate limited! Telegram asked for $RETRY_AFTER. Waiting $TOTAL_WAIT seconds (including buffer)..."
            sleep "$TOTAL_WAIT"
            # Loop repeats to try the same batch again
        else
            echo "❌ Permanent Error for @$USERNAME: $RESPONSE"
            attempt_success=true # Skip to next user to avoid infinite loop on bad files
        fi
    done

    # Base delay between different users
    sleep 5 
done < "$TARGETS_FILE"
