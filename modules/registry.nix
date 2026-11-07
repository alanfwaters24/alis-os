# Every ALIS module, from alis-core/ports_and_env.json (29 Oct 2026) and
# ALIS-CORE.md (1 Nov 2026). When a module is added or moves port there,
# update it here too.
#
#   host       where it runs today (for "link" mode defaults)
#   port       LAN port            tsPort   Tailscale HTTPS port
#   ui         has a web page → gets a start-menu app on PCs/laptops
#   live       running today → linked by default on PCs/laptops
#   builtin    ALIS OS can run it itself (recipe in roles/brain.nix)
let
  devAutomation = { lan = "192.168.1.235"; ts = "dev-automation.tail80e958.ts.net"; };
  brainVm = { lan = "192.168.1.251"; ts = null; }; # not on Tailscale yet
  vault = { lan = "192.168.1.252"; ts = "truenas-scale.tail80e958.ts.net"; };
in
{
  nest = { title = "ALIS NEST"; about = "Dashboard + shared brain (alis-live)"; host = devAutomation; port = 8080; tsPort = 443; ui = true; live = true; builtin = true; };
  push = { title = "alis-push"; about = "Notifications for every ALIS app"; host = devAutomation; port = 8091; tsPort = 10001; ui = false; live = true; builtin = true; };
  glance = { title = "GLANCE"; about = "Daily brief"; host = devAutomation; port = 3512; tsPort = 10006; ui = true; live = true; builtin = true; };
  homeassistant = { title = "Home Assistant"; about = "Smart home"; host = brainVm; port = 8123; tsPort = null; ui = true; live = true; builtin = true; };
  voice = { title = "ALIS voice"; about = "Whisper + Piper + openWakeWord (Wyoming 10300/10200/10400)"; host = brainVm; port = 10200; tsPort = null; ui = false; live = true; builtin = true; scheme = "tcp"; };
  ollama = { title = "Ollama"; about = "Local AI"; host = brainVm; port = 11434; tsPort = null; ui = false; live = true; builtin = true; };

  score = { title = "SCORE"; about = "Sports Centre Of Results & Events"; host = devAutomation; port = 3503; tsPort = null; ui = true; live = true; builtin = false; };
  dose = { title = "DOSE"; about = "Daily Organiser of Scheduled Essentials"; host = devAutomation; port = null; tsPort = 10000; ui = true; live = true; builtin = false; };
  nova = { title = "NOVA"; about = "Notes Over Voice & Audio"; host = devAutomation; port = 3507; tsPort = 10003; ui = true; live = true; builtin = false; };
  arch = { title = "ARCH"; about = "ALIS App Store"; host = devAutomation; port = null; tsPort = 10002; ui = true; live = true; builtin = false; };
  stall = { title = "STALL"; about = "Etsy listings (Katie's shop)"; host = devAutomation; port = 3514; tsPort = 10007; ui = true; live = true; builtin = false; };
  speak = { title = "ALIS Speak"; about = "Text-to-speech server"; host = devAutomation; port = 3513; tsPort = null; ui = false; live = true; builtin = false; };
  vault = { title = "VAULT"; about = "NAS admin (TrueNAS)"; host = vault; port = 80; tsPort = null; ui = true; live = true; builtin = false; };
  flick = { title = "FLICK"; about = "Films & TV (Jellyfin)"; host = vault; port = 8096; tsPort = null; ui = true; live = false; builtin = false; };

  fuel = { title = "FUEL"; about = "Food & Usage Energy Log"; host = devAutomation; port = 3501; tsPort = 10004; ui = true; live = false; builtin = false; };
  earn = { title = "EARN"; about = "Everyday Achievement & Reward Network"; host = devAutomation; port = 3504; tsPort = null; ui = true; live = false; builtin = false; };
  peny = { title = "PENY"; about = "Personal Expenditure & Net Yield"; host = devAutomation; port = 4278; tsPort = null; ui = true; live = false; builtin = false; };
  post = { title = "POST"; about = "Private, Open-Standard Transport (mail)"; host = devAutomation; port = 3505; tsPort = null; ui = true; live = false; builtin = false; };
  snap = { title = "SNAP"; about = "Shared Network Archive of Photos"; host = devAutomation; port = 3506; tsPort = null; ui = true; live = false; builtin = false; };
  roam = { title = "ROAM"; about = "On-the-move assistant"; host = devAutomation; port = 3508; tsPort = null; ui = true; live = false; builtin = false; };
  arcade = { title = "ARCADE"; about = "Games"; host = devAutomation; port = 3509; tsPort = null; ui = true; live = false; builtin = false; };
  swap = { title = "SWAP"; about = "Sync With Another Platform (music)"; host = devAutomation; port = 3510; tsPort = 10005; ui = true; live = false; builtin = false; };
  suite = { title = "ALIS Suite"; about = "Suite shell"; host = devAutomation; port = 3500; tsPort = null; ui = true; live = false; builtin = false; };
}
