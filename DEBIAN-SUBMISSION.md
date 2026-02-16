# Debian Package Submission Checklist

This document tracks the completion status of all requirements for submitting nemo-crypt to Debian.

## ✅ Completed Items

### Essential Files
- ✅ **LICENSE** - GPL-3.0 license reference
- ✅ **README.md** - Comprehensive documentation
- ✅ **CHANGELOG.md** - Version history in Keep a Changelog format
- ✅ **.gitignore** - Proper exclusions for Python, Debian, and editors

### Debian Packaging
- ✅ **debian/changelog** - Debian-format changelog
- ✅ **debian/control** - Package metadata and dependencies
- ✅ **debian/copyright** - GPL-3.0 copyright information
- ✅ **debian/rules** - Build and installation instructions
- ✅ **debian/compat** - Debhelper compatibility level 13
- ✅ **debian/source/format** - Source package format (3.0 native)

### Documentation
- ✅ **man/gpg-encrypt.1** - Man page for encryption script
- ✅ **man/gpg-decrypt-verify.1** - Man page for decryption script
- ✅ **README.md** sections:
  - Features list
  - Installation instructions
  - Usage examples
  - Dependencies
  - Troubleshooting
  - Security considerations

### Code Quality
- ✅ **License headers** - Added to all source files
- ✅ **Syntax validation** - All scripts pass syntax checks
- ✅ **Executable permissions** - Proper file permissions set
- ✅ **Shared library** - Common code extracted to gpg-common.sh

### Installation & Testing
- ✅ **install.sh** - Installation script with user/system modes
- ✅ **tests/run-tests.sh** - Comprehensive test suite
- ✅ **Uninstall support** - Clean removal capability

### Git Repository
- ✅ **Git initialized** - Repository created
- ✅ **Commits following best practices** - Conventional Commits format
- ✅ **Commit messages** - Clear, descriptive messages

## 📋 Pre-Submission Checklist

### Before Building Package

1. **Update metadata** - Replace placeholders:
   - [ ] Update "John Crouch" in all files
   - [ ] Update "github@ko4dfo.com" in all files
   - [ ] Update GitHub repository URLs
   - [ ] Update maintainer information in debian/control
   - [ ] Update copyright year if needed

2. **Version management**:
   - [x] Version set to 0.2.0
   - [x] Update version in install.sh if changed
   - [x] Update version in man pages if changed

3. **Final testing**:
   - [ ] Run test suite: `./tests/run-tests.sh`
   - [ ] Test installation: `sudo ./install.sh`
   - [ ] Test uninstallation: `sudo ./install.sh --uninstall`
   - [ ] Verify all functionality works

### Building the Debian Package

```bash
# Install build dependencies
sudo apt-get install debhelper dh-make

# Build the package
dpkg-buildpackage -us -uc

# Check the package
lintian ../nemo-crypt_0.2.0-1_all.deb

# Install and test
sudo dpkg -i ../nemo-crypt_0.2.0-1_all.deb
```

### Linting

```bash
# Check with lintian (Debian package validator)
lintian ../nemo-crypt_0.2.0-1_all.deb

# Check shell scripts (if shellcheck available)
shellcheck gpg-*.sh install.sh

# Check Python code (if flake8 available)
flake8 gpg-encrypt-dialog.py
```

### Submission Methods

**Option 1: Debian Mentors (Recommended for new maintainers)**
- Create account at https://mentors.debian.net
- Upload package and request sponsorship
- Work with Debian Developer for review

**Option 2: ITP (Intent To Package)**
- File ITP bug against wnpp (work-needing and prospective packages)
- Include package description and build info
- Wait for sponsor

**Option 3: Personal Repository**
- Host on Launchpad PPA (Ubuntu)
- Host on personal APT repository
- Distribute .deb files directly

## 📝 Additional Files to Consider

### Optional but Recommended
- [ ] **CONTRIBUTING.md** - Contribution guidelines
- [ ] **CODE_OF_CONDUCT.md** - Community standards
- [ ] **.github/ISSUE_TEMPLATE.md** - Issue template
- [ ] **.github/PULL_REQUEST_TEMPLATE.md** - PR template
- [ ] **Screenshots** - Add to README for visual reference
- [ ] **SECURITY.md** - Security policy and vulnerability reporting

### For Wider Distribution
- [ ] **AppStream metadata** - For software centers
- [ ] **Desktop file** - If creating GUI launcher
- [ ] **Icon files** - Application icons in various sizes

## 🔍 Final Review

### Code Review Points
- [x] All bash scripts use `set -euo pipefail`
- [x] All scripts have license headers
- [x] Error handling implemented throughout
- [x] Security considerations addressed (path traversal, cleanup traps)
- [x] Dependency checking before operations
- [x] User input validation

### Documentation Review
- [x] README is comprehensive
- [x] Man pages are complete
- [x] CHANGELOG follows standard format
- [x] Installation instructions are clear
- [x] Troubleshooting section included

### Packaging Review
- [x] debian/control has correct dependencies
- [x] debian/copyright is accurate
- [x] debian/rules installs files correctly
- [x] Package description is informative
- [x] Version numbers are consistent

## 🚀 Next Steps

1. **Replace all placeholders** with your actual information
2. **Test the package build**: `dpkg-buildpackage -us -uc`
3. **Run lintian** and fix any issues
4. **Test installation** on a clean system
5. **Create GitHub repository** and push code
6. **Submit to Debian Mentors** or file ITP

## 📚 Useful Resources

- **Debian Policy Manual**: https://www.debian.org/doc/debian-policy/
- **Debian New Maintainers' Guide**: https://www.debian.org/doc/manuals/maint-guide/
- **Debian Mentors**: https://mentors.debian.net/
- **Lintian Tags**: https://lintian.debian.org/tags.html
- **debhelper Manual**: https://manpages.debian.org/debhelper

## 📊 Package Statistics

- **Total Lines of Code**: ~500 (bash/python)
- **Number of Files**: 19
- **Dependencies**: 7 runtime packages
- **Man Pages**: 2
- **License**: GPL-3.0+
- **Size**: ~50KB (source)

---

**Status**: ✅ Ready for package build and testing
**Last Updated**: 2026-02-14
