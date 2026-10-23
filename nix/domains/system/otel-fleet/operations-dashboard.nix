let
  prometheus = { type = "prometheus"; uid = "overalls-prometheus"; };
  timeseries = id: title: y: expr: unit: {
    inherit id title;
    type = "timeseries"; datasource = prometheus;
    gridPos = { h = 8; w = 12; x = if id - 2 * (builtins.div id 2) == 0 then 12 else 0; inherit y; };
    targets = [{ refId = "A"; inherit expr; }];
    fieldConfig.defaults = { inherit unit; };
  };
  # Per-view LiveView refresh totals divided by that view's refresh count for
  # the same reporting interval; views without refreshes stay absent.
  live = measure:
    ''label_replace({__name__=~"overalls_gauge_live_.+_${measure}"}, "view", "$1", "__name__", "overalls_gauge_live_(.+)_${measure}") / on(host_name,unit,view) (label_replace({__name__=~"overalls_gauge_live_.+_count"}, "view", "$1", "__name__", "overalls_gauge_live_(.+)_count") > 0)'';
  # Per-phase LiveView callback totals across every view, divided by that
  # phase's callback count; per-view detail lives in marshall.live.callback spans.
  liveview = measure:
    ''label_replace({__name__=~"overalls_gauge_liveview_.+_${measure}"}, "phase", "$1", "__name__", "overalls_gauge_liveview_(.+)_${measure}") / on(host_name,unit,phase) (label_replace({__name__=~"overalls_gauge_liveview_.+_count"}, "phase", "$1", "__name__", "overalls_gauge_liveview_(.+)_count") > 0)'';
  table = id: title: y: expr: {
    inherit id title;
    type = "table"; datasource = prometheus;
    gridPos = { h = 10; w = 24; x = 0; inherit y; };
    targets = [{ refId = "A"; inherit expr; instant = true; format = "table"; }];
  };
  deployment = ''max by(host_name, overalls_deployment_revision) ({__name__=~"overalls_deployment_info.*"})'';
in {
  uid = "overalls-fleet-operations";
  title = "Overalls fleet operations";
  tags = [ "overalls" "fleet" "operations" ];
  schemaVersion = 41; version = 1; refresh = "30s";
  time = { from = "now-6h"; to = "now"; };
  # A deployment annotation marks the first sample of each host's new revision.
  annotations.list = [{
    name = "Deployments"; enable = true; iconColor = "blue"; datasource = prometheus;
    expr = ''${deployment} unless max by(host_name, overalls_deployment_revision) ({__name__=~"overalls_deployment_info.*"} offset 5m)'';
    step = "60s"; titleFormat = "Deployed {{overalls_deployment_revision}}"; textFormat = "{{host_name}}";
  }];
  description = "Host, pool, guest and infrastructure diagnostics. Missing or invalid source data stays unavailable. Infrastructure alerts are operational signals, separate from seven-day objectives.";
  panels = [
    (table 1 "Fleet measurements · numeric observations with bounded dimensions" 0
      ''{__name__=~"overalls_fleet_gauge|overalls_fleet_rate"} and on(host_name) (overalls_fleet_collection_valid == 1) and on(host_name) (time() - overalls_fleet_sampled_at_seconds < 45)'')
    (table 2 "Backup and updater state · unknown and failures remain visible" 10
      ''{__name__=~"overalls_fleet_.*state_info|overalls_fleet_.*valid|overalls_fleet_.*sample_time.*"}'')
    (timeseries 3 "Logging queue bytes" 20 "overalls_logging_queue_bytes" "bytes")
    (timeseries 4 "Oldest pending log chunk" 20 "overalls_logging_oldest_chunk_seconds" "s")
    (timeseries 5 "Log records dropped by destination" 28 "sum by(instance,output) (increase(overalls_logging_output_dropped_records_total[5m]))" "short")
    (timeseries 6 "Logging delivery retries" 28 "sum by(instance,output) (increase(overalls_logging_output_retries_total[5m]))" "short")
    (table 7 "Logging source validity and output budgets" 36
      ''{__name__=~"overalls_logging_.*valid|overalls_logging_.*budget_bytes|overalls_logging_shard_cursor_present"}'')
    (table 8 "Current infrastructure alerts" 46
        ''ALERTS{alertname=~"OverallsLogging.*|OverallsFleet.*|OverallsBackup.*|OverallsUpdate.*|OverallsTelemetry.*|OverallsTrace.*|OverallsMetrics.*|OverallsLogStore.*|OverallsSDK.*|OverallsAgent.*"}'')
    (table 9 "Trace custody · source validity, backlog and retained storage" 56
      ''{__name__=~"overalls_trace_spool_.*"}'')
    (table 10 "SDK producer health · fresh local counters by host and unit" 66
      ''{__name__=~"overalls_gauge_trace_available|overalls_gauge_trace_pending|overalls_gauge_trace_queue_dropped|overalls_gauge_trace_export_failed"} and on(host_name,unit) (time() - overalls_gauge_trace_observed_at_seconds >= 0) and on(host_name,unit) (time() - overalls_gauge_trace_observed_at_seconds < 90)'')
    (timeseries 11 "SDK health observation age · stale remains visible" 76
      "time() - overalls_gauge_trace_observed_at_seconds" "s")
    (timeseries 12 "SDK queue refusals" 76
      ''sum by(host_name,service,unit) (increase(overalls_gauge_trace_queue_dropped[5m]))'' "short")
    (timeseries 13 "SDK export failures" 84
      ''sum by(host_name,service,unit) (increase(overalls_gauge_trace_export_failed[5m]))'' "short")
    (timeseries 14 "BEAM memory · fresh runtime observations" 84
      ''overalls_gauge_beam_memory_bytes and on(host_name,unit) (time() - overalls_gauge_runtime_observed_at_seconds >= 0) and on(host_name,unit) (time() - overalls_gauge_runtime_observed_at_seconds < 90)'' "bytes")
    (timeseries 15 "BEAM run queue · fresh runtime observations" 92
      ''overalls_gauge_beam_run_queue and on(host_name,unit) (time() - overalls_gauge_runtime_observed_at_seconds >= 0) and on(host_name,unit) (time() - overalls_gauge_runtime_observed_at_seconds < 90)'' "short")
    (timeseries 16 "Stuck agent turns" 100
      ''overalls_gauge_agent_stuck_turns'' "short")
    (timeseries 17 "Marshall page refresh · mean duration by view" 108
      (live "duration_ms") "ms")
    (timeseries 18 "Marshall page refresh · mean database queries by view" 108
      (live "queries") "short")
    (timeseries 19 "Marshall database · mean query time" 116
      ''overalls_gauge_database_duration_ms / on(host_name,unit) (overalls_gauge_database_count > 0)'' "ms")
    (timeseries 20 "Marshall database · mean connection pool wait" 116
      ''overalls_gauge_database_queue_duration_ms / on(host_name,unit) (overalls_gauge_database_queue_count > 0)'' "ms")
    (timeseries 21 "Marshall LiveView callbacks · mean duration by phase" 124
      (liveview "duration_ms") "ms")
    (timeseries 22 "Marshall LiveView callbacks · mean database queries by phase" 124
      (liveview "queries") "short")
    (table 23 "Deployed source revision by host" 132 deployment)
    # Per-minute summed checkout wait over 60 s: the mean number of callers
    # queued for a connection. Sustained values near the pool size mean the
    # pool is saturated even when the per-query mean wait looks small.
    (timeseries 24 "Marshall database · callers waiting for a pool connection" 142
      ''overalls_gauge_database_queue_duration_ms / 60000'' "short")
    (timeseries 25 "Marshall database · failed queries per minute" 142
      ''overalls_gauge_database_errors'' "short")
  ];
}
