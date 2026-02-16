# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/0.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-15

### Added
- Anonymous recipient encryption option (--throw-keyids) via checkbox in encryption dialog
- Automatic detection of anonymous recipient encryption during decryption
- Interactive key selection dialog for anonymous encrypted files
- Shared GPG key listing functions in gpg-common.sh (list_secret_keys, list_public_keys)
- Comprehensive debug logging system with NEMO_CRYPT_DEBUG environment variable
- Debug log file at ~/.cache/nemo-crypt/debug.log
- Logging functions: log_debug(), log_info(), log_error()

### Changed
- Anonymous recipient checkbox automatically disabled when symmetric mode is selected
- Improved error messages for decryption failures with specific context
- Enhanced validation of dialog output (MODE and ANONYMOUS values)

### Fixed
- Word splitting vulnerability in key selection parsing (now uses associative arrays)
- Unsafe grep pattern matching on key IDs (replaced with exact mapping)
- Missing error handling for gpg --list-packets failures
- Shell scripting anti-patterns in key parsing logic

### Security
- Fixed shell scripting vulnerabilities in GPG key ID parsing
- Added validation to prevent malformed dialog output
- Improved robustness of key selection with exact ID matching

## [0.1.0] - 2026-02-14

### Added
- Initial beta release of nemo-crypt
- GPG encryption integration for Nemo file manager
- Right-click context menu actions for encryption and decryption
- Symmetric (passphrase) encryption mode
- Asymmetric (public key) encryption mode with recipient selection
- Digital signature support during encryption
- Signature verification during decryption with detailed status reporting
- Multi-file encryption support
- Archive packaging options (.zip, .tar.gz, .tar.bz2) for multi-file encryption
- GTK3 encryption settings dialog matching nemo-seahorse style
- Interactive key selection with search and filter functionality
- Desktop notifications for operation status and signature verification
- Comprehensive error handling and validation
- Dependency checking before operations
- Cleanup traps to remove partial files on interruption
- Path traversal protection for package names
- Empty package name validation
- Multi-file overwrite confirmation
- Dialog output format validation
- Duplicate key filtering in recipient list
- Shared utility library (gpg-common.sh)
- Man pages for gpg-encrypt and gpg-decrypt-verify
- Installation script with user and system-wide options
- Uninstallation support
- Comprehensive test suite
- Debian packaging support
- README with usage examples and troubleshooting
- GPL-3.0 license

### Security
- Path traversal attack prevention in package naming
- Cleanup traps prevent exposure of partial decrypted files
- Input sanitization for package names
- Validation of all user inputs
- Secure temporary file handling

## [Unreleased]

### Planned
- ASCII armor output option (--armor flag)
- Progress indication for large file operations
- Debug/verbose mode
- Configuration file support
- Batch mode for scripting
- Additional archive formats
- File type detection warnings

---

## Release Notes

### Version 0.1.0

This is the initial beta release of nemo-crypt, providing seamless GPG encryption and decryption directly from the Nemo file manager.

**Key Features:**
- Easy-to-use right-click context menu integration
- Support for both symmetric and public key encryption
- Digital signature creation and verification
- Multi-file handling with flexible packaging
- Native GTK3 interface
- Robust error handling and security features

**Requirements:**
- Nemo file manager
- GnuPG 2.0 or later
- Python 3.6+ with GTK bindings
- Zenity and libnotify-bin

**Installation:**
```bash
sudo ./install.sh          # System-wide
./install.sh --user        # User-specific
```

**Debian Package:**
```bash
dpkg-buildpackage -us -uc
sudo dpkg -i ../nemo-crypt_0.2.0-1_all.deb
```

For detailed usage instructions, see the README.md file.
