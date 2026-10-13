#!/usr/bin/env bash
#
# images-to-avif.sh - Image to AVIF Converter
#
# Description:
#   Converts images to AVIF format to minimize file size while maintaining
#   high visual quality. Automatically preserves transparency (Alpha Channel)
#   for formats like PNG or WebP.
#
# Dependencies: ffmpeg, ffprobe, kdialog

set -uo pipefail

# ==========================================
# CONFIGURATION
# ==========================================

# Quality: Lower is better. 18-30 is recommended range for AVIF.
QUALITY=30
# Maximum parallel conversions. Adjust based on your CPU cores (4 is a safe default).
MAX_PARALLEL=4
TOTAL_FILES=$#

# ==========================================
# DEPENDENCY CHECK
# ==========================================

check_dependencies() {
    local missing_deps=()
    for dep in ffmpeg ffprobe kdialog; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        kdialog --error "Error: Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# ==========================================
# CORE FUNCTIONS
# ==========================================

detect_encoder() {
    # Prefer SVT-AV1 for speed if available, otherwise fallback to libaom
    if ffmpeg -encoders 2>/dev/null | grep -q "libsvtav1"; then
        echo "libsvtav1"
    else
        echo "libaom-av1"
    fi
}

convert_image() {
    local input_file="$1"
    local output_file="${input_file%.*}.avif"
    local pix_fmt
    local target_pix_fmt

    # Safety check: Avoid overwriting existing files
    if [[ -f "$output_file" ]]; then
        echo "Skipping: '$output_file' already exists."
        return 1
    fi

    # ---------------------------------------------------------
    # TRANSPARENCY DETECTION LOGIC
    # ---------------------------------------------------------
    # We use ffprobe to check the pixel format of the input.
    # Common formats with alpha: rgba, yuva420p, pal8 (palette/gifs)
    # We default to 'yuv420p' (standard) if no alpha is found.

    pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    target_pix_fmt="yuv420p"

    # If the format string contains 'a' (alpha) or 'pal' (palette), switch to yuva420p
    if [[ "$pix_fmt" == *"a"* || "$pix_fmt" == *"pal"* ]]; then
        target_pix_fmt="yuva420p"
    fi

    # ---------------------------------------------------------
    # CONVERSION EXECUTION
    # ---------------------------------------------------------
    ffmpeg -i "$input_file" \
        -c:v "$ENCODER" \
        -crf "$QUALITY" \
        -pix_fmt "$target_pix_fmt" \
        -strict experimental \
        -y "$output_file" >/dev/null 2>&1
}

process_items() {
    local running=0

    for item in "$@"; do
        if [[ -f "$item" ]]; then
            convert_image "$item" &
            ((running++))
            if ((running >= MAX_PARALLEL)); then
                wait -n
                ((running--))
            fi
        elif [[ -d "$item" ]]; then
            while IFS= read -r -d '' file; do
                convert_image "$file" &
                ((running++))
                if ((running >= MAX_PARALLEL)); then
                    wait -n
                    ((running--))
                fi
            done < <(find "$item" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.tiff" \) -print0 2>/dev/null)
        fi
    done

    wait
}

# ==========================================
# MAIN EXECUTION
# ==========================================

check_dependencies

# Detect best encoder once
ENCODER=$(detect_encoder)

# 1. Start Notification
kdialog --title "AVIF Converter" \
    --icon "video-x-generic" \
    --passivepopup "Converting $TOTAL_FILES items using $ENCODER... Please wait." 5 &

# Run logic
process_items "$@"

# 2. End Notification
kdialog --title "AVIF Converter" \
    --icon "checkbox" \
    --passivepopup "Conversion finished! Files optimized." 3

exit 0
