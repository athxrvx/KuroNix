{ ... }:
{
  # Ryzen 7 8845HS supports AMD P-State EPP. Let the active driver balance
  # boost clocks against temperature and power limits; TuneD owns the policy.
  boot.kernelParams = [ "amd_pstate=active" ];

  # Kernel sleep/hibernate and UPower are infrastructure, not competing
  # governors. UPower is also required by tuned-ppd for battery detection.
  powerManagement.enable = true;
  services.upower.enable = true;

  services.tuned = {
    enable = true;
    ppdSupport = true;
    ppdSettings.main.default = "balanced";
  };

  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = false;
  services.tlp.enable = false;
  hardware.system76.power-daemon.enable = false;
}
