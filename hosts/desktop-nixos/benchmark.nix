# Temporary: tunes this host for upstreamer's benchmark runs. Kernel TLS for the proxies under
# test, unprivileged perf and kernel symbols for profiling, and fixed CPU frequencies (P-cores at
# 5.0 GHz, E-cores at 4.0 GHz) so turbo and temperature do not move numbers between runs. The unit
# saves every value it changes and its stop step restores them, so deleting this file undoes it on
# the next switch without a reboot.
{ pkgs, ... }:
{
  systemd.services.benchmark-tuning = {
    description = "Kernel TLS, perf access and fixed CPU frequencies for benchmark runs";
    wantedBy = [ "multi-user.target" ];
    after = [ "cpufreq.service" ];
    path = [
      pkgs.kmod
      pkgs.procps
      pkgs.gnugrep
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      state=/run/benchmark-tuning
      mkdir -p $state
      sysctl -n kernel.perf_event_paranoid > $state/paranoid
      sysctl -n kernel.kptr_restrict > $state/kptr
      if lsmod | grep -q '^tls '; then echo 1 > $state/tls; else echo 0 > $state/tls; fi

      modprobe tls
      sysctl -w kernel.perf_event_paranoid=1 kernel.kptr_restrict=0

      for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        n=''${cpu##*cpu}
        f=$cpu/cpufreq
        [ -d $f ] || continue
        cat $f/scaling_governor > $state/governor$n
        cat $f/scaling_min_freq > $state/min$n
        cat $f/scaling_max_freq > $state/max$n
        if [ $n -le 15 ]; then khz=5000000; else khz=4000000; fi
        echo performance > $f/scaling_governor
        echo $khz > $f/scaling_max_freq
        echo $khz > $f/scaling_min_freq
      done
    '';
    postStop = ''
      state=/run/benchmark-tuning
      [ -d $state ] || exit 0
      for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        n=''${cpu##*cpu}
        f=$cpu/cpufreq
        [ -f $state/min$n ] || continue
        cat $state/min$n > $f/scaling_min_freq
        cat $state/max$n > $f/scaling_max_freq
        cat $state/governor$n > $f/scaling_governor
      done
      sysctl -w kernel.perf_event_paranoid=$(cat $state/paranoid) kernel.kptr_restrict=$(cat $state/kptr)
      if [ "$(cat $state/tls)" = 0 ]; then modprobe -r tls || true; fi
      rm -rf $state
    '';
  };
}
