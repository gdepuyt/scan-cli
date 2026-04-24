#!/bin/bash

# Configuration
DEVICE="airscan:e0:Brother MFC-L2710DW series"
DATE=$(date +%Y-%m-%d_%H%M%S)

# 1. Select Format
FORMAT=$(echo -e "pdf\njpeg\npng\ntiff" | fzf --height 40% --layout=reverse --prompt="📄 Select Output Format: ")
[ -z "$FORMAT" ] && exit 1

# 2. Select Mode
MODE=$(echo -e "Color\nGray" | fzf --height 40% --layout=reverse --prompt="🎨 Select Color Mode: ")
[ -z "$MODE" ] && exit 1

# 3. Select Source
SOURCE=$(echo -e "Flatbed\nADF" | fzf --height 40% --layout=reverse --prompt="📥 Select Paper Source: ")
[ -z "$SOURCE" ] && exit 1

# 4. Select Output Folder (Optimized for speed)
# List common user directories and current work dir
DEST_DIR=$(printf "%s\n%s\n%s\n%s\n%s" "$HOME/Documents" "$HOME/Pictures" "$HOME/Work" "$HOME/Desktop" "$(pwd)" | fzf --height 40% --layout=reverse --prompt="📂 Select Output Folder: ")
[ -z "$DEST_DIR" ] && exit 1

FILENAME="$DEST_DIR/$DATE.$FORMAT"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "🚀 Scanning from $SOURCE in $MODE mode..."

if [ "$SOURCE" == "ADF" ]; then
    echo "📄 ADF detected. Starting batch scan..."
    # Scan multiple pages from ADF
    scanimage -d "$DEVICE" \
              --source "$SOURCE" \
              --mode "$MODE" \
              --resolution 300 \
              --batch="$TEMP_DIR/out%d.tiff" \
              --format=tiff

    # Check if any files were created
    if ls "$TEMP_DIR"/out*.tiff >/dev/null 2>&1; then
        echo "⚙️  Converting to $FORMAT..."
        if [ "$FORMAT" == "pdf" ]; then
            magick "$TEMP_DIR"/out*.tiff "$FILENAME"
        else
            # If not PDF but multi-page ADF, we might want to warn or just convert the first
            magick "$TEMP_DIR"/out1.tiff "$FILENAME"
        fi
    else
        echo "❌ No pages scanned from ADF."
        exit 1
    fi
else
    # Flatbed - single page
    echo "📷 Scanning single page from Flatbed..."
    if [ "$FORMAT" == "pdf" ]; then
        scanimage -d "$DEVICE" \
                  --source "$SOURCE" \
                  --mode "$MODE" \
                  --resolution 300 \
                  --format=tiff > "$TEMP_DIR/single.tiff"
        magick "$TEMP_DIR/single.tiff" "$FILENAME"
    else
        scanimage -d "$DEVICE" \
                  --source "$SOURCE" \
                  --mode "$MODE" \
                  --resolution 300 \
                  --format="$FORMAT" > "$FILENAME"
    fi
fi

if [ $? -eq 0 ] && [ -f "$FILENAME" ]; then
    echo "✅ Successfully saved: $FILENAME"
    # Show a notification if notify-send is available
    command -v notify-send >/dev/null && notify-send "Scan Complete" "Saved to $FILENAME" -i scanner
else
    echo "❌ Scan failed. Check if scanner is busy, offline, or out of paper."
    exit 1
fi
