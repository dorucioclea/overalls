# Lilly

Lilly is Overalls' Elixir provisioner on each execution host. It polls Marshall
for authorized work, manages Firecracker microVMs, ZFS storage and guest networks,
and reports physical outcomes; running guests survive Lilly restarts.

```mermaid
flowchart LR
  Lilly["Lilly"] -->|"Poll work and report outcomes"| Marshall["Marshall"]
  Lilly -->|"Manage execution"| Guests["Firecracker guests"]
  Lilly -->|"Own disks"| ZFS["ZFS datasets"]
  Lilly -->|"Enforce isolation"| Network["Guest networks"]
```

See the [deployment guide](../docs/operations/deployment.md).
