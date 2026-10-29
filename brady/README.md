# Brady

Brady is Overalls' Elixir proxy and cache for permitted guest HTTP/HTTPS egress.
It verifies upstream destinations and caches only eligible public, anonymous
responses in bounded ZFS storage, while Lilly supplies network interception and
current guest identity.

```mermaid
flowchart LR
  Guests["Guests with web egress"] -->|"Lilly interception"| Brady["Brady"]
  Brady -->|"Verified upstream requests"| Internet["Web origins"]
  Brady -->|"Eligible responses"| Cache["Bounded ZFS cache"]
  Brady -->|"Current guest identity"| Lilly["Lilly"]
```

See the [Brady design](../docs/services/brady-design.md).
