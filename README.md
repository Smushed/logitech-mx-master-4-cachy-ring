# Logitech MX Master 4 Cachy Ring

A small KDE Plasma 6 / KWin extension for the Logitech MX Master 4 and Solaar,
shown in KDE settings as **MX App Ring**. Built and tested on CachyOS with
KDE Plasma 6.7 / Wayland.
Press the haptic thumb button, then click a wedge. Existing windows are restored
and focused, including windows on another desktop or activity. If there is no
matching window, KDE opens the application using its desktop entry.

The six defaults are Chrome, Dolphin (Files), Ghostty (Terminal), Code - OSS
(VS Code), Discord, and Steam. Edit the defaults to match your installed apps.
If several windows match, the topmost matching window is selected. A program
running only in the system tray is reopened through its launcher.

## Install

```sh
git clone https://github.com/Smushed/logitech-mx-master-4-cachy-ring.git
cd logitech-mx-master-4-cachy-ring
python install.py
```

Requires KDE Plasma 6, Solaar, Python, PyYAML, and KDE's `kpackagetool6`,
`kwriteconfig6`, and `qdbus6` commands. These were already installed on the tested
CachyOS machine. No background daemon is added. Run the installer as your normal
desktop user, without `sudo`. The installer enables **MX App Ring** in
System Settings → Window Management → KWin Scripts. It replaces the existing
Haptic → Alt+Tab rule, keeping a backup at
`~/.config/solaar/rules.yaml.before-mx-ring`. Other rules are preserved.
Restart Solaar after installing if it was running; otherwise login normally.
Set Solaar's **Key/Button Diversion → Haptic** to **Diverted** and keep Solaar running.
If another custom Haptic rule exists, the installer asks you to review it first.

## Controls

- Haptic thumb button or **Meta+Alt+Space**: open/close at the pointer.
- Click a wedge, or press **1–6**: switch to or open the app.
- Arrow keys / Tab, then Enter: select and activate.
- Escape, right-click, center click, or outside click: dismiss.
- **Open** below an icon means a matching window exists.

## Change the apps

Edit `contents/ui/apps.js`, then run `python install.py` again. Each entry has a
label, a `.desktop` file ID (from `/usr/share/applications` or
`~/.local/share/applications`), and exact window-class aliases. Keep 2–8 entries
for a readable wheel. Place entries clockwise, starting at the top.

KWin's desktop-file identity is used first, so a Chrome web app is not mistaken
for a regular browser window. For an unusual app, use KWin's Debug Console to
inspect `desktopFileName` and `resourceClass`, then add the identity to `classes`.

Solaar calls the extension directly, without simulated keys:

```yaml
- Key: [Haptic, pressed]
- Execute: [/usr/bin/qdbus6, org.kde.kglobalaccel, /component/kwin, invokeShortcut, MXRingToggle]
```

This recreates the app wheel; it does not program haptic vibration patterns.

## Check / remove

The logic checks require Node.js (not needed to run the extension):

```sh
node test_logic.cjs
```

To remove, disable **MX App Ring** in KWin Scripts, uninstall it with
`kpackagetool6 --type KWin/Script --remove mx-ring`, restore the original haptic
rule from the backup, and restart Solaar. If you added rules after installation,
restore just the old haptic rule instead of replacing the whole file.

Built on [KWin scripting](https://develop.kde.org/docs/plasma/kwin/) and
[Solaar Execute rules](https://pwr-solaar.github.io/Solaar/rules/).
KDE's application-menu model performs native `.desktop` launches.
