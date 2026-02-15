# nemo-crypt

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Release](https://img.shields.io/github/v/release/john-crouch/nemo-crypt)](https://github.com/john-crouch/nemo-crypt/releases)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)
[![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python-3.6+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![GPG](https://img.shields.io/badge/Encryption-GPG-0093DD?logo=gnu-privacy-guard&logoColor=white)](https://gnupg.org/)

GPG encryption and decryption integration for the Nemo file manager, providing seamless right-click context menu actions for encrypting and decrypting files with OpenPGP.

## Features

- **Right-click encryption** - Encrypt files directly from Nemo's context menu
- **Flexible encryption modes** - Symmetric (passphrase) or asymmetric (public key recipients)
- **Digital signatures** - Optional signing with your secret key
- **Multi-file support** - Encrypt multiple files separately or packaged together
- **Archive formats** - Package files as .zip, .tar.gz, or .tar.bz2 before encryption
- **Signature verification** - Automatic verification and display of digital signatures on decryption
- **GTK3 interface** - Native-looking encryption settings dialog matching nemo-seahorse
- **Comprehensive error handling** - Clear error messages and validation
- **Security features** - Path traversal protection, cleanup traps, dependency validation

## Screenshots

*(Add screenshots here showing the context menu and encryption dialog)*

## Requirements

### Runtime Dependencies

- `gnupg` (>= 2.0) - GNU Privacy Guard
- `python3` (>= 3.6)
- `python3-gi` - Python GObject introspection bindings
- `gir1.2-gtk-3.0` - GTK 3 introspection data
- `zenity` - Display GTK dialogs from shell scripts
- `libnotify-bin` - Desktop notifications (notify-send)
- `nemo` - Nemo file manager

### Optional Dependencies

- `zip` - For creating .zip archives
- `tar` - For creating .tar.gz and .tar.bz2 archives (usually pre-installed)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/ko4dfo/nemo-crypt.git
cd nemo-crypt

# Run the installation script
sudo ./install.sh

# Or install to user directory
./install.sh --user
```

### Manual Installation

```bash
# Copy scripts to installation directory
sudo mkdir -p /usr/local/share/nemo-crypt
sudo cp gpg-*.sh gpg-*.py gpg-common.sh /usr/local/share/nemo-crypt/
sudo chmod +x /usr/local/share/nemo-crypt/*.{sh,py}

# Install Nemo actions
mkdir -p ~/.local/share/nemo/actions
sed "s|<gpg-encrypt.sh>|/usr/local/share/nemo-crypt/gpg-encrypt.sh|g" \
    gpg-encrypt.nemo_action > ~/.local/share/nemo/actions/gpg-encrypt.nemo_action
sed "s|<gpg-decrypt-verify.sh>|/usr/local/share/nemo-crypt/gpg-decrypt-verify.sh|g" \
    decrypt-gpg.nemo_action > ~/.local/share/nemo/actions/decrypt-gpg.nemo_action

# Restart Nemo
nemo -q
```

### Debian/Ubuntu Package

```bash
# Install from .deb package
sudo dpkg -i nemo-crypt_0.1.0_all.deb
sudo apt-get install -f  # Install dependencies if needed
```

## Usage

### Encrypting Files

1. Right-click on one or more files in Nemo
2. Select **"Encrypt..."** from the context menu
3. If encrypting multiple files, choose to encrypt separately or package together
4. Select encryption settings:
   - **Use passphrase only** - Symmetric encryption (no GPG keys required)
   - **Choose recipients** - Asymmetric encryption using public keys
   - Optionally sign with your secret key
5. Choose output location
6. Enter passphrase or wait for encryption to complete

### Decrypting Files

1. Right-click on an encrypted file (.gpg, .pgp, or .asc)
2. Select **"Decrypt File"** from the context menu
3. Enter passphrase when prompted
4. View signature verification results in the notification

### Multi-file Packaging

When encrypting multiple files, you can:

- **Encrypt separately** - Creates individual .pgp files for each file
- **Package together** - Combines files into a single archive before encryption
  - Choose package name
  - Select format: .zip, .tar.gz, or .tar.bz2

## Configuration

### GPG Key Setup

```bash
# Generate a new GPG key pair (if you don't have one)
gpg --full-generate-key

# List your keys
gpg --list-keys

# Import someone's public key
gpg --import their-public-key.asc

# Export your public key to share
gpg --armor --export your@email.com > my-public-key.asc
```

## Architecture

nemo-crypt consists of three main components:

1. **gpg-encrypt.sh** - Bash script orchestrating the encryption workflow
2. **gpg-decrypt-verify.sh** - Bash script handling decryption and signature verification
3. **gpg-encrypt-dialog.py** - GTK3 Python dialog for encryption settings
4. **gpg-common.sh** - Shared utilities library

### Workflow

**Encryption:**
```
User selects files → Nemo Action → gpg-encrypt.sh
  ↓ (if multiple files)
Packaging dialog → create archive
  ↓
gpg-encrypt-dialog.py → select recipients/mode/signer
  ↓
Output location dialog
  ↓
gpg --encrypt/--symmetric → .pgp file(s)
  ↓
Desktop notification
```

**Decryption:**
```
User selects .gpg file → Nemo Action → gpg-decrypt-verify.sh
  ↓
gpg --decrypt --status-file
  ↓
Parse signature verification status
  ↓
Desktop notification with signature details
```

## Troubleshooting

### No keys appear in the encryption dialog

- Verify GPG keys exist: `gpg --list-keys`
- Generate a key if needed: `gpg --full-generate-key`
- Check GPG installation: `which gpg`

### "Missing Dependencies" error

Install required packages:
```bash
# Debian/Ubuntu
sudo apt-get install gnupg zenity python3-gi gir1.2-gtk-3.0 libnotify-bin

# Fedora
sudo dnf install gnupg2 zenity python3-gobject gtk3 libnotify
```

### Encryption fails silently

Enable debug mode:
```bash
GPG_CRYPT_DEBUG=1 /path/to/gpg-encrypt.sh yourfile.txt
```

### Context menu doesn't appear

- Restart Nemo: `nemo -q`
- Check action files exist: `ls ~/.local/share/nemo/actions/`
- Verify scripts are executable: `ls -l /usr/local/share/nemo-crypt/`

## Security Considerations

- **Passphrase strength** - Use strong, unique passphrases for symmetric encryption
- **Key verification** - Always verify recipient public keys before encrypting
- **Signature verification** - Pay attention to signature verification results when decrypting
- **Temporary files** - Encrypted archives are automatically cleaned up on success or cancellation
- **Partial files** - Cleanup traps ensure partial decrypted files are removed on interruption

## Development

### Running Tests

```bash
./tests/run-tests.sh
```

### Code Quality

```bash
# Shell scripts
shellcheck gpg-*.sh

# Python
flake8 gpg-encrypt-dialog.py
pylint gpg-encrypt-dialog.py
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and linting
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by nemo-seahorse's GPG integration
- Uses GnuPG for encryption operations
- Built for the Nemo file manager (Linux Mint)

## Authors

- John Crouch <github@ko4dfo.com>

## Links

- **Homepage**: https://github.com/ko4dfo/nemo-crypt
- **Bug Reports**: https://github.com/ko4dfo/nemo-crypt/issues
- **GPG Documentation**: https://gnupg.org/documentation/
- **Nemo Actions**: https://github.com/linuxmint/nemo/blob/master/files/usr/share/nemo/actions/README
