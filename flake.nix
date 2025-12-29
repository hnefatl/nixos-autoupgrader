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
        default = pkgs.writeShellApplication {
          name = "autoupgrade";

          text = pkgs.lib.readFile ./autoupgrade.sh;

          runtimeInputs = with pkgs; [
            (callPackage ./shflags.nix { })
            nix
            aha # ANSI colour codes to HTML markup
            system-sendmail
          ];
        };
      };
    };
}
