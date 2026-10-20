#!/bin/bash
BASE_DIR="/root/ig-downloader/downloads"
CENTRAL_LOG="/root/ig-downloader/sent_to_discord_ig.txt"

echo "🧹 Starting Discord Instagram cleanup: $(date)"

# Check if the central log file exists and has content
if [ ! -s "$CENTRAL_LOG" ]; then
    echo "ℹ️ No files logged in $CENTRAL_LOG or file is empty. Nothing to clean."
    exit 0
fi

echo "Processing central log: $CENTRAL_LOG"
echo "----------------------------------------"

# Read each line from the central log
while IFS= read -r logged_path || [ -n "$logged_path" ]; do
    # Strip carriage returns and leading/trailing whitespace
    logged_path=$(echo "$logged_path" | tr -d '\r' | xargs)

    # Skip empty lines
    [ -z "$logged_path" ] && continue

    # Clean the path: remove leading "./downloads/", "./instagram_downloads/" or "./" if present
    cleaned_path="${logged_path#./downloads/}"
    cleaned_path="${cleaned_path#./instagram_downloads/}" # Added just in case IG uses a different folder name
    cleaned_path="${cleaned_path#./}"

    # Determine the target file path
    if [[ "$cleaned_path" == */* ]]; then
        # If it contains a subfolder path, prepend the base directory
        file_path="${BASE_DIR}/${cleaned_path}"
    else
        # If it's just a raw filename, look for it inside any subdirectory
        file_path=$(find "$BASE_DIR" -type f -name "$cleaned_path" -print -quit)
    fi

    # Delete the file if it exists
    if [ -n "$file_path" ] && [ -f "$file_path" ]; then
        rm "$file_path"
        echo "Deleted: $logged_path"
    else
        echo "Already missing or not found: $logged_path"
    fi

done < "$CENTRAL_LOG"

# Optional: Clear or truncate the log file once clean-up is done
# > "$CENTRAL_LOG"

echo "----------------------------------------"
echo "✨ Discord Instagram Cleanup complete."
