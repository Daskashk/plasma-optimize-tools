#!/bin/bash
#
# gif_optimizer.sh - Intelligent GIF Compressor
# Logic: Resizes -> Caps FPS -> Generates GIF vs WebP -> Keeps smallest file.
#

# ==========================================
# 1. CONFIGURATION & SECURITY
# ==========================================

set -euo pipefail
export LC_ALL=C

# Configuration Parameters
MAX_WIDTH=720
MAX_FPS=30
GIF_LOSSY_LEVEL=30   # 0-200 (Lower is better quality, higher is smaller size)
WEBP_QUALITY=75      # 0-100

# ==========================================
# 2. DEPENDENCIES CHECK
# ==========================================

check_dependencies() {
    local missing_deps=()

    if ! command -v ffmpeg &> /dev/null; then missing_deps+=("ffmpeg"); fi
    if ! command -v ffprobe &> /dev/null; then missing_deps+=("ffprobe"); fi
    if ! command -v gifsicle &> /dev/null; then missing_deps+=("gifsicle"); fi
    if ! command -v kdialog &> /dev/null; then missing_deps+=("kdialog"); fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        kdialog --error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# ==========================================
# 3. HELPER FUNCTIONS
# ==========================================

get_file_size() {
    local file="$1"
    # Get size in bytes
    stat --printf="%s" "$file"
}

# ==========================================
# 4. OPTIMIZATION LOGIC
# ==========================================

optimize_gif() {
    local input_file="$1"
    local input_dir
    input_dir=$(dirname "$input_file")
    local input_name
    input_name=$(basename "$input_file")
    local base_name="${input_name%.*}"

    echo "Analyzing: $input_name"

    # 1. Analyze Dimensions and FPS
    local width
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$input_file" 2>/dev/null)

    local fps_raw
    fps_raw=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$input_file" 2>/dev/null)

    # Calculate FPS (handle fraction string like 30/1)
    local fps
    fps=$(echo "scale=2; $fps_raw" | bc 2>/dev/null || echo "30")

    # 2. Determine Filter String (Resize & FPS)
    local filter_str=""

    if (( $(echo "$width > $MAX_WIDTH" | bc -l) )); then
        filter_str="scale=$MAX_WIDTH:-1:flags=lanczos"
        echo " -> Resizing to max width: $MAX_WIDTH"
    fi

    if (( $(echo "$fps > $MAX_FPS" | bc -l) )); then
        # Append fps filter if scale already exists
        [[ -n "$filter_str" ]] && filter_str="${filter_str},"
        filter_str="${filter_str}fps=$MAX_FPS"
        echo " -> Capping FPS to: $MAX_FPS"
    fi

    # Temporary files
    local temp_gif="/tmp/temp_opt.gif"
    local temp_webp="/tmp/temp_opt.webp"

    # Cleanup previous runs if exist
    rm -f "$temp_gif" "$temp_webp"

    # 3. Generate Candidate A: Optimized GIF
    # Strategy: If filters needed, use ffmpeg first to generate a clean palette gif, then optimize with gifsicle.
    # If no filters needed, go straight to gifsicle.

    if [[ -n "$filter_str" ]]; then
        # Generate palette for better quality resize
        local palette="/tmp/palette.png"
        ffmpeg -v error -i "$input_file" -vf "$filter_str,palettegen" -y "$palette" 2>/dev/null
        ffmpeg -v error -i "$input_file" -i "$palette" -lavci "$filter_str [x]; [x][1:v] paletteuse" -y "$temp_gif" 2>/dev/null
        rm -f "$palette"
        # Apply lossy compression on the processed gif
        gifsicle -O3 --lossy=$GIF_LOSSY_LEVEL -o "$temp_gif" "$temp_gif" 2>/dev/null
    else
        # Direct optimization
        gifsicle -O3 --lossy=$GIF_LOSSY_LEVEL -o "$temp_gif" "$input_file" 2>/dev/null
    fi

    # 4. Generate Candidate B: WebP
    # Use ffmpeg. If scaling needed, apply it here too.
    local webp_filter="$filter_str"
    local webp_args="-v quiet -quality $WEBP_QUALITY -y"

    if [[ -n "$webp_filter" ]]; then
        ffmpeg -i "$input_file" -vf "$webp_filter" $webp_args "$temp_webp" 2>/dev/null
    else
        ffmpeg -i "$input_file" $webp_args "$temp_webp" 2>/dev/null
    fi

    # 5. Compare and Decide Winner
    local size_gif
    size_gif=$(get_file_size "$temp_gif")
    local size_webp
    size_webp=$(get_file_size "$temp_webp")

    local final_ext="gif"
    local final_size=$size_gif

    if [[ "$size_webp" -lt "$size_gif" ]]; then
        final_ext="webp"
        final_size=$size_webp
        cp "$temp_webp" "${input_dir}/${base_name}_opt.webp"
        echo " -> Winner: WebP ($size_webp bytes)"
    else
        cp "$temp_gif" "${input_dir}/${base_name}_opt.gif"
        echo " -> Winner: GIF ($size_gif bytes)"
    fi

    # Cleanup
    rm -f "$temp_gif" "$temp_webp"
}

# ==========================================
# 5. MAIN EXECUTION
# ==========================================

check_dependencies

TOTAL_FILES=$#

kdialog --title "GIF Optimizer" \
    --icon "image-x-generic" \
    --passivepopup "Processing $TOTAL_FILES files..." 5 &

for archivo in "$@"; do
    if [[ -f "$archivo" ]]; then
        optimize_gif "$archivo"
    fi
done

kdialog --title "GIF Optimizer" \
    --icon "checkbox" \
    --passivepopup "Optimization complete." 5

exit 0
