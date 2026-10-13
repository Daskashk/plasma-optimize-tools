#!/usr/bin/env bash
#
# install.sh - Installer for plasma-optimize-tools
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

# Detect KDE Plasma version to pick the right service menu path
detect_menu_dir() {
    if [[ -d "$HOME/.local/share/kio/servicemenus" ]] || \
       pkg-config --exists kf6 2>/dev/null || \
       plasmashell --version 2>/dev/null | grep -q "6\."; then
        echo "$HOME/.local/share/kio/servicemenus"
    else
        echo "$HOME/.local/share/kservices5/ServiceMenus"
    fi
}
MENU_DIR="$(detect_menu_dir)"

# ---------- Uninstall mode ----------
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling plasma-optimize-tools..."

    for f in "$SCRIPT_DIR"/*.sh; do
        [[ "$(basename "$f")" == "install.sh" ]] && continue
        rm -f "$BIN_DIR/$(basename "$f")"
    done

    for f in "$SCRIPT_DIR"/*.desktop; do
        rm -f "$MENU_DIR/$(basename "$f")"
    done

    echo "Done."
    exit 0
fi

# ---------- Install mode ----------
echo "Installing plasma-optimize-tools..."
echo "  scripts  -> $BIN_DIR"
echo "  menus    -> $MENU_DIR"
echo

mkdir -p "$BIN_DIR" "$MENU_DIR"

# Scripts
for f in "$SCRIPT_DIR"/*.sh; do
    [[ "$(basename "$f")" == "install.sh" ]] && continue
    install -m 0755 "$f" "$BIN_DIR/"
    echo "  + $(basename "$f")"
done

# Desktop service menus
for f in "$SCRIPT_DIR"/*.desktop; do
    install -m 0644 "$f" "$MENU_DIR/"
    echo "  + $(basename "$f")"
done

# PATH check
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo
    echo "⚠️  $BIN_DIR is not in your PATH."
    echo "   Add this to ~/.bashrc and restart your session:"
    echo "     export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo
echo "✅ Installation complete. Right-click a supported file in Dolphin → Actions."
