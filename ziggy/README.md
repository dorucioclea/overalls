# Ziggy

Ziggy is Overalls' Elixir inference proxy and agent model worker on Lilly hosts.
It handles guest inference and pulls agent model work under Marshall's authority,
keeps provider credentials outside guests, and durably reports usage.

```mermaid
flowchart LR
  Guests["Guests"] --> Audi["Audi private frontend"]
  Audi --> Ziggy["Ziggy"]
  Ziggy -->|"Authorization, work and usage"| Marshall["Marshall"]
  Ziggy -->|"Model requests"| Providers["Configured providers or host-local Underclass"]
```

See [Ziggy configuration](../docs/services/ziggy.md).
