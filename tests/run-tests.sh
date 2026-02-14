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
