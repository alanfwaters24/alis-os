{
  description = "ALIS OS — the ALIS ecosystem as a Linux distribution (built on NixOS)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";

    # The ALIS dashboard gets baked into the image so every machine has it,
    # even with no network. Private repo — see README "Building" for the
    # one-line GitHub token setup.
    alis-dashboard = {
      url = "github:alanfwaters24/alis-dashboard";
      flake = false;
    };

    # Brain-role modules (private repos, code only — no secrets: each app's
    # config.json / .env / data stay on the machine, see modules/apps.nix).
    alis-live = { url = "github:alanfwaters24/alis-live"; flake = false; };
    alis-push = { url = "github:alanfwaters24/alis-push"; flake = false; };
    glance = { url = "github:alanfwaters24/glance"; flake = false; };
  };

  outputs = { self, nixpkgs, alis-dashboard, alis-live, alis-push, glance }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Everything ALIS OS adds on top of plain NixOS, as one importable module.
      alisModule = {
        imports = [ ./modules ];
        alis.dashboard.src = alis-dashboard;
        alis.brain.sources = { inherit alis-live alis-push glance; };
      };

      mkAlis = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ alisModule ] ++ extraModules;
      };
    in
    {
      # Other repos (e.g. alis-os-home) can import this to become ALIS machines.
      nixosModules.default = alisModule;

      nixosConfigurations = {
        # Stage 1: live test image — boots straight into the ALIS dashboard.
        alis-live-test = mkAlis [ ./hosts/live-test.nix ];
        # Same, for the desktop role (KDE Plasma, ALIS-themed).
        alis-desktop-test = mkAlis [ ./hosts/live-desktop.nix ];
      };

      packages.${system} = {
        # Bootable USB/DVD image:   nix build .#iso
        iso = self.nixosConfigurations.alis-live-test.config.system.build.isoImage;
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
        # A Brain that uses an existing Home Assistant instead of its own.
        brain-existing-ha = (mkAlis [{
          alis.role = "brain";
          alis.homeAssistant.url = "http://192.168.1.251:8123";
          networking.hostName = "alis-example-brain-ha";
          fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
          boot.loader.systemd-boot.enable = true;
          system.stateVersion = "26.05";
        }]).config.system.build.toplevel;
      };
    };
}
