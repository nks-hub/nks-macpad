# MacPad

[![Platform](https://img.shields.io/badge/platform-macOS%2014+-111827.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-AppKit-F05138.svg?logo=swift&logoColor=white)](https://developer.apple.com/documentation/appkit)
[![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)](#installation)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> Native tabbed text editor for macOS with draft recovery, pinned notes and Windows 11 Notepad-style controls. Swift + AppKit, no external dependencies.

![MacPad in light mode with a pinned note and three tabs](docs/screenshots/macpad-light.png)

<details>
<summary>Dark mode</summary>

![MacPad in dark mode](docs/screenshots/macpad-dark.png)

</details>

---

## Features

- 🗂️ **Tabbed notes** - New tabs, pinning, custom draft names, moving tabs between windows, reopening closed files
- 📄 **Plain text files** - Open, Save, Save As, Save All; UTF-8, UTF-16 and Windows-1250 with encoding, BOM and line endings preserved
- 💾 **Draft recovery** - Restores drafts, tab order, selection and scroll position after relaunch; recovery copies never touch the original file
- 🔍 **Search** - Find and replace in the current document, search across all open tabs and jump straight to a match
- ⌨️ **Fast navigation** - Tab switcher, command palette, macOS shortcuts and selected Windows-style Ctrl shortcuts
- ✂️ **Line operations** - Insert date/time, duplicate, move, sort and remove exact duplicates; all undoable
- 🎨 **Workspace** - Light, dark and system appearance, font, zoom, word wrap, line numbers, focus mode and always-on-top
- ⚡ **Quick note** - Compact window, optional menu bar item and configurable global shortcut
- 🌐 **Localization** - English and Czech UI

Markdown preview, split view, saved-version history and diff are planned for 1.1 and are not part of the app yet.

## Requirements

- macOS 14 or later (verified on macOS 15.7.4)
- Apple Silicon (verified); Intel not verified yet
- Xcode 26.3 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44.1 for building
- No runtime dependencies beyond AppKit, Foundation, CryptoKit and Carbon

## Installation

MacPad is in development (0.1.0). A signed and notarized release is not published yet, so build it from source:

```sh
git clone https://github.com/nks-hub/nks-macpad.git
cd nks-macpad
bash scripts/build.sh build
open build/DerivedData/Build/Products/Debug/MacPad.app
```

XcodeGen must be in `PATH`, or set `XCODEGEN` to its executable. The script generates the project from `project.yml`; the generated `MacPad.xcodeproj` and build output are not tracked in Git.

Bundle identifiers: `com.nkshub.macpad` (app) and `com.nkshub.macpad.core` (shared framework).

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New tab / new window | ⌘N or ⌘T / ⇧⌘N |
| Open / Save / Save As | ⌘O / ⌘S / ⇧⌘S |
| Save All | ⌥⌘S |
| Close tab / window | ⌘W / ⇧⌘W |
| Find / Replace | ⌘F / ⌥⌘F |
| Find in all tabs | ⇧⌘F |
| Tab switcher / command palette | ⌘K / ⇧⌘P |
| Reopen closed file | ⇧⌘T |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Print | ⌘P |

Ctrl aliases work inside the editor and do not override the system keyboard. The quick note global shortcut is off until you set it.

## Saving and Privacy

- Files on disk change only after an explicit save. If another program modifies an open file, MacPad reports the conflict; a change during the atomic replace is kept in a separate copy and its path is shown.
- Drafts live in `~/Library/Application Support/MacPad`. They are not encrypted. Recovery can be turned off in Settings; discarding a draft removes it from both recovery copies.
- No account, no cloud sync, no telemetry. Saving into a synced folder works, but concurrent edits can still conflict.

## Testing

```sh
bash scripts/build.sh test
CONFIGURATION=Release bash scripts/build.sh test
```

76 automated tests pass on macOS 15.7.4 in Release: 37 for the file layer and recovery, 39 for AppKit, lifecycle and performance. On an Apple M1 Pro, opening a 50 MiB file with short ASCII lines takes 643 ms (median) and inserting a character at the end 9 ms. Details are in [docs/VALIDATION.md](docs/VALIDATION.md).

Set `MACPAD_SESSION_DIR` to a separate folder for isolated test runs. Do not use real personal notes as test data.

## Contributing

Contributions are welcome! For major changes, please open an issue first.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: description'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

When reporting a bug, include the macOS version, architecture, app revision and steps to reproduce. Use made-up text in examples.

## Support

- 📧 **Email:** dev@nks-hub.cz
- 🐛 **Bug reports:** [GitHub Issues](https://github.com/nks-hub/nks-macpad/issues)

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/nks-hub">NKS Hub</a>
</p>
