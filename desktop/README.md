# Regolith 3 copycat desktop for Ubuntu 26.04

A [sway](https://swaywm.org/) desktop that reproduces the look and keybindings
of [Regolith Desktop 3](https://regolith-desktop.com/) (its default
"lascaille" look) using nothing but packages from the standard Ubuntu 26.04
archive. No PPA, no third-party repository, nothing built from source.

Everything lives in the home directory. No system file is changed and no custom
session file is needed: the stock `/usr/share/wayland-sessions/sway.desktop`
from the `sway` package is what you pick at the GDM login screen.

## Why

At the time of the author's fresh Ubuntu 26.04 installation (August 2026),
Regolith did not support 26.04: its package repository had no release for it,
so Regolith could not be installed at all. Rather than wait, or pin an older
Ubuntu release to keep it, the desktop was rebuilt from what the 26.04 archive
already provides. Sway itself, the terminal, launcher, bar, notification
centre, lock screen and display tools are all stock Ubuntu packages; only the
configuration and a few small helper scripts are custom.

This has two consequences worth being clear about. It is an approximation, not
Regolith: the components Regolith writes itself (ilia, i3status-rs,
rofication, avizo, gtklock, remontoire and friends) are replaced by archive
packages that do the same job, listed under
[What was substituted](#what-was-substituted). And it stays working across
Ubuntu upgrades on its own, because there is no external repository that has
to catch up first.

## Quick start

```bash
git clone https://github.com/silvestrst/sway-regolith3-copycat.git
cd sway-regolith3-copycat
./desktop/install.sh
```

Then log out, click the gear icon on the GDM login screen, pick **Sway** and
log in. `Super+Shift+?` shows every keybinding.

The script installs the packages in [`packages.txt`](packages.txt) with
`apt-get` (the only step that uses `sudo`), copies the configuration files into
place, and runs a few checks that need no running sway session (`sway -C`,
`foot --check-config`, syntax checks on the scripts, and a check that every
command the config calls is installed).

| Flag | Effect |
|---|---|
| `--dry-run` | Print what would happen. Nothing is changed and `sudo` is not called. |
| `--skip-packages` | Do not run `apt-get`; only install the configuration files. |
| `--overwrite` | Replace destinations that already exist and differ (see below). |
| `--help` | Usage. |

### Existing configuration

Before it installs anything, the script compares every destination with the
repo copy and prints one line per path: `new`, `unchanged` or `conflict`. If
any path is a `conflict` (it exists and differs), the script stops right there
with the list, before `apt-get` has run and before any file has been copied.

You can then either move those paths aside yourself and re-run, or re-run with
`--overwrite`. With `--overwrite` each conflicting path is moved to
`<path>.bak.<timestamp>` and the repo copy is installed in its place. Nothing
is ever deleted. Paths that are already identical are skipped, so re-running
the script on a machine that is up to date changes nothing.

## What gets installed

The packages, grouped as in `packages.txt`:

| Group | Packages |
|---|---|
| Compositor and session | sway, swaybg, swayidle, swaylock, xwayland |
| Terminal, launcher, status bar | foot, rofi, i3blocks |
| Notifications and OSD | sway-notification-center, swayosd |
| Screenshots and clipboard | grim, slurp, swappy, wl-clipboard |
| Displays | kanshi, nwg-displays |
| Portals | xdg-desktop-portal, xdg-desktop-portal-wlr, xdg-desktop-portal-gtk |
| Audio and media | wireplumber, pulseaudio-utils, pavucontrol, playerctl, brightnessctl |
| Network and Bluetooth | network-manager, network-manager-applet, nm-connection-editor, blueman |
| Authentication and secrets | mate-polkit, gnome-keyring |
| Theme, icons, fonts | gnome-themes-extra, papirus-icon-theme, fonts-font-awesome, ttf-bitstream-vera |
| Tools the config calls | jq, libnotify-bin, libglib2.0-bin, dbus-bin, python3, python3-i3ipc, xdg-user-dirs, xdg-utils, libgtk-3-bin, im-config, gnome-control-center, nautilus, lm-sensors |

`gnome-calendar` is listed but commented out; the clock in the bar opens it on
click and does nothing if it is missing.

## Layout

| Repo path | Installed to | Purpose |
|---|---|---|
| `install.sh` | – | The installer. |
| `packages.txt` | – | The apt package list, one per line. |
| `config/sway/` | `~/.config/sway/` | The sway config. `config` only includes `config.d/*`; each fragment covers one concern (variables and colours, outputs, input, launchers, navigation, gaps, style, session keys, bar, screenshots, ...). |
| `config/i3blocks/` | `~/.config/i3blocks/` | The status bar: `config` lists the blocks, `blocks/` holds one bash script per block plus `_common` (colours, glyphs, the `emit` helper). |
| `config/foot/` | `~/.config/foot/` | Terminal font and the lascaille colour scheme. |
| `config/rofi/` | `~/.config/rofi/` | Launcher settings and the lascaille theme. |
| `config/swaync/` | `~/.config/swaync/` | Notification centre settings and CSS. |
| `config/kanshi/` | `~/.config/kanshi/` | Monitor profiles for hot-plugging. Ships with a commented-out example only. |
| `config/xdg-desktop-portal/` | `~/.config/xdg-desktop-portal/` | Portal backends: screen sharing and screenshots through wlr, everything else through gtk. |
| `bin/` | `~/.local/bin/` | The helper scripts below, copied one file at a time. |
| `backgrounds/lascaille/` | `~/.local/share/backgrounds/lascaille/` | Desktop and lock-screen wallpapers. |

### Helper scripts

| Script | Stands in for | What it does |
|---|---|---|
| `regolith-apply-look` | Regolith's look loader | Sets the GTK theme, icons, fonts, cursor and wallpapers with `gsettings` and writes `~/.config/gtk-3.0/settings.ini` and `gtk-4.0/settings.ini`. Runs on every sway start and on `Super+Shift+r`. |
| `regolith-lock` | gtklock | swaylock with the lascaille colours and the lock-screen image. |
| `regolith-grimshot` | grimshot (sway-contrib) | Screenshots of the active window, an area or the whole screen with grim and slurp, to the clipboard and `~/Pictures`. |
| `regolith-keybindings` | remontoire / ilia | Parses the `## Category // Action // Keys ##` comments in the sway config and shows them in rofi. |
| `regolith-next-free-workspace` | childe | Jumps to, or moves the window to, the lowest unused workspace. |
| `regolith-swap-focus` | i3-swap-focus | Daemon that remembers the previously focused window; `Super+.` goes back to it. |
| `regolith-force-kill` | – | `SIGKILL` for the focused window's process (`Super+Alt+q`). |
| `regolith-polkit-agent` | – | Starts the MATE polkit agent from whichever path the package installs it to. |
| `sway-toggle-stacking` | – | `Super+s` switches the focused container to stacking and back to the split it had before. |

## What was substituted

Regolith's own components are not in the Ubuntu archive. This is what stands
in for each of them.

| Regolith | Here |
|---|---|
| ilia (launcher) | rofi 2.0, native Wayland |
| i3status-rs and i3xrocks (bar) | i3blocks with the bash blocks in `config/i3blocks/blocks/` |
| rofication (notifications) | swaync (sway-notification-center) |
| avizo (volume/brightness OSD) | swayosd |
| gtklock | swaylock |
| grimshot, childe, i3-swap-focus, remontoire | the scripts in `bin/` |
| BitstreamVeraSansMono Nerd Font | Bitstream Vera Sans Mono, with Font Awesome 4.7 for the bar glyphs |
| Ayu-Mirage-Dark GTK theme | Adwaita-dark with `color-scheme` set to prefer-dark |
| Papirus-Dark icons | Papirus-Dark (the same) |
| Ptyxis / x-terminal-emulator | foot |

The lascaille palette (Ayu Mirage) is used as-is: window borders and the bar in
`config/sway/config.d/00_variables`, the bar blocks in `_common`, foot, rofi,
swaync and swaylock all carry the same colours.

## Adapting to other hardware

No monitor layout is pinned. Sway places monitors left to right in the order
it detects them, at their preferred mode, which is right for a single screen
and often right for two. If yours come up in the wrong order, add `output`
lines to `config/sway/config.d/05_outputs` (a commented example is in the
file), or press `Super+d` for `nwg-displays`, which writes them for you.
Matching on the EDID "Make Model Serial" string from `swaymsg -t get_outputs`
keeps each panel in place whichever port it is plugged into. For a laptop that
is docked and undocked, put the same layouts in `config/kanshi/config` as
profiles; kanshi applies whichever one matches the monitors currently
connected.

Two files carry settings specific to the author's machine:

- `config/sway/config.d/06_input` sets `xkb_layout gb` and `xkb_model pc105`.
- `config/sway/config.d/96_clamshell` turns `eDP-1` off when a laptop lid
  closes. It does nothing on a machine without that output.

The battery and temperature blocks in the bar hide themselves when there is no
battery or no supported temperature sensor.

## What happens at runtime

A few files are written by the session itself, which is why they are not in
this repo:

- `regolith-apply-look` runs on every sway start. It applies the theme with
  `gsettings` and regenerates `~/.config/gtk-3.0/settings.ini` and
  `~/.config/gtk-4.0/settings.ini`. Since `gsettings` writes to the shared
  dconf database, a GNOME session on the same account picks up the same theme,
  fonts and wallpaper.
- `exec_always im-config -n none` rewrites `~/.xinputrc` so no input method
  framework starts, as Regolith does.
- kanshi is restarted on every reload, so any monitor profile is reapplied.

## Keybindings

`Super` is the Windows key. Press `Super+Shift+?` inside the session for the
same list, or click the `?` at the right end of the bar. The tables are
generated from the `## Category // Action // Keys ##` comments in
`config/sway/config.d/*`, which is also what the in-session viewer reads.

### Launch

| Action | Keys |
|---|---|
| Terminal | Super + Enter |
| Browser | Super + Shift + Enter |
| File Browser | Super + Shift + n |
| Application | Super + Space |
| Command | Super + Shift + Space |
| File Search | Super + Alt + Space |
| Keybinding Viewer | Super + Shift + ? |
| Notification Viewer | Super + n |

### Navigate

| Action | Keys |
|---|---|
| Window by Name | Super + Ctrl + Space |
| Relative Parent | Super + a |
| Relative Child | Super + z |
| Relative Window | Super + ↑ ↓ ← → |
| Relative Window | Super + k j h l |
| Workspaces 1-10 | Super + 0..9 |
| Workspace 11 - 19 | Super + Ctrl + 1..9 |
| Next Workspace | Super + Tab |
| Next Workspace | Super + Alt + → |
| Previous Workspace | Super + Shift + Tab |
| Previous Workspace | Super + Alt + ← |
| Next Workspace on Output | Super + Ctrl + Tab |
| Next Workspace on Output | Super + Ctrl + l |
| Previous Workspace on Output | Super + Ctrl + Shift + Tab |
| Previous Workspace on Output | Super + Ctrl + h |
| Scratchpad | Super + Ctrl + a |
| Last Focused Window | Super + . |
| Next Free Workspace | Super + \` |

### Modify

| Action | Keys |
|---|---|
| Move Window to Next Free Workspace | Super + Shift + \` |
| Carry Window to Next Free Workspace | Super + Alt + \` |
| Window Position | Super + Shift + ↑ ↓ ← → |
| Window Position | Super + Shift + k j h l |
| Containing Workspace | Super + Ctrl + Shift + ↑ ↓ ← → |
| Containing Workspace | Super + Ctrl + Shift + k j h l |
| Vertical Window Orientation | Super + v |
| Horizontal Window Orientation | Super + g |
| Toggle Window Orientation | Super + Backspace |
| Window Fullscreen Toggle | Super + f |
| Window Floating Toggle | Super + Shift + f |
| Move to Scratchpad | Super + Ctrl + m |
| Tile/Float Focus Toggle | Super + Shift + t |
| Window Layout Mode | Super + t |
| Toggle Stacked Layout | Super + s |
| Move Window to Workspace 1 - 10 | Super + Shift + 0..9 |
| Move Window to Workspace 11 - 19 | Super + Ctrl + Shift + 1..9 |
| Carry Window to Workspace 1 - 10 | Super + Alt + 0..9 |
| Carry Window to Workspace 11 - 19 | Super + Alt + Ctrl + 1..9 |
| Settings | Super + c |
| Display Settings | Super + d |
| Wifi Settings | Super + w |
| Bluetooth Settings | Super + b |
| Next Layout | Super + Alt + BackSpace |
| Prev Layout | Super + Alt + Shift + BackSpace |
| Toggle Bar | Super + i |
| Toggle Do Not Disturb | Super + Shift + d |

### Resize

| Action | Keys |
|---|---|
| Window Gaps | Super + Plus / Minus |
| Big Window Gaps | Super + Shift + Plus / Minus |
| Enter Resize Mode | Super + r |
| Resize Window | ↑ ↓ ← → |
| Resize Window | k j h l |
| Exit Resize Mode | Escape or Enter |

### Session

| Action | Keys |
|---|---|
| Lock Screen | Super + Escape |
| Exit App | Super + Shift + q |
| Terminate App | Super + Alt + q |
| Reload Sway Config | Super + Shift + c |
| Refresh Session | Super + Shift + r |
| Logout | Super + Shift + e |
| Reboot | Super + Shift + b |
| Power Down | Super + Shift + p |
| Sleep | Super + Shift + s |
| Window Snapshot | Super + PrtSc |
| Screenshot | Super + Shift + PrtSc |
| Capture All Screens | Super + Shift + Ctrl + PrtSc |


## Rolling back

`--overwrite` leaves the previous version of every replaced path next to the
new one:

```bash
mv ~/.config/sway ~/.config/sway.repo
mv ~/.config/sway.bak.20260930-120000 ~/.config/sway
```

The packages can be removed with `apt-get remove` using the list in
`packages.txt`. The `gsettings` changes made by `regolith-apply-look` persist
until you change them from GNOME Settings or with `gsettings reset`.

## Wallpapers and licence

The two images in `backgrounds/lascaille/` are the ones Regolith ships with
its lascaille look, taken from
[regolith-look-extra](https://github.com/regolith-linux/regolith-look-extra).
Both are NASA/JPL imagery and in the public domain: the desktop is HiRISE
observation ESP_016895_1525 and the lock screen is PIA21972.

The configuration files and scripts are covered by the licence in the
repository root. The images are not.

## Sources

The keybindings, layout and look were reconstructed from Regolith's own
repositories:

- [regolith-wm-config](https://github.com/regolith-linux/regolith-wm-config) — the sway/i3 keybindings and config fragments
- [regolith-look-extra](https://github.com/regolith-linux/regolith-look-extra) — the lascaille look
- [regolith-look-default](https://github.com/regolith-linux/regolith-look-default) — the look loader and defaults
