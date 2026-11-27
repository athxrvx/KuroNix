{ pkgs, ... }:
let
  lidIsClosed = ''
    lid_is_closed() {
      local state
      for state in /proc/acpi/button/lid/*/state; do
        [ -r "$state" ] || continue
        ${pkgs.gnugrep}/bin/grep -qiE 'state:[[:space:]]*closed' "$state" && return 0
      done
      return 1
    }
  '';
in
{
  # ACPI handles lid close so Kuro is locked before the machine suspends.
  # Keep the ACPI lid device armed so opening the lid can wake the machine.
  services.udev.extraRules = ''
    SUBSYSTEM=="platform", KERNEL=="PNP0C0D:00", ATTR{power/wakeup}="enabled"
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  services.acpid = {
    enable = true;
    handlers.lid-close = {
      event = "button/lid.*";
      action = ''
        case "$1" in
          *close*) ${pkgs.systemd}/bin/systemctl start lid-close-suspend.service ;;
          *open*)
            ${pkgs.systemd}/bin/systemctl stop lid-close-suspend.service
            ;;
        esac
      '';
    };
  };

  systemd.services.lid-close-suspend = {
    description = "Lock Kuro and hibernate when the laptop lid closes";
    serviceConfig.Type = "oneshot";
    script = ''
      ${lidIsClosed}
      lid_is_closed || exit 0

      if ! ${pkgs.systemd}/bin/systemctl --user --machine=atharva@.host start kuro-shell-lid-lock.service; then
        echo "Kuro lock service failed; aborting lid-close hibernation" >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/sleep 1

      # The lid may have been reopened while Kuro was locking.
      lid_is_closed && ${pkgs.systemd}/bin/systemctl hibernate
    '';
  };
}
