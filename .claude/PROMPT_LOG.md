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
