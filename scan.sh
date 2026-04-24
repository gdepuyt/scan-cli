#!/bin/bash

# Configuration
DEVICE="airscan:e0:Brother MFC-L2710DW series"
DATE=$(date +%Y-%m-%d_%H%M%S)

# 1. Select Format
FORMAT=$(echo -e "pdf\njpeg\npng\ntiff" | fzf --prompt="Select Output Format: ")
[ -z "$FORMAT" ] && exit 1

# 2. Select Mode
MODE=$(echo -e "Color\nGray" | fzf --prompt="Select Color Mode: ")
[ -z "$MODE" ] && exit 1

# 3. Select Source (Flatbed or Auto Document Feeder)
SOURCE=$(echo -e "Flatbed\nADF" | fzf --prompt="Select Paper Source: ")
[ -z "$SOURCE" ] && exit 1

# 4. Select Output Folder
# This looks at common folders in your Home directory
DEST_DIR=$(find ~ -maxdepth 2 -type d | fzf --prompt="Select Output Folder: ")
[ -z "$DEST_DIR" ] && exit 1

FILENAME="$DEST_DIR/$DATE.$FORMAT"

echo "Scanning $SOURCE in $MODE mode to $FILENAME..."

# Execute Scan
# Note: --batch is used for ADF if you want to scan multiple pages into one PDF
if [ "$SOURCE" == "ADF" ] && [ "$FORMAT" == "pdf" ]; then
    scanimage -d "$DEVICE" \
              --source "$SOURCE" \
              --mode "$MODE" \
              --format="$FORMAT" \
              --batch-count=10 \
              --batch-prompt > "$FILENAME"
else
    scanimage -d "$DEVICE" \
              --source "$SOURCE" \
              --mode "$MODE" \
              --format="$FORMAT" > "$FILENAME"
fi

if [ $? -eq 0 ]; then
    echo "Successfully saved: $FILENAME"
    # Optional: Open the folder or file afterward
    # xdg-open "$DEST_DIR"
else
    echo "Scan failed. Check if scanner is busy or offline."
fi
