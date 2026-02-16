#!/bin/bash
# nemo-crypt - GPG encryption integration for Nemo file manager
# Copyright (C) 2026 John Crouch <github@ko4dfo.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Shared utilities for nemo-crypt GPG scripts

# ─── Debug and Logging ──────────────────────────────────────────────────

# Enable debug mode with: export NEMO_CRYPT_DEBUG=1
NEMO_CRYPT_DEBUG="${NEMO_CRYPT_DEBUG:-0}"
NEMO_CRYPT_LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/nemo-crypt/debug.log"

# Initialize logging if debug mode is enabled
if [ "$NEMO_CRYPT_DEBUG" = "1" ]; then
    mkdir -p "$(dirname "$NEMO_CRYPT_LOG_FILE")"
    echo "=== nemo-crypt debug session started at $(date) ===" >> "$NEMO_CRYPT_LOG_FILE"
    echo "Script: $0" >> "$NEMO_CRYPT_LOG_FILE"
    echo "Arguments: $*" >> "$NEMO_CRYPT_LOG_FILE"
    echo "Working directory: $(pwd)" >> "$NEMO_CRYPT_LOG_FILE"
    echo "" >> "$NEMO_CRYPT_LOG_FILE"
fi

log_debug() {
    if [ "$NEMO_CRYPT_DEBUG" = "1" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG: $*" >> "$NEMO_CRYPT_LOG_FILE"
    fi
}

log_error() {
    local msg="$*"
    if [ "$NEMO_CRYPT_DEBUG" = "1" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $msg" >> "$NEMO_CRYPT_LOG_FILE"
    fi
    echo "ERROR: $msg" >&2
}

log_info() {
    if [ "$NEMO_CRYPT_DEBUG" = "1" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$NEMO_CRYPT_LOG_FILE"
    fi
}

# ─── Dependency Checking ────────────────────────────────────────────────

check_dependencies() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -i dialog-error "Missing Dependencies" \
                "Required programs not found: ${missing[*]}"
        else
            echo "ERROR: Missing dependencies: ${missing[*]}" >&2
        fi
        exit 1
    fi
}

# ─── GPG Key Listing ────────────────────────────────────────────────

# List secret keys in "keyid uid" format (tab-separated)
# Returns: 0 on success, 1 on error
# Output: One line per key: "KEYID<TAB>UID"
list_secret_keys() {
    local output
    # Use --fast-list to avoid touching smartcards/Yubikeys during listing
    # This prevents PIN prompts when just building the key selection dialog
    if ! output=$(gpg --list-secret-keys --with-colons --fast-list 2>/dev/null); then
        log_error "Failed to list secret keys"
        return 1
    fi

    # Parse GPG output: save keyid when we see sec:, print when we see uid:
    echo "$output" | awk -F: '
        /^sec:/ { keyid=$5 }
        /^uid:/ && keyid { print keyid "\t" $10; keyid="" }
    '
    return 0
}

# List public keys in "keyid uid" format (tab-separated)
# Returns: 0 on success, 1 on error
# Output: One line per key: "KEYID<TAB>UID"
list_public_keys() {
    local output
    # Use --fast-list to avoid touching smartcards/Yubikeys during listing
    if ! output=$(gpg --list-keys --with-colons --fast-list 2>/dev/null); then
        log_error "Failed to list public keys"
        return 1
    fi

    # Parse GPG output: save keyid when we see pub:, print when we see uid:
    echo "$output" | awk -F: '
        /^pub:/ { keyid=$5 }
        /^uid:/ && keyid { print keyid "\t" $10; keyid="" }
    '
    return 0
}
