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

# 3. Select Resolution
RES=$(echo -e "150\n300\n600" | fzf --height 40% --layout=reverse --prompt="🔍 Select Resolution (DPI): ")
[ -z "$RES" ] && exit 1

# 4. Select Source
SOURCE=$(echo -e "Flatbed\nADF" | fzf --height 40% --layout=reverse --prompt="📥 Select Paper Source: ")
[ -z "$SOURCE" ] && exit 1

# 5. Select Output Folder
DEST_DIR=$(printf "%s\n%s\n%s\n%s\n%s" "$HOME/Documents" "$HOME/Pictures" "$HOME/Work" "$HOME/Desktop" "$(pwd)" | fzf --height 40% --layout=reverse --prompt="📂 Select Output Folder: ")
[ -z "$DEST_DIR" ] && exit 1

FILENAME="$DEST_DIR/$DATE.$FORMAT"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "🚀 Scanning from $SOURCE in $MODE mode ($RES DPI)..."

# Magick compression settings for PDF
COMPRESSION_ARGS="-compress jpeg -quality 80"

if [ "$SOURCE" == "ADF" ]; then
    echo "📄 ADF detected. Starting batch scan..."
    scanimage -d "$DEVICE" \
              --source "$SOURCE" \
              --mode "$MODE" \
              --resolution "$RES" \
              --batch="$TEMP_DIR/out%d.tiff" \
              --format=tiff

    if ls "$TEMP_DIR"/out*.tiff >/dev/null 2>&1; then
        echo "⚙️  Converting and compressing to $FORMAT..."
        if [ "$FORMAT" == "pdf" ]; then
            magick "$TEMP_DIR"/out*.tiff $COMPRESSION_ARGS "$FILENAME"
        else
            magick "$TEMP_DIR"/out1.tiff "$FILENAME"
        fi
    else
        echo "❌ No pages scanned from ADF."
        exit 1
    fi
else
    echo "📷 Scanning single page from Flatbed..."
    if [ "$FORMAT" == "pdf" ]; then
        scanimage -d "$DEVICE" \
                  --source "$SOURCE" \
                  --mode "$MODE" \
                  --resolution "$RES" \
                  --format=tiff > "$TEMP_DIR/single.tiff"
        magick "$TEMP_DIR/single.tiff" $COMPRESSION_ARGS "$FILENAME"
    else
        scanimage -d "$DEVICE" \
                  --source "$SOURCE" \
                  --mode "$MODE" \
                  --resolution "$RES" \
                  --format="$FORMAT" > "$FILENAME"
    fi
fi

if [ $? -eq 0 ] && [ -f "$FILENAME" ]; then
    echo "✅ Successfully saved: $FILENAME ($(du -h "$FILENAME" | cut -f1))"
    command -v notify-send >/dev/null && notify-send "Scan Complete" "Saved to $FILENAME" -i scanner

    while true; do
        ACTION=$(echo -e "👁 View File\n✉ Email File (Thunderbird)\n📂 Open Folder\n🚪 Exit" | fzf --height 40% --layout=reverse --prompt="⏭ Next Action: ")
        case "$ACTION" in
            "👁 View File") xdg-open "$FILENAME" ;;
            "✉ Email File (Thunderbird)")
                echo "📨 Opening Thunderbird..."
                thunderbird -compose "attachment='file://$FILENAME'"
                ;;
            "📂 Open Folder") xdg-open "$DEST_DIR" ;;
            *) break ;;
        esac
    done
else
    echo "❌ Scan failed."
    exit 1
fi
