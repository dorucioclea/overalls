# Marshall

Marshall is Overalls' Elixir/Phoenix control plane and web interface. It owns
accounts, authorization, machine lifecycle, scheduling and agent workflows,
keeping durable state in PostgreSQL while Lilly performs host operations.

```mermaid
flowchart LR
  Users["Browser users"] --> Marshall["Marshall"]
  Services["Service clients"] -->|"Authorized APIs"| Marshall
  Marshall --> PostgreSQL["PostgreSQL"]
  Lilly["Lilly provisioners"] -->|"Poll work and report outcomes"| Marshall
  Lilly --> Guests["Firecracker guests"]
```

See the [architecture overview](../docs/architecture/README.md).
