#!/bin/bash
#
# extract_all_subs.sh - Batch Subtitle Extractor
# Extracts all subtitles to a 'Subtitles' folder.
#

# ==========================================
# 1. DEPENDENCIES
# ==========================================

if ! command -v ffmpeg &> /dev/null || ! command -v ffprobe &> /dev/null; then
    kdialog --error "Error: ffmpeg and ffprobe are required."
    exit 1
fi

# ==========================================
# 2. HELPER FUNCTIONS
# ==========================================

# Clean filenames to avoid errors
sanitize_name() {
    local name="$1"
    name="${name//\\//-}"
    name="${name//\"/}"
    echo "$name"
}

# ==========================================
# 3. EXTRACTION LOGIC
# ==========================================

extract_file() {
    local input_file="$1"

    # Prepare directory and filenames
    local file_dir=$(dirname "$input_file")
    local sub_folder="${file_dir}/Subtitles"
    mkdir -p "$sub_folder"

    local file_name=$(basename "$input_file")
    local base_name="${file_name%.*}"
    local safe_base_name=$(sanitize_name "$base_name")

    # Count subtitle streams (Robust method)
    local sub_count=$(ffprobe -v error -select_streams s -show_entries stream=codec_name -of csv=p=0 "$input_file" 2>/dev/null | wc -l)

    if [[ "$sub_count" -eq 0 ]]; then
        return 0
    fi

    # Process each stream
    for (( i=0; i<sub_count; i++ )); do

        # Get Codec
        local codec=$(ffprobe -v error -select_streams s:$i -show_entries stream=codec_name -of csv=p=0 "$input_file" 2>/dev/null | head -n1)

        # Get Language
        local lang=$(ffprobe -v error -select_streams s:$i -show_entries stream_tags=language -of csv=p=0 "$input_file" 2>/dev/null | head -n1)
        lang="${lang//\"/}"
        local lang_lower=$(echo "$lang" | tr '[:upper:]' '[:lower:]')

        # Check if Forced
        local forced=$(ffprobe -v error -select_streams s:$i -show_entries stream_disposition=forced -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)

        # Determine Suffix
        local suffix="sub${i}"
        case "$lang_lower" in
            spa|es) suffix="es" ;;
            eng|en) suffix="en" ;;
            und)    suffix="und" ;;
        esac
        if [[ "$forced" == "1" ]]; then
            suffix="${suffix}_forced"
        fi

        # Determine Extension
        local ext="srt"
        case "$codec" in
            hdmv_pgs_subtitle|dvd_subtitle) ext="sup" ;;
            ass|ssa) ext="ass" ;;
            webvtt) ext="vtt" ;;
        esac

        local output_path="${sub_folder}/${safe_base_name}_${suffix}.${ext}"

        # Execute Extraction
        if ffmpeg -y -loglevel error -i "$input_file" -map 0:s:$i -c:s copy "$output_path" 2>/dev/null; then
            if [[ ! -s "$output_path" ]]; then
                rm -f "$output_path"
            fi
        fi
    done
}

# ==========================================
# 4. MAIN EXECUTION
# ==========================================

TOTAL_FILES=$#

# Start Notification (5 seconds)
kdialog --title "Subtitle Extractor" \
    --icon "video-x-generic" \
    --passivepopup "Starting extraction for $TOTAL_FILES files..." 5 &

# Loop through arguments
for archivo in "$@"; do
    if [[ -f "$archivo" ]]; then
        extract_file "$archivo"
    fi
done

# End Notification (10 seconds to allow reading)
kdialog --title "Subtitle Extractor" \
    --icon "checkbox" \
    --passivepopup "Process complete.\nFiles processed: $TOTAL_FILES" 10

exit 0
