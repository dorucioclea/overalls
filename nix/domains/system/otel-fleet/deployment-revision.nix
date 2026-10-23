# @cc [owner:ghuntley,label:observability] deployment-revision-source
# Telemetry MUST name the host build's flake source revision, taken from
# system.configurationRevision, and MUST fall back to "unknown" rather than
# guess. The value is restricted to the spool's simple identifier alphabet.
{ config, lib }:
let
  revision = config.system.configurationRevision or null;
  valid = value: builtins.match "[A-Za-z0-9_.@-]{1,64}" value != null;
in if revision != null && valid revision then revision else "unknown"
