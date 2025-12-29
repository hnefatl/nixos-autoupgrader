{
  pkgs,
  version ? "1.3.0",
  hash ? "sha256-qOFPSYglb6p8GxagXVHdJW2namUCxi3REuR55On8QEo=",
  ...
}:
let
  src = pkgs.fetchFromGitHub {
    owner = "kward";
    repo = "shflags";
    rev = "v${version}";
    inherit hash;
  };
in
pkgs.writeTextFile {
  name = "shflags.sh";
  # Make sure it ends up in PATH, so dependees can source it.
  destination = "/bin/shflags.sh";

  text = builtins.readFile "${src}/shflags";
}
