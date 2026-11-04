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
