# Release Process

This document describes how to create a new release of nemo-crypt.

## Automated Releases (Recommended)

The project uses GitHub Actions to automatically build and publish releases when you push a version tag.

### Quick Release Steps

1. **Update version in all files:**
   ```bash
   # Update these files with the new version number:
   # - debian/changelog (add new entry at top)
   # - install.sh (VERSION variable)
   # - man/gpg-encrypt.1 (header)
   # - man/gpg-decrypt-verify.1 (header)
   # - CHANGELOG.md (add new section)
   # - README.md (installation examples)
   ```

2. **Commit changes:**
   ```bash
   git add .
   git commit -s -m "chore: bump version to 0.2.0"
   ```

3. **Create and push tag:**
   ```bash
   git tag -s v0.2.0 -m "Release version 0.2.0"
   git push origin main
   git push origin v0.2.0
   ```

4. **GitHub Actions automatically:**
   - Builds the .deb package
   - Runs lintian checks
   - Creates a GitHub Release
   - Attaches the .deb file and SHA256 checksum
   - Extracts release notes from CHANGELOG.md

5. **Verify the release:**
   - Go to https://github.com/john-crouch/nemo-crypt/releases
   - Check that v0.2.0 release is created
   - Download and test the .deb package

## Manual Release (Fallback)

If GitHub Actions fails or you need to build manually:

1. **Build the package:**
   ```bash
   dpkg-buildpackage -us -uc
   ```

2. **Test the package:**
   ```bash
   lintian ../nemo-crypt_0.2.0-1_all.deb
   sudo dpkg -i ../nemo-crypt_0.2.0-1_all.deb
   # Test functionality
   sudo dpkg -r nemo-crypt
   ```

3. **Create checksums:**
   ```bash
   cd ..
   sha256sum nemo-crypt_0.2.0-1_all.deb > nemo-crypt_0.2.0-1_all.deb.sha256
   ```

4. **Create GitHub Release manually:**
   ```bash
   gh release create v0.2.0 \
     --title "Release v0.2.0" \
     --notes-file <(awk '/## \[0.2.0\]/,/## \[/' CHANGELOG.md | head -n -1) \
     nemo-crypt_0.2.0-1_all.deb \
     nemo-crypt_0.2.0-1_all.deb.sha256
   ```

## Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 0.2.0)
  - **MAJOR**: Breaking changes (incompatible API changes)
  - **MINOR**: New features (backward compatible)
  - **PATCH**: Bug fixes only (backward compatible)

- **Debian revision**: -1, -2, etc.
  - Increment when changing packaging only (debian/* files)
  - Reset to -1 when upstream version changes

Examples:
- `0.2.0-1` → `0.3.0-1` (new features)
- `0.2.0-1` → `0.2.1-1` (bug fixes)
- `0.2.0-1` → `0.2.0-2` (packaging changes only)

## Pre-Release Checklist

Before creating a release:

- [ ] All tests pass: `./tests/run-tests.sh`
- [ ] Version numbers updated in all files
- [ ] CHANGELOG.md has entry for this version
- [ ] debian/changelog has entry for this version
- [ ] Man pages updated with new version and date
- [ ] README.md installation examples use new version
- [ ] No uncommitted changes: `git status`
- [ ] Working on main branch: `git branch`

## Post-Release Checklist

After release is published:

- [ ] Verify GitHub Release was created
- [ ] Download and test .deb from GitHub
- [ ] Verify checksum matches
- [ ] Update project documentation if needed
- [ ] Announce release (social media, mailing lists, etc.)
- [ ] Close related issues and milestones

## GitHub Actions Workflows

### `.github/workflows/release.yml`
Triggered by: Version tags (v*)
- Builds .deb package
- Runs lintian checks
- Creates GitHub Release
- Uploads artifacts

### `.github/workflows/test.yml`
Triggered by: Push to main, Pull Requests
- Runs test suite
- Shellcheck linting
- Test package build
- Uploads test artifacts

## Troubleshooting

### Release workflow fails with version mismatch
**Problem**: Git tag (v0.2.0) doesn't match debian/changelog (0.1.0)
**Solution**: Update debian/changelog to match the tag version

### Package not building
**Problem**: Missing build dependencies
**Solution**: GitHub Actions installs all dependencies automatically. For local builds:
```bash
sudo apt-get install debhelper dh-make devscripts lintian
```

### Lintian warnings
**Problem**: Package has warnings or errors
**Solution**: Review lintian output and fix issues before release. Some warnings may be acceptable.

### Can't push tags
**Problem**: Permission denied when pushing tags
**Solution**: Ensure you have write access to the repository and are authenticated with GitHub

## Emergency Rollback

If a release has critical issues:

1. **Delete the GitHub Release:**
   ```bash
   gh release delete v0.2.0 --yes
   ```

2. **Delete the tag:**
   ```bash
   git tag -d v0.2.0
   git push origin :refs/tags/v0.2.0
   ```

3. **Fix the issues and create a new patch release:**
   ```bash
   # Fix code, update to 0.2.1
   git tag -s v0.2.1 -m "Release version 0.2.1 (fixes v0.2.0)"
   git push origin v0.2.1
   ```
