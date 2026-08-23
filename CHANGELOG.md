# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.3] - 2026-08-23

### Fixed
- Use a session-level passive event tap for global keyboard observation
- Base the permission check on the exact event tap used by recording

## [1.1.2] - 2026-08-23

### Fixed
- Use Apple's native HID permission request flow for Input Monitoring
- Allow passive keyboard recording without requiring Accessibility permission
- Update the in-app permissions help text to match the actual macOS requirement

## [1.1.1] - 2026-08-23

### Fixed
- Use macOS's native Input Monitoring permission check so recording starts after permissions are granted
- Refresh permission status when returning from System Settings
- Localize permission and recording error messages in French and Italian

## [1.1.0] - 2026-08-22

### Added
- Native macOS Preferences with General, Recording, and About sections
- Automatic, Light, and Dark appearance modes
- Native Recording menu commands and `⌘R`, `⌘.`, and `⌘,` shortcuts
- Key detection from the physical keyboard
- Partial CSV export when stopping a recording early
- Reproducible macOS DMG packaging
- Searchable local session catalogue backed by SQLite
- Internal CSV archive with unlimited re-export
- CSV import and in-app interval preview
- Editable experiment metadata without changing measured durations

### Fixed
- Serialized recording events with the main-actor session state
- CSV headers with quotes and locale-dependent decimal formatting
- Permission prompting after the application state is ready

## [1.0.0] - 2026-08-12

### Added
- Core keyboard monitoring functionality
- Configurable key tracking (supports alphanumeric keys)
- Custom interval and duration settings
- Live recording statistics
- CSV export with timestamps
- macOS 15.1+ support
- Privacy-focused design (100% local processing)
- Permission handling for Accessibility and Input Monitoring

### Security
- No network connectivity
- All data stored locally
- Transparent permission system
- Thread-safe event processing

[Unreleased]: https://github.com/romainfrezier/key-recorder/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/romainfrezier/key-recorder/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/romainfrezier/key-recorder/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/romainfrezier/key-recorder/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/romainfrezier/key-recorder/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/romainfrezier/key-recorder/releases/tag/v1.0.0
