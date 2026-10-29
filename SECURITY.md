# Security

Right Folder works inside other apps' Open and Save dialogs, which takes a powerful permission. So it's built to use as little of it as it can, to see only folder paths, and to never touch your files or what you type.

## Reporting a vulnerability

Please report security problems privately through **Security → Report a vulnerability** on this repository, not in a public issue. You'll get a reply within a few days.

## What Right Folder can access

| | |
|---|---|
| **Accessibility** | The one permission it asks for, which you turn on yourself in System Settings → Privacy & Security → Accessibility. It's used for three things only, listed below. Without it, Right Folder does nothing but show its menu and window. |
| **Folder paths** | The path of the folder each Finder window shows, your favorites and your recent folders. It checks whether a folder is there by looking at the folder's own entry, never at what's inside it. |
| **Its own settings** | Your favorites, recent folders and options, in its preferences file. Each favorite also keeps a bookmark, macOS's way of finding a folder again after it's renamed or moved. |

### What it uses Accessibility for

1. **Noticing an Open or Save dialog.** It asks macOS to tell it when a window or sheet opens, or focus moves, in the app in front, and only that app. Then it reads the role, subrole and identifier of that app's focused window and the sheets on it. AppKit names its dialogs `open-panel` and `save-panel`, and that's how they're recognized. It also reads the dialog's position and size, to put its panel beside it.
2. **Reading which folder each Finder window shows.** Each Finder window tells Accessibility the folder it's showing, the same one its title bar icon stands for. That's the only thing read from Finder.
3. **Sending the dialog to a folder you pick.** It presses ⇧⌘G in the dialog's app, which opens the dialog's Go to Folder field, puts the folder's path in that field, and presses Return. If the field won't take the path directly, the path is typed into it instead.

## What it can't access

- **The internet.** It has no networking code and no network entitlement. CI checks the source of every build for networking APIs, for opening URLs other than the one Settings page, and for starting other programs, and checks the built app links no networking or scripting framework and imports none of those calls. The one thing it ever opens is System Settings, at Privacy & Security → Accessibility, when you click Allow Accessibility.
- **What you type.** It has no event tap, keyboard monitor or Input Monitoring permission. The ⌃⌥J shortcut is registered with macOS only while a dialog is open, and macOS tells it only that the shortcut was pressed, never any other key. CI checks there's no way for it to listen to keys.
- **What's in your windows.** It never reads a window's title, a field's text, a selection or the screen. The one value it reads is the Go to Folder field's, right after setting it, to check the path went in. CI checks that only that one file reads or sets a value, and that titles, selected text and screen capture are never used.
- **Your files.** It never lists a folder, opens a file, or writes, moves or deletes anything. CI checks for each of those. Its settings go through `UserDefaults`.
- **Other apps' insides, beyond the above.** No Apple Events, so it can't script Finder or any other app, and it asks for no Automation, Full Disk Access, Screen Recording or Input Monitoring permission.

Check it yourself on any copy of the app:

```bash
codesign -d --entitlements - "/Applications/Right Folder.app"
```

It prints no entitlements at all.

## How it handles things

- **Keys go only to the dialog's app.** Every key event is posted to that one app's process, not to whatever happens to be in front. Before ⇧⌘G, before the path goes in and before Return, it checks the dialog is still open and its app still in front, and stops if not.
- **Return goes only to Go to Folder.** In a Save dialog, Return pressed anywhere but the Go to Folder field would save your file. So the field has to be found for certain: a text field, not a search field, that took the keyboard after ⇧⌘G, and that sits inside the dialog itself, which it checks by following the field's parents up to the dialog. If it can't tell what had the keyboard before ⇧⌘G, it doesn't start. If no such field appears within a second and a half, it gives up and says so, having sent nothing but ⇧⌘G. The same checks run again before the path goes in and before Return, and if the field says what it holds, it must hold the path.
- **The path is set, not typed,** when the field allows it, so no keystrokes are involved. When it does have to type, it types into that same field only after checking it still has the keyboard, and it types the path as text, a few whole characters at a time, which doesn't depend on your keyboard layout. ⇧⌘G itself is sent on the key that types G with ⌘ held on your layout.
- **Paths are checked first.** Only absolute paths are used, with `.` and `..` worked out, and anything holding a line break or other control character is dropped, since it could end the Go to Folder field early. Trash folders and the insides of apps and other packages are never offered.
- **Network volumes are never touched.** Checking a folder on a server that's stopped answering can hang, so a folder on a network volume, or in `/net` or `/Network`, is offered as long as it could be there, without looking. Each part of a local path is looked at without following links, and a link that leads onto a server is taken as there without looking past it. The list of mounted volumes comes from the kernel's table without asking any volume to answer. Bookmarks are only made and resolved for folders on local disks, and never mount anything.
- **A hung app can't hold it up for long.** Every Accessibility request has a 0.3-second limit, a look at an app stops at the first request that runs out of time, and an app that stopped answering is left alone for three seconds before it looks again. A busy moment isn't mistaken for the dialog closing.
- **Its own dialogs are left alone.** The folder picker for pinning favorites is Right Folder's own, and it never offers its panel there.
- **Saved settings are read as untrusted.** A favorite or recent folder that isn't a usable path is dropped when settings are loaded, and one damaged entry doesn't lose the rest.
- **Names are shown safely.** Folder and app names have control characters and invisible text-direction marks removed before they're shown.
- It has no dependencies. Every line that runs is in this repository.

## Why it isn't sandboxed

The App Sandbox is made for apps that keep to themselves. Right Folder's whole job is working another app's dialog through Accessibility, which the Mac App Store doesn't allow, and which the sandbox isn't designed around. So it runs outside it, like other Accessibility utilities, with no entitlements at all, the hardened runtime, and the checks above enforced by CI on every build. The command `codesign -d --entitlements -` above shows exactly what it's allowed.

## The signature

Releases are signed ad hoc, not with a paid Apple Developer ID. macOS ties the Accessibility permission you grant to that exact build, so no other program can borrow it by claiming to be Right Folder. The catch is that each update counts as a new app: after updating, go to System Settings → Privacy & Security → Accessibility, select Right Folder, click –, then open Right Folder and click Allow Accessibility… again. A Developer ID signature, which would keep the permission across updates, is planned.
