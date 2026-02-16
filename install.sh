#!/bin/bash
set -euo pipefail

# nemo-crypt installation script

VERSION="0.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default installation directories
SYSTEM_SCRIPT_DIR="/usr/local/share/nemo-crypt"
SYSTEM_ACTION_DIR="/usr/share/nemo/actions"
USER_ACTION_DIR="$HOME/.local/share/nemo/actions"

# Parse command line arguments
USER_INSTALL=false
UNINSTALL=false

usage() {
    cat <<EOF
nemo-crypt installation script v${VERSION}

Usage: $0 [OPTIONS]

Options:
    --user          Install to user directory (~/.local/share)
    --uninstall     Uninstall nemo-crypt
    --help          Show this help message

Examples:
    # System-wide installation (requires sudo)
    sudo $0

    # User installation (no sudo required)
    $0 --user

    # Uninstall
    sudo $0 --uninstall
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            USER_INSTALL=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Set installation directories based on mode
if [ "$USER_INSTALL" = true ]; then
    SCRIPT_DIR_TARGET="$HOME/.local/share/nemo-crypt"
    ACTION_DIR="$USER_ACTION_DIR"
    MAN_DIR="$HOME/.local/share/man/man1"
else
    SCRIPT_DIR_TARGET="$SYSTEM_SCRIPT_DIR"
    ACTION_DIR="$SYSTEM_ACTION_DIR"
    MAN_DIR="/usr/local/share/man/man1"
fi

# Check if running as root for system installation
if [ "$USER_INSTALL" = false ] && [ "$EUID" -ne 0 ]; then
    echo "ERROR: System-wide installation requires root privileges."
    echo "Please run with sudo, or use --user for user installation."
    exit 1
fi

# Uninstall function
uninstall() {
    echo "Uninstalling nemo-crypt..."

    # Remove scripts
    if [ -d "$SCRIPT_DIR_TARGET" ]; then
        rm -rf "$SCRIPT_DIR_TARGET"
        echo "Removed: $SCRIPT_DIR_TARGET"
    fi

    # Remove Nemo actions
    for action in gpg-encrypt.nemo_action decrypt-gpg.nemo_action; do
        if [ -f "$ACTION_DIR/$action" ]; then
            rm -f "$ACTION_DIR/$action"
            echo "Removed: $ACTION_DIR/$action"
        fi
    done

    # Remove man pages (only for system install)
    if [ "$USER_INSTALL" = false ]; then
        for man in gpg-encrypt.1 gpg-decrypt-verify.1; do
            if [ -f "$MAN_DIR/$man" ]; then
                rm -f "$MAN_DIR/$man"
                echo "Removed: $MAN_DIR/$man"
            fi
        done
        # Update man database
        if command -v mandb >/dev/null 2>&1; then
            mandb -q 2>/dev/null || true
        fi
    fi

    echo ""
    echo "Uninstallation complete."
    echo "Please restart Nemo: nemo -q"
    exit 0
}

# Run uninstall if requested
if [ "$UNINSTALL" = true ]; then
    uninstall
fi

# Installation
echo "Installing nemo-crypt v${VERSION}..."
echo "Installation mode: $([ "$USER_INSTALL" = true ] && echo "User" || echo "System-wide")"
echo ""

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()
for cmd in gpg python3 zenity notify-send; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

# Check Python GTK bindings
if ! python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
    MISSING_DEPS+=("python3-gi")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "ERROR: Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Install them with:"
    echo "  Debian/Ubuntu: sudo apt-get install gnupg python3-gi gir1.2-gtk-3.0 zenity libnotify-bin"
    echo "  Fedora: sudo dnf install gnupg2 python3-gobject gtk3 zenity libnotify"
    exit 1
fi
echo "All dependencies satisfied."
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "$SCRIPT_DIR_TARGET"
mkdir -p "$ACTION_DIR"
if [ "$USER_INSTALL" = false ]; then
    mkdir -p "$MAN_DIR"
fi

# Install scripts
echo "Installing scripts..."
install -m 0755 "$SCRIPT_DIR/gpg-encrypt.sh" "$SCRIPT_DIR_TARGET/"
install -m 0755 "$SCRIPT_DIR/gpg-decrypt-verify.sh" "$SCRIPT_DIR_TARGET/"
install -m 0755 "$SCRIPT_DIR/gpg-encrypt-dialog.py" "$SCRIPT_DIR_TARGET/"
install -m 0644 "$SCRIPT_DIR/gpg-common.sh" "$SCRIPT_DIR_TARGET/"
echo "  Installed scripts to: $SCRIPT_DIR_TARGET"

# Install Nemo actions with correct paths
echo "Installing Nemo actions..."
sed "s|<gpg-encrypt.sh>|$SCRIPT_DIR_TARGET/gpg-encrypt.sh|g" \
    "$SCRIPT_DIR/gpg-encrypt.nemo_action" > "$ACTION_DIR/gpg-encrypt.nemo_action"
sed "s|<gpg-decrypt-verify.sh>|$SCRIPT_DIR_TARGET/gpg-decrypt-verify.sh|g" \
    "$SCRIPT_DIR/decrypt-gpg.nemo_action" > "$ACTION_DIR/decrypt-gpg.nemo_action"
echo "  Installed Nemo actions to: $ACTION_DIR"

# Install man pages (system install only)
if [ "$USER_INSTALL" = false ] && [ -d "$SCRIPT_DIR/man" ]; then
    echo "Installing man pages..."
    install -m 0644 "$SCRIPT_DIR/man/gpg-encrypt.1" "$MAN_DIR/"
    install -m 0644 "$SCRIPT_DIR/man/gpg-decrypt-verify.1" "$MAN_DIR/"
    echo "  Installed man pages to: $MAN_DIR"

    # Update man database
    if command -v mandb >/dev/null 2>&1; then
        echo "Updating man database..."
        mandb -q 2>/dev/null || true
    fi
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart Nemo: nemo -q"
echo "  2. Right-click on a file to see 'Encrypt...' option"
echo "  3. Right-click on .gpg/.pgp/.asc files to see 'Decrypt File' option"
echo ""
echo "Documentation:"
if [ "$USER_INSTALL" = false ]; then
    echo "  Man pages: man gpg-encrypt, man gpg-decrypt-verify"
fi
echo "  README: $SCRIPT_DIR/README.md"
echo "  GitHub: https://github.com/ko4dfo/nemo-crypt"
