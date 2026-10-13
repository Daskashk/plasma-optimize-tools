# plasma-optimize-tools

A collection of KDE Plasma service menu actions for Dolphin to convert,
compress and optimize audio, video and image files on the fly.

## Tools

| Service menu | Script | What it does |
|---|---|---|
| **Convert to Opus** | `audio-to-opus.sh` | Converts FLAC/WAV/MP3/etc. to high-quality Opus (510 kbps, comp 10) preserving cover art. |
| **Convert to AVIF** | `avif-converter.sh` | Converts PNG/JPEG/WebP/TIFF to AVIF, preserving alpha. Uses SVT-AV1 if available, else libaom. |
| **Compress video** | `video-converter.sh` | Compresses video to 720p H.264 (NVENC if available, else libx264) with compact bitrate. |
| **Extract All Subtitles** | `extract_all_subs.sh` | Extracts every subtitle stream of a video into a `Subtitles/` folder, tagged by language and forced flag. |
| **GIF Optimizer** | `gif-to-webp.sh` | Resizes/caps FPS, generates both optimized GIF and WebP, and keeps the smaller one. |

## Dependencies

Install the tools you actually need:

```bash
# openSUSE
sudo zypper install ffmpeg opus-tools gifsicle kdialog

# Fedora
sudo dnf install ffmpeg opus-tools gifsicle kdialog

# Arch
sudo pacman -S ffmpeg opus-tools gifsicle kdialog
```

| Tool | Used by |
|---|---|
| `ffmpeg` | all |
| `ffprobe` | avif, gif, subtitles |
| `opusenc` (opus-tools) | audio-to-opus |
| `gifsicle` | gif-to-webp |
| `kdialog` | all (notifications) |

## Installation

```bash
git clone https://github.com/Daskashk/plasma-optimize-tools.git
cd plasma-optimize-tools
./install.sh
```

The installer copies the scripts to `~/.local/bin` and the `.desktop` files to
the correct KDE service menu directory (auto-detects Plasma 5 vs Plasma 6).

Then right-click any supported file in Dolphin → **Actions** → pick the tool.

## Manual installation

If you prefer to install by hand:

```bash
# Scripts
install -Dm755 *.sh ~/.local/bin/

# Service menus — Plasma 6
install -Dm644 *.desktop ~/.local/share/kio/servicemenus/

# Service menus — Plasma 5
install -Dm644 *.desktop ~/.local/share/kservices5/ServiceMenus/
```

Make sure `~/.local/bin` is in your `$PATH`:

```bash
echo $PATH | grep -q "$HOME/.local/bin" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## Uninstallation

```bash
./install.sh --uninstall
```

## License

MIT — see [LICENSE](LICENSE).
