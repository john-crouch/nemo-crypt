# nemo-crypt Testing Guide

## Pre-Installation Verification

### ✅ Package Quality Checks

All automated checks passed:
- **Lintian**: Clean (only 1 acceptable warning for new packages)
- **Dependencies**: All 7 required packages available
- **Script Syntax**: All scripts validated
- **Permissions**: All executables properly marked (755)
- **Package Size**: 24KB

### GPG Environment
- **GPG Version**: 2.4.4
- **Public Keys**: 3 available
- **Secret Keys**: 1 available
- **Python GTK**: OK

## Installation Testing

### 1. Install Package

```bash
cd /home/john/gitlocal/nemo-crypt
sudo dpkg -i ../nemo-crypt_0.2.0-1_all.deb
```

**Expected output:**
```
Selecting previously unselected package nemo-crypt.
(Reading database ... XX files and directories currently installed.)
Preparing to unpack .../nemo-crypt_0.2.0-1_all.deb ...
Unpacking nemo-crypt (0.2.0-1) ...
Setting up nemo-crypt (0.2.0-1) ...
```

### 2. Verify Installation

```bash
# Check installed files
dpkg -L nemo-crypt

# Verify scripts are executable
ls -l /usr/share/nemo-crypt/

# Check Nemo actions
ls -l /usr/share/nemo/actions/ | grep gpg

# Test man pages
man gpg-encrypt
man gpg-decrypt-verify
```

### 3. Restart Nemo

```bash
nemo -q
```

Wait 2-3 seconds, then open Nemo file manager.

## Functional Testing

### Test Files Created

Test directory: `/home/john/gitlocal/nemo-crypt/test-nemo-crypt/`

Files:
- `test-file.txt` (36 bytes)
- `test-file-2.txt` (19 bytes)
- `secret.txt` (18 bytes)

### Test 1: Single File Encryption (Symmetric)

1. Open Nemo and navigate to `test-nemo-crypt/`
2. Right-click on `test-file.txt`
3. Select "Encrypt..." from context menu
4. **Expected**: GTK dialog appears with encryption options
5. Select "Use passphrase only"
6. Click OK
7. Enter passphrase (e.g., "test123")
8. **Expected**: `test-file.txt.gpg` created
9. **Expected**: Desktop notification: "Encrypted: test-file.txt"

**Verification:**
```bash
ls -lh test-nemo-crypt/test-file.txt.gpg
file test-nemo-crypt/test-file.txt.gpg  # Should show "GPG encrypted data"
```

### Test 2: Decrypt File

1. Right-click on `test-file.txt.gpg`
2. Select "Decrypt File" from context menu
3. Enter passphrase: "test123"
4. **Expected**: `test-file.txt` created (or numbered variant if exists)
5. **Expected**: Notification showing:
   - "Decrypted: test-file.txt.gpg"
   - "Signature: Not signed"

**Verification:**
```bash
cat test-nemo-crypt/test-file.txt
# Should contain: "This is a test file for encryption."
```

### Test 3: Public Key Encryption

1. Right-click on `secret.txt`
2. Select "Encrypt..."
3. Select "Choose a set of recipients"
4. Check one or more public keys
5. Optionally select a signer from "Sign message as:" dropdown
6. Click OK
7. **Expected**: `secret.txt.gpg` created
8. **Expected**: Notification shows success

**Verification:**
```bash
gpg --list-packets test-nemo-crypt/secret.txt.gpg
# Should show encryption key IDs
```

### Test 4: Multi-File Encryption

1. Select multiple files (Ctrl+click): `test-file.txt` and `test-file-2.txt`
2. Right-click on selection
3. Select "Encrypt..."
4. **Expected**: Dialog asks for package name
5. Enter package name (e.g., "test-package")
6. Choose encryption method and click OK
7. **Expected**: `test-package.zip.gpg` or `test-package.tar.gz.gpg` created

**Verification:**
```bash
ls -lh test-nemo-crypt/*.gpg
```

### Test 5: Signature Verification

If you encrypted with a signature:

1. Right-click on signed `.gpg` file
2. Select "Decrypt File"
3. Enter passphrase
4. **Expected**: Notification shows:
   - "Valid signature" (green shield icon)
   - "Signed by: [Your Key]"
   - "Signed on: [Date/Time]"

### Test 6: Man Pages

```bash
man gpg-encrypt
# Check sections: NAME, SYNOPSIS, DESCRIPTION, OPTIONS, EXAMPLES

man gpg-decrypt-verify
# Verify all sections present and formatted correctly
```

### Test 7: Error Handling

**Test missing dependencies:**
```bash
# Temporarily rename zenity to test error handling
sudo mv /usr/bin/zenity /usr/bin/zenity.bak
./test-nemo-crypt/test-file.txt  # Try to encrypt
# Expected: Error notification about missing zenity
sudo mv /usr/bin/zenity.bak /usr/bin/zenity
```

**Test invalid files:**
1. Create corrupted .gpg file: `echo "invalid" > bad.gpg`
2. Try to decrypt it
3. **Expected**: Error notification

**Test path traversal protection:**
```bash
# This is handled internally, but verify logs show no issues
```

## Uninstallation Testing

### 1. Remove Package

```bash
sudo dpkg -r nemo-crypt
```

**Expected output:**
```
(Reading database ... XX files and directories currently installed.)
Removing nemo-crypt (0.2.0-1) ...
```

### 2. Verify Clean Removal

```bash
# Check files removed
ls /usr/share/nemo-crypt/  # Should not exist
ls /usr/share/nemo/actions/ | grep gpg  # Should be empty
man gpg-encrypt  # Should show "No manual entry"

# Check package removed
dpkg -l | grep nemo-crypt  # Should show 'rc' (removed, config files remain) or nothing
```

### 3. Purge (Complete Removal)

```bash
sudo dpkg --purge nemo-crypt
```

## Test Results Checklist

- [ ] Package installs without errors
- [ ] All files installed to correct locations
- [ ] Scripts are executable
- [ ] Nemo actions appear in context menu
- [ ] Single file symmetric encryption works
- [ ] Single file decryption works
- [ ] Public key encryption works
- [ ] Multi-file encryption with packaging works
- [ ] Signature verification displays correctly
- [ ] Man pages are accessible and formatted
- [ ] Error handling works (missing dependencies, corrupted files)
- [ ] Package removes cleanly
- [ ] No leftover files after purge

## Known Acceptable Behaviors

1. **First encryption**: May take a second to start (GTK dialog loading)
2. **Signature verification**: Shows "Not signed" for symmetric encryption (normal)
3. **Multi-file**: Creates zip/tar.gz package first, then encrypts package
4. **Decryption**: Removes `.gpg`/`.pgp`/`.asc` extension automatically
5. **Lintian warning**: `initial-upload-closes-no-bugs` is normal for new packages

## Screenshot Checklist for README

Recommended screenshots to capture:

1. **Context menu**: Right-click showing "Encrypt..." option
2. **Encryption dialog**: GTK3 settings dialog with key selection
3. **Decryption notification**: Desktop notification with signature status
4. **Man page**: Terminal showing `man gpg-encrypt` output
5. **File listing**: Nemo showing before/after encryption

## Report Issues

If any tests fail, document:
- Test step that failed
- Expected behavior
- Actual behavior
- Error messages (check `dmesg` or `journalctl`)
- System info: `lsb_release -a`, `dpkg --print-architecture`
