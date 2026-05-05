#!/bin/bash
BASE_DIR="/root/ig-downloader/downloads"

echo "🧹 Starting Instagram cleanup: $(date)"

for user_dir in "$BASE_DIR"/*/; do
    if [ -f "${user_dir}sent_to_telegram.txt" ]; then
        echo "Processing folder: $(basename "$user_dir")"
        
        while IFS= read -r filename || [ -n "$filename" ]; do
            file_path="${user_dir}${filename}"
            if [ -f "$file_path" ]; then
                rm "$file_path"
                echo "Deleted: $filename"
            fi
        done < "${user_dir}sent_to_telegram.txt"
    fi
done

echo "✨ Instagram Cleanup complete."
