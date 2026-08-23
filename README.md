<div align="center">

# 🔑 Key Recorder

**A private macOS timer for measuring two keyboard-controlled events**

[![macOS 15.1+](https://img.shields.io/badge/macOS-15.1%2B-111827?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 5](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Latest release](https://img.shields.io/github/v/release/romainfrezier/key-recorder?display_name=tag&sort=semver)](https://github.com/romainfrezier/key-recorder/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-16a34a.svg)](LICENSE)

[Website](https://key-recorder.com) · [Download](https://github.com/romainfrezier/key-recorder/releases/latest) · [User guide](docs/user-guide.md) · [Contributing](CONTRIBUTING.md)

<p align="center" style="margin: 20px 0;">
  <img src="docs/screenshot.png" alt="Key Recorder recording window" width="760">
</p>

<p>
  <a href="https://buymeacoffee.com/romainfrezier">
    <img src="docs/bmc-button.png" alt="Buy Me a Coffee" width="100">
  </a>
</p>

</div>

---

## What Key Recorder does

Key Recorder is a native, open-source macOS app for short, controlled
observations. Assign a meaning to two physical keys, hold one while an event
is happening, and get a clean CSV showing the duration accumulated by each key
over time intervals.

It is useful for:

- animal-behaviour and laboratory observations;
- UX or accessibility studies;
- productivity and workflow experiments;
- any protocol where an operator needs two simple event markers.

Key Recorder does **not** record what you type, identify people, or send data
over the network. It listens only while the app is open and a recording is in
progress, then keeps the result on your Mac.

> **Use responsibly.** Keyboard monitoring requires explicit macOS permission.
> Use this app only with the knowledge and consent required by your protocol,
> workplace, institution, and applicable privacy rules.

## Highlights

- **Two configurable event keys** with custom names and physical-key detection.
- **Duration-based measurements** split into configurable intervals.
- **Live recording status** with start, stop, and early-stop support.
- **Portable CSV exports** with stable headers, interval labels, decimal values, and
  a `TOTAL` row.
- **Local session archive** backed by SQLite, with search, metadata, preview,
  import, and unlimited re-export.
- **Three languages**: English, French, and Italian.
- **Native macOS experience** with Preferences, Light/Dark/Automatic appearance,
  and keyboard shortcuts.
- **Privacy-first architecture**: no analytics, no cloud account, and no
  network service.

## Install

### Download the app

Download the latest DMG from the
[GitHub Releases](https://github.com/romainfrezier/key-recorder/releases/latest)
page, open it, and drag **Key Recorder** to **Applications**.

The public DMG is ad hoc signed and is not notarized by Apple. macOS may show
a Gatekeeper warning the first time you open it. Only open a release downloaded
from the official repository, or build the app yourself from source.

### Build from source

Requirements:

- macOS 15.1 or later;
- Xcode 16.2 or later;
- a Mac capable of running the Xcode build tools.

```bash
git clone https://github.com/romainfrezier/key-recorder.git
cd key-recorder
open key-recorder.xcodeproj
```

Run the app with **⌘R**. Run the test suite with **⌘U**.

For a reproducible local DMG after building an archive:

```bash
./scripts/package-dmg.sh 1.1.3 \
  "/path/to/Key Recorder.app" \
  "/path/to/output/Key-Recorder-1.1.3.dmg"
```

## First recording

1. Open **Key Recorder → Preferences…** with **⌘,** if you want to change the
   language, appearance, or recording defaults.
2. Choose two keys and give them meaningful names, such as `Food dispenser`
   and `Lever`.
3. Use **Detect…** when the physical key is not obvious, especially with a
   non-US keyboard layout.
4. Set the total duration and the analysis interval in seconds.
5. Choose the destination for an external CSV copy in the main window.
6. Click **Start Recording** or press **⌘R**.
7. Hold the configured key while its event is happening, then release it.
8. Wait for the countdown to finish, or press **⌘.** to stop early.

The app exports the CSV when the session ends. An early stop creates a valid
partial export with a `-partial` filename suffix.

### Permissions

Key Recorder uses a passive macOS event tap to receive global key-down and
key-up events. **Input Monitoring** is the permission required for recording.
Enable it under **System Settings → Privacy & Security → Input Monitoring**.

The app may also display an Accessibility status because macOS exposes both
capabilities for keyboard-related tools. Key Recorder only listens to events;
it does not post, modify, or automate keyboard input, so Accessibility is not
required for passive recording in the current release.

If the status does not update after changing a permission, quit and reopen the
app. See the [researcher user guide](docs/user-guide.md) for a complete setup
and troubleshooting walkthrough.

## CSV format

Values are **durations in seconds**, not counts of key presses. The interval is
an analysis window: it is not a sampling delay.

```csv
interval,Food dispenser,Lever
0s - 30s,12.450,4.200
30s - 60s,8.100,10.000

TOTAL,20.550,14.200
```

Each row contains the time spent holding each configured key during that
interval. `TOTAL` sums the durations across the complete observation. The
result can be opened in spreadsheet software or processed with R, Python, or
another analysis tool.

## Sessions and local storage

Every completed, partial, or imported session is kept in the local **Sessions** archive.
From the sidebar you can:

- search by title, experiment ID, subject, operator, protocol, tag, or note;
- preview the CSV without opening a spreadsheet;
- edit experiment metadata without changing measured durations;
- import an older compatible CSV;
- export another copy or reveal the archived file in Finder.

The internal archive is stored at:

```text
~/Library/Application Support/Key Recorder/
├── Sessions.sqlite3
└── CSV/
```

The CSV in this folder is the protected internal copy. Files exported to the
Desktop, Downloads, or a shared laboratory folder are separate copies.
Removing a session from the list does not delete its archived CSV.

## Project layout

```text
key-recorder/
├── key-recorder/
│   ├── App/       # App lifecycle and menu commands
│   ├── Core/      # Recording, permissions, CSV, archive, and models
│   └── UI/        # SwiftUI views and application state
├── key-recorderTests/
├── docs/
├── scripts/
└── website/       # Multilingual static marketing site
```

The app uses native macOS frameworks, SwiftUI, Core Graphics event taps, and
SQLite. Recording events are handled away from the main UI thread and the app
does not include a network client or telemetry service.

## Development

Open `key-recorder.xcodeproj` in Xcode, then use:

- **⌘R** to build and run;
- **⌘U** to run unit tests;
- the **Recording** menu to exercise start, stop, CSV location, and last-export
  commands.

The project website lives in [`website/`](website/README.md) and contains the
English, French, and Italian product pages with pre-rendered SEO metadata.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
Recent changes are documented in [CHANGELOG.md](CHANGELOG.md).

## Privacy and security

- No analytics or telemetry.
- No cloud account and no network upload.
- No general keyboard log: only the two selected key codes are used during a
  recording.
- Transparent permission handling before monitoring begins.
- Local archive files remain under the user's macOS Application Support folder.

Because the archive is local, apply your own institution's backup, retention,
and access-control policy to the Mac and any exported copies.

## Support

- [Researcher user guide](docs/user-guide.md)
- [GitHub Issues](https://github.com/romainfrezier/key-recorder/issues)
- [GitHub Discussions](https://github.com/romainfrezier/key-recorder/discussions)
- [Buy Me a Coffee](https://buymeacoffee.com/romainfrezier)

## License

Key Recorder is released under the [MIT License](LICENSE).

<div align="center">

**[🌟 Star the repository](https://github.com/romainfrezier/key-recorder)** if
you find it useful.

Made with ❤️ for careful, local-first observations.

</div>
