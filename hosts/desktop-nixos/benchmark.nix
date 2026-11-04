{ lib, pkgs, ... }:
let
  # i9-13900K: logical CPUs 0-15 are the eight P-cores, two threads each (P-core n is CPUs 2n
  # and 2n+1), and 16-31 are the sixteen E-cores. Check with `lscpu --extended` before relying
  # on it. gungnir pins measurements to CPU 14; its sibling 15 stays idle.
  benchCpus = "14,15";
  otherCpus = "0-13,16-31";
  # The same set as a hex mask, which /proc/irq/default_smp_affinity requires.
  otherMask = "ffff3fff";

  # Bench mode fixes the clock for the length of a measurement session and restores the
  # previous state afterwards, so daily use keeps turbo and the normal governor.
  benchMode = pkgs.writeShellApplication {
    name = "gungnir-bench-mode";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      cpu=/sys/devices/system/cpu
      state=/run/gungnir-bench

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
        for policy in "$cpu"/cpufreq/policy*; do
          echo performance > "$policy/scaling_governor"
          if [ -e "$policy/energy_performance_preference" ]; then
            echo performance > "$policy/energy_performance_preference"
          fi
        done
        echo 1 > "$cpu/intel_pstate/no_turbo"
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
        echo "governor cpu14:  $(cat "$cpu/cpu14/cpufreq/scaling_governor")"
        echo "isolated cpus:   $(cat "$cpu/isolated")"
        echo "nohz_full cpus:  $(cat "$cpu/nohz_full" 2>/dev/null || echo unsupported)"
        echo "perf paranoid:   $(cat /proc/sys/kernel/perf_event_paranoid)"
      }

      case "''${1:-status}" in
        on) on; status ;;
        off) off; status ;;
        status) status ;;
        *) echo "usage: gungnir-bench-mode on|off|status" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  # gungnir reads instruction counts and samples profiles with perf. The shared kernel module
  # sets 3, which forbids both for unprivileged users.
  boot.kernel.sysctl."kernel.perf_event_paranoid" = lib.mkForce 1;

  # The NMI watchdog holds a hardware counter; freeing it keeps perf from multiplexing.
  boot.kernel.sysctl."kernel.nmi_watchdog" = 0;

  # Keep the scheduler, the timer tick and RCU callbacks off the measurement core. This
  # reserves one P-core (2 of 32 threads) permanently; drop these three to give it back.
  boot.kernelParams = [
    "isolcpus=${benchCpus}"
    "nohz_full=${benchCpus}"
    "rcu_nocbs=${benchCpus}"
  ];

  # gungnir runs every sandboxed program in a transient systemd user scope with memory, CPU
  # and task limits, which needs these controllers delegated to the user manager.
  systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

  environment.systemPackages = [ benchMode ];

  security.sudo.extraRules = [
    {
      users = [ "r3dlust" ];
      commands = [
        {
          command = "${benchMode}/bin/gungnir-bench-mode";
          options = [ "NOPASSWD" ];
        }
        # sudo matches the path the command is found at, which on PATH is the system profile.
        {
          command = "/run/current-system/sw/bin/gungnir-bench-mode";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
