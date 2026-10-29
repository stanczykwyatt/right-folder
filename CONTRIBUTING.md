# Contributing

Thanks for helping out! Bug reports, ideas and pull requests are all welcome.

## Reporting a dialog it missed

If an app's Open or Save dialog doesn't get the panel, or a folder click doesn't move it, open a [bug report](https://github.com/stanczykwyatt/right-folder/issues/new?template=bug.yml) with the app's name and version, your macOS version, and whether the dialog was a sheet or its own window. Please don't paste the paths of your folders: describe them instead, like "a folder on a network share" or "a folder in iCloud Drive with an accent in its name".

The most helpful thing for a missed dialog is what Accessibility says about it. With the dialog open, Accessibility Inspector (it comes with Xcode, under Xcode → Open Developer Tool) shows the window's **Role**, **Subrole** and **Identifier**. Those three are all Right Folder looks at.

## Getting started

You need macOS 14 or later and Swift 6 (Xcode 16 or the Command Line Tools).

```bash
swift test                # run the tests
scripts/build-app.sh      # build "Right Folder.app" into ./build
open "build/Right Folder.app"
```

Telling dialogs from other windows, cleaning up and naming folder paths, the recent and favorite folders, what the panel lists and in what order, where it sits beside a dialog, the steps of a jump and all the wording live in `Sources/FolderCore`, with tests in `Tests/FolderCoreTests`. Those tests use window data shaped like what Accessibility reports, including the role, subrole and identifier read from real, never-shown Open and Save panels, made-up folders and volumes, and a made-up dialog that acts out every way a jump can go wrong. Changes to how dialogs are recognized belong in `Dialogs.swift`, with a test that describes the window.

The menu bar app, the panel, the menu and the window are in `Sources/RightFolder`, tested in `Tests/RightFolderTests` with made-up folders and dialogs, and windows that are never shown. `Navigator.swift` is the only file that sends keys or changes anything in another app. No test sends a key, opens a dialog, reads your Finder windows or puts anything on screen.

To redraw the art: `swift scripts/make-icon.swift`, `swift scripts/make-art.swift`, and `SCREENSHOT_DIR=docs swift test --filter Window` for the screenshots.

## Ground rules

- **No network access, ever.** Pull requests that add networking, analytics or update checks won't be merged.
- **Folder paths only.** Never list a folder, open a file, or read what's in a window beyond the role, subrole and identifier that say it's a dialog.
- **Never see what's typed.** No event taps, keyboard monitors or global shortcuts that stay registered when no dialog is open.
- **Keys go to the dialog's app alone,** and Return only to the Go to Folder field.
- **Least access.** No entitlements, and no new permissions without a very good reason.
- **No new dependencies** without a very good reason. The app has none today, which keeps it easy to audit.
- **Made-up folders only** in screenshots, art, tests and bug reports.
- Run `swift test` before opening a pull request, and add tests for changes to `FolderCore`.
- Keep commits small, with a short message saying what changed and why.

## Security issues

Please don't open public issues for vulnerabilities. See [SECURITY.md](SECURITY.md).
