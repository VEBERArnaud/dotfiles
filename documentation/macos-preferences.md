# macOS Preferences

Three scripts in `home/.chezmoiscripts/system/darwin/` configure macOS preferences automatically. They run on content change (`run_onchange_after_`) and require macOS (`{{ if .is_mac }}`).

## Scripts

| Script                                 | Purpose                                   |
| -------------------------------------- | ----------------------------------------- |
| `run_onchange_after_system_ui.sh.tmpl` | System-level UI, input, screen settings   |
| `run_onchange_after_apps.sh.tmpl`      | Finder, Dock, Safari, and app preferences |
| `run_onchange_after_restart.sh.tmpl`   | Restarts affected apps to apply changes   |

All scripts request `sudo` upfront and keep the sudo session alive during execution.

## System UI Settings (`system_ui`)

### General UI/UX

- Standby delay set to 24 hours
- Boot sound disabled
- Battery percentage shown in menu bar
- Bluetooth and Sound shown in menu bar
- Sidebar icon size: medium
- Scrollbars: automatic
- Focus ring animation disabled
- Window resize speed increased
- Save and print panels expanded by default
- Save to disk by default (not iCloud)
- Printer app auto-quits after print jobs
- "Are you sure you want to open this application?" dialog disabled
- Resume disabled system-wide
- Automatic app termination disabled
- Crash reporter dialog disabled
- Software updates checked daily
- Smart dashes disabled

### SSD Optimizations

- Time Machine local snapshots disabled
- Hibernation disabled (faster sleep)
- Sudden motion sensor disabled

### Input Devices

- Tap to click disabled on trackpad
- Right-click via two-finger tap enabled
- "Natural" scrolling disabled
- Bluetooth audio quality increased (bitpool 40)
- Full keyboard access for all controls
- Ctrl+scroll zoom enabled (follows keyboard focus)
- Press-and-hold disabled (key repeat instead)
- Key repeat rate: 2 (fast)
- Initial key repeat delay: 15 (short)
- Languages: English, French
- Locale: `en_US@currency=EUR`
- Metric units, timezone `Europe/Paris`
- Auto-correct disabled

### Screen

- Password required immediately after sleep/screensaver
- Screenshots: PNG format, saved to Desktop, no shadow, with date
- HiDPI display modes enabled

## Application Settings (`apps`)

### Finder

- Quit via Cmd+Q enabled (hides desktop icons)
- Animations disabled
- Default new window: Desktop
- Desktop icons: hard drives, servers, removable media
- Hidden files shown
- All file extensions shown
- Status bar and path bar shown
- Full POSIX path in window title
- Search scope: current folder
- Extension change warning disabled
- Spring loading enabled (no delay)
- No `.DS_Store` on network/USB volumes
- Disk image verification disabled
- Auto-open Finder on volume mount
- List view by default
- Folders sorted first
- Open folders in tabs
- Trash empty warning disabled
- AirDrop over Ethernet enabled
- `~/Library` and `/Volumes` shown

### Dock

- Icon size: 50px
- Minimize effect: scale
- Minimize into app icon
- All default app icons wiped
- Only open apps shown (static mode)
- Launch animation disabled
- Mission Control animation: 0.1s
- Windows not grouped by app in Mission Control
- Spaces not rearranged by recent use
- Auto-hide enabled (no delay, no animation)
- Hidden app icons translucent
- Launchpad gesture disabled
- Recent apps not shown

### Hot Corners

| Corner       | Action               |
| ------------ | -------------------- |
| Top left     | No action            |
| Top right    | No action            |
| Bottom left  | Put display to sleep |
| Bottom right | Start screen saver   |

### Safari

- Search queries not sent to Apple
- Tab highlights links on page
- Full URL in address bar
- Home page: `about:blank`
- Safe file auto-open disabled
- Backspace navigates back
- Bookmarks bar hidden
- Debug and Develop menus enabled
- Web Inspector enabled

### Window Manager (Sonoma+)

- Click wallpaper to show desktop disabled
- Tiled window margins disabled (Sequoia+)
- Stage Manager disabled
- Desktop icons shown

### Mail

- Send/reply animations disabled
- Email addresses copied without name
- Cmd+Enter sends email
- Threaded mode, sorted by date
- Inline attachments disabled
- Spell checking disabled

### Spotlight

- Enabled categories: Applications, System Preferences, Directories, PDFs, Fonts
- All other categories disabled (Documents, Messages, Contacts, etc.)
- Index rebuilt from scratch on apply

### Other Apps

- Terminal: UTF-8 only
- Time Machine: don't prompt for new backup volumes
- Activity Monitor: show all processes, sort by CPU, CPU icon in Dock
- TextEdit: plain text mode, UTF-8
- Address Book and Disk Utility: debug menus enabled
- Photos: no auto-open on device plug-in
- Messages: emoji substitution, smart quotes, and spell check disabled
- Google Chrome: trackpad/mouse backswipe disabled, native print dialog

### Login Items

- Lasso (window manager) added to login items if installed

## Restart Script

After preferences are applied, the restart script kills affected applications:

Activity Monitor, Address Book, Calendar, Contacts, cfprefsd, Dock, Finder, Google Chrome, Mail, Messages, Photos, Safari, SystemUIServer, Terminal, iCal.

Some changes require a full logout or restart to take effect.
