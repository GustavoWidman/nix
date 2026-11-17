# Temporary: prepares this host for shimeji's benchmark runs. Deleting this file undoes it on the
# next switch, apart from the kernel parameters, which leave with the next boot.
{ lib, pkgs, ... }:
let
  # i9-13900K: logical CPUs 0-15 are the eight P-cores, two threads each (P-core n is CPUs 2n and
  # 2n+1), and 16-31 are the sixteen E-cores. P-cores 4 to 7 (CPUs 8-15) are reserved for
  # measuring; a benchmark runs on the first thread of one of them and leaves its sibling idle.
  benchCpus = "8-15";
  otherCpus = "0-7,16-31";
  # The same set as a hex mask, which /proc/irq/default_smp_affinity requires.
  otherMask = "ffff00ff";

  # Bench mode runs every core at its base clock with turbo off, for the length of a measurement
  # session, and `off` restores the governor, frequency limits and IRQ affinity it saved.
  benchMode = pkgs.writeShellApplication {
    name = "shimeji-bench-mode";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      cpu=/sys/devices/system/cpu
      state=/run/shimeji-bench

      save() {
        mkdir -p "$state"
        cat "$cpu/intel_pstate/no_turbo" > "$state/no_turbo"
        for policy in "$cpu"/cpufreq/policy*; do
          name=$(basename "$policy")
          cat "$policy/scaling_governor" > "$state/$name.governor"
          if [ -e "$policy/energy_performance_preference" ]; then
            cat "$policy/energy_performance_preference" > "$state/$name.epp"
          fi
        done
        cat /proc/irq/default_smp_affinity > "$state/default_smp_affinity"
      }

      on() {
        [ -d "$state" ] || save
        echo 1 > "$cpu/intel_pstate/no_turbo"
        for policy in "$cpu"/cpufreq/policy*; do
          echo performance > "$policy/scaling_governor"
          if [ -e "$policy/energy_performance_preference" ]; then
            echo performance > "$policy/energy_performance_preference"
          fi
        done
        echo "${otherMask}" > /proc/irq/default_smp_affinity
        for irq in /proc/irq/[0-9]*; do
          echo "${otherCpus}" > "$irq/smp_affinity_list" 2>/dev/null || true
        done
      }

      off() {
        [ -d "$state" ] || { echo "bench mode is not on"; return 0; }
        cat "$state/no_turbo" > "$cpu/intel_pstate/no_turbo"
        for policy in "$cpu"/cpufreq/policy*; do
          name=$(basename "$policy")
          cat "$state/$name.governor" > "$policy/scaling_governor"
          if [ -e "$state/$name.epp" ]; then
            cat "$state/$name.epp" > "$policy/energy_performance_preference"
          fi
        done
        cat "$state/default_smp_affinity" > /proc/irq/default_smp_affinity
        rm -rf "$state"
      }

      status() {
        echo "bench mode:      $([ -d "$state" ] && echo on || echo off)"
        echo "no_turbo:        $(cat "$cpu/intel_pstate/no_turbo")"
        for n in 8 10 12 14; do
          echo "cpu$n:           $(cat "$cpu/cpu$n/cpufreq/scaling_governor"), $(cat "$cpu/cpu$n/cpufreq/scaling_cur_freq") kHz"
        done
        echo "isolated cpus:   $(cat "$cpu/isolated")"
        echo "nohz_full cpus:  $(cat "$cpu/nohz_full" 2>/dev/null || echo unsupported)"
        echo "perf paranoid:   $(cat /proc/sys/kernel/perf_event_paranoid)"
      }

      case "''${1:-status}" in
        on) on; status ;;
        off) off; status ;;
        status) status ;;
        *) echo "usage: shimeji-bench-mode on|off|status" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  # The harness reads cycles and retired instructions with perf_event_open. The shared kernel
  # module sets 3, which forbids that for unprivileged users.
  boot.kernel.sysctl."kernel.perf_event_paranoid" = lib.mkForce 1;

  # The NMI watchdog holds a hardware counter; freeing it keeps perf from multiplexing.
  boot.kernel.sysctl."kernel.nmi_watchdog" = 0;

  # Keep the scheduler, the timer tick and RCU callbacks off the measurement cores.
  boot.kernelParams = [
    "isolcpus=${benchCpus}"
    "nohz_full=${benchCpus}"
    "rcu_nocbs=${benchCpus}"
  ];

  environment.systemPackages = [ benchMode ];

  security.sudo.extraRules = [
    {
      users = [ "r3dlust" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/shimeji-bench-mode";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
