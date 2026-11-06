# ALIS OS — prompt & answer log

## 2026-11-04 — Stage 1: ALIS OS foundation + live test image

**Asked:** "Help me rebuild an operating system like Linux, but based around my ALIS dashboard, modules and core principles."

**Clarified (Alan's answers):**
- Approach: an ALIS distro on top of NixOS (not a from-scratch kernel), growing out of the existing `alis-os-home` NixOS config.
- Targets: all four: office PC, wall/fridge tablets, mini PC/servers, spare laptops.
- Stage 1: a bootable ALIS test image, tried in a VM before real hardware.

**Done:**
- `alis-os` flake with one shared ALIS module + four roles (`alis.role = kiosk | desktop | laptop | server`).
- Branding: "ALIS OS" in os-release/boot menu, generated ALIS Glass logo + splash (SVG → PNG at build time), Plymouth boot splash, ALIS console palette.
- `alis-dashboard` bundled into the OS and served on localhost:8080 (same python http.server approach as its install.sh); `alis.dashboard.url` can point a screen at the live NEST instead.
- `alis.apps.<name>`: the shared ALIS systemd service template from the 21 Oct deployment standard, with a build-time port-clash check (tested: two modules on 3513 fails the build with a named error).
- Home Assistant + Matter from `alis-os-home` moved in as `alis.homeAssistant.enable`.
- Kiosk = cage + Chromium full-screen, self-restarting. Desktop/laptop = greetd login + ALIS-coloured sway with the dashboard on workspace 1.
- `nix flake check` builds an example machine for every role.
- Live ISO built (2.1 GB) and boot-tested in QEMU (no KVM): boots unattended to the full-screen dashboard in ~4 min. Chromium asks for location on first load — kiosk permission policy still to decide.

**Decisions:**
- No new kernel: Linux + NixOS underneath, ALIS on top (SteamOS/ChromeOS model) — rollback, one-file rebuilds, fits "repurposed hardware".
- `alis-os-home` left untouched; it can later import `alis-os`'s `nixosModules.default`.
- Brand fonts (Exo 2 / Rajdhani / Share Tech Mono) not packaged yet; system UI uses DejaVu, dashboard still loads its own fonts. Flagged for later.

## 2026-11-04 (cont.) — Kiosk permissions, Brain role, KDE desktop, NAS, module registry

**Asked (in order):** don't overwrite anything current · show the boot screenshot · fix kiosk pop-ups · "a brain which runs alis-push and ALIS speech etc" · use an existing HA · full PC OS (file explorer, Chrome-style browser, storage manager, settings, themes, calculator, notepad, office suite) · NAS storage links · link to the existing Brain · "the same with all modules — built in, or link if I already have them".

**Decisions (Alan's answers):**
- Kiosk: auto-allow location + mic for the dashboard only (Chromium policies); other mic/camera blocked, notifications off.
- "ALIS speech" = Whisper + Piper + openWakeWord (not the unregistered alis-speak service).
- Brain = new `brain` role: HA + Matter, voice, Ollama, NEST (alis-live incl. brain.py), alis-push, GLANCE. STALL deferred (Node native add-ons need their own packaging).
- Desktop/laptop: KDE Plasma (ALIS Glass colour scheme, wallpaper, SDDM background), OnlyOffice, Chromium (not Google Chrome).
- NAS: both styles — `stash` always-mounted (shared login in /etc/alis/nas-credentials), personal shares as Dolphin links with each person's own login.
- All modules: `alis.modules.<name>.mode = builtin | link | off`, from a registry copied out of ports_and_env.json.

**Done:**
- Booted the kiosk ISO in QEMU twice and sent screenshots; the second boot (after the policy fix) had no pop-up.
- `alis.apps` template now links module code into /var/lib/alis/<name> so existing apps run unchanged; config.json/.env/data/certs never linked from git. Optional `tailscale serve` per app.
- `tests/brain.nix` VM test — 9/9 subtests passed (push, GLANCE, NEST, openWakeWord, Ollama, HA, Whisper/Piper units, local data).
- Registry + start-menu app per module on PCs/laptops; laptops use Tailscale addresses.

**Flag for ALIS-CORE (not edited here, per alis-core/CLAUDE.md):**
- ALIS Brain is `brain.py` inside alis-live (`/api/brain` on 8080/8443), not a separate service on 8085 — the 8085 "uncertain" entry looks stale.
- `alis-live/config.json` (with the HA long-lived token) is committed to the alis-live repo. Recommend removing it from git and rotating the token. Not changed, per "don't overwrite anything current".
- ports_and_env.json now calls alis_speak "ALIS Speak (text-to-speech server)", while ALIS-CORE.md still says "unregistered".

## 2026-11-05 — Dashboard fallback + Stage 2 installer

**Asked:** fall back to the built-in dashboard when NEST is unreachable; then build the installer (first target a spare laptop; office PC later = replace Ubuntu, keep Windows; guided ALIS script rather than a graphical wizard).

**Done:**
- `alis-open-dashboard`: tries live NEST for 4 s, else opens the built-in copy (kiosk + desktop). Tested both paths.
- `machines/<name>/` folders become machines automatically; `modules/machine.nix` = standard by-label disk layout.
- `installer/alis-install.sh` + `hosts/installer.nix` (installer USB, auto-starts on screen 1).
- `flake.lock` now committed: nixpkgs via the official channel URL, ALIS repos via git+https (git uses the normal GitHub login).
- **Full VM test passed:** UEFI VM → installer → picked vm-test + the 20 GB disk → ERASE → installed offline from the USB → rebooted with no USB → "Welcome to ALIS OS", logged in as alan, /etc/alis-os present, `systemctl is-system-running` = running.

**Bugs found by the test and fixed:** floppy drive listed as a disk; ✓ not in console font; install tried to rebuild everything because swapped-in sources lost version info (fixed with flake.lock); installer didn't reuse the USB's software (now copies it directly when present).

**Still to do:** office PC "use Ubuntu's partition" mode (Stage 2b); a real-hardware run on the spare laptop (needs internet; downloads the KDE desktop).

## 2026-11-05 (cont.) — First real install: HP 15-db0 laptop

**Hardware:** HP Laptop 15-db0xxx, AMD A6-9225, 4 GB RAM (one slot only — JDIMM2 not fitted), Crucial BX500 500 GB SSD, previously ChromeOS Flex. (HP 240 G7 rejected: blink code 5.3, main board fault.) zram added to the laptop role for 4 GB machines.

**Problems hit on real hardware, all fixed in the repo:**
1. USB written in Rufus ISO mode → boot timed out waiting for /dev/disk/by-label/ALIS_OS_INSTALL (FAT labels max 11 chars). Labels now ALIS_INST / ALIS_DESK; README says Etcher or Rufus DD mode.
2. "No disks found": DD-mode stick mounts /iso from the whole disk, `lsblk -no PKNAME` returned a multi-line value that excluded every disk. Now `lsblk -ndo PKNAME` with fallback.
3. "lacks a signature by a trusted key" for the USB's nixpkgs source. A blanket require-sigs=false was blocked (rightly); instead the flake + its 5 pinned inputs are copied with --no-check-sigs, downloads stay signature-checked.
4. Desktop up, but nothing connected: laptops defaulted to Tailscale addresses and the laptop wasn't on Tailscale. New `alis.network = "auto"` (laptop default): home address first, Tailscale fallback, dashboard last falls back to the built-in copy (`pkgs/alis-open-url.nix`, tested with down/up/both-down cases).

**Result:** ALIS OS desktop running on the HP (photo confirmed: wallpaper, start menu, taskbar).

## 2026-11-06 — ALIS Assistant built into ALIS OS (Stage A)

**Asked:** build ALIS Assistant into ALIS OS, always there, with mute and stop, the voice animation as her look. Choices: orb pops up when called; hard-off mute, stop button, keyboard shortcuts; PCs/laptops and kiosks; "as much as we can give her to do, fully functional and web connected".

**Done (Stage A, PCs/laptops):**
- `pkgs/alis-assistant/assistant.py`: stdlib Python. Mic via parec → NEST `/api/wake/ws` (hey_alis) → record to silence → `/api/stt` → PC-only commands or `/api/brain` (caps open_app, phone_media, phone_volume, brightness, wifi, bluetooth) → carries out the brain's action → `/api/tts` → paplay, orb pulses from the real reply audio. Local control server on 127.0.0.1:47100 (talk/stop/mute/unmute/status, orb page + SSE).
- `orb.html`: the phone app's ported NEST orb + Mute/Stop buttons and the live state feed.
- `modules/assistant.nix`: user service in the desktop session, Win+A / Win+Shift+A shortcuts, start-menu controls, KWin rule (borderless, on top, not in taskbar), brightnessctl permissions.
- `tests/assistant_test.py`: pretend NEST + pretend mic, 14 checks all passing. Found and fixed a real bug: after mute, the wake-word link stayed stuck so unmute never resumed listening.

**Decisions / notes:**
- Web questions already come through the brain → Home Assistant's conversation agent (the Claude agent), so no separate web search engine was added; "search the web for…" opens a DuckDuckGo search.
- PC-only commands live in the assistant for now; flagged to move into brain.py as new caps (not edited: alis-live is a live module).
- Not yet tested on real hardware: real mic/speakers, KDE shortcut registration, the KWin orb rule.
- Kiosk + reading notifications = Stage B.

## 2026-11-06 (cont.) — PANE, the Personal ALIS Network Explorer

**Asked:** skin Chromium as PANE with the ALIS look; then skin the other apps (office, calculator, settings, taskbar…); then a second laptop test.
**Choices:** ALIS start page; DuckDuckGo; ALIS bookmarks bar, uBlock Origin Lite, dark web pages.
**Done:** `pkgs/pane` (MV3 colour theme loaded by the `pane` wrapper with --force-dark-mode, start page built on alis-core's alis_glass_theme.css, PANE icon, desktop entry renamed to PANE under Chromium's own desktop-file name so the taskbar shows it) + `modules/pane.nix` (Chromium policies: start page, search, managed "ALIS" bookmarks, uBO Lite force-install, no promos/sign-in/metrics; /etc/pane/links.js generated from the module registry). Verified by launching PANE with the policies on a virtual screen and screenshotting: theme, start page, bookmarks folder, home button all applied.

## 2026-11-06 (cont.) — ALIS Glass theme pack + VM desktop test

**Choices:** frosted glass apps; ALIS glow edge; floating glass dock; both office suites.
**Done:** alis-fonts (pinned google/fonts), Kvantum "ALIS Glass" generated from KvFlat (all colours moved onto the ALIS palette, frosted translucency), "ALIS Glass" Global Theme with dock layout (floating, fit-to-content, centred, ALIS logo start button, pinned apps), KWin blur, teal Breeze shadow glow, ALIS fonts in kdeglobals, LibreOffice (Qt6) + OnlyOffice dark, KCalc colours, lock-screen wallpaper. First-login script versioned (alis.theme.version = 2) so the HP picks up the new look once.
**Tested:** full desktop ISO in a VM — floating glass dock with ALIS start button, Exo 2 titles, Rajdhani everywhere, teal selection/sliders, teal window glow, Dolphin + System Settings fully ALIS, NAS/stash under Places, dashboard fell back to the built-in copy. Found + fixed: KCalc grey buttons, default lock-screen wallpaper. Not fixed: desktop dashboard asks for location once (one click).
**Test-harness lessons:** KDE's platform plugin crashes outside a real Plasma session (side-tests can't show the true look — boot the real desktop instead); typing via QEMU needs ( ) mapped.

## 2026-11-06 (cont.) — Assistant overlay: orb from the top-right, controls by the dock

**Asked:** the centred orb is annoying with false positives; have her balloon in from the top-right corner, with Stop and Mic-off sliding in separately just above the tray end of the taskbar.
**Done:** `pkgs/alis-assistant/alis-ui.qml` — two see-through KDE layer-shell overlays (no window frame, never in the taskbar, never steals focus): the NEST orb redrawn in QML (conic teal→violet ring, glow pulsing with her voice, helix) anchored top-right, ballooning out (OutBack overshoot) and shrinking back; Mic/Stop glass buttons anchored bottom-right 76 px up, sliding in while active, red mic stays while muted. Polls the assistant's /api/status. Chromium orb + KWin rule removed. False wakes: listening gives up after 3.5 s of silence (was 5).
**Tested:** in a headless Wayland compositor (sway, layer-shell) with a pretend assistant: idle → nothing; balloon frames; listening; speaking; done → gone; muted → red mic only. Packaged overlay drew the orb. Assistant end-to-end test still 14/14. (Qt Quick needs QT_QUICK_BACKEND=software in the GPU-less test only.)

## 2026-11-06 (cont.) — Fix: "Hey ALIS" shows the orb but she doesn't listen (HP laptop)

**Cause:** speech detection used NEST's fixed 0.02 loudness threshold. NEST gets Chrome's automatic mic gain; ALIS OS reads the raw mic (parec), where laptop speech is ~0.01 RMS. Also the room-noise estimate learned from "Hey ALIS" itself, raising the bar right before listening.
**Fix:** threshold = 3× the room's quiet level (min 0.004); noise tracker falls fast / rises slowly; ~1 s pre-roll so one-breath commands aren't cut; "I didn't catch that" shown instead of vanishing; each listen logged (room/threshold/loudest/spoke) for journalctl.
**Tested:** assistant test now uses raw laptop-level audio (speech ~0.011): new version 15/15; the previous version reproduces the bug (wakes, hears nothing).

## 2026-11-06 (cont.) — Laptop test 2 passed; office PC prep

**Result on the HP:** after the update, "Hey ALIS" → orb from the top-right → she hears and answers out loud (full voice chain on real hardware).
**Next (Alan's choice):** office PC install (Stage 2b): ALIS OS into Ubuntu's space, Windows kept. Waiting on Alan's disk layout (lsblk, ESP size, efibootmgr) and BitLocker status before building the "keep Windows" installer mode. Risks flagged: small (100 MB) shared EFI partition → 1 GB XBOOTLDR carved from Ubuntu's space if needed; BitLocker recovery key before any boot-menu change; copy anything wanted from Ubuntu to stash first.
Added `machines/office-pc` (desktop role) — not installable until Stage 2b exists.
- Office PC: BitLocker OFF on C: (Protection Off, fully decrypted) → no recovery-key risk. Nothing on Ubuntu to keep. C: is 930 GB (≈ a whole 1 TB disk) → Ubuntu may be on a separate drive; if so, install whole-disk onto Ubuntu's drive and never write to the Windows drive. Waiting on lsblk / df /boot/efi / efibootmgr.

## 2026-11-06 (cont.) — Office PC install mode tested (VM)

**Layout (from Alan's Disk Management):** Windows 11 on Disk 3 with its own 100 MB EFI partition; four NTFS games drives (ARCADE 3.7 TB, Games, New Games, Steam); Ubuntu on Disk 5, a 119 GB NVMe (M.2 2230 from the Surface Pro 4) with its own 1 GB EFI partition. BitLocker off. **Decision:** keep picking the drive at boot (F8), so a plain whole-disk install onto the NVMe; nothing reads or writes the Windows drive.
**Installer change:** each disk labelled (Windows/NTFS files + labels, Windows start-up files, Linux); Windows/NTFS disks in red and need typing NTFS.
**VM test** (fake Windows disk with ESP + bootmgfw.efi + NTFS, fake "Games" NTFS disk, fake 20 GB Ubuntu disk): labels correct; picking Games refused without NTFS ("Nothing was changed"); install onto the Ubuntu disk OK; **Windows and Games disk images byte-for-byte identical (sha256) afterwards**; booted ALIS OS from the Ubuntu disk with the other two attached; system running.
**Hiccup:** this cloud box ran out of disk mid-test; QEMU paused the VM (io-error) until space was freed and it was resumed.

## 2026-11-06 (cont.) — Office PC install: "build-vms.nix lacks a signature"

**Cause:** the online build used `--eval-store auto --store /mnt`: files created while working out the system land in the USB's store and are then COPIED to /mnt, and copies (unlike substitutes via auto?trusted=1) need signatures the USB's paths don't have. The laptop install happened not to need any such file built locally. Couldn't reproduce here: on this box root's own store paths are fully trusted.
**Fix:** evaluate directly on the target (`nix build --store /mnt`, as the official nixos-install does); the pinned sources are still pre-copied so nothing is fetched from GitHub. Workaround on the current USB: copy alis-install, `sed 's/--eval-store auto //'`, run the copy.

## 2026-11-06 (cont.) — Office PC installed

ALIS OS installed on the office PC's Samsung MZFLV128 NVMe (M.2_4) with the patched installer (evaluate on target); Windows (WD 1 TB, M.2_1) and the games drives untouched; Windows still chosen via F8. Hardware file pushed by Alan (c50099c: nvme/xhci/ahci, kvm-intel, Intel microcode); office-pc recipe builds with it. Two ALIS OS machines now real: spare-laptop (HP 15-db0) and office-pc.

## 2026-11-06 (cont.) — Stage 4: auto-updates + nightly backups

**Choices:** updates apply on next restart; versions move weekly on dev-automation after a build check; backups to a stash folder; home minus junk.
**Done:** modules/updates.nix (nightly 03:30/Persistent, git pull + flake archive as alan, nixos-rebuild boot, battery skip, notifications), modules/backup.nix (restic → stash/ALIS backups/<machine>, excludes, 7/4/6 retention, alis-backup-setup, alis-backup-browse via restic mount), pkgs/alis-notify.nix, enabled for installed machines only; tools/weekly-update.sh + install script (dev-automation user timer, real builds of every machine + assistant test before pushing, alis-push to phone).
**Tested:** tests/upkeep.nix VM test 6/6 (timers; no-password refusal; backup includes Documents + /var/lib/alis, excludes Downloads/.cache; byte-exact restore; second snapshot; update job without repo explains). Weekly script shellchecked but not run here (it pushes to the real branch) — first run on dev-automation.
**Also asked:** Tailscale on office PC (already installed: `sudo tailscale up`); ALIS duotone icon theme from Papirus (roadmap 5f, next).

## 2026-11-06 (cont.) — Office PC: stash + first real backup

- `ls /mnt/nas/stash` said "No such device" until a restart (new kernel from the update); then `mount error(13)`: wrong password in /etc/alis/nas-credentials (smbclient: NT_STATUS_LOGON_FAILURE) → fixed by Alan; smbclient lists shares incl. stash.
- Dolphin sidebar "stash" (Remote) failed: "not installed setuid root" → fixed (f98d53f: setuid mount.cifs + "user" option).
- `sudo alis-backup-setup` + first run: **snapshot 4738ad25 saved, 170 MiB of /home stored as 50 MiB**, retention 7/4/6 applied. Nightly from now on.
- Desktop settings "reverted" after restart: config files untouched since the 18:00 first-login look step, i.e. ALIS didn't re-apply; changes made after 18:00 were most likely never saved by Plasma before the restart. Awaiting Alan's photo/details.

## 2026-11-06 — Office PC: PipeWire crash + desktop background still wrong

**Asked:** KDE crash reporter kept popping up coredumps; desktop background still wrong after logging out/in.
**Found:** One real crash: PipeWire (sound) segfaulted in its `x11-bell` add-on when Xwayland went away at log-out (the ~20 drkonqi dumps were the crash reporter itself failing to open its window). Sound restarted on its own.
**Done:**
- Disabled PipeWire's x11-bell module (`module.x11.bell = false`) on desktops/laptops.
- Wallpaper: the Global Theme had no default wallpaper, so any desktop Plasma creates later (e.g. a screen that comes up after a restart) got the Plasma default picture. Added `[Wallpaper] Image=ALIS` to the look-and-feel defaults.
- First-login now sets the wallpaper from the stable `/etc/alis/artwork/splash.png` instead of a /nix/store path (which the weekly clean-up would delete after an update).
- One-off repair (own marker `alis-wallpaper-fix-v1`, no layout reset) puts the ALIS wallpaper on every screen at next login.

## 2026-11-06 — Fix: office PC rebuild failed on the mount.cifs wrapper

**Asked:** `nixos-rebuild switch` failed: "path …cifs-utils-7.5/bin/mount.cifs does not exist".
**Cause:** cifs-utils puts its programs in a separate `bin` output; the setuid wrapper (f98d53f) pointed at the main output. Earlier checks were dry-runs, which don't run the wrapper check.
**Done:** `source = "${lib.getBin pkgs.cifs-utils}/bin/mount.cifs"`; did a real full build of office-pc (passes). Lesson: real-build (not dry-run) after changing security.wrappers.

## 2026-11-06 — Confirmed on the office PC

After rebuilding (f4d98b1) and logging back in: ALIS background showing, and Dolphin's NAS sidebar link opens stash with no setuid error.

## 2026-11-06 — ALIS icons enabled (5f)

**Asked:** User saw the before/after preview (30 key icons: apps, folders, tray) and chose "Looks good, enable it".
**Done:** alis-icons package installed on desktops/laptops; system default `[Icons] Theme=ALIS` (/etc/xdg/kdeglobals + Global Theme defaults); one-off switch at next login (marker `alis-icons-v1`, kwriteconfig6 + plasma-changeicons). alis.theme.version NOT bumped, so the dock and layout aren't reset. Theme inherits breeze-dark/hicolor for anything Papirus lacks.

## 2026-11-06 — App launcher (start button) blank on the office PC

**Found:** ALIS icons now showing after clearing ~/.cache/icon-cache.kcache and re-logging. Start button config was `icon=/etc/alis/artwork/logo.png` (a file path), which the dock drew blank.
**Done:** ALIS logo installed as a named icon `alis-logo` (hicolor, svg + 256 png); Global Theme layout uses it; one-off fix (marker `alis-launcher-icon-v1`) switches existing start buttons still on the old file path, via plasmashell's scripting D-Bus call — a person's own pick is left alone. Real builds of office-pc + spare-laptop pass.
