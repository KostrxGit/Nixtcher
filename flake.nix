{
  description = "Konstanty's NixOS laptop (ThinkPad X1 Yoga Gen 7)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      settings = import ./settings.nix;
    in
    {
      nixosConfigurations.${settings.hostname} = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs settings; };
        modules = [ ./hosts/x1-yoga ];
      };

      # `nix flake init -t ~/nixos#node` etc. inside a new project
      templates = {
        node = {
          path = ./templates/node;
          description = "Node / TypeScript / React";
        };
        expo = {
          path = ./templates/expo;
          description = "Expo / React Native with Android tools";
        };
        python = {
          path = ./templates/python;
          description = "Python with uv";
        };
        rust = {
          path = ./templates/rust;
          description = "Rust";
        };
      };
    };
}
