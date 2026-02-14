#!/bin/bash
# Condition script for Encrypt action
# Returns 0 (success) if file should show Encrypt option
# Returns 1 (failure) if file should NOT show Encrypt option

# Check if any file is already encrypted
for FILE in "$@"; do
    if file -b "$FILE" | grep -qi "gpg\|pgp\|openpgp"; then
        exit 1  # At least one file is encrypted, don't show menu
    fi
done

exit 0  # All files are OK to encrypt
