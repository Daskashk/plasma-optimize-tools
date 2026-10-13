#!/usr/bin/env bash

# ==========================================
# Configuration
# ==========================================

# CRF/CQ (Quality): 29 es el punto óptimo para 480p (mucha compresión, sin verse fatal)
QUALITY=29

# Audio Bitrate: 96k es ideal para voz/música de fondo en videos compactos.
AUDIO_BITRATE="96k"

# Maximum parallel conversions.
MAX_PARALLEL=2

# Target Resolution Limits (480p for max compactness)
TARGET_WIDTH=1280
TARGET_HEIGHT=720
TARGET_FPS=30

# Bitrate limits to guarantee small file sizes (VBV Buffer)
MAX_RATE="1000k"
BUF_SIZE="1500k"

TOTAL_FILES=$#

# ==========================================
# Dependency & Encoder Check
# ==========================================

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v kdialog >/dev/null 2>&1; then
    kdialog --error "Error: Missing dependencies (ffmpeg, kdialog)"
    exit 1
fi

detect_encoder() {
    # Use NVIDIA GPU (NVENC) if available, much faster for H.264 sharing.
    # Falls back to CPU (libx264) if GPU is not available/compatible.
    if ffmpeg -encoders 2>/dev/null | grep -q "h264_nvenc"; then
        echo "h264_nvenc"
    else
        echo "libx264"
    fi
}

# Detect best encoder once
ENCODER=$(detect_encoder)

# ==========================================
# 1. Start Notification
# ==========================================
kdialog --title "Video Compressor" \
    --icon "video-x-generic" \
    --passivepopup "Compressing $TOTAL_FILES videos to 720p using $ENCODER..." 5 &

# ==========================================
# 2. Process Loop
# ==========================================

running=0

for archivo in "$@"; do
    # Get output filename (adds _compressed)
    nombre_base="${archivo%.*}"
    nombre_final="${nombre_base}_compressed.mp4"

    # Adapt quality flag and bitrate control based on encoder
    if [[ "$ENCODER" == "h264_nvenc" ]]; then
        # -rc vbr is REQUIRED in NVENC for -maxrate to work properly
        quality_flag="-cq $QUALITY -preset p4 -rc vbr -maxrate $MAX_RATE -bufsize $BUF_SIZE"
    else
        # veryslow sacrifices encoding speed for maximum file size reduction
        quality_flag="-crf $QUALITY -preset veryslow -maxrate $MAX_RATE -bufsize $BUF_SIZE"
    fi

    # Convert Logic
    # 1. -vf: Limita a 30fps, escala a max 480p manteniendo aspect ratio.
    #         El 'pad' al final asegura que los píxeles sean pares (evita crashes en H.264).
    ffmpeg -i "$archivo" \
        -c:v "$ENCODER" \
        $quality_flag \
        -vf "fps=$TARGET_FPS,scale='min(${TARGET_WIDTH},iw)':'min(${TARGET_HEIGHT},ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2" \
        -c:a aac \
        -b:a "$AUDIO_BITRATE" \
        -movflags +faststart \
        -y "$nombre_final" >/dev/null 2>&1 &

    ((running++))
    if ((running >= MAX_PARALLEL)); then
        wait -n
        ((running--))
    fi
done

# Wait for any remaining background jobs to finish
wait

# ==========================================
# 3. End Notification
# ==========================================
kdialog --title "Video Compressor" \
    --icon "checkbox" \
    --passivepopup "Compression finished! Compact 720p files are ready to share." 3
