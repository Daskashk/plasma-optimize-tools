#!/usr/bin/env bash
#
# audio-to-opus.sh - Universal Audio to Opus Converter
#
# Description:
#   Converts various audio formats (FLAC, WAV, MP3, etc.) to high-quality Opus.
#   Designed for integration with KDE Plasma (Dolphin service menu).
#
# Usage:
#   ./audio-to-opus.sh file1.flac file2.mp3 directory1
#
# Dependencies: ffmpeg, opusenc (opus-tools), kdialog

set -uo pipefail

# ==============================================
# CONFIGURATION AND CONSTANTS
# ==============================================

# Supported extensions (lowercase)
# This array ensures consistency between file checks and directory searches
readonly SUPPORTED_EXTENSIONS=("flac" "wav" "aiff" "aif" "alac" "m4a" "mp3" "wma" "aac" "ape" "wv" "wavpack" "tta" "ogg" "oga" "dsf" "dff" "mka")

# Opus encoding settings (High Quality)
readonly OPUS_BITRATE=510
readonly OPUS_COMP=10
readonly OPUS_FRAMESIZE=60

# Counters for final report
TOTAL_ARGS=$#
SUCCESS_COUNT=0
TOTAL_PROCESSED=0

# Temporary file tracking for cleanup
TEMP_FILES=()

# ==============================================
# SAFETY FUNCTIONS
# ==============================================

# Cleanup function triggered on exit or interrupt
cleanup() {
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        rm -f "${TEMP_FILES[@]}" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# ==============================================
# DEPENDENCY CHECK
# ==============================================

check_dependencies() {
    local missing_deps=()
    for dep in ffmpeg opusenc kdialog; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        kdialog --error "Error: Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# ==============================================
# CORE FUNCTIONS
# ==============================================

# Function: convert_file
# Description: Converts a single input file to Opus format.
# Arguments: $1 = Input file path
convert_file() {
    local input_file="$1"
    local output_file="${input_file%.*}.opus"
    local temp_cover
    local temp_audio
    local ffmpeg_success=false

    # Safety check: Does input exist?
    if [[ ! -f "$input_file" ]]; then
        return 1
    fi

    # Safety check: Does output already exist? (Avoid overwriting)
    if [[ -f "$output_file" ]]; then
        echo "Skipping: '$output_file' already exists."
        return 1
    fi

    # Create secure temporary files
    temp_cover="$(mktemp --suffix=.jpg)"
    temp_audio="$(mktemp --suffix=.wav)"
    TEMP_FILES+=("$temp_cover" "$temp_audio")

    # ----------------------------------------------------------
    # STEP 1: Extract Audio to WAV (PCM)
    # ----------------------------------------------------------
    # We retry up to 3 times to handle transient read errors
    for attempt in {1..3}; do
        if ffmpeg -y -loglevel error -i "$input_file" -vn -c:a pcm_s24le "$temp_audio" 2>/dev/null; then
            ffmpeg_success=true
            break
        fi
        sleep 1
    done

    if [[ "$ffmpeg_success" != "true" ]]; then
        echo "Error: Failed to extract audio from '$input_file'"
        return 1
    fi

    # ----------------------------------------------------------
    # STEP 2: Extract Cover Art & Encode to Opus
    # ----------------------------------------------------------

    # Try to extract cover art
    if ffmpeg -y -loglevel error -i "$input_file" -an -vcodec copy "$temp_cover" 2>/dev/null && [[ -s "$temp_cover" ]]; then
        # Encode WITH cover art
        opusenc --bitrate "$OPUS_BITRATE" --comp "$OPUS_COMP" --framesize "$OPUS_FRAMESIZE" \
                --padding 0 --discard-comments --picture "$temp_cover" "$temp_audio" "$output_file" >/dev/null 2>&1
    else
        # Encode WITHOUT cover art
        opusenc --bitrate "$OPUS_BITRATE" --comp "$OPUS_COMP" --framesize "$OPUS_FRAMESIZE" \
                --padding 0 --discard-comments "$temp_audio" "$output_file" >/dev/null 2>&1
    fi

    # ----------------------------------------------------------
    # STEP 3: Verification & Cleanup
    # ----------------------------------------------------------

    # Remove specific temp files from the tracking list (handled by trap as fallback)
    rm -f "$temp_cover" "$temp_audio" 2>/dev/null || true

    # Verify output file exists and has content
    if [[ ! -s "$output_file" ]]; then
        return 1
    fi

    return 0
}

# Function: process_items
# Description: Iterates through arguments (files or directories)
process_items() {
    local args=("$@")
    local file_extension

    for item in "${args[@]}"; do
        if [[ -f "$item" ]]; then
            # --- Handle Single File ---
            file_extension="${item##*.}" # Extract extension
            file_extension="${file_extension,,}"  # Convert to lowercase

            # Check if extension is in our supported list
            if [[ " ${SUPPORTED_EXTENSIONS[*]} " =~ " ${file_extension} " ]]; then
                if convert_file "$item"; then
                    ((SUCCESS_COUNT++))
                fi
                ((TOTAL_PROCESSED++))
            fi

        elif [[ -d "$item" ]]; then
            # --- Handle Directory ---
            # Build find command arguments dynamically based on SUPPORTED_EXTENSIONS
            local find_args=()
            for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
                find_args+=(-iname "*.${ext}" -o)
            done
            # Remove the trailing '-o' operator
            unset 'find_args[-1]'

            # Process files found in directory
            while IFS= read -r -d '' found_file; do
                if convert_file "$found_file"; then
                    ((SUCCESS_COUNT++))
                fi
                ((TOTAL_PROCESSED++))
            done < <(find "$item" -type f \( "${find_args[@]}" \) -print0 2>/dev/null)
        fi
    done
}

# ==============================================
# MAIN EXECUTION
# ==============================================

check_dependencies

# 1. Start Notification
kdialog --title "Opus Converter" \
    --icon "audio-x-generic" \
    --passivepopup "Initializing conversion for $TOTAL_ARGS items..." 5 &

# Run main logic
process_items "$@"

# 2. End Notification
kdialog --title "Opus Converter" \
    --icon "checkbox" \
    --passivepopup "Conversion finished!\nSuccess: $SUCCESS_COUNT / $TOTAL_PROCESSED files." 5

exit 0
