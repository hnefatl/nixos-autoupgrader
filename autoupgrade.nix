{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "autoupgrade";

  text = pkgs.lib.readFile ./autoupgrade.sh;

  runtimeInputs = with pkgs; [
    (callPackage ./shflags.nix { })
    nh
    nix
    aha # ANSI colour codes to HTML markup
    system-sendmail
    git
    # Used by shflags
    coreutils
    toybox
    gawk
  ];
}
