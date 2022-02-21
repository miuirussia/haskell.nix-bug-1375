{
  inputs = {
    nixpkgs = { url = "github:miuirussia/nixpkgs/48331c4cd2d01fd35ac79a6d3f15a59c9a959bec"; };

    # haskell nix
    haskell-nix = {
      url = "github:input-output-hk/haskell.nix/659b73698e06c02cc0f3029383bd383c8acdbe98";
      inputs.nixpkgs.follows = "hnixpkgs";
    };
    hnixpkgs.url = "github:NixOS/nixpkgs/1882c6b7368fd284ad01b0a5b5601ef136321292";
  };
  outputs = inputs @ { self, nixpkgs, ... }:
    let
      findFirst = pred: default: list:
        let
          found = builtins.filter pred list;
        in
        if found == [ ] then default else builtins.head found;

      nixpkgsOverlays =
        let
          path = ./overlays;
        in
        with builtins;
        map (n: (import (path + ("/" + n)) inputs)) (
          filter
            (
              n:
              match ".*\\.nix" n != null
              || pathExists (path + ("/" + n + "/default.nix"))
            )
            (attrNames (readDir path))
        );

      nixpkgsConfig = with inputs; {
        config = {
          allowUnfree = true;
        };
        overlays = nixpkgsOverlays ++ [
          (final: prev:
            let
              overlays = [ haskell-nix.overlay ];
              pkgs = import hnixpkgs { system = final.system; inherit overlays; inherit (haskell-nix) config; };
            in
            {
              inherit (pkgs) haskell-nix;
            })
        ];
      };

      mkNixosModules = { user, host }: [
        ({
          system.stateVersion = "21.11";
        })

        (findFirst builtins.pathExists { } [ /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix ])
        ({ pkgs, ... }: {
          nixpkgs = nixpkgsConfig;
          networking.hostName = host;
          users.mutableUsers = false;
          users.users.${user} = {
            createHome = true;
            extraGroups = [ "wheel" ];
            group = "${user}";
            home = "/home/${user}";
            isNormalUser = true;
            shell = pkgs.zsh;
            password = "123123";
          };
          users.groups.${user} = { };
          environment.systemPackages = with pkgs; [
            curl
            git
            hls
            vim
          ];
        })

      ];
    in
    {
      nixosConfigurations = {
        demo = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs nixpkgs; lib = nixpkgs.lib; };
          modules = mkNixosModules {
            user = "demo";
            host = "demo";
          };
        };
      };
    };
}
