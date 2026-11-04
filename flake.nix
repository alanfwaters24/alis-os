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
  };

  outputs = { self, nixpkgs, alis-dashboard }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Everything ALIS OS adds on top of plain NixOS, as one importable module.
      alisModule = {
        imports = [ ./modules ];
        alis.dashboard.src = alis-dashboard;
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
      };

      packages.${system} = {
        # Bootable USB/DVD image:   nix build .#iso
        iso = self.nixosConfigurations.alis-live-test.config.system.build.isoImage;
        # Quick virtual-machine test:   nix run .#vm
        vm = self.nixosConfigurations.alis-live-test.config.system.build.vm;
        # The ALIS logo / boot splash on its own (handy for checking artwork).
        artwork = pkgs.callPackage ./artwork { };
        default = self.packages.${system}.iso;
      };

      # `nix flake check` builds one example machine per role, so a change
      # that breaks e.g. the server role is caught before it reaches a real box.
      checks.${system} = nixpkgs.lib.genAttrs [ "kiosk" "desktop" "laptop" "server" ] (role:
        (mkAlis [{
          alis.role = role;
          networking.hostName = "alis-example-${role}";
          fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
          boot.loader.systemd-boot.enable = true;
          system.stateVersion = "26.05";
        }]).config.system.build.toplevel);
    };
}
