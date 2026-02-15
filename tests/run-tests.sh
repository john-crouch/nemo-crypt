#!/bin/bash
# Test suite for nemo-crypt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    echo "  Error: $2"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

test_skip() {
    echo -e "${YELLOW}⊘${NC} $1 (skipped: $2)"
}

# Dependency checks
test_dependencies() {
    echo "Testing dependency checks..."

    for cmd in gpg python3 zenity notify-send; do
        if command -v "$cmd" >/dev/null 2>&1; then
            test_pass "Dependency available: $cmd"
        else
            test_fail "Dependency missing: $cmd" "Required for nemo-crypt"
        fi
    done

    # Test Python GTK bindings
    if python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
        test_pass "Python GTK bindings available"
    else
        test_fail "Python GTK bindings missing" "Install python3-gi"
    fi
}

# Script syntax checks
test_syntax() {
    echo ""
    echo "Testing script syntax..."

    # Bash scripts
    for script in "$PROJECT_DIR"/*.sh "$PROJECT_DIR"/gpg-common.sh; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                test_pass "Bash syntax: $(basename "$script")"
            else
                test_fail "Bash syntax: $(basename "$script")" "Syntax error in script"
            fi
        fi
    done

    # Python scripts
    for script in "$PROJECT_DIR"/*.py; do
        if [ -f "$script" ]; then
            if python3 -m py_compile "$script" 2>/dev/null; then
                test_pass "Python syntax: $(basename "$script")"
            else
                test_fail "Python syntax: $(basename "$script")" "Syntax error in script"
            fi
        fi
    done
}

# File permission checks
test_permissions() {
    echo ""
    echo "Testing file permissions..."

    for script in "$PROJECT_DIR"/gpg-encrypt.sh "$PROJECT_DIR"/gpg-decrypt-verify.sh \
                  "$PROJECT_DIR"/gpg-encrypt-dialog.py "$PROJECT_DIR"/install.sh; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                test_pass "Executable: $(basename "$script")"
            else
                test_fail "Not executable: $(basename "$script")" "Missing execute permission"
            fi
        fi
    done
}

# GPG functionality tests (if GPG is available)
test_gpg_functions() {
    echo ""
    echo "Testing GPG functions..."

    if ! command -v gpg >/dev/null 2>&1; then
        test_skip "GPG functionality tests" "gpg not available"
        return
    fi

    # Test GPG key listing
    if gpg --list-keys --with-colons >/dev/null 2>&1; then
        test_pass "GPG key listing works"
    else
        test_fail "GPG key listing failed" "GPG configuration issue"
    fi

    # Test GPG secret key listing
    if gpg --list-secret-keys --with-colons >/dev/null 2>&1; then
        test_pass "GPG secret key listing works"
    else
        test_fail "GPG secret key listing failed" "GPG configuration issue"
    fi
}

# Test encryption/decryption workflow (if test key available)
test_encryption_workflow() {
    echo ""
    echo "Testing encryption/decryption workflow..."

    if ! command -v gpg >/dev/null 2>&1; then
        test_skip "Encryption workflow test" "gpg not available"
        return
    fi

    # Create temporary test file
    TEST_FILE=$(mktemp)
    TEST_ENCRYPTED=$(mktemp).gpg
    TEST_DECRYPTED=$(mktemp)

    echo "Test data for nemo-crypt" > "$TEST_FILE"

    # Test symmetric encryption
    if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --output "$TEST_ENCRYPTED" "$TEST_FILE" 2>/dev/null; then
        test_pass "GPG symmetric encryption works"

        # Test decryption
        if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
            --decrypt --output "$TEST_DECRYPTED" "$TEST_ENCRYPTED" 2>/dev/null; then
            test_pass "GPG symmetric decryption works"

            # Verify content matches
            if diff -q "$TEST_FILE" "$TEST_DECRYPTED" >/dev/null 2>&1; then
                test_pass "Encrypted/decrypted content matches"
            else
                test_fail "Content mismatch" "Encrypted and decrypted files differ"
            fi
        else
            test_fail "GPG symmetric decryption failed" "Decryption error"
        fi
    else
        test_fail "GPG symmetric encryption failed" "Encryption error"
    fi

    # Cleanup
    rm -f "$TEST_FILE" "$TEST_ENCRYPTED" "$TEST_DECRYPTED"
}

# Test Python dialog can be imported
test_python_dialog() {
    echo ""
    echo "Testing Python dialog module..."

    if python3 -c "
import sys
sys.path.insert(0, '$PROJECT_DIR')
# Don't actually run the dialog, just test imports
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Pango
" 2>/dev/null; then
        test_pass "Python dialog imports work"
    else
        test_fail "Python dialog imports failed" "GTK binding issue"
    fi
}

# Test common library can be sourced
test_common_library() {
    echo ""
    echo "Testing common library..."

    if bash -c "source '$PROJECT_DIR/gpg-common.sh'; declare -f check_dependencies" 2>/dev/null >/dev/null; then
        test_pass "Common library can be sourced"
    else
        test_fail "Common library sourcing failed" "Syntax or logic error"
    fi
}

# Test Nemo action files are valid
test_nemo_actions() {
    echo ""
    echo "Testing Nemo action files..."

    for action in "$PROJECT_DIR"/*.nemo_action; do
        if [ -f "$action" ]; then
            # Check required fields exist
            if grep -q "^\[Nemo Action\]" "$action" && \
               grep -q "^Name=" "$action" && \
               grep -q "^Exec=" "$action"; then
                test_pass "Nemo action valid: $(basename "$action")"
            else
                test_fail "Nemo action invalid: $(basename "$action")" "Missing required fields"
            fi
        fi
    done
}

# Test error handling scenarios
test_error_scenarios() {
    echo ""
    echo "Testing error handling..."

    if ! command -v gpg >/dev/null 2>&1; then
        test_skip "Error scenario tests" "gpg not available"
        return
    fi

    # Test encryption of already encrypted file
    TEST_FILE=$(mktemp)
    TEST_ENCRYPTED=$(mktemp).gpg
    echo "Test data" > "$TEST_FILE"

    # Encrypt the file first
    if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --output "$TEST_ENCRYPTED" "$TEST_FILE" 2>/dev/null; then

        # Check that it's detected as already encrypted
        if file -b "$TEST_ENCRYPTED" | grep -qi "gpg\|pgp\|openpgp"; then
            test_pass "Detects already encrypted files"
        else
            test_fail "Failed to detect encrypted file" "file command output issue"
        fi
    fi

    # Test decryption with wrong passphrase
    TEST_DECRYPTED=$(mktemp)
    if echo "wrongpass" | gpg --batch --yes --passphrase-fd 0 \
        --decrypt --output "$TEST_DECRYPTED" "$TEST_ENCRYPTED" 2>/dev/null; then
        test_fail "Decryption should fail with wrong passphrase" "Security issue"
    else
        test_pass "Decryption fails with wrong passphrase"
    fi

    # Test handling of empty files
    EMPTY_FILE=$(mktemp)
    EMPTY_ENCRYPTED=$(mktemp).gpg
    touch "$EMPTY_FILE"

    if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --output "$EMPTY_ENCRYPTED" "$EMPTY_FILE" 2>/dev/null; then
        test_pass "Can encrypt empty files"

        EMPTY_DECRYPTED=$(mktemp)
        if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
            --decrypt --output "$EMPTY_DECRYPTED" "$EMPTY_ENCRYPTED" 2>/dev/null; then
            if [ ! -s "$EMPTY_DECRYPTED" ]; then
                test_pass "Can decrypt empty files"
            else
                test_fail "Empty file decryption produced content" "Data corruption"
            fi
        fi
    fi

    # Test large file handling (1MB)
    LARGE_FILE=$(mktemp)
    LARGE_ENCRYPTED=$(mktemp).gpg
    dd if=/dev/zero of="$LARGE_FILE" bs=1M count=1 2>/dev/null

    if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --output "$LARGE_ENCRYPTED" "$LARGE_FILE" 2>/dev/null; then
        test_pass "Can encrypt 1MB file"

        LARGE_SIZE=$(stat -c%s "$LARGE_ENCRYPTED" 2>/dev/null || stat -f%z "$LARGE_ENCRYPTED")
        if [ "$LARGE_SIZE" -gt 0 ]; then
            test_pass "Encrypted file has non-zero size"
        fi
    fi

    # Cleanup
    rm -f "$TEST_FILE" "$TEST_ENCRYPTED" "$TEST_DECRYPTED" \
          "$EMPTY_FILE" "$EMPTY_ENCRYPTED" "$EMPTY_DECRYPTED" \
          "$LARGE_FILE" "$LARGE_ENCRYPTED"
}

# Test multi-file packaging
test_multifile_packaging() {
    echo ""
    echo "Testing multi-file packaging..."

    if ! command -v zip >/dev/null 2>&1; then
        test_skip "Multi-file packaging tests" "zip not available"
        return
    fi

    # Create test files
    TEST_DIR=$(mktemp -d)
    echo "File 1" > "$TEST_DIR/file1.txt"
    echo "File 2" > "$TEST_DIR/file2.txt"
    echo "File 3" > "$TEST_DIR/file3.txt"

    # Test zip creation
    TEST_ZIP="$TEST_DIR/test-package.zip"
    if zip -j "$TEST_ZIP" "$TEST_DIR"/*.txt >/dev/null 2>&1; then
        test_pass "Can create zip package"

        # Verify zip contents
        if unzip -l "$TEST_ZIP" | grep -q "file1.txt"; then
            test_pass "Zip package contains files"
        else
            test_fail "Zip package missing files" "Archive creation issue"
        fi
    else
        test_fail "Failed to create zip package" "zip command failed"
    fi

    # Test tar.gz creation
    TEST_TAR="$TEST_DIR/test-package.tar.gz"
    if tar czf "$TEST_TAR" -C "$TEST_DIR" file1.txt file2.txt file3.txt 2>/dev/null; then
        test_pass "Can create tar.gz package"

        # Verify tar contents
        if tar tzf "$TEST_TAR" | grep -q "file1.txt"; then
            test_pass "Tar.gz package contains files"
        else
            test_fail "Tar.gz package missing files" "Archive creation issue"
        fi
    else
        test_fail "Failed to create tar.gz package" "tar command failed"
    fi

    # Test encrypting the packages
    if command -v gpg >/dev/null 2>&1; then
        ZIP_ENCRYPTED="$TEST_ZIP.gpg"
        if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
            --symmetric --output "$ZIP_ENCRYPTED" "$TEST_ZIP" 2>/dev/null; then
            test_pass "Can encrypt zip package"
        fi

        TAR_ENCRYPTED="$TEST_TAR.gpg"
        if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
            --symmetric --output "$TAR_ENCRYPTED" "$TEST_TAR" 2>/dev/null; then
            test_pass "Can encrypt tar.gz package"
        fi
    fi

    # Cleanup
    rm -rf "$TEST_DIR"
}

# Test signature verification parsing
test_signature_verification() {
    echo ""
    echo "Testing signature verification parsing..."

    if ! command -v gpg >/dev/null 2>&1; then
        test_skip "Signature verification tests" "gpg not available"
        return
    fi

    # Check if we have any secret keys for testing
    if ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q "^sec:"; then
        test_skip "Signature verification tests" "no secret keys available"
        return
    fi

    # Get first available secret key
    SECRET_KEY=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep "^sec:" | head -1 | cut -d: -f5)

    if [ -z "$SECRET_KEY" ]; then
        test_skip "Signature verification tests" "could not extract key ID"
        return
    fi

    # Create test file
    TEST_FILE=$(mktemp)
    echo "Test data for signing" > "$TEST_FILE"
    TEST_SIGNED=$(mktemp).gpg

    # Test signing and encryption
    if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
        --symmetric --sign --local-user "$SECRET_KEY" \
        --output "$TEST_SIGNED" "$TEST_FILE" 2>/dev/null; then
        test_pass "Can sign and encrypt file"

        # Test signature verification output parsing
        TEST_DECRYPTED=$(mktemp)
        STATUS_FILE=$(mktemp)

        if echo "testpass" | gpg --batch --yes --passphrase-fd 0 \
            --status-file "$STATUS_FILE" \
            --decrypt --output "$TEST_DECRYPTED" "$TEST_SIGNED" 2>/dev/null; then

            # Check for signature status codes
            if grep -q "GOODSIG\|VALIDSIG" "$STATUS_FILE"; then
                test_pass "Signature verification produces GOODSIG status"
            else
                test_fail "Missing signature status" "Status file: $(cat "$STATUS_FILE")"
            fi

            # Check for signer info
            if grep -q "GOODSIG.*$SECRET_KEY" "$STATUS_FILE"; then
                test_pass "Signature verification includes signer key ID"
            fi

            # Test status code parsing logic
            if grep -q "VALIDSIG" "$STATUS_FILE"; then
                TIMESTAMP=$(grep "VALIDSIG" "$STATUS_FILE" | awk '{print $5}')
                if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" -gt 0 ] 2>/dev/null; then
                    test_pass "Can extract signature timestamp"
                fi
            fi
        fi

        rm -f "$STATUS_FILE" "$TEST_DECRYPTED"
    fi

    # Cleanup
    rm -f "$TEST_FILE" "$TEST_SIGNED"
}

# Test debug mode functionality
test_debug_mode() {
    echo ""
    echo "Testing debug mode..."

    # Test that debug logging works
    export NEMO_CRYPT_DEBUG=1
    LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nemo-crypt"
    LOG_FILE="$LOG_DIR/debug.log"

    # Clear any existing log
    rm -f "$LOG_FILE"

    # Source gpg-common.sh to test logging functions
    if bash -c "
        source '$PROJECT_DIR/gpg-common.sh'
        log_debug 'Test debug message'
        log_info 'Test info message'
        log_error 'Test error message'
    " 2>/dev/null; then
        if [ -f "$LOG_FILE" ]; then
            test_pass "Debug mode creates log file"

            if grep -q "Test debug message" "$LOG_FILE"; then
                test_pass "Debug messages are logged"
            fi

            if grep -q "Test info message" "$LOG_FILE"; then
                test_pass "Info messages are logged"
            fi

            if grep -q "Test error message" "$LOG_FILE"; then
                test_pass "Error messages are logged"
            fi
        else
            test_fail "Debug mode log file not created" "Check log directory permissions"
        fi
    fi

    # Test debug mode disabled
    unset NEMO_CRYPT_DEBUG
    rm -f "$LOG_FILE"

    bash -c "
        source '$PROJECT_DIR/gpg-common.sh'
        log_debug 'Should not be logged'
    " 2>/dev/null

    if [ ! -f "$LOG_FILE" ]; then
        test_pass "Debug mode disabled by default"
    else
        if ! grep -q "Should not be logged" "$LOG_FILE"; then
            test_pass "Debug messages not logged when disabled"
        fi
    fi

    # Cleanup
    rm -f "$LOG_FILE"
}

# Main test execution
main() {
    echo "================================"
    echo "  nemo-crypt Test Suite"
    echo "================================"
    echo ""

    test_dependencies
    test_syntax
    test_permissions
    test_common_library
    test_python_dialog
    test_gpg_functions
    test_encryption_workflow
    test_nemo_actions
    test_error_scenarios
    test_multifile_packaging
    test_signature_verification
    test_debug_mode

    echo ""
    echo "================================"
    echo "  Test Results"
    echo "================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

main
