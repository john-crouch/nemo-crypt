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

if [ -z "$FILE" ]; then
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
    --window-icon=dialog-password) || exit 0

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

# Decrypt and capture status output (using fd 3 to separate status from stderr)
STATUS=$(gpg --batch --yes --status-fd 3 --decrypt --output "$OUTFILE" "$FILE" 2>&1 3>&1 1>&2)
GPG_EXIT=$?

if [ $GPG_EXIT -ne 0 ]; then
    notify-send -i dialog-error "Decryption Failed" "Failed to decrypt ${FILENAME}"
    exit 1
fi

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
if grep -q "BADSIG" <<< "$STATUS"; then
    SIG_STATUS="BAD signature"
    SIGNER=$(extract_signer "BADSIG")
    SIG_ICON="security-low"
elif grep -q "REVKEYSIG" <<< "$STATUS"; then
    SIG_STATUS="Signature by revoked key"
    SIGNER=$(extract_signer "REVKEYSIG")
    SIG_ICON="security-low"
elif grep -q "EXPSIG" <<< "$STATUS"; then
    SIG_STATUS="Expired signature"
    SIGNER=$(extract_signer "EXPSIG")
    SIG_ICON="security-medium"
elif grep -q "EXPKEYSIG" <<< "$STATUS"; then
    SIG_STATUS="Signature by expired key"
    SIGNER=$(extract_signer "EXPKEYSIG")
    SIG_ICON="security-medium"
elif grep -q "GOODSIG" <<< "$STATUS"; then
    SIG_STATUS="Valid signature"
    SIGNER=$(extract_signer "GOODSIG")
    SIG_ICON="security-high"
elif grep -q "ERRSIG" <<< "$STATUS"; then
    KEYID=$(extract_keyid "ERRSIG")
    SIG_STATUS="Unable to verify (key $KEYID not found)"
    SIGNER="Unknown"
    SIG_ICON="security-medium"
else
    SIG_STATUS="Not signed"
    SIGNER=""
    SIG_ICON="dialog-information"
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
