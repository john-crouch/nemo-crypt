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
# GPG Decrypt with signature verification notification

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/gpg-common.sh"

check_dependencies gpg notify-send

FILE="$1"

log_info "Starting decryption process"
log_debug "Input file: $FILE"

if [ -z "$FILE" ]; then
    log_error "No file specified"
    notify-send -i dialog-error "Decrypt File" "No file specified."
    exit 1
fi

FILENAME=$(basename "$FILE")
# Determine default output filename
DEFAULT_OUT="$FILE"
if [[ "$FILE" == *.gpg ]]; then
    DEFAULT_OUT="${FILE%.gpg}"
elif [[ "$FILE" == *.pgp ]]; then
    DEFAULT_OUT="${FILE%.pgp}"
elif [[ "$FILE" == *.asc ]]; then
    DEFAULT_OUT="${FILE%.asc}"
else
    # No recognized extension - add .decrypted to avoid overwriting
    DEFAULT_OUT="${FILE}.decrypted"
fi

# Prompt user for save location
OUTFILE=$(zenity --file-selection --save --confirm-overwrite \
    --title="Choose Decrypted File Name for '$(basename "$FILE")'" \
    --filename="$DEFAULT_OUT" \
    --window-icon=dialog-password \
    --file-filter='All Files | *') || exit 0

# Cleanup function for partial decryption on interrupt
DECRYPTION_STARTED=false
cleanup() {
    if [ "$DECRYPTION_STARTED" = true ] && [ -f "$OUTFILE" ]; then
        # Remove partial decrypted file on error/interrupt
        rm -f "$OUTFILE"
    fi
}
trap cleanup EXIT INT TERM

# Mark that decryption is starting
DECRYPTION_STARTED=true

log_debug "Output file: $OUTFILE"

# Check if file uses anonymous recipient (throw-keyids)
log_debug "Checking for anonymous recipient encryption"

# Use --no-default-keyring to prevent GPG from trying keys (which would trigger Yubikey PIN)
# This way we only examine the packet structure without attempting decryption
# Note: This command will return non-zero (can't decrypt), but that's OK - we only need the packet structure
PACKETS=$(gpg --no-default-keyring --keyring /dev/null --list-packets "$FILE" 2>&1) || PACKETS_EXIT=$?
PACKETS_EXIT=${PACKETS_EXIT:-0}

log_debug "GPG list-packets exit code: $PACKETS_EXIT"
log_debug "Packet output length: ${#PACKETS} bytes"

# Check if we got any output (we expect output even if gpg returned non-zero)
if [ -z "$PACKETS" ]; then
    log_error "Failed to read GPG packet data from file (exit code: $PACKETS_EXIT)"
    notify-send -i dialog-error "Decryption Failed" \
        "Unable to read encryption data from file.\nThe file may be corrupted."
    exit 1
fi

log_debug "Packet data (first 500 chars): ${PACKETS:0:500}"

IS_ANONYMOUS=false
if echo "$PACKETS" | grep -q "keyid 0000000000000000"; then
    IS_ANONYMOUS=true
    log_info "Detected anonymous recipient encryption"
fi

# If anonymous, prompt user to select which key to try
TRY_KEY_ARGS=()
if [ "$IS_ANONYMOUS" = true ]; then
    log_debug "Prompting for key selection"

    # Get list of secret keys using shared function
    if ! SECRET_KEYS=$(list_secret_keys); then
        log_error "Failed to retrieve secret keys"
        notify-send -i dialog-error "Decryption Failed" "Unable to access GPG keyring."
        exit 1
    fi

    if [ -z "$SECRET_KEYS" ]; then
        log_error "No secret keys found for anonymous decryption"
        notify-send -i dialog-error "Decryption Failed" "No secret keys available for decryption."
        exit 1
    fi

    # Build zenity list for key selection and store full keyid mapping
    declare -A KEYID_MAP  # short_id -> full_keyid
    ZENITY_LIST=()

    while IFS=$'\t' read -r keyid uid; do
        short_id=${keyid: -8}
        KEYID_MAP["$short_id"]="$keyid"
        ZENITY_LIST+=("FALSE" "$short_id" "$uid")
    done <<< "$SECRET_KEYS"

    if [ ${#ZENITY_LIST[@]} -eq 0 ]; then
        log_error "No keys available for selection"
        notify-send -i dialog-error "Decryption Failed" "No secret keys available for decryption."
        exit 1
    fi

    # Prompt user to select key(s)
    SELECTED=$(zenity --list --checklist \
        --title="Select Decryption Key" \
        --text="This file uses anonymous encryption.\nSelect which key(s) to try for decryption:\n\nNote: GPG may try other keys if the selected ones fail." \
        --column="Try" --column="Key ID" --column="Name" \
        --width=600 --height=400 \
        --window-icon=dialog-password \
        "${ZENITY_LIST[@]}") || exit 0

    if [ -z "$SELECTED" ]; then
        log_info "No keys selected for decryption"
        exit 0
    fi

    # Convert selected short IDs back to full key IDs and build --try-secret-key args
    while IFS='|' read -ra SELECTED_IDS; do
        for short_id in "${SELECTED_IDS[@]}"; do
            full_keyid="${KEYID_MAP[$short_id]}"
            if [ -n "$full_keyid" ]; then
                TRY_KEY_ARGS+=(--try-secret-key "$full_keyid")
                log_debug "Will try key: $full_keyid"
            else
                log_error "Could not find full key ID for short ID: $short_id"
            fi
        done
    done <<< "$SELECTED"
fi

log_info "Executing GPG decryption"

# If we have specific keys selected (anonymous encryption), use them as hints to GPG
# Note: GPG may still try other keys due to hardware key limitations, but selected keys are prioritized
if [ ${#TRY_KEY_ARGS[@]} -gt 0 ]; then
    log_debug "Attempting decryption with selected keys"

    # Try decryption with selected keys (GPG will prioritize these but may try others)
    STATUS=$(gpg --batch --yes --status-fd 3 "${TRY_KEY_ARGS[@]}" --decrypt --output "$OUTFILE" "$FILE" 2>&1 3>&1 1>&2)
    GPG_EXIT=$?

    log_debug "GPG exit code: $GPG_EXIT"

    if [ $GPG_EXIT -ne 0 ]; then
        log_error "Decryption failed with exit code $GPG_EXIT"
        notify-send -i dialog-error "Decryption Failed" "Failed to decrypt ${FILENAME}\n\nNone of the selected keys could decrypt this file."
        exit 1
    fi

    log_info "Decryption successful"
else
    # Normal decryption (non-anonymous)
    STATUS=$(gpg --batch --yes --status-fd 3 --decrypt --output "$OUTFILE" "$FILE" 2>&1 3>&1 1>&2)
    GPG_EXIT=$?

    log_debug "GPG exit code: $GPG_EXIT"
    log_debug "GPG status output: $STATUS"

    if [ $GPG_EXIT -ne 0 ]; then
        log_error "Decryption failed with exit code $GPG_EXIT"
        notify-send -i dialog-error "Decryption Failed" "Failed to decrypt ${FILENAME}"
        exit 1
    fi
fi

log_info "Decryption successful"

# Decryption successful - don't clean up the output file
DECRYPTION_STARTED=false

# Helper function to extract signer from status line
extract_signer() {
    local status_type="$1"
    grep "$status_type" <<< "$STATUS" | sed "s/.*$status_type [A-F0-9]* //"
}

# Helper function to extract keyid from status line
extract_keyid() {
    local status_type="$1"
    grep "$status_type" <<< "$STATUS" | awk '{print $3}'
}

# Parse signature status (priority: bad > revoked > expired > good > error > none)
log_debug "Parsing signature verification status"

if grep -q "BADSIG" <<< "$STATUS"; then
    SIG_STATUS="BAD signature"
    SIGNER=$(extract_signer "BADSIG")
    SIG_ICON="security-low"
    log_info "Signature verification: BAD signature from $SIGNER"
elif grep -q "REVKEYSIG" <<< "$STATUS"; then
    SIG_STATUS="Signature by revoked key"
    SIGNER=$(extract_signer "REVKEYSIG")
    SIG_ICON="security-low"
    log_info "Signature verification: Revoked key - $SIGNER"
elif grep -q "EXPSIG" <<< "$STATUS"; then
    SIG_STATUS="Expired signature"
    SIGNER=$(extract_signer "EXPSIG")
    SIG_ICON="security-medium"
    log_info "Signature verification: Expired signature from $SIGNER"
elif grep -q "EXPKEYSIG" <<< "$STATUS"; then
    SIG_STATUS="Signature by expired key"
    SIGNER=$(extract_signer "EXPKEYSIG")
    SIG_ICON="security-medium"
    log_info "Signature verification: Expired key - $SIGNER"
elif grep -q "GOODSIG" <<< "$STATUS"; then
    SIG_STATUS="Valid signature"
    SIGNER=$(extract_signer "GOODSIG")
    SIG_ICON="security-high"
    log_info "Signature verification: GOOD signature from $SIGNER"
elif grep -q "ERRSIG" <<< "$STATUS"; then
    KEYID=$(extract_keyid "ERRSIG")
    SIG_STATUS="Unable to verify (key $KEYID not found)"
    SIGNER="Unknown"
    SIG_ICON="security-medium"
    log_info "Signature verification: Unable to verify - key $KEYID not found"
else
    SIG_STATUS="Not signed"
    SIGNER=""
    SIG_ICON="dialog-information"
    log_info "File was not signed"
fi

# Parse timestamp if present
SIG_DATE=""
if grep -q "VALIDSIG" <<< "$STATUS"; then
    TIMESTAMP=$(grep "VALIDSIG" <<< "$STATUS" | awk '{print $5}')
    if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" -gt 0 ] 2>/dev/null; then
        SIG_DATE=$(date -d "@$TIMESTAMP" "+%Y-%m-%d %H:%M:%S %Z")
    fi
fi

# Build notification body
BODY="Output: $(basename "$OUTFILE")\nSignature: $SIG_STATUS"

if [ -n "$SIGNER" ]; then
    BODY+="\nSigned by: $SIGNER"
fi

if [ -n "$SIG_DATE" ]; then
    BODY+="\nSigned on: $SIG_DATE"
fi

notify-send -i "$SIG_ICON" "Decrypted: $FILENAME" "$BODY"
