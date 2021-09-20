{ externalOverrides ? {}
}:

let

    external = import ./external // externalOverrides;

    nix-project = import external.nix-project;

    nixpkgs = import external.nixpkgs-stable {
        config = {};
        overlays = [ overlay ];
    };

    overlay = self: _super: nix-project // {
        nix-project-multi = self.callPackage ./multi.nix {};
    };

    distribution = {
        inherit (nixpkgs) nix-project-multi;
    };

in {
    inherit
    distribution
    nixpkgs
    nix-project;
}
