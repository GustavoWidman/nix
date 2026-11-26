# norn serves nothing and its runs always exit 0, so phoebe reads its health
# from the gauge every run rewrites: the last moment its runs were healthy,
# which stands still once they stay troubled or stop
{
  heartbeat = {
    metric = "norn_healthy_timestamp_seconds";
    # two sweeps, as long as `norn status` waits before calling it troubled
    within = 30 * 60;
  };
}
