{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      formatter."${system}" = pkgs.nixfmt-tree;
      devShells."${system}".default = pkgs.mkShell {
        packages = [ pkgs.bashInteractive ];
      };
      packages."${system}" = {
        default = import ./autoupgrade.nix { inherit pkgs; };
      };
    };
}
