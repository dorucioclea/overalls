# Enrico

Enrico is Overalls' private Elixir GitHub mirror service. It refreshes registered
repositories in a bounded ZFS cache and serves read-only Git queries to Marshall,
which owns registration, authorization and the repository browser.

```mermaid
flowchart LR
  Marshall["Marshall"] -->|"Refresh and read requests"| Enrico["Enrico"]
  Enrico -->|"Fetch public repositories"| GitHub["GitHub"]
  Enrico -->|"Store and read mirrors"| Cache["Bounded ZFS cache"]
```

See the [mirror decision](../docs/architecture/decisions/0097-enrico-git-mirrors.md).
