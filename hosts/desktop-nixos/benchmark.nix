{ lib, pkgs, ... }:
let
  # i9-13900K: logical CPUs 0-15 are the eight P-cores, two threads each (P-core n is CPUs 2n
  # and 2n+1), and 16-31 are the sixteen E-cores. Check with `lscpu --extended` before relying
  # on it. P-cores 4 to 7 (CPUs 8-15) are reserved for measuring: gungnir runs one comparison on
  # the first thread of each (CPUs 8, 10, 12 and 14) and leaves the siblings idle. P-cores 0 to 3
  # and every E-core stay with everything else.
  benchCpus = "8-15";
  benchList = "8 9 10 11 12 13 14 15";
  otherCpus = "0-7,16-31";
  # The same set as a hex mask, which /proc/irq/default_smp_affinity requires.
  otherMask = "ffff00ff";

  # Bench mode fixes the clock for the length of a measurement session and restores the
  # previous state afterwards, so daily use keeps turbo and the normal governor. `on` runs every
  # core at its base clock with turbo off; `on MHZ` instead keeps turbo on and pins the
  # measurement cores to MHZ by setting their minimum and maximum frequency to it.
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
          cat "$policy/scaling_min_freq" > "$state/$name.min"
          cat "$policy/scaling_max_freq" > "$state/$name.max"
          if [ -e "$policy/energy_performance_preference" ]; then
            cat "$policy/energy_performance_preference" > "$state/$name.epp"
          fi
        done
        cat /proc/irq/default_smp_affinity > "$state/default_smp_affinity"
      }

      on() {
        local mhz=$1
        [ -d "$state" ] || save
        for policy in "$cpu"/cpufreq/policy*; do
          echo performance > "$policy/scaling_governor"
          if [ -e "$policy/energy_performance_preference" ]; then
            echo performance > "$policy/energy_performance_preference"
          fi
        done
        if [ -z "$mhz" ]; then
          echo 1 > "$cpu/intel_pstate/no_turbo"
        else
          echo 0 > "$cpu/intel_pstate/no_turbo"
          for n in ${benchList}; do
            # Raise the maximum first, so that the minimum never exceeds it.
            echo $((mhz * 1000)) > "$cpu/cpufreq/policy$n/scaling_max_freq"
            echo $((mhz * 1000)) > "$cpu/cpufreq/policy$n/scaling_min_freq"
          done
        fi
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
          # Lower the minimum first, so that it never exceeds the maximum.
          cat "$state/$name.min" > "$policy/scaling_min_freq"
          cat "$state/$name.max" > "$policy/scaling_max_freq"
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
        echo "governor cpu8:   $(cat "$cpu/cpu8/cpufreq/scaling_governor")"
        for n in 8 10 12 14; do
          echo "cpu$n kHz:       $(cat "$cpu/cpu$n/cpufreq/scaling_cur_freq") (min $(cat "$cpu/cpu$n/cpufreq/scaling_min_freq"), max $(cat "$cpu/cpu$n/cpufreq/scaling_max_freq"))"
        done
        echo "isolated cpus:   $(cat "$cpu/isolated")"
        echo "nohz_full cpus:  $(cat "$cpu/nohz_full" 2>/dev/null || echo unsupported)"
        echo "perf paranoid:   $(cat /proc/sys/kernel/perf_event_paranoid)"
      }

      case "''${1:-status}" in
        on) on "''${2:-}"; status ;;
        off) off; status ;;
        status) status ;;
        *) echo "usage: gungnir-bench-mode on [MHZ]|off|status" >&2; exit 2 ;;
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

  # Keep the scheduler, the timer tick and RCU callbacks off the measurement cores. This
  # reserves four P-cores (8 of 32 threads) permanently; drop these three to give them back.
  boot.kernelParams = [
    "isolcpus=${benchCpus}"
    "nohz_full=${benchCpus}"
    "rcu_nocbs=${benchCpus}"
  ];

  # gungnir runs every sandboxed program in a transient systemd user scope with memory, CPU
  # and task limits, which needs these controllers delegated to the user manager.
  systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

  # A measurement session runs for hours as a user service; without lingering, the user manager
  # and the measurement stop when the last login session closes.
  users.users.r3dlust.linger = true;

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
        {
          command = "/run/current-system/sw/bin/poweroff";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
