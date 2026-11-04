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
| `laptop` | Spare/old laptops | Desktop + battery modes, suspend on lid close, firmware updates. |
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
| Web browser | Chromium (open-source Chrome) |
| Office (Word/Excel/PowerPoint files) | OnlyOffice |
| Notepad / text editor | KWrite, Kate |
| Calculator | KCalc |
| Storage — what's using space / drives | Filelight, Partition Manager |
| Zip files / downloads | Ark (Downloads folder in your home folder) |
| Photos, PDFs, screenshots | Gwenview, Okular, Spectacle |
| More apps | Discover (app store, with Flathub) |
| Settings & themes | System Settings → Appearance (ALIS Glass is the default colour scheme) |

## Using your existing Home Assistant

```nix
alis.homeAssistant.url = "http://192.168.1.251:8123";
```

The Brain then doesn't run its own Home Assistant, and every ALIS module is
given the address as `ALIS_HA_URL` (also in `/etc/alis/ha-url`). NEST reads
`ha_url` from its own `config.json`, which already defaults to that address.

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
| Ollama — local AI | 11434 | NixOS (no models downloaded unless listed in `alis.brain.ollama.models`) |
| NEST + shared brain (`/api/brain`) | 8080 / 8443 | `alis-live` repo |
| alis-push | 8091 · TS 10001 | `alis-push` repo |
| GLANCE | 3512 · TS 10006 | `glance` repo |

Switch any piece off on its own, e.g. `alis.brain.ollama.enable = false;`.

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
  home-assistant.nix Home Assistant + Matter (copied over from alis-os-home)
roles/               kiosk / desktop / laptop / server / brain
tests/brain.nix      boots a Brain in a VM and checks every service answers
hosts/live-test.nix  Stage 1 live test image
artwork/             logo + splash, drawn from the ALIS Glass palette
```

## Building

The ALIS module repos (dashboard, alis-live, alis-push, glance) are private, so Nix needs your GitHub login once:

```bash
mkdir -p ~/.config/nix
echo "access-tokens = github.com=$(gh auth token)" >> ~/.config/nix/nix.conf
```

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

## Roadmap

- [x] **Stage 1:** bootable live test image → ALIS dashboard
- [ ] **Stage 2:** ALIS installer, real host files (`hosts/office-pc.nix`, `hosts/fridge-tablet.nix`…), first real kiosk
- [x] **Brain role:** HA, voice, Ollama, NEST + brain, alis-push, GLANCE, with a VM boot test
- [ ] **Stage 3:** STALL, then NOVA/FUEL/PENY/EARN as they're rebuilt, into `alis.apps`
- [ ] **Stage 4:** auto-updates from this repo + nightly backup to VAULT built in
- [ ] **Later:** ALIS Glass fonts (Exo 2 / Rajdhani / Share Tech Mono) packaged locally, graphical ALIS greeter, Plymouth theme with the rotating ring
