{
  description = "ALIS OS — the ALIS ecosystem as a Linux distribution (built on NixOS)";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";

    # The ALIS dashboard gets baked into the image so every machine has it,
    # even with no network. Private repo — see README "Building" for the
    # one-line GitHub token setup.
    alis-dashboard = {
      url = "git+https://github.com/alanfwaters24/alis-dashboard";
      flake = false;
    };

    # Brain-role modules (private repos, code only — no secrets: each app's
    # config.json / .env / data stay on the machine, see modules/apps.nix).
    alis-live = { url = "git+https://github.com/alanfwaters24/alis-live"; flake = false; };
    alis-push = { url = "git+https://github.com/alanfwaters24/alis-push"; flake = false; };
    glance = { url = "git+https://github.com/alanfwaters24/glance"; flake = false; };

    # Secure Boot (modules/secure-boot.nix): Lanzaboote signs ALIS's boot
    # files with the machine's own key. Its helpers are pinned to the exact
    # versions Lanzaboote 1.2.0 shipped with; its dev-only git hooks are skipped.
    lanzaboote = {
      url = "git+https://github.com/nix-community/lanzaboote?ref=refs/tags/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.crane.follows = "lanzaboote-crane";
      inputs.rust-overlay.follows = "lanzaboote-rust-overlay";
      inputs.pre-commit.follows = "";
    };
    lanzaboote-crane.url = "git+https://github.com/ipetkov/crane?rev=73b980519cefc727a5f6cc8e5c0947a2f9be6edd";
    lanzaboote-rust-overlay = {
      url = "git+https://github.com/oxalica/rust-overlay?rev=1fb104a12a8667045559b2575d6d448ae2fbd99b&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, alis-dashboard, alis-live, alis-push, glance, lanzaboote, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Everything ALIS OS adds on top of plain NixOS, as one importable module.
      alisModule = {
        imports = [ ./modules lanzaboote.nixosModules.lanzaboote ];
        alis.dashboard.src = alis-dashboard;
        alis.brain.sources = { inherit alis-live alis-push glance; };
      };

      mkAlis = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ alisModule ] ++ extraModules;
      };

      # Real machines: one folder each in machines/ (see machines/README.md).
      machineConfigs = nixpkgs.lib.mapAttrs
        (name: _: mkAlis [ ./modules/machine.nix { alis.machine = name; } ./machines/${name} ])
        (nixpkgs.lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./machines));

      installer = preinstalled: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          alisFlake = self.outPath;
          alisInputs = { inherit nixpkgs alis-dashboard alis-live alis-push glance; };
          inherit preinstalled;
        };
        modules = [ ./hosts/installer.nix ];
      };
    in
    {
      # Other repos (e.g. alis-os-home) can import this to become ALIS machines.
      nixosModules.default = alisModule;

      nixosConfigurations = machineConfigs // {
        # Stage 1: live test image — boots straight into the ALIS dashboard.
        alis-live-test = mkAlis [ ./hosts/live-test.nix ];
        # Same, for the desktop role (KDE Plasma, ALIS-themed).
        alis-desktop-test = mkAlis [ ./hosts/live-desktop.nix ];
      };

      packages.${system} = {
        # Bootable USB/DVD image:   nix build .#iso
        iso = self.nixosConfigurations.alis-live-test.config.system.build.isoImage;
        # The ALIS OS installer USB:   nix build .#installer
        installer = (installer [ ]).config.system.build.isoImage;
        # Installer with the vm-test machine already on it (offline VM test).
        installer-vmtest = (installer [
          self.nixosConfigurations.vm-test.config.system.build.toplevel
        ]).config.system.build.isoImage;
        # Desktop-role live image:   nix build .#iso-desktop
        iso-desktop = self.nixosConfigurations.alis-desktop-test.config.system.build.isoImage;
        # Quick virtual-machine test:   nix run .#vm
        vm = self.nixosConfigurations.alis-live-test.config.system.build.vm;
        # The ALIS logo / boot splash on its own (handy for checking artwork).
        artwork = pkgs.callPackage ./artwork { };
        default = self.packages.${system}.iso;
      };

      # `nix flake check` builds one example machine per role, so a change
      # that breaks e.g. the server role is caught before it reaches a real box.
      checks.${system} = nixpkgs.lib.genAttrs [ "kiosk" "desktop" "laptop" "server" "brain" ] (role:
        (mkAlis [{
          alis.role = role;
          networking.hostName = "alis-example-${role}";
          fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
          boot.loader.systemd-boot.enable = true;
          system.stateVersion = "26.05";
        }]).config.system.build.toplevel)
      // {
        # Boots a Brain in a VM and checks each service answers.
        brain-boot = import ./tests/brain.nix { inherit pkgs alisModule; };
        # Backups + update job safety on an installed-style machine.
        upkeep = import ./tests/upkeep.nix { inherit pkgs alisModule; };
        # The boot picker on a UEFI machine with a second "Windows" drive.
        boot-picker = import ./tests/boot-picker.nix { inherit pkgs alisModule; };
        # Secure Boot on (office PC, for Fortnite tournaments): enroll, then both tiles.
        secure-boot = import ./tests/secure-boot.nix { inherit pkgs alisModule; };
        # An office PC linked to the existing Brain, HA and NAS shares.
        desktop-existing-brain = (mkAlis [{
          alis.role = "desktop";
          alis.modules.fuel.mode = "link";
          alis.nas.shares = { stash = { }; alan = { mount = false; }; };
          networking.hostName = "alis-example-desktop-linked";
          fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
          boot.loader.systemd-boot.enable = true;
          system.stateVersion = "26.05";
        }]).config.system.build.toplevel;
        # A Brain that uses an existing Home Assistant instead of its own.
        brain-existing-ha = (mkAlis [{
          alis.role = "brain";
          alis.modules.homeassistant.mode = "link";
          networking.hostName = "alis-example-brain-ha";
          fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
          boot.loader.systemd-boot.enable = true;
          system.stateVersion = "26.05";
        }]).config.system.build.toplevel;
      };
    };
}
