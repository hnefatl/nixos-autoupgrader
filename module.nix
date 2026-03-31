{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.nixos-autoupgrade;
  autoupgrade = import ./autoupgrade.nix { inherit pkgs; };
in
{
  options = {
    nixos-autoupgrade = {
      enable = lib.mkEnableOption "Enable nixos-autoupgrade";

      when = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "When to run autoupgrades, formatted as an `OnCalendar` timer string: https://wiki.archlinux.org/title/Systemd/Timers#Realtime_timer";
      };

      args = {
        os-flake-dir = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "/etc/nixos/os";
          description = "Directory containing NixOS flake to update";
        };
        home-flake-dir = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "/etc/nixos/home";
          description = "Directory containing home-manager flake to update";
        };
        home-user = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "keith";
          description = "Which user to run the home-manager upgrade as";
        };
        update-inputs = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "nixpkgs nixpkgs-unstable";
          description = "Space-separated list of flake inputs to update. Defaults to all inputs.";
        };
        from-email = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "foo@bar.com";
          description = "Which address to send a result email from.";
        };
        to-email = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "foo@bar.com";
          description = "Which address to send a result email to.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.nixos-autoupgrade = {
      timerConfig = {
        OnCalender = cfg.when;
      };
      wantedBy = [ "timers.target" ];
    };
    systemd.services.nixos-autoupgrade = {
      serviceConfig = {
        ExecStart = lib.strings.join " " [
          "${autoupgrade}/bin/autoupgrade"
          "--os_flake_dir=${cfg.args.os-flake-dir}"
          "--home_flake_dir=${cfg.args.home-flake-dir}"
          "--home_user=${cfg.args.home-user}"
          "--update_inputs=${cfg.args.update-inputs}"
          "--from_email=${cfg.args.from-email}"
          "--to_email=${cfg.args.to-email}"
        ];
      };
    };
  };
}
