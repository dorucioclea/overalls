# Audi

Audi is Overalls' Elixir DNS and ingress service. It provides authoritative DNS,
public HTTP/HTTPS and guest SSH gateways, plus a private frontend for guest
services; Marshall supplies access and placement authority, and Lilly verifies
local guest execution.

```mermaid
flowchart LR
  Clients["Public clients"] -->|"DNS, web and SSH"| Audi["Audi"]
  Audi -->|"Access and placement"| Marshall["Marshall"]
  Audi -->|"Guest connections"| Lilly["Lilly connector"]
  Lilly --> Guests["Local guests"]
  Guests -->|"Private service requests"| Audi
  Audi --> Services["Ziggy and Galileo"]
```

See [Audi operations](../docs/services/audi.md).
