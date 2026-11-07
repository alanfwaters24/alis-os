# A.L.I.S OS

The ALIS ecosystem as its own Linux distribution. Linux does the hard parts
underneath (hardware, drivers, security updates), NixOS lets the whole machine
be described in a few files, and ALIS sits on top: the ALIS boot splash and
colours, the dashboard as the home screen, ALIS modules as built-in services.

Same idea as SteamOS or ChromeOS: you don't write a new kernel, you build
your own OS around it.

## Why NixOS underneath

- **One recipe = one machine.** Every ALIS machine is rebuilt from this repo.
  If a box dies, reinstall and run one command and it's back exactly as it was.
- **Rollback for free.** Every change is a new numbered version. A bad update
  can be undone by picking the previous one in the boot menu.
- **Matches the ALIS principles:** self-hosted, no subscriptions, runs on
  repurposed hardware, every module a systemd service from one template.

## Roles: one line per machine

| Role | For | What you get |
|---|---|---|
| `kiosk` | Wall / fridge tablets | Powers on → dashboard full-screen. No login, can't be closed (restarts itself). |
| `desktop` | Office PC | A full PC desktop (KDE Plasma) dressed as ALIS — see below. |
| `laptop` | Spare/old laptops | Desktop + battery modes, suspend on lid close, firmware updates, compressed memory (zram) so 4 GB goes further. |
| `server` | Mini PC / VMs | No screen. Runs ALIS modules (`alis.apps.*`) and optionally Home Assistant. |
| `brain` | The ALIS Brain (mini PC) | A server with the whole Brain stack on — see below. |

```nix
alis.role = "kiosk";
alis.dashboard.url = "http://192.168.1.235:8080";   # optional: show the live NEST instead of the built-in copy
```

### Browser permissions
- **Kiosk:** no pop-ups ever. The dashboard gets the microphone ("Hey ALIS") and location automatically; mic/camera are blocked for anything else, notifications off. Kiosk mode can't leave the dashboard.
- **Desktop/laptop:** the dashboard gets the mic without asking; every other site asks as normal.

### The desktop (office PC / laptops)

KDE Plasma underneath (Windows-style taskbar and start menu, real glass/blur
effects), with the ALIS Glass colour scheme, wallpaper and login screen
applied on first login. The **ALIS Dashboard** opens as its own app window
on login and sits in the start menu.

| You want | App |
|---|---|
| File explorer | Dolphin |
| Web browser | **PANE**, the Personal ALIS Network Explorer (Chromium in ALIS Glass, see below) |
| Office (Word/Excel/PowerPoint files) | OnlyOffice |
| Notepad / text editor | KWrite, Kate |
| Calculator | KCalc |
| Storage — what's using space / drives | Filelight, Partition Manager |
| Zip files / downloads | Ark (Downloads folder in your home folder) |
| Photos, PDFs, screenshots | Gwenview, Okular, Spectacle |
| More apps | Discover (app store, with Flathub) |
| Settings & themes | System Settings → Appearance (ALIS Glass is the default colour scheme) |

## The ALIS Glass look (PCs and laptops)

Applied once per person when they log in, then theirs to change in
System Settings → Appearance (pick "ALIS Glass" there to get it back):

- **Fonts:** Rajdhani for text, Exo 2 for window titles, Share Tech Mono for numbers/code
- **Frosted glass apps:** a Kvantum "ALIS Glass" style (dark teal, slightly
  see-through windows and menus, blurred behind). Covers every KDE/Qt app:
  Files, Settings, Calculator, Kate, the music player, LibreOffice...
- **ALIS glow edge:** the active window gets a soft teal glow
- **Floating glass dock:** a rounded see-through bar floating above the bottom
  edge, the ALIS logo as the start button, Dashboard / PANE / Files /
  OnlyOffice / Kate / Settings pinned
- **Icons, all in ALIS duotone** (one set of colour rules, `pkgs/alis-icons/recolour.py`):
  - system icons: Papirus-Dark recoloured (`pkgs/alis-icons`, "ALIS")
  - ALIS apps: each app's own icon from its repo, so the PC matches the phone
    apps (`artwork/apps`: NEST, DOSE, ARCH, STALL, VAULT, Assistant)
  - LibreOffice toolbars: its Breeze Dark set recoloured, an "ALIS" icon style
    (`pkgs/alis-libreoffice-icons`)
  - dock, tray, pop-ups: an "ALIS Glass" Plasma style (`pkgs/alis-plasma-theme`)
  - cursors: Breeze Dark reshaded, dark ALIS green with a teal edge (`pkgs/alis-cursors`)
- **Office:** LibreOffice follows the ALIS look fully. OnlyOffice gets an
  "ALIS" interface theme (its Dark theme in ALIS colours,
  `pkgs/alis-onlyoffice-theme`); its toolbar icons are built into the app and
  can't be swapped
- Each of these is switched on once per person at login with its own marker,
  without resetting the dock or layout; choosing something else afterwards sticks

Code: `pkgs/alis-fonts`, `pkgs/alis-glass-kvantum` (generated from
Kvantum's KvFlat), `pkgs/alis-lookandfeel` (the Global Theme + dock layout),
`modules/theme.nix`. When the look changes, `alis.theme.version` is bumped
so everyone gets the new look once.

## PANE: Personal ALIS Network Explorer

The browser on every PC and laptop. Same Chromium engine underneath (same
updates, same extensions, Chrome Web Store works), dressed as ALIS:
- ALIS Glass theme (dark teal frame, teal buttons), dark mode for websites
  that have one, PANE name and icon in the menu and taskbar
- **ALIS start page** for new tabs and Home: clock, greeting, DuckDuckGo
  search, and a glass tile for every ALIS module (teal dot = reachable;
  laptops switch a tile to its Tailscale address when away)
- **ALIS bookmarks folder** with every module, kept in step by ALIS OS
- **DuckDuckGo** search, **uBlock Origin Lite** ad and tracker blocking
- Set as Chromium policies, so they can't be lost by accident.

Code: `pkgs/pane/` (theme, start page, icon, wrapper) and `modules/pane.nix`
(policies, module links). The ALIS Dashboard app windows and kiosks still
use plain Chromium.

## ALIS Assistant ("Hey ALIS"), built in

Every PC and laptop has ALIS ready to help. Say **"Hey ALIS"**, or press
**Win+A**: the ALIS orb balloons out of the **top-right corner** (a
see-through overlay, no window), listens, answers out loud and does it, then
shrinks back into the corner. **Mic** and **Stop** buttons slide in at the
bottom right, just above the dock, while she's active; while muted, the red
mic button stays there so you can see she's off. If she wakes by mistake and
nobody speaks, she goes away again after 3.5 seconds.

| Control | |
|---|---|
| **Win+A** | talk to ALIS without the wake word |
| **Win+Shift+A** | microphone on/off. Off is a hard off: the mic isn't opened at all, and the orb goes grey |
| **Stop** button (by the dock) | stop her talking and end the conversation |
| **Mic** button (by the dock) | mute / unmute (red while muted) |
| Start menu | "ALIS · Talk to ALIS", "ALIS · Microphone on/off", "ALIS · Stop" |

What she can do:
- **Everything the shared brain does** (NEST `/api/brain`): lights, heating,
  music, timers, reminders, weather and general questions through Home
  Assistant's conversation agent (web-connected).
- **On the PC:** open apps ("open OnlyOffice", "open SCORE"), folders ("open
  my downloads"), volume, media (play/pause/next, "what's playing"),
  brightness, Wi-Fi settings, Bluetooth on/off, **take a screenshot**,
  **lock the computer**, web search ("search the web for…"), open websites,
  "stop listening".

How: it uses NEST's own voice pipeline, the same as the dashboards and the
phone app: "Hey ALIS" detection over `/api/wake/ws` (your `hey_alis` model),
Whisper `/api/stt`, the brain, Piper `/api/tts`. The orb is the phone app's
ported NEST orb. Home network first, Tailscale when away. Code:
`pkgs/alis-assistant/` (plain Python, standard library only), settings in
`modules/assistant.nix` (`alis.assistant.startMuted`, `.enable`). Test:
`python3 tests/assistant_test.py`.

**Keep in step with the phone app:** any change to the ALIS Assistant phone
app's assistant behaviour must be applied here too. Pending changes are listed
in `pkgs/alis-assistant/PHONE-PARITY.md`.

## NAS storage (VAULT)

PCs and laptops show NAS shares in the file explorer (Dolphin) sidebar.

```nix
alis.nas.shares = {
  stash = { };                  # shared household drive: always mounted at /mnt/nas/stash
  alan  = { mount = false; };   # personal: sidebar link, each person logs in with their own NAS account
};
```

- **Mounted** shares use one shared NAS login kept on the machine. Put it there once:
  `sudo install -m 600 /dev/stdin /etc/alis/nas-credentials` then type
  `username=...` and `password=...` on two lines and press Ctrl+D.
- **Links** ask for the person's own NAS login the first time; KDE remembers it.
- If VAULT is off, nothing hangs: the drive just doesn't open (10-second timeout).
- `stash` is linked by default. Away from home, set `alis.nas.host` to VAULT's Tailscale name.

## Every ALIS module: built in, or link to the one you have

Every module in the ALIS blueprint (`modules/registry.nix`, copied from
`alis-core/ports_and_env.json`) has one switch:

```nix
alis.modules.glance.mode = "builtin";   # run it on this machine
alis.modules.fuel.mode   = "link";      # use the existing one — address pre-filled from the blueprint
alis.modules.fuel.url    = "http://192.168.1.240:3501";   # ...or give a different address
alis.modules.arcade.mode = "off";
```

| Machine | Default |
|---|---|
| Brain | Runs everything ALIS OS can build in (NEST, alis-push, GLANCE, Home Assistant, voice, Ollama); links every other live module |
| PC / laptop / kiosk | Links every module that's live today; nothing heavy runs locally |
| Server | Everything off; switch on what you want |

- On PCs and laptops, every module that's on and has a web page gets its own
  app in the start menu ("ALIS · SCORE", "ALIS · NOVA"...).
- Laptops (`alis.network = "auto"`) try the home-network address first and
  Tailscale when that doesn't answer, so they work at home straight after
  install and away from home once `sudo tailscale up` has been run once.
  Others use home-network addresses. Set `"lan"` or `"tailscale"` to force one.
- Every module's address is in `/etc/alis/connect.json` and given to every ALIS
  app as `ALIS_<NAME>_URL` (e.g. `ALIS_HOMEASSISTANT_URL`).
- **Dashboard fallback:** PCs, laptops and kiosks open the live NEST, but if it
  doesn't answer within 4 seconds (Brain down, laptop away from home) they show
  the dashboard copy built into ALIS OS instead, so there's never a blank window.
  (`alis.dashboard.fallbackAfter` changes the wait.)
- NEST (alis-live) reads `ha_url` from its own `config.json`, which already
  defaults to your Home Assistant at 192.168.1.251.
- **Can be built in today:** NEST, alis-push, GLANCE, Home Assistant, voice,
  Ollama. Everything else links. Asking to build in one that isn't ready
  stops the build with a plain message. Adding a recipe moves a module over.

## The Brain role

`alis.role = "brain";` turns a machine into the ALIS Brain: what's spread
over the Brain VM and dev-automation today, on one box. Ports match
`alis-core/ports_and_env.json`.

| Piece | Port | Where it comes from |
|---|---|---|
| Home Assistant + Matter | 8123 | NixOS (settings from alis-os-home) |
| Whisper — speech → text | 10300 (Wyoming) | NixOS |
| Piper — text → speech | 10200 (Wyoming) | NixOS, voice `en_GB-southern_english_female-low` |
| openWakeWord — "Hey ALIS" | 10400 (Wyoming) | NixOS |
| Ollama — local AI | 11434 | NixOS (no models downloaded unless listed in `alis.brain.ollamaModels`) |
| NEST + shared brain (`/api/brain`) | 8080 / 8443 | `alis-live` repo |
| alis-push | 8091 · TS 10001 | `alis-push` repo |
| GLANCE | 3512 · TS 10006 | `glance` repo |

Already have one of these? Link to it instead, e.g.
`alis.modules.homeassistant.mode = "link";` uses your Home Assistant at 192.168.1.251.

**Per-machine settings never come from git.** Each module's `config.json`,
`.env`, `data/` and certificates live only in `/var/lib/alis/<module>/` on
the machine. Put them there by hand once (e.g. copy NEST's `config.json`
across). Code updates replace the code, never those files.

**Not in yet:** STALL. It's a Node app with native add-ons (`sharp`,
`better-sqlite3`) that need their own packaging step — next stage.

## ALIS modules as services

The ALIS deployment standard (one shared systemd template, local data, own
port) is built in:

```nix
alis.apps.stall = {
  enable = true;
  port = 3514;
  command = "${pkgs.nodejs}/bin/node server.js";
  workingDirectory = "/var/lib/alis/stall";
};
```

If two modules ask for the same port, the build **fails** and names them,
so a clash like STALL/alis-speak on 3513 can't happen on an ALIS OS machine.

## Repo layout

```
flake.nix            entry point — machines, ISO, VM
modules/             what ALIS adds to Linux
  base.nix           every machine: UK locale, SSH, Tailscale, users, auto-cleanup
  branding.nix       "ALIS OS" name, boot splash, console colours
  dashboard.nix      bundled ALIS dashboard served on localhost:8080
  apps.nix           shared ALIS module service template + port-clash check
  registry.nix       every ALIS module: ports, hosts, Tailscale ports
  modules.nix        builtin / link / off switch per module, start-menu apps
  home-assistant.nix Home Assistant + Matter recipe (copied over from alis-os-home)
  nas.nix            NAS shares: mounted drives + file-explorer links
roles/               kiosk / desktop / laptop / server / brain
tests/brain.nix      boots a Brain in a VM and checks every service answers
hosts/live-test.nix  Stage 1 live test image
hosts/installer.nix  the installer USB
installer/           alis-install guided install script
machines/            one folder per real machine (spare-laptop, ...)
artwork/             logo + splash, drawn from the ALIS Glass palette
```

## Building

The ALIS module repos (dashboard, alis-live, alis-push, glance) are private.
Nix fetches them with git, so git needs your GitHub login once:

```bash
gh auth login && gh auth setup-git
```

`flake.lock` pins the exact version of every source (nixpkgs and each ALIS
repo). To move everything to the latest versions: `nix flake update`, then
rebuild. To take just one module's latest code: `nix flake update glance`.

Then, on any Linux machine with Nix (dev-automation works):

```bash
git clone https://github.com/alanfwaters24/alis-os && cd alis-os
nix build .#iso          # → result/iso/alis-os-live-test.iso  (~2–3 GB)
nix run .#vm             # or: try it in a window, no USB needed
nix flake check          # builds an example of every role to make sure nothing's broken
```

## Trying the live test image (Stage 1)

1. Build the ISO (above), or grab it from wherever it was copied.
2. **VM first:** in Proxmox, upload the ISO → new VM, 4 GB RAM, 2 cores, UEFI or BIOS both fine → boot.
3. **Then real hardware:** write it to a USB stick with Balena Etcher or Rufus, boot the spare laptop from USB.
4. You should see: ALIS boot menu → ALIS splash → the ALIS dashboard full-screen.
5. Nothing is written to the disk. Unplug the stick and the machine is unchanged.
6. To poke around: `Ctrl+Alt+F2` for a text console, log in as `alan` / `alis`
   (test image only; real machines use SSH keys).

Some dashboard tiles need the home network (Home Assistant etc.), so on
another network those will show as offline. That's expected.

## Installing on a real machine (Stage 2)

1. **Make the installer USB** (on dev-automation or any Linux box with Nix):
   `nix build .#installer` → `result/iso/alis-os-installer.iso` (~1.6 GB).
   Write it to a USB stick with **Balena Etcher**, or **Rufus in "DD Image mode"**
   (if Rufus asks "ISO or DD?", pick DD).
2. **Boot the machine from the USB.** On HP: turn **Secure Boot off** first
   (F10 → Boot Options), then tap **F9** at power-on and pick the USB. It must be in UEFI mode (all PCs from
   the last ~10 years; turn off "Legacy/CSM" in the firmware if it complains).
3. The **ALIS installer starts by itself** and asks, in plain English:
   - Wi-Fi, if there's no cable plugged in
   - which machine this is: one listed in `machines/`, or "a new machine" (name + role)
   - which disk. It only lists real disks, never the USB stick itself.
   - **type ERASE to confirm.** Nothing is touched before this.
   - a password for `alan`
4. Takes 10–30 minutes (downloads ~2–6 GB). Then remove the USB and restart.
5. The installer writes `machines/<name>/hardware-configuration.nix` for that
   exact hardware and tells you the five commands to save it to GitHub.

After that, the machine's own recipe lives at `/etc/alis-os`. Change it with
`sudo nixos-rebuild switch --flake /etc/alis-os#<name>`. Every change is a new
entry in the boot menu, so a bad change can be undone by picking the one before.

**Disk layout** (the same on every machine): `ALIS-BOOT` 1 GB FAT32 + `alis-root`
ext4 for the rest, plus a 4 GB swap file.

**Office PC (conservatory):** Windows 11 is on its own drive and Ubuntu on a
separate 120 GB NVMe (the M.2 2230 from the old Surface Pro 4), so ALIS OS
simply replaces Ubuntu on that drive. The Windows drive and the games drives
are never written to. At power-on the **ALIS boot picker** shows two big
tiles, **ALIS OS** and **Windows** (arrow keys + Enter), and after 30 seconds
starts whichever was used last. The PC's own boot menu (**F8** on the Asus ROG
board) still works as a backup.
In the installer pick **office-pc**, then the disk marked **"has Linux (e.g.
Ubuntu)"** (~119G). Disks with Windows or NTFS files (games drives) are
marked in red and need an extra "NTFS" confirmation, so they can't be
picked by mistake.

### ALIS boot picker (dual-boot PCs)

`alis.bootPicker.enable = true;` in a machine's folder (on for the office PC).
It's rEFInd, themed ALIS (`modules/boot-picker.nix`, artwork in
`artwork/boot-picker.nix`), on ALIS's own boot partition in front of ALIS's
normal boot loader; Windows is found on its own drive and nothing there is
changed. Every rebuild re-writes it and makes sure it's first in the PC's
boot order (Windows updates sometimes push themselves first).

```
sudo alis-boot-picker 30        # wait 30 s, then start the last one used (default)
sudo alis-boot-picker forever   # wait until someone picks
sudo alis-boot-picker off       # start the last one used straight away (hold a key for the menu)
alis-boot-picker                # show the current setting
```

Older ALIS versions: pick ALIS OS, then hold **Space**. Mouse support is
`alis.bootPicker.mouse = true;`, off by default: in testing it hid the
keyboard highlight and arrows + Enter could start the wrong system.

## Updates and backups (installed machines)

**Updates.** Every night around 03:30 (or soon after start-up if the machine was
off), each machine pulls the latest ALIS OS from GitHub into
`/home/alan/alis-os` and prepares it for the **next restart**; a notification
says "ALIS OS update ready". Nothing changes while you're using it, and the
previous version stays in the boot menu. Laptops skip it on battery. Run one
now: `sudo systemctl start alis-update`; see what happened:
`journalctl -u alis-update`.

**Software versions** move once a week on dev-automation
(`tools/weekly-update.sh`, Sundays 04:15): it updates nixpkgs and the ALIS
module repos, **builds every machine for real** and runs the assistant test,
and only then pushes. Your phone gets an alis-push notification either way.
Install once on dev-automation: `~/alis-os/tools/install-weekly-update.sh`.

**Backups.** Nightly at 02:30 (or soon after start-up) to
`stash/ALIS backups/<machine>` with restic: encrypted, de-duplicated, keeping
7 daily / 4 weekly / 6 monthly. Backs up `/home` (minus Downloads, caches,
Trash and games), ALIS module data and Home Assistant where it runs. VAULT's
Backblaze B2 copy of DataKeeper covers it off-site.
- **Once per machine:** `sudo alis-backup-setup` (backup password: use the
  same one everywhere and keep it in your password manager), and the stash
  login in `/etc/alis/nas-credentials` (see "NAS storage").
- **Run one now:** `sudo systemctl start restic-backups-alis`
- **Get files back:** `sudo alis-backup-browse`, then open `/run/alis-backups`
  in Dolphin: one folder per night; copy back what you need.

## Roadmap

- [x] **Stage 1:** bootable live test image → ALIS dashboard
- [x] **Stage 2:** ALIS guided installer + `machines/` folders (first target: a spare laptop)
- [x] **Stage 2b:** office PC: whole-disk install onto Ubuntu's own NVMe, Windows/games drives untouched (disk labels + NTFS lock in the installer) — **installed 6 Nov 2026**
- [x] **Brain role:** HA, voice, Ollama, NEST + brain, alis-push, GLANCE, with a VM boot test
- [x] **Boot picker:** ALIS OS / Windows tiles at power-on for dual-boot PCs (office PC), last-used default, adjustable wait
- [ ] **Stage 3:** STALL, then NOVA/FUEL/PENY/EARN as they're rebuilt, into `alis.apps`
- [x] **Stage 4:** auto-updates from this repo (next restart) + weekly build-checked version updates on dev-automation + nightly restic backups to stash
- [x] **ALIS Assistant A:** "Hey ALIS" + pop-up orb, hard mute, stop, shortcuts, brain + PC actions on PCs/laptops
- [ ] **ALIS Assistant B:** read desktop notifications aloud; kiosk wall screens (orb over the full-screen dashboard, hand-over from NEST's own voice); move the PC-only commands (screenshot, lock, folders, web search) into the shared brain as new caps
- [ ] **Stage 5: ALIS Glass theme pack:** every PC/laptop gets it automatically; switch it off in System Settings like any other theme. Built one piece at a time:
  - [x] **5a Fonts:** Exo 2 / Rajdhani / Share Tech Mono packaged and used system-wide
  - [x] **5b Chromium → PANE:** ALIS Glass theme, ALIS start page with module tiles, ALIS bookmarks, DuckDuckGo, uBlock Origin Lite, dark mode
  - [x] **5c KDE apps:** Kvantum "ALIS Glass" frosted style, ALIS glow edge (later: animated rotating edge)
  - [x] **5d Desktop:** ALIS Glass Global Theme, floating glass dock, ALIS logo start button (later: graphical ALIS login + lock screen, animated boot splash)
  - [x] **5f ALIS icon theme:** every icon (tray, toolbar, folders, file types, app icons) in ALIS duotone (mint-white lines, teal/violet accents, teal glass folders), generated from the Papirus set so nothing is left in stock style
  - [x] **5e Apps that draw their own look:** OnlyOffice ALIS theme; LibreOffice ALIS toolbar icons
  - [x] **5g The rest of the icon packs:** ALIS app icons from each app's repo, ALIS Plasma style (dock/tray), ALIS cursors
