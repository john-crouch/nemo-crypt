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

set -euo pipefail
# GPG Encrypt — drop-in replacement for nemo-seahorse encrypt
# Uses gpg-encrypt-dialog.py for the native-style GTK3 settings dialog

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/gpg-common.sh"

check_dependencies gpg zenity notify-send python3
FILES=("$@")

log_info "Starting encryption process"
log_debug "Number of files: ${#FILES[@]}"
log_debug "Files: ${FILES[*]}"

if [ ${#FILES[@]} -eq 0 ]; then
    log_error "No files specified"
    notify-send -i dialog-error "Encrypt" "No files specified."
    exit 1
fi

# ─── Multi-file packaging ───────────────────────────────────────────────
PACKAGE=""

# Cleanup function for temporary package
cleanup() {
    if [ -n "$PACKAGE" ] && [ -f "$PACKAGE" ]; then
        rm -f "$PACKAGE"
    fi
}
trap cleanup EXIT INT TERM

if [ ${#FILES[@]} -gt 1 ]; then
    log_debug "Multiple files selected, showing packaging dialog"
    CHOICE=$(zenity --list --radiolist \
        --title="Encrypt Multiple Files" \
        --text="<b>You have selected multiple files</b>\n\nPackaging:" \
        --column="" --column="Option" \
        TRUE "Encrypt each file separately" \
        FALSE "Encrypt packed together in a package" \
        --width=420 --height=220) || exit 0

    log_debug "User choice: $CHOICE"
    if [ "$CHOICE" = "Encrypt packed together in a package" ]; then
        log_info "Creating package from ${#FILES[@]} files"
        PKG_NAME=$(zenity --entry \
            --title="Package Name" \
            --text="Package name:" \
            --entry-text="encrypted-package" \
            --width=360) || exit 0

        # Validate package name is not empty or only whitespace
        if [ -z "$PKG_NAME" ] || [[ "$PKG_NAME" =~ ^[[:space:]]*$ ]]; then
            notify-send -i dialog-error "Encrypt" "Package name cannot be empty."
            exit 1
        fi

        # Check for path traversal attempts and invalid characters
        if [[ "$PKG_NAME" =~ \.\./|/\.\.|^/|/ ]]; then
            notify-send -i dialog-error "Encrypt" "Package name cannot contain path separators or directory traversal."
            exit 1
        fi

        # Sanitize any remaining problematic characters
        PKG_NAME=$(echo "$PKG_NAME" | tr -d '\n\r' | sed 's/[^a-zA-Z0-9._-]/_/g')

        PKG_EXT=$(zenity --list --radiolist \
            --title="Package Extension" \
            --text="Archive format:" \
            --column="" --column="Extension" \
            TRUE ".zip" \
            FALSE ".tar.gz" \
            FALSE ".tar.bz2" \
            --width=300 --height=220) || exit 0

        PKG_DIR=$(dirname "${FILES[0]}")
        PACKAGE="${PKG_DIR}/${PKG_NAME}${PKG_EXT}"

        case "$PKG_EXT" in
            .zip)
                if ! ERROR=$(zip -j "$PACKAGE" "${FILES[@]}" 2>&1); then
                    notify-send -i dialog-error "Archive Failed" "ZIP error:\n${ERROR:0:200}"
                    exit 1
                fi
                ;;
            .tar.gz)
                if ! ERROR=$(tar czf "$PACKAGE" --transform='s|.*/||' "${FILES[@]}" 2>&1); then
                    notify-send -i dialog-error "Archive Failed" "tar.gz error:\n${ERROR:0:200}"
                    exit 1
                fi
                ;;
            .tar.bz2)
                if ! ERROR=$(tar cjf "$PACKAGE" --transform='s|.*/||' "${FILES[@]}" 2>&1); then
                    notify-send -i dialog-error "Archive Failed" "tar.bz2 error:\n${ERROR:0:200}"
                    exit 1
                fi
                ;;
        esac

        FILES=("$PACKAGE")
    fi
fi

# ─── Encryption settings dialog ─────────────────────────────────────────
log_debug "Launching encryption settings dialog"
DIALOG_OUTPUT=$(python3 "${SCRIPT_DIR}/gpg-encrypt-dialog.py")
DIALOG_EXIT=$?
log_debug "Dialog exit code: $DIALOG_EXIT"

if [ $DIALOG_EXIT -ne 0 ]; then
    log_info "User cancelled encryption dialog"
    exit 0
fi

log_debug "Dialog output: $DIALOG_OUTPUT"

# Validate dialog output format
if [[ ! "$DIALOG_OUTPUT" =~ ^MODE= ]] || [[ ! "$DIALOG_OUTPUT" =~ RECIPIENTS= ]] || [[ ! "$DIALOG_OUTPUT" =~ SIGNER= ]]; then
    log_error "Dialog returned invalid output format"
    notify-send -i dialog-error "Encrypt" "Encryption dialog returned invalid data.\n\nPlease try again."
    exit 1
fi

ENC_MODE=$(echo "$DIALOG_OUTPUT" | grep '^MODE=' | cut -d= -f2)
RECIPIENTS=$(echo "$DIALOG_OUTPUT" | grep '^RECIPIENTS=' | cut -d= -f2)
SIGNER=$(echo "$DIALOG_OUTPUT" | grep '^SIGNER=' | cut -d= -f2)

log_info "Encryption mode: $ENC_MODE"
log_debug "Recipients: $RECIPIENTS"
log_debug "Signer: $SIGNER"

# Build recipient args
RCPT_ARGS=()
if [ "$ENC_MODE" = "recipients" ] && [ -n "$RECIPIENTS" ]; then
    IFS=',' read -ra RCPTS <<< "$RECIPIENTS"
    for r in "${RCPTS[@]}"; do
        RCPT_ARGS+=(--recipient "$r")
    done
fi

# Build signer args
SIGN_ARGS=()
if [ -n "$SIGNER" ] && [ "$SIGNER" != "none" ]; then
    SIGN_ARGS=(--sign --local-user "$SIGNER")
fi

# ─── Output location ─────────────────────────────────────────────────────
OUTFILES=()

if [ ${#FILES[@]} -eq 1 ]; then
    # Single file: save-as dialog
    DEFAULT_OUT="${FILES[0]}.gpg"
    OUTFILE=$(zenity --file-selection --save --confirm-overwrite \
        --title="Choose Encrypted File Name for '$(basename "${FILES[0]}")'" \
        --filename="$DEFAULT_OUT" \
        --window-icon=dialog-password \
        --file-filter='GPG Files | *.gpg *.pgp *.asc' \
        --file-filter='All Files | *') || exit 0
    OUTFILES=("$OUTFILE")
else
    # Multiple files: choose output directory
    DEFAULT_DIR=$(dirname "${FILES[0]}")
    OUTDIR=$(zenity --file-selection --directory \
        --title="Choose Output Directory for Encrypted Files" \
        --filename="$DEFAULT_DIR/" \
        --window-icon=dialog-password) || exit 0
    for FILE in "${FILES[@]}"; do
        OUTFILES+=("${OUTDIR}/$(basename "$FILE").gpg")
    done

    # Check for existing files and confirm overwrite
    EXISTING_FILES=()
    for OUTFILE in "${OUTFILES[@]}"; do
        if [ -f "$OUTFILE" ]; then
            EXISTING_FILES+=("$(basename "$OUTFILE")")
        fi
    done

    if [ ${#EXISTING_FILES[@]} -gt 0 ]; then
        FILE_LIST=$(printf '%s\n' "${EXISTING_FILES[@]}")
        if ! zenity --question \
            --title="Confirm Overwrite" \
            --text="The following files already exist:\n\n${FILE_LIST}\n\nOverwrite them?" \
            --width=400; then
            exit 0
        fi
    fi
fi

# ─── Encrypt ─────────────────────────────────────────────────────────────
SUCCEEDED=0
FAILED=0
FAIL_NAMES=""

log_info "Starting encryption of ${#FILES[@]} file(s)"

for i in "${!FILES[@]}"; do
    FILE="${FILES[$i]}"
    OUTFILE="${OUTFILES[$i]}"

    log_debug "Processing file: $FILE -> $OUTFILE"

    # Skip files that are already GPG encrypted (check file header)
    if file -b "$FILE" | grep -qi "gpg\|pgp\|openpgp"; then
        log_info "Skipping already encrypted file: $FILE"
        ((FAILED++))
        FAIL_NAMES+="\n$(basename "$FILE"): Already encrypted"
        continue
    fi

    GPG_CMD=(gpg --yes --output "$OUTFILE")

    if [ "$ENC_MODE" = "symmetric" ]; then
        GPG_CMD+=(--symmetric "${SIGN_ARGS[@]}")
    else
        GPG_CMD+=(--encrypt "${RCPT_ARGS[@]}" "${SIGN_ARGS[@]}")
    fi

    log_debug "GPG command: ${GPG_CMD[*]} $FILE"

    if ERROR=$("${GPG_CMD[@]}" "$FILE" 2>&1); then
        log_info "Successfully encrypted: $(basename "$FILE")"
        ((SUCCEEDED++)) || true
    else
        log_error "Failed to encrypt $(basename "$FILE"): $ERROR"
        ((FAILED++)) || true
        FAIL_NAMES+="\n$(basename "$FILE"): ${ERROR:0:100}"
        rm -f "$OUTFILE"
    fi
done

log_info "Encryption complete: $SUCCEEDED succeeded, $FAILED failed"


# Clean up temporary package after successful encryption (or keep on failure for inspection)
if [ -n "$PACKAGE" ] && [ $FAILED -eq 0 ]; then
    rm -f "$PACKAGE"
    PACKAGE=""  # Clear so trap doesn't try to delete again
fi

# ─── Notification ────────────────────────────────────────────────────────
if [ $FAILED -eq 0 ]; then
    # Build notification title and body to match decrypt format
    if [ $SUCCEEDED -eq 1 ]; then
        TITLE="Encrypted: $(basename "${FILES[0]}")"
        BODY="Output: $(basename "${OUTFILES[0]}")"
    else
        TITLE="Encrypted: ${SUCCEEDED} files"
        BODY="${SUCCEEDED} files encrypted"
    fi

    # Add encryption details
    if [ "$ENC_MODE" = "symmetric" ]; then
        BODY+="\nMethod: Passphrase"
    else
        BODY+="\nMethod: Public key"
    fi

    if [ ${#SIGN_ARGS[@]} -gt 0 ]; then
        BODY+="\nSigned: Yes"
    fi

    notify-send -i dialog-password -u normal -t 5000 "$TITLE" "$BODY"
else
    if [ $SUCCEEDED -eq 1 ]; then
        TITLE="Encryption Failed: $(basename "${FILES[0]}")"
    else
        TITLE="Encryption Failed: ${FAILED} file(s)"
    fi

    if [ $SUCCEEDED -gt 0 ]; then
        BODY="${SUCCEEDED} succeeded, ${FAILED} failed"
    else
        BODY="${FAILED} file(s) failed"
    fi
    BODY+="$FAIL_NAMES"

    notify-send -i dialog-error -u normal -t 5000 "$TITLE" "$BODY"
fi

