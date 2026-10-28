# NixOS option reference

Generated from the default module's evaluated declarations. These are module defaults, not the running fleet configuration. `<name>` selects a named record; `*` selects a list element. Enable a service only after supplying its required configuration and satisfying its assertions. Package store hashes are omitted.

## `overalls.access.enable`

Whether to enable authoritative named fleet SSH access.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.access.users`

Shared public user registry; permissions are explicit and fleet-wide.

Type: `attribute set of (submodule)`.

Default:

```nix
{
  ghuntley = {
    admin = true;
    extraGroups = [ ];
    group = "users";
    login = true;
    secretRecovery = true;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFiX7qvQS3QjzL8y31KxMPn5EOyufjgz2YuRD3GNWcuR"
    ];
  };
}
```


## `overalls.access.users.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.access.users.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.access.users.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.access.users.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.access.users.<name>.admin`

Grant this login user passwordless sudo.

Type: `boolean`.

Default:

```nix
false
```


## `overalls.access.users.<name>.extraGroups`

Supplementary Unix groups.

Type: `list of string matching the pattern [a-z_][a-z0-9_-]{0,31}`.

Default:

```nix
[ ]
```


## `overalls.access.users.<name>.group`

Primary Unix group.

Type: `string matching the pattern [a-z_][a-z0-9_-]{0,31}`.

Default:

```nix
"users"
```


## `overalls.access.users.<name>.login`

Create a named SSH account on every participating host.

Type: `boolean`.

Default:

```nix
false
```


## `overalls.access.users.<name>.secretRecovery`

Include these keys in every managed encrypted document.

Type: `boolean`.

Default:

```nix
false
```


## `overalls.access.users.<name>.sshKeys`

Pinned public Ed25519 keys for SSH and optional recovery.

Type: `list of string matching the pattern ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI[A-Za-z0-9+/]{43}( [^
]+)?`.

Default:

```nix
[ ]
```


## `overalls.fleetAddresses.enable`

Whether to enable fleet public addresses delivered through SOPS instead of the repository.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.fleetAddresses.encryptedFile`

Shared SOPS document (project overalls-fleet-addresses); null on a base system, which uses only the uplink recovery copy.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `overalls.fleetAddresses.environmentFile`

EnvironmentFile with every selected secret by its secret name.

Type: `string`.

Default:

```nix
"/run/overalls-secrets/fleet-addresses/addresses.env"
```


## `overalls.fleetAddresses.files`

Runtime file per logical name, for consumers such as firewall rules and listeners.

Type: `attribute set of string`.

Default:

```nix
{ }
```


## `overalls.fleetAddresses.names`

Logical name to secret name; secrets ending _IPV4 are addresses and _PREFIX are prefix lengths.

Type: `attribute set of string matching the pattern [A-Z][A-Z0-9_]{0,62}_(IPV4|PREFIX)`.

Default:

```nix
{ }
```


## `overalls.fleetAddresses.unit`

Unit after which every runtime address has been validated.

Type: `string`.

Default:

```nix
"overalls-fleet-addresses.service"
```


## `overalls.fleetAddresses.uplink`

Static uplink addressing applied as a runtime networkd drop-in.

Type: `null or (submodule)`.

Default:

```nix
null
```


## `overalls.fleetAddresses.uplink._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.fleetAddresses.uplink._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.fleetAddresses.uplink._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.fleetAddresses.uplink._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetAddresses.uplink.addresses`

No additional description is declared by the module.

Type: `non-empty (list of string matching the pattern [a-z][A-Za-z0-9]{0,31})`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetAddresses.uplink.gateway`

No additional description is declared by the module.

Type: `string matching the pattern [a-z][A-Za-z0-9]{0,31}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetAddresses.uplink.hostRoutes`

Addresses routed as /32 through the gateway.

Type: `list of string matching the pattern [a-z][A-Za-z0-9]{0,31}`.

Default:

```nix
[ ]
```


## `overalls.fleetAddresses.uplink.network`

No additional description is declared by the module.

Type: `string matching the pattern [A-Za-z0-9][A-Za-z0-9_.-]{0,63}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetAddresses.uplink.prefix`

No additional description is declared by the module.

Type: `string matching the pattern [a-z][A-Za-z0-9]{0,31}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetAddresses.uplink.recoveryFile`

Last applied drop-in, used when the document cannot be decrypted, and written by host installation.

Type: `string`.

Default:

```nix
"/var/lib/overalls-host/uplink.conf"
```


## `overalls.fleetBuilds.enable`

Whether to enable fleet build scheduling through a tribuchet hub and grpc:// stores.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.fleetBuilds.grpcCaCertificate`

Public nix-grpc-store CA certificate.

Type: `absolute path`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.grpcPort`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
50051
```


## `overalls.fleetBuilds.localName`

No additional description is declared by the module.

Type: `string matching the pattern [a-z][a-z0-9-]{0,27}`.

Default:

```nix
"nixos"
```


## `overalls.fleetBuilds.machines`

No additional description is declared by the module.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.fleetBuilds.machines.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.fleetBuilds.machines.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.fleetBuilds.machines.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.fleetBuilds.machines.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.machines.<name>.address`

Tailnet IPv4 address; the certificates' IP SAN.

Type: `string matching the pattern [0-9]{1,3}(\.[0-9]{1,3}){3}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.machines.<name>.encryptedFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.machines.<name>.grpcCertificate`

Public grpc certificate, CN build-NAME.

Type: `absolute path`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.machines.<name>.logicalCpus`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.machines.<name>.supportedFeatures`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_-]+`.

Default:

```nix
[ ]
```


## `overalls.fleetBuilds.machines.<name>.systems`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_-]+`.

Default:

```nix
[ ]
```


## `overalls.fleetBuilds.machines.<name>.tribuchetCertificate`

Public tribuchet worker certificate.

Type: `absolute path`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.machines.<name>.tribuchetHubCertificate`

No additional description is declared by the module.

Type: `null or absolute path`.

Default:

```nix
null
```


## `overalls.fleetBuilds.scheduler`

The one participant running the tribuchet hub.

Type: `string matching the pattern [a-z][a-z0-9-]{0,27}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetBuilds.tribuchetCaCertificate`

Public tribuchet CA certificate.

Type: `absolute path`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetFirewall.allowedHosts`

Named IPv4 sources allowed to reach every fleet host over TCP and UDP; fleet hosts fill it from the reviewed policy in nix/policy/network/allowed-hosts.nix.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.fleetFirewall.allowedHosts.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.fleetFirewall.allowedHosts.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.fleetFirewall.allowedHosts.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.fleetFirewall.allowedHosts.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetFirewall.allowedHosts.<name>.address`

Reviewed IPv4 source address.

Type: `null or string matching the pattern [0-9]{1,3}(\.[0-9]{1,3}){3}`.

Default:

```nix
null
```


## `overalls.fleetFirewall.allowedHosts.<name>.addressFile`

Runtime file holding the reviewed IPv4 source, for addresses kept out of the repository.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `overalls.fleetFirewall.allowedHosts.<name>.addressUnit`

Unit that publishes addressFile.

Type: `null or string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
null
```


## `overalls.fleetFirewall.allowedHosts.<name>.comment`

Required human-readable owner or purpose for this grant.

Type: `string matching the pattern [A-Za-z0-9][A-Za-z0-9 ._()/-]{0,95}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetFirewall.enable`

Whether to enable fleet-wide Tailscale and reviewed-source firewall access.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.fleetFirewall.publicServices`

Named destination-scoped listeners admitted from any IPv4 source; each needs an explicit local address, at least one TCP or UDP port, and a reviewed comment.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.fleetFirewall.publicServices.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.fleetFirewall.publicServices.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.fleetFirewall.publicServices.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.fleetFirewall.publicServices.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetFirewall.publicServices.<name>.address`

Explicit local IPv4 destination address; never a wildcard.

Type: `null or string matching the pattern [0-9]{1,3}(\.[0-9]{1,3}){3}`.

Default:

```nix
null
```


## `overalls.fleetFirewall.publicServices.<name>.addressFile`

Runtime file holding the explicit local IPv4 destination, for addresses kept out of the repository (for example a decrypted SOPS bundle).

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `overalls.fleetFirewall.publicServices.<name>.addressUnit`

Unit that publishes addressFile; the listener rules follow it.

Type: `null or string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
null
```


## `overalls.fleetFirewall.publicServices.<name>.comment`

Required human-readable owner or purpose for this listener.

Type: `string matching the pattern [A-Za-z0-9][A-Za-z0-9 ._()/-]{0,95}`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetFirewall.publicServices.<name>.tcpPorts`

TCP ports reachable from any source at this address.

Type: `list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
[ ]
```


## `overalls.fleetFirewall.publicServices.<name>.udpPorts`

UDP ports reachable from any source at this address.

Type: `list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
[ ]
```


## `overalls.fleetNetwork.address`

Unique host address in the dedicated 10.90.0.0/24 fleet network.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetNetwork.enable`

Whether to enable IPv4-only host fleet WireGuard transport.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.fleetNetwork.endpointAddress`

Physical IPv4 destination admitted for WireGuard handshakes.

Type: `null or string`.

Default:

```nix
null
```


## `overalls.fleetNetwork.endpointAddressFile`

Runtime file holding the physical IPv4 destination, kept out of the repository.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `overalls.fleetNetwork.endpointUnits`

Units that publish the runtime endpoint files of this host and its peers.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `overalls.fleetNetwork.peers`

No additional description is declared by the module.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.fleetNetwork.peers.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.fleetNetwork.peers.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.fleetNetwork.peers.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.fleetNetwork.peers.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetNetwork.peers.<name>.address`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetNetwork.peers.<name>.endpointAddress`

No additional description is declared by the module.

Type: `null or string`.

Default:

```nix
null
```


## `overalls.fleetNetwork.peers.<name>.endpointAddressFile`

Runtime file holding the peer's physical IPv4 endpoint.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `overalls.fleetNetwork.peers.<name>.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
51820
```


## `overalls.fleetNetwork.peers.<name>.publicKey`

No additional description is declared by the module.

Type: `string matching the pattern [A-Za-z0-9+/]{43}=`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetNetwork.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
51820
```


## `overalls.fleetNetwork.privateKeyFile`

Runtime private WireGuard key; never embedded in the store.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `overalls.fleetNetwork.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `overalls.fleetNetwork.tcpPorts`

Local fleet services admitted only from configured tunnel peers.

Type: `list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
[ ]
```


## `overalls.remoteBuilders.enable`

Whether to enable reciprocal pinned SSH caches with restricted machine access.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.remoteBuilders.localName`

No additional description is declared by the module.

Type: `string matching the pattern [a-z][a-z0-9-]{0,27}`.

Default:

```nix
"nixos"
```


## `overalls.remoteBuilders.machines`

No additional description is declared by the module.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.remoteBuilders.machines.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.remoteBuilders.machines.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.remoteBuilders.machines.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.remoteBuilders.machines.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.remoteBuilders.machines.<name>.address`

No additional description is declared by the module.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `overalls.remoteBuilders.machines.<name>.clientPublicKeys`

No additional description is declared by the module.

Type: `list of string matching the pattern ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI[A-Za-z0-9+/]{43}( [^
]+)?`.

Default:

```nix
[ ]
```


## `overalls.remoteBuilders.machines.<name>.encryptedFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `overalls.remoteBuilders.machines.<name>.hostPublicKey`

No additional description is declared by the module.

Type: `string matching the pattern ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI[A-Za-z0-9+/]{43}( [^
]+)?`.

Default: Required when its service or enclosing record is selected.


## `overalls.remoteBuilders.machines.<name>.logicalCpus`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default: Required when its service or enclosing record is selected.


## `overalls.remoteBuilders.machines.<name>.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
22
```


## `overalls.remoteBuilders.machines.<name>.supportedFeatures`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_-]+`.

Default:

```nix
[ ]
```


## `overalls.remoteBuilders.machines.<name>.systems`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_-]+`.

Default:

```nix
[ ]
```


## `overalls.remoteBuilders.substitutePeers`

Peers used as ssh-ng substituters; fleet builds replace some with grpc:// (ADR-0248).

Type: `list of string matching the pattern [a-z][a-z0-9-]{0,27}`.

Default:

```nix
every registered peer
```


## `overalls.runtimeFirewall.rules`

Input accept rules whose source or destination IPv4 address is runtime data (for example a decrypted SOPS bundle) kept out of the repository and the Nix store.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.runtimeFirewall.rules.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.runtimeFirewall.rules.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.runtimeFirewall.rules.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.runtimeFirewall.rules.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.runtimeFirewall.rules.<name>.comment`

No additional description is declared by the module.

Type: `string matching the pattern [A-Za-z0-9][A-Za-z0-9 ._()/-]{0,95}`.

Default: Required when its service or enclosing record is selected.


## `overalls.runtimeFirewall.rules.<name>.destination`

Static local IPv4 destination.

Type: `null or string`.

Default:

```nix
null
```


## `overalls.runtimeFirewall.rules.<name>.destinationFile`

Runtime file holding the local IPv4 destination.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `overalls.runtimeFirewall.rules.<name>.interface`

No additional description is declared by the module.

Type: `null or string matching the pattern [a-z][a-z0-9]{0,14}`.

Default:

```nix
null
```


## `overalls.runtimeFirewall.rules.<name>.optional`

Skip only this rule while its runtime file is absent; a present but malformed address still empties the chain.

Type: `boolean`.

Default:

```nix
false
```


## `overalls.runtimeFirewall.rules.<name>.ports`

No additional description is declared by the module.

Type: `list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
[ ]
```


## `overalls.runtimeFirewall.rules.<name>.protocol`

tcp or udp with ports, or any for every TCP and UDP port.

Type: `one of "tcp", "udp", "any"`.

Default: Required when its service or enclosing record is selected.


## `overalls.runtimeFirewall.rules.<name>.source`

Static IPv4 source.

Type: `null or string`.

Default:

```nix
null
```


## `overalls.runtimeFirewall.rules.<name>.sourceFile`

Runtime file holding the IPv4 source.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `overalls.runtimeFirewall.rules.<name>.units`

Units that publish the runtime files; the rules follow them.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `overalls.runtimeSockets`

Socket units whose IPv4 ListenStream address is runtime data (for example a decrypted SOPS bundle output), keyed by the socket unit name without .socket. The socket's static listenStreams stay empty; a validating unit supplies the address as a runtime drop-in.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `overalls.runtimeSockets.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `overalls.runtimeSockets.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `overalls.runtimeSockets.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `overalls.runtimeSockets.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `overalls.runtimeSockets.<name>.addressFile`

Runtime file holding the explicit IPv4 listen address.

Type: `string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default: Required when its service or enclosing record is selected.


## `overalls.runtimeSockets.<name>.addressUnit`

Unit that publishes addressFile; the socket address follows it.

Type: `string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default: Required when its service or enclosing record is selected.


## `overalls.runtimeSockets.<name>.port`

Listen port on the runtime address.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default: Required when its service or enclosing record is selected.


## `overalls.sysctl.enable`

Whether to enable Overalls host BBR and fq profile.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `overalls.tailscale.exitNode`

Whether to enable Tailscale exit-node advertisement and forwarding.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audi.administrativeAccess`

Administrative access path. Console-only deployments must disable administrative OpenSSH.

Type: `one of "openssh", "console"`.

Default:

```nix
"openssh"
```


## `services.audi.bindAddress`

Static IPv4 listener address for the Audi gateway listeners; null when bindAddressFile supplies it at runtime.

Type: `null or string`.

Default:

```nix
if bindAddressFile == null then "0.0.0.0" else null
```


## `services.audi.bindAddressFile`

Runtime file under /run holding the canonical IPv4 listener address for the Audi gateway listeners, kept out of the repository and the Nix store.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.audi.bindAddressUnit`

Unit that publishes bindAddressFile; the Audi gateway listeners starts after it and stops with it.

Type: `null or string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
null
```


## `services.audi.caFile`

CA certificates authenticating the Marshall HTTPS endpoint.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.audi.connectorPath`

Restricted local Lilly Unix socket; no guest address is configured in Audi.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/lilly-ingress/audi.sock"
```


## `services.audi.connectorUid`

Expected Linux peer UID of the Lilly connector: the Lilly service user where Lilly runs.

Type: `integer between 0 and 4294967294 (both inclusive)`.

Default:

```nix
config.users.users.lilly.uid
```


## `services.audi.controlPlane`

Verified HTTPS Marshall origin.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.audi.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2
```


## `services.audi.crashDumps.enable`

Whether to enable bounded encrypted OTP crash dumps.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audi.crashDumps.publicKeyFile`

Operator RSA public key (at least 3072 bits). Keep its private key off-host.

Type: `null or string matching the pattern /[^
]+`.

Default:

```nix
null
```


## `services.audi.credentialFile`

Private runtime file containing a separately provisioned Marshall gateway token.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.audi.editorPackages`

Immutable browser editor packages by linux-x64 or win32-x64 target, serving exact release webview assets; empty disables assets. Every published gateway must serve all Marshall-approved releases.

Type: `attribute set of package`.

Default:

```nix
{
  linux-x64 = <derivation overalls-vscode-web-1.141.0>;
}
```


## `services.audi.enable`

Whether to enable Audi local guest SSH gateway.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audi.hostId`

Enrolled identity of the local Lilly host.

Type: `string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default: Required when its service or enclosing record is selected.


## `services.audi.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
1024
```


## `services.audi.openFirewall`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
false
```


## `services.audi.package`

Independent source-built Audi release.

Type: `package`.

Default:

```nix
<derivation overalls-audi-0.1.0>
```


## `services.audi.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
22
```


## `services.audi.publicOrigin`

Public Marshall HTTPS origin for SSH setup guidance; never the private control endpoint.

Type: `null or string`.

Default:

```nix
null
```


## `services.audi.relay.address`

Exact local fleet /32; never a guest or public listener address.

Type: `null or string`.

Default:

```nix
null
```


## `services.audi.relay.enable`

Whether to enable single-hop authorized ingress over the host fleet WireGuard network.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audi.relay.peers`

Explicit keyed fleet /32 peers allowed to present single-use relay capabilities.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.audi.relay.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
9445
```


## `services.audi.secretUnits`

Credential preparation services required before startup.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.audi.tls.browserOrigin`

Public HTTPS Marshall browser origin for identity approval; separate from the private control API.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.audi.tls.certificateRootsFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.audi.tls.enable`

Whether to enable Audi fleet wildcard TLS listener.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audi.tls.httpPort`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
80
```


## `services.audi.tls.httpsPort`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
443
```


## `services.audi.tls.trustedProxyPeer`

Inception parent gateway allowed to supply IPv4 PROXY metadata; null for public listeners.

Type: `null or string`.

Default:

```nix
null
```


## `services.audi.tls.zone`

Delegated application DNS zone. Browser editor assets require at least two canonical lowercase DNS labels.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.audiDns.bindAddress`

Static IPv4 listener address for the Audi DNS listener; null when bindAddressFile supplies it at runtime.

Type: `null or string`.

Default:

```nix
if bindAddressFile == null then "0.0.0.0" else null
```


## `services.audiDns.bindAddressFile`

Runtime file under /run holding the canonical IPv4 listener address for the Audi DNS listener, kept out of the repository and the Nix store.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.audiDns.bindAddressUnit`

Unit that publishes bindAddressFile; the Audi DNS listener starts after it and stops with it.

Type: `null or string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
null
```


## `services.audiDns.caFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.audiDns.controlPlane`

Verified HTTPS Marshall origin.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.audiDns.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2
```


## `services.audiDns.credentialFile`

Private runtime file containing a separately enrolled DNS service token.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.audiDns.enable`

Whether to enable Audi authoritative DNS.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audiDns.mailbox`

SOA responsible mailbox in DNS name form.

Type: `string matching the pattern [a-z0-9][a-z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.audiDns.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
512
```


## `services.audiDns.nameservers`

At least two independent authoritative nameservers.

Type: `list of string matching the pattern [a-z0-9][a-z0-9.-]*`.

Default:

```nix
[ ]
```


## `services.audiDns.openFirewall`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
false
```


## `services.audiDns.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-audi-0.1.0>
```


## `services.audiDns.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
53
```


## `services.audiDns.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.audiDns.zone`

Delegated application zone.

Type: `string matching the pattern [a-z0-9][a-z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.audiPrivate.certificateFile`

Fleet wildcard leaf and intermediate PEM chain from the bundle.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/audi-private/chain.pem"
```


## `services.audiPrivate.configurationFile`

Runtime configuration override for the replacement host; default keeps the deployed configuration.

Type: `null or absolute path`.

Default:

```nix
null
```


## `services.audiPrivate.enable`

Whether to enable Audi private service DNS and TLS in the Lilly namespace.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audiPrivate.keyFile`

Fleet wildcard leaf key from the bundle; rotation is operator custody.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/audi-private/key.pem"
```


## `services.audiPrivate.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-audi-0.1.0>
```


## `services.audiPrivate.rootsFile`

Public private-service CA trust bundle, also supplied to guest images.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.audiPrivate.secretUnits`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.audiPrivate.secretsFile`

SOPS document containing AUDI_PRIVATE_CERTIFICATE_CHAIN and AUDI_PRIVATE_CERTIFICATE_KEY (fleet wildcard leaf).

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.audiobookshelf.dataDir`

Path to Audiobookshelf config and metadata inside of /var/lib.

Type: `string`.

Default:

```nix
"audiobookshelf"
```


## `services.audiobookshelf.enable`

Whether to enable Audiobookshelf, self-hosted audiobook and podcast server.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.audiobookshelf.group`

Group under which Audiobookshelf runs.

Type: `string`.

Default:

```nix
"audiobookshelf"
```


## `services.audiobookshelf.host`

The host Audiobookshelf binds to.

Type: `string`.

Default:

```nix
"127.0.0.1"
```

Example:

```nix
"0.0.0.0"
```


## `services.audiobookshelf.openFirewall`

Open ports in the firewall for the Audiobookshelf web interface.

Type: `boolean`.

Default:

```nix
false
```


## `services.audiobookshelf.package`

The audiobookshelf package to use.

Type: `package`.

Default:

```nix
pkgs.audiobookshelf
```


## `services.audiobookshelf.port`

The TCP port Audiobookshelf will listen on.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
8000
```


## `services.audiobookshelf.user`

User account under which Audiobookshelf runs.

Type: `string`.

Default:

```nix
"audiobookshelf"
```


## `services.brady.dnsResolvers`

No additional description is declared by the module.

Type: `list of string matching the pattern [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+`.

Default:

```nix
[
  "1.1.1.1"
  "8.8.8.8"
]
```


## `services.brady.enable`

Whether to enable native transparent Firecracker HTTP/HTTPS cache.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.brady.httpPorts`

No additional description is declared by the module.

Type: `list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
[
  80
]
```


## `services.brady.httpsPorts`

No additional description is declared by the module.

Type: `list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
[
  443
]
```


## `services.brady.issuerCertificateFile`

Runtime signing CA certificate; Brady does not provision the CA.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.brady.issuerKeyFile`

Runtime signing CA key.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.brady.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-brady-0.1.0>
```


## `services.brady.poolId`

No additional description is declared by the module.

Type: `null or string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default:

```nix
null
```


## `services.brady.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.brady.tlsExceptions`

No additional description is declared by the module.

Type: `list of (submodule)`.

Default:

```nix
[ ]
```


## `services.brady.tlsExceptions.*._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.brady.tlsExceptions.*._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.brady.tlsExceptions.*._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.brady.tlsExceptions.*._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.brady.tlsExceptions.*.host`

No additional description is declared by the module.

Type: `string matching the pattern [a-z0-9][a-z0-9.-]{0,252}`.

Default: Required when its service or enclosing record is selected.


## `services.brady.tlsExceptions.*.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
443
```


## `services.brady.upstreamCAFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.enrico.bindAddress`

No additional description is declared by the module.

Type: `string matching the pattern [0-9]+(\.[0-9]+){3}`.

Default:

```nix
"127.0.0.1"
```


## `services.enrico.cacheDataset`

No additional description is declared by the module.

Type: `null or string`.

Default:

```nix
null
```


## `services.enrico.cacheQuotaGiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
100
```


## `services.enrico.certificateFile`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.enrico.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2
```


## `services.enrico.enable`

Whether to enable private public-GitHub mirror service.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.enrico.keyFile`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.enrico.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
8192
```


## `services.enrico.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-enrico-0.1.0>
```


## `services.enrico.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
5445
```


## `services.enrico.secretUnits`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.enrico.stateDirectory`

No additional description is declared by the module.

Type: `string`.

Default:

```nix
"/var/lib/enrico"
```


## `services.enrico.tokenFile`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.galileo.caFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.galileo.configurationFile`

Release-independent runtime configuration; null uses the deployed configuration.

Type: `null or absolute path`.

Default:

```nix
null
```


## `services.galileo.controlPlane`

Verified HTTPS Marshall origin.

Type: `string`.

Default:

```nix
<derived from required configuration>
```


## `services.galileo.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2
```


## `services.galileo.credentialFile`

Dedicated Galileo control credential runtime file.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/galileo/control.token"
```


## `services.galileo.enable`

Whether to enable private node-local named integration proxy.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.galileo.hostId`

Enrolled local Lilly host identity.

Type: `string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default:

```nix
<derived from required configuration>
```


## `services.galileo.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2048
```


## `services.galileo.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-galileo-0.1.0>
```


## `services.galileo.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.galileo.secretsFile`

SOPS document containing GALILEO_CREDENTIAL.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.checkpointImageIds`

Exact immutable image IDs with separately reviewed native memory-continuation qualification. Empty refuses pause/resume while retaining ordinary boot admission.

Type: `list of string matching the pattern sha256:[0-9a-f]{64}`.

Default:

```nix
[ ]
```


## `services.lilly.controlPlane`

Verified HTTPS control-plane origin; no embedded credentials.

Type: `string matching the pattern https://([a-zA-Z0-9][a-zA-Z0-9.-]*|[[][0-9a-fA-F:]+[]])(:[0-9]{1,5})?/?`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.controlPlaneCAFile`

CA bundle authenticating the control-plane endpoint. Lilly reads it through systemd LoadCredential, so the file may be readable by root only.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.lilly.crashDumps.enable`

Whether to enable bounded encrypted OTP crash dumps.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.lilly.crashDumps.publicKeyFile`

Operator RSA public key (at least 3072 bits). Keep its private key off-host.

Type: `null or string matching the pattern /[^
]+`.

Default:

```nix
null
```


## `services.lilly.credentialFile`

Private host-bound enrollment credential file.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/lilly-credential.json"
```


## `services.lilly.egressInterface`

Host uplink carrying routed guest egress.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9_.-]{0,14}`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.enable`

Whether to enable Lilly Firecracker provisioner.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.lilly.firecrackerLogging.enable`

Independent bounded native Firecracker diagnostics.

Type: `boolean`.

Default:

```nix
false
```


## `services.lilly.firecrackerLogging.maxBytes`

Host-wide native log file budget.

Type: `positive integer, meaning >0`.

Default:

```nix
1073741824
```


## `services.lilly.firecrackerLogging.maxStreams`

No additional description is declared by the module.

Type: `integer between 2 and 65536 (both inclusive)`.

Default:

```nix
2048
```


## `services.lilly.guestCpuCores`

Aggregate guest CPU quota in logical cores.

Type: `positive integer, meaning >0`.

Default:

```nix
24
```


## `services.lilly.guestMemoryMiB`

Aggregate guest and VMM memory budget in MiB.

Type: `positive integer, meaning >0`.

Default:

```nix
98304
```


## `services.lilly.guestTrustRoots`

Public platform CA certificates delivered to each guest on boot.

Type: `list of absolute path`.

Default:

```nix
[ ]
```


## `services.lilly.hostId`

Enrolled, persistent Marshall host resource UUID.

Type: `string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.hostd.peerCgroups`

cgroup v2 paths whose root processes may open a lilly-hostd session.
Lilly's own unit by default; an empty list admits any root peer
(machine tests whose probe BEAMs run outside lilly.service).


Type: `list of string`.

Default:

```nix
[
  "/system.slice/lilly.service"
]
```


## `services.lilly.imageIoTimeoutSeconds`

Deadline for one root-disk image copy or flush per pool (ADR-0173); expiry fails the placement closed. Raise it only where image I/O is known to be slow, such as nested test hosts reading a non-sparse store.

Type: `integer between 1 and 14400 (both inclusive)`.

Default:

```nix
300
```


## `services.lilly.imageTemplates.budgetBytes`

Conservative per-pool artifact budget for sealed image templates (ADR-0130); images larger than the budget use fresh verification for every provision.

Type: `integer between 1 and 1099511627776 (both inclusive)`.

Default:

```nix
34359738368
```


## `services.lilly.images`

Immutable local images verified by Lilly before advertising, in operator order.

Type: `list of (submodule)`.

Default:

```nix
[ ]
```


## `services.lilly.images.*._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.lilly.images.*._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.lilly.images.*._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.lilly.images.*._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.images.*.path`

Immutable local image directory (manifest.json and artifacts) verified by Lilly before advertising.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.inceptionImageId`

Exact locally installed Inception image allowed to receive the shared SMTP bundle.

Type: `null or string matching the pattern sha256:[0-9a-f]{64}`.

Default:

```nix
null
```


## `services.lilly.inceptionSMTPFile`

Private runtime JSON containing only shared Inception SMTP configuration; null disables Inception bootstrap.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.lilly.ingress.enable`

Whether to enable restricted local Audi guest SSH ingress.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.lilly.localTransferBytesPerSecond`

Maximum same-host clone stream bytes per second; these never cross the network.

Type: `integer between 1 and 1073741824 (both inclusive)`.

Default:

```nix
1073741824
```


## `services.lilly.networkStateDirectory`

Durable host networking ownership directory.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/var/lib/lilly/network"
```


## `services.lilly.package`

Source-built Lilly release with canonical host-tool metadata.

Type: `package`.

Default:

```nix
<derivation overalls-lilly-0.1.0>
```


## `services.lilly.pools`

Bound storage pools; filesystem identity must match the actual mount.

Type: `list of (submodule)`.

Default:

```nix
[ ]
```


## `services.lilly.pools.*._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.lilly.pools.*._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.lilly.pools.*._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.lilly.pools.*._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.filesystem_id`

Verified filesystem identity.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.id`

Enrolled pool UUID.

Type: `string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.max_iops`

Measured or configured IOPS limit; null means unknown. ZFS uses logical whole-pool operations. This is monitoring metadata, not admission capacity.

Type: `null or (positive integer, meaning >0)`.

Default:

```nix
null
```


## `services.lilly.pools.*.max_iops_source`

Provenance of the IOPS limit.

Type: `null or string`.

Default:

```nix
null
```


## `services.lilly.pools.*.path`

Canonical mounted pool path.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.storage`

Required native ZFS pool and dataset identity.

Type: `submodule`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.storage._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.lilly.pools.*.storage._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.lilly.pools.*.storage._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.lilly.pools.*.storage._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.storage.backend`

No additional description is declared by the module.

Type: `value "zfs" (singular enum)`.

Default:

```nix
"zfs"
```


## `services.lilly.pools.*.storage.dataset`

Existing mounted parent dataset, with LZ4 and no reservations.

Type: `string matching the pattern [a-zA-Z][a-zA-Z0-9_.-]*(/[a-zA-Z0-9][a-zA-Z0-9_.-]*)+`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.storage.dataset_guid`

Actual parent dataset GUID as a decimal string.

Type: `string matching the pattern [1-9][0-9]{0,19}`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.pools.*.storage.zpool_guid`

Actual unsigned 64-bit zpool GUID as a decimal string.

Type: `string matching the pattern [1-9][0-9]{0,19}`.

Default: Required when its service or enclosing record is selected.


## `services.lilly.privateServices.enable`

Whether to enable registered private DNS and HTTPS in the owned namespace.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.lilly.protectedAddressFiles`

Runtime files, each holding one canonical IPv4 address, denied to guests as /32 networks in addition to protectedCidrs; for addresses kept out of the repository.

Type: `list of string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
[ ]
```


## `services.lilly.protectedAddressUnits`

Units that publish protectedAddressFiles; Lilly and Brady start after them.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.lilly.protectedCidrs`

Additional canonical IPv4 networks denied to guests, including public management endpoints.

Type: `list of string matching the pattern [0-9.]+/[0-9]+`.

Default:

```nix
[ ]
```


## `services.lilly.secretUnits`

Required preparation services that publish runtime credentials.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.lilly.stateDirectory`

Durable control receipt and host ownership directory.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/var/lib/lilly/control"
```


## `services.lilly.transferBytesPerSecond`

Maximum receive stream bytes per second, with a 64 KiB burst allowance.

Type: `integer between 1 and 1073741824 (both inclusive)`.

Default:

```nix
67108864
```


## `services.lilly.vmStateDirectory`

Durable VM actor directory; maximum 45 bytes for UNIX sockets.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/var/lib/lilly/vms"
```


## `services.lillyTransfer.configurationFile`

Private v3 export configuration containing local host, journal root and bound pools; no control-plane credentials.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.lillyTransfer.enable`

Whether to enable restricted permit-bound Lilly ZFS export.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.lillyTransfer.hostKeyFile`

Existing enrolled source host identity. This service never generates or replaces it.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/etc/ssh/ssh_host_ed25519_key"
```


## `services.lillyTransfer.listenAddress`

Local IPv4 address for the dedicated SSH listener.

Type: `string`.

Default:

```nix
"0.0.0.0"
```


## `services.lillyTransfer.openFirewall`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
false
```


## `services.lillyTransfer.package`

Source-built Lilly release used by isolated export workers.

Type: `package`.

Default:

```nix
<derivation overalls-lilly-0.1.0>
```


## `services.lillyTransfer.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
2222
```


## `services.lillyTransfer.stateDirectory`

Durable transfer journal root used by Lilly's generated export configuration.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/var/lib/lilly/transfers"
```


## `services.marshall.artifactContent.debugEcho`

Machine-test only: makes GET /v/<ticket>/__echo report whether Cookie and Authorization reached Marshall and emit a probe Set-Cookie. Requires machineTestFixture; never enable in a deployment.

Type: `boolean`.

Default:

```nix
false
```


## `services.marshall.artifactContent.host`

Lowercase public DNS name of the isolated artifact content origin (for example usercontent.ghuntley.dev). It must differ from publicHost. Null disables the content listener and the artifact viewer reports that it is unavailable.

Type: `null or lowercase multi-label DNS hostname`.

Default:

```nix
null
```


## `services.marshall.cpuCores`

Aggregate CPU quota in logical cores for Marshall instances.

Type: `positive integer, meaning >0`.

Default:

```nix
4
```


## `services.marshall.crashDumps.enable`

Whether to enable bounded encrypted OTP crash dumps.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.marshall.crashDumps.publicKeyFile`

Operator RSA public key (at least 3072 bits). Keep its private key off-host.

Type: `null or string matching the pattern /[^
]+`.

Default:

```nix
null
```


## `services.marshall.databaseCAFile`

CA bundle authenticating the PostgreSQL endpoint.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.marshall.databaseConnectionBudget`

Fleet database allocation, including one notifier per instance and ten operator connections.

Type: `integer between 1 and 100000 (both inclusive)`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.defaultImageId`

Default immutable image for new SSH machines and initial browser drafts; admission still requires image availability.

Type: `null or string matching the pattern sha256:[0-9a-f]{64}`.

Default:

```nix
null
```


## `services.marshall.defaultImageIdFile`

Optional operator-owned runtime default image identity, delivered through systemd credentials. Overrides defaultImageId; empty input disables the default and invalid input prevents startup.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.editorPackages`

Immutable official-source browser editor packages by linux-x64 or win32-x64 target; their exact descriptors govern image and gateway admission. Empty disables editor authority.

Type: `attribute set of package`.

Default:

```nix
{
  linux-x64 = <derivation overalls-vscode-web-1.141.0>;
}
```


## `services.marshall.enable`

Whether to enable Marshall control plane instances.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.marshall.environmentFile`

Private systemd environment file containing database, signing, Cloak and SMTP configuration.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/marshall.env"
```


## `services.marshall.githubBootstrapRelease`

Immutable source-built executor inventory for retained-machine tool maintenance.

Type: `null or package`.

Default:

```nix
<derivation overalls-executor-bootstrap-v1>
```


## `services.marshall.githubRestoreEpochFile`

Root-controlled public UUID restored-authority fence, shared identically across all replicas before recovery startup. The marker persists after invalidation.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/var/lib/overalls-marshall-recovery/github-restore-epoch"
```


## `services.marshall.githubToolsRelease`

Immutable manifest for the managed guest GitHub tools release.

Type: `null or package`.

Default:

```nix
<derivation overalls-github-tools-release-v1>
```


## `services.marshall.inceptionImageId`

Immutable image bound exclusively to the Inception development profile; native host eligibility is also required.

Type: `null or string matching the pattern sha256:[0-9a-f]{64}`.

Default:

```nix
null
```


## `services.marshall.inference.aggregateDays`

Daily inference usage retention in days.

Type: `integer between 1 and 36500 (both inclusive)`.

Default:

```nix
365
```


## `services.marshall.inference.detailDays`

Inference request metadata retention in days.

Type: `integer between 1 and 36500 (both inclusive)`.

Default:

```nix
90
```


## `services.marshall.ingress.httpsPort`

Public HTTPS port shared by Audi gateways; used for browser callbacks.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
443
```


## `services.marshall.ingress.inceptionPublicFile`

Operator-owned JSON public Inception issuer, consent, DNS and trust settings, delivered through systemd credentials. Contains no parent credentials. Null leaves public bootstrap disabled.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.ingress.wildcardAcme`

One Marshall instance authorized to issue the public Audi wildcard.

Type: `null or (submodule)`.

Default:

```nix
null
```


## `services.marshall.ingress.wildcardAcme._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.marshall.ingress.wildcardAcme._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshall.ingress.wildcardAcme._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.marshall.ingress.wildcardAcme._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.acceptTerms`

Explicit consent to register an ACME account.

Type: `boolean`.

Default:

```nix
false
```


## `services.marshall.ingress.wildcardAcme.certificateRootsFile`

CA roots validating issued certificate chains.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.directory`

Operator selected ACME directory.

Type: `string matching the pattern https://[^ ]+`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.issuerCaFile`

CA roots authenticating the ACME directory.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.issuerInstance`

Local Marshall instance consuming the certificate queue.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.nameservers`

Authoritative Audi DNS replicas checked before challenge acknowledgement.

Type: `list of (submodule)`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.nameservers.*._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.marshall.ingress.wildcardAcme.nameservers.*._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshall.ingress.wildcardAcme.nameservers.*._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.marshall.ingress.wildcardAcme.nameservers.*._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.ingress.wildcardAcme.nameservers.*.address`

No additional description is declared by the module.

Type: `null or string`.

Default:

```nix
null
```


## `services.marshall.ingress.wildcardAcme.nameservers.*.addressFile`

Runtime file holding the replica's IPv4 address; list its publishing unit in secretUnits.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `services.marshall.ingress.wildcardAcme.nameservers.*.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
53
```


## `services.marshall.ingress.zone`

Delegated Audi application zone, shared by all gateways and DNS replicas. Editor authority requires at least two canonical lowercase DNS labels.

Type: `null or string matching the pattern [a-z0-9][a-z0-9.-]*`.

Default:

```nix
null
```


## `services.marshall.instances`

Local instances keyed by distinct fleet-wide identities.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.marshall.instances.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.marshall.instances.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshall.instances.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.marshall.instances.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.instances.<name>.artifactPort`

Separate artifact content HTTPS port, bound on bindAddress with the backend certificate only when artifactContent.host is set. Opened by openFirewall like port.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
<derived from required configuration>
```


## `services.marshall.instances.<name>.bindAddress`

Literal IPv4 backend bind address.

Type: `string`.

Default:

```nix
"127.0.0.1"
```


## `services.marshall.instances.<name>.certificateFile`

Runtime backend certificate delivered through systemd credentials.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.instances.<name>.fleetBindAddress`

Explicit IPv4 fleet listener address. Remote access requires separate interface-scoped firewall policy.

Type: `string`.

Default:

```nix
"127.0.0.1"
```


## `services.marshall.instances.<name>.fleetLoopback`

Also bind fleet TLS to loopback for colocated clients when the main fleet bind uses a private interface.

Type: `boolean`.

Default:

```nix
false
```


## `services.marshall.instances.<name>.fleetPort`

Separate machine HTTPS port; never opened by openFirewall.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
<derived from required configuration>
```


## `services.marshall.instances.<name>.keyFile`

Runtime backend private key delivered through systemd credentials.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.instances.<name>.port`

Backend HTTPS port.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.instances.<name>.terminalPeerCAFile`

Optional private CA bundle for terminal peer TLS; system roots otherwise.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.instances.<name>.terminalPeerUrl`

Verified HTTPS origin of this instance's fleet listener for terminal peer routing.

Type: `null or string matching the pattern https://[A-Za-z0-9.-]+(:[0-9]+)?/?`.

Default:

```nix
null
```


## `services.marshall.integrations.github.clientId`

Public GitHub OAuth application client identity. Configure together with clientSecretFile and redirectUri.

Type: `null or string matching the pattern [A-Za-z0-9_.-]{1,200}`.

Default:

```nix
null
```


## `services.marshall.integrations.github.clientSecretFile`

Private runtime GitHub OAuth client secret, delivered through systemd credentials.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.integrations.github.redirectUri`

Registered HTTPS GitHub OAuth callback URL.

Type: `null or string matching the pattern https://[A-Za-z0-9.-]+(:[0-9]+)?/auth/github-com/callback`.

Default:

```nix
null
```


## `services.marshall.machineTestFixture`

Marks a disposable NixOS machine-test fixture. Test-only knobs such as artifactContent.debugEcho are refused unless this is set.

Type: `boolean`.

Default:

```nix
false
```


## `services.marshall.marvinPackage`

Immutable unsigned Chrome and Firefox browser extension package served at the public /bin routes. Null disables browser extension downloads.

Type: `null or package`.

Default:

```nix
<derivation overalls-marvin-0.1.0>
```


## `services.marshall.memoryMiB`

Aggregate Marshall memory limit in MiB.

Type: `positive integer, meaning >0`.

Default:

```nix
8192
```


## `services.marshall.notifications.enable`

Send content-free, end-to-end encrypted Mila push pokes through the Susan relay at https://notifications.overalls.dev. When false, device registration is refused with push_disabled and no deliveries are produced.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshall.openFirewall`

Open backend TLS ports; unnecessary for a colocated proxy.

Type: `boolean`.

Default:

```nix
false
```


## `services.marshall.package`

Source-built Marshall release.

Type: `package`.

Default:

```nix
<derivation overalls-marshall-0.1.0>
```


## `services.marshall.poolSize`

Database pool connections per instance.

Type: `integer between 1 and 100 (both inclusive)`.

Default:

```nix
10
```


## `services.marshall.publicHost`

Public DNS name used by sign-in links and origin checks.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.marshall.publicHostFile`

Optional operator-owned runtime public hostname, delivered through systemd credentials. Overrides publicHost; invalid or missing input prevents startup.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.replicaCount`

Total planned Marshall instances across the fleet.

Type: `integer between 1 and 100 (both inclusive)`.

Default:

```nix
3
```


## `services.marshall.secretUnits`

Required preparation services that publish runtime secrets before startup.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.marshall.serperKeyFile`

Private runtime Serper API key, delivered to each Marshall instance through systemd credentials.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.serperOrigin`

Fixed Serper origin; loopback is reserved for the machine-test fixture.

Type: `one of "https://google.serper.dev", "http://127.0.0.1:18080"`.

Default:

```nix
"https://google.serper.dev"
```


## `services.marshall.smtpRelay.enable`

Whether to enable host-local synchronous SMTP forwarding.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.marshall.smtpRelay.from`

Verified envelope and message sender address.

Type: `string`.

Default:

```nix
""
```


## `services.marshall.smtpRelay.maxConnections`

No additional description is declared by the module.

Type: `integer between 1 and 1000 (both inclusive)`.

Default:

```nix
100
```


## `services.marshall.smtpRelay.maxMessageSize`

No additional description is declared by the module.

Type: `integer between 1024 and 10485760 (both inclusive)`.

Default:

```nix
1048576
```


## `services.marshall.smtpRelay.metricsPort`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
9469
```


## `services.marshall.smtpRelay.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
2525
```


## `services.marshall.smtpRelay.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.marshall.smtpRelay.upstream.auth`

No additional description is declared by the module.

Type: `one of "plain", "login"`.

Default:

```nix
"plain"
```


## `services.marshall.smtpRelay.upstream.caFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.marshall.smtpRelay.upstream.host`

No additional description is declared by the module.

Type: `null or string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default:

```nix
null
```


## `services.marshall.smtpRelay.upstream.passwordFile`

No additional description is declared by the module.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.smtpRelay.upstream.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
587
```


## `services.marshall.smtpRelay.upstream.provider`

No additional description is declared by the module.

Type: `one of "generic", "ses", "resend"`.

Default:

```nix
"generic"
```


## `services.marshall.smtpRelay.upstream.region`

No additional description is declared by the module.

Type: `null or string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default:

```nix
null
```


## `services.marshall.smtpRelay.upstream.tls`

No additional description is declared by the module.

Type: `one of "starttls", "implicit"`.

Default:

```nix
"starttls"
```


## `services.marshall.smtpRelay.upstream.usernameFile`

No additional description is declared by the module.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.sshHostCa.keyFile`

Runtime SSH CA private key delivered only to Marshall.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshall.sshHostCa.publicKey`

Dedicated SSH host CA public key.

Type: `null or string matching the pattern ssh-ed25519 [A-Za-z0-9+/]{68}`.

Default:

```nix
null
```


## `services.marshall.sshHostCa.retirement`

SSH CA operational retirement in Unix seconds (2046-09-25).

Type: `positive integer, meaning >0`.

Default:

```nix
2421446400
```


## `services.marshallProxy.acme.caFile`

Trust bundle for the ACME/Route 53 endpoints and issued public certificate.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.marshallProxy.acme.challengeType`

Domain validation method; DNS-01 uses Route 53.

Type: `one of "http-01", "dns-01"`.

Default:

```nix
"http-01"
```


## `services.marshallProxy.acme.email`

ACME account contact email.

Type: `string matching the pattern [a-zA-Z0-9._%+-]+@[a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.acme.enable`

Whether to enable ACME issuance and validated proxy certificate publication.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.marshallProxy.acme.http01.bindAddress`

Local Lego responder IP; use a stable private address when configuring peers.

Type: `string`.

Default:

```nix
"127.0.0.1"
```


## `services.marshallProxy.acme.http01.peers`

Other HTTP-01 issuers for the same hostname on a trusted private network. Configure every frontend with every other issuer.

Type: `list of (submodule)`.

Default:

```nix
[ ]
```


## `services.marshallProxy.acme.http01.peers.*._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.marshallProxy.acme.http01.peers.*._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshallProxy.acme.http01.peers.*._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.marshallProxy.acme.http01.peers.*._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.acme.http01.peers.*.address`

Stable private peer IP (not its public round-robin hostname).

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.acme.http01.peers.*.port`

Peer's Lego responder port.

Type: `integer between 1024 and 65535 (both inclusive)`.

Default:

```nix
9080
```


## `services.marshallProxy.acme.http01.port`

Private Lego responder port, never the public validation port.

Type: `integer between 1024 and 65535 (both inclusive)`.

Default:

```nix
9080
```


## `services.marshallProxy.acme.http01.publicIngress`

Admit port 80 on the proxy address from any source through the fleet perimeter (ADR-0181), so the public CA can reach HTTP-01 challenges. The listener serves only challenges and HTTPS redirects.

Type: `boolean`.

Default:

```nix
false
```


## `services.marshallProxy.acme.minimumValiditySeconds`

Minimum remaining lifetime before a certificate can be published.

Type: `positive integer, meaning >0`.

Default:

```nix
3600
```


## `services.marshallProxy.acme.route53.credentialsFile`

Private AWS shared credentials INI with only the default profile; required for DNS-01.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshallProxy.acme.route53.dnsResolver`

Optional IPv4 recursive DNS resolver or hostname including its port.

Type: `null or string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*:[0-9]{1,5}`.

Default:

```nix
null
```


## `services.marshallProxy.acme.route53.endpoint`

Optional verified HTTPS Route 53 endpoint for isolated fixtures or compatible services.

Type: `null or string matching the pattern https://[a-zA-Z0-9][a-zA-Z0-9.:/-]*`.

Default:

```nix
null
```


## `services.marshallProxy.acme.route53.hostedZoneId`

Route 53 hosted zone authorized for this hostname's TXT challenge; required for DNS-01.

Type: `null or string matching the pattern [A-Z0-9]+`.

Default:

```nix
null
```


## `services.marshallProxy.acme.route53.region`

AWS signing region.

Type: `string matching the pattern [a-z0-9-]+`.

Default:

```nix
"us-east-1"
```


## `services.marshallProxy.acme.secretUnits`

Prerequisites publishing issuer trust or selected DNS credentials before issuance.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.marshallProxy.acme.server`

Verified HTTPS ACME directory.

Type: `string matching the pattern https://[a-zA-Z0-9][a-zA-Z0-9.:/-]*`.

Default:

```nix
"https://acme-v02.api.letsencrypt.org/directory"
```


## `services.marshallProxy.addressEnvironmentFile`

EnvironmentFile carrying the validated runtime address variable for every HAProxy consumer.

Type: `null or string`.

Default:

```nix
null
```


## `services.marshallProxy.addressGuard`

ExecStartPre/ExecReload command refusing a missing or non-canonical runtime address; consumers order it first.

Type: `null or string`.

Default:

```nix
null
```


## `services.marshallProxy.addressUnits`

Units every HAProxy consumer of the proxy address must follow.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.marshallProxy.artifactContent.certificateFile`

Atomically published PEM key and full certificate chain for the content host, readable by the haproxy group. Required with host; ACME sets it when enabled.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.marshallProxy.artifactContent.host`

Lowercase public DNS name of the isolated artifact content origin, served on the same HTTPS listener by SNI and Host. Null routes no content traffic.

Type: `null or lowercase multi-label DNS hostname`.

Default:

```nix
null
```


## `services.marshallProxy.backendCAFile`

CA bundle authenticating Marshall backend certificates.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.marshallProxy.backends`

Marshall TLS endpoints, keyed by backend identity.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.marshallProxy.backends.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.marshallProxy.backends.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshallProxy.backends.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.marshallProxy.backends.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.backends.<name>.address`

Backend IPv4 address or hostname.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.backends.<name>.artifactPort`

Backend artifact content HTTPS port, used only when artifactContent.host is set. Health follows the browser port's readiness check.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
6443
```


## `services.marshallProxy.backends.<name>.port`

Backend HTTPS port.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
4443
```


## `services.marshallProxy.backends.<name>.serverName`

Required certificate hostname and TLS SNI for traffic and health checks.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.bindAddress`

Literal public listener address.

Type: `string`.

Default:

```nix
"0.0.0.0"
```


## `services.marshallProxy.bindAddressFile`

Runtime file holding the explicit listener IPv4 address (for example a decrypted SOPS bundle output), used instead of bindAddress so the address never enters the Nix store. Every HAProxy listener derived from this proxy binds it.

Type: `null or string matching the pattern /run/[A-Za-z0-9_./-]+`.

Default:

```nix
null
```


## `services.marshallProxy.bindAddressUnit`

Unit that publishes bindAddressFile; the proxy address unit follows it.

Type: `null or string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
null
```


## `services.marshallProxy.bindSpec`

HAProxy bind argument for a port on the proxy address: the literal, or the quoted runtime environment reference.

Type: `function that evaluates to a(n) string`.

Default:

```nix
<function>
```


## `services.marshallProxy.certificateFile`

Atomically published PEM key and full certificate chain, readable by the haproxy group.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.enable`

Whether to enable HAProxy HTTPS termination with verified Marshall backends.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.marshallProxy.openFirewall`

Open the public HTTPS port.

Type: `boolean`.

Default:

```nix
true
```


## `services.marshallProxy.port`

Public HTTPS port.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
443
```


## `services.marshallProxy.publicHost`

Public DNS hostname accepted by the proxy.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.marshallProxy.secretUnits`

Required services publishing runtime TLS files before proxy startup.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.overallsAutoUpdate.activationSockets`

Socket activators to quiesce before stopping consumers and restore after activation.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.socket`.

Default:

```nix
[ ]
```


## `services.overallsAutoUpdate.branch`

No additional description is declared by the module.

Type: `string matching the pattern [A-Za-z0-9][A-Za-z0-9._/-]*`.

Default:

```nix
"main"
```


## `services.overallsAutoUpdate.enable`

Whether to enable independent Git-driven host updates with migration and health verification.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsAutoUpdate.enrollmentReceipt`

Host-tool receipt required before polling.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.overallsAutoUpdate.flakeAttr`

Host attribute under nixosConfigurations.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9_-]{0,63}`.

Default: Required when its service or enclosing record is selected.


## `services.overallsAutoUpdate.healthTimeout`

No additional description is declared by the module.

Type: `integer between 10 and 1800 (both inclusive)`.

Default:

```nix
120
```


## `services.overallsAutoUpdate.installationBinding`

Immutable platform, disk and persistent identity bindings.

Type: `null or (attribute set)`.

Default:

```nix
null
```


## `services.overallsAutoUpdate.interval`

No additional description is declared by the module.

Type: `string matching the pattern [1-9][0-9]*(s|min|h)`.

Default:

```nix
"10s"
```


## `services.overallsAutoUpdate.knownHostsFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/etc/ssh/ssh_known_hosts"
```


## `services.overallsAutoUpdate.marshallHealth`

Per-instance TLS health overrides; default uses publicHost and the configured certificate as trust anchor.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.overallsAutoUpdate.marshallHealth.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsAutoUpdate.marshallHealth.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsAutoUpdate.marshallHealth.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsAutoUpdate.marshallHealth.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsAutoUpdate.marshallHealth.<name>.caFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsAutoUpdate.marshallHealth.<name>.serverName`

No additional description is declared by the module.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9.-]*`.

Default: Required when its service or enclosing record is selected.


## `services.overallsAutoUpdate.repository`

Trusted Git repository. HTTPS credentials in URLs are forbidden; local paths support isolated fixtures.

Type: `string matching the pattern (https://[A-Za-z0-9./:_-]+|ssh://[A-Za-z0-9@./:_-]+|[A-Za-z0-9_-]+@[A-Za-z0-9.-]+:[A-Za-z0-9./_-]+|/[^[:space:]]+)`.

Default: Required when its service or enclosing record is selected.


## `services.overallsAutoUpdate.resourcePolicy`

Reviewed live CPU/RAM/quota tuning, bound to immutable storage identity.

Type: `null or (attribute set)`.

Default:

```nix
null
```


## `services.overallsAutoUpdate.secretUnits`

Current-generation preparation dependencies for Git authentication.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.overallsAutoUpdate.sshKeyFile`

No additional description is declared by the module.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.overallsAutoUpdate.verbose`

Retain verbose build output in the private attempt log.

Type: `boolean`.

Default:

```nix
false
```


## `services.overallsBackups.commandTimeoutSeconds`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
7200
```


## `services.overallsBackups.defaults.enable`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsBackups.enable`

Whether to enable host recovery backups with Restic.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsBackups.environmentFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/backup/s3.env"
```


## `services.overallsBackups.excludePaths`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.overallsBackups.extraPaths`

No additional description is declared by the module.

Type: `list of string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
[ ]
```


## `services.overallsBackups.initialize`

Initialize only when Restic positively reports that the repository does not exist.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsBackups.minimumFreeBytes`

Minimum free Lilly pool space before capture and during upload.

Type: `positive integer, meaning >0`.

Default:

```nix
1073741824
```


## `services.overallsBackups.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation restic-0.18.1>
```


## `services.overallsBackups.passwordFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/backup/password"
```


## `services.overallsBackups.postgres.enable`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
false
```


## `services.overallsBackups.postgres.package`

pg_dump/pg_restore tools compatible with Marshall's database server.

Type: `package`.

Default:

```nix
<derivation postgresql-18.6>
```


## `services.overallsBackups.randomizedDelaySec`

Stable per-host random delay in seconds; spreads database and S3 load.

Type: `unsigned integer, meaning >=0`.

Default:

```nix
300
```


## `services.overallsBackups.retention.keepLast`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
12
```


## `services.overallsBackups.s3.bucket`

No additional description is declared by the module.

Type: `string matching the pattern [a-z0-9][a-z0-9.-]{1,61}[a-z0-9]`.

Default: Required when its service or enclosing record is selected.


## `services.overallsBackups.s3.endpoint`

S3 HTTPS endpoint without credentials or trailing slash.

Type: `string matching the pattern https://[a-zA-Z0-9][a-zA-Z0-9.:-]*`.

Default: Required when its service or enclosing record is selected.


## `services.overallsBackups.s3.prefix`

No additional description is declared by the module.

Type: `string matching the pattern [a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)*`.

Default:

```nix
"hosts"
```


## `services.overallsBackups.s3.region`

No additional description is declared by the module.

Type: `string matching the pattern [a-zA-Z0-9-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsBackups.schedule`

No additional description is declared by the module.

Type: `string`.

Default:

```nix
"*-*-* *:00,30:00"
```


## `services.overallsBackups.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[
  "overalls-secrets-backup.service"
]
```


## `services.overallsBackups.uploadLimitKiB`

Upload bandwidth cap in KiB/s; zero means unlimited.

Type: `unsigned integer, meaning >=0`.

Default:

```nix
0
```


## `services.overallsBrowserProbes.instances`

Five-minute real authenticated editor journeys; fixtures and operator sessions are private runtime credentials.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.overallsBrowserProbes.instances.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsBrowserProbes.instances.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsBrowserProbes.instances.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsBrowserProbes.instances.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsBrowserProbes.instances.<name>.enable`

Whether to enable this browser editor probe.

Type: `boolean`.

Default:

```nix
true
```

Example:

```nix
true
```


## `services.overallsBrowserProbes.instances.<name>.fixtureFile`

Private runtime JSON fixture identifying the real operator's guest, origin, UID and existing Markdown probe file.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsBrowserProbes.instances.<name>.storageStateFile`

Private Playwright storage state obtained from a real Marshall operator browser sign-in; no authentication bypass.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsCloudWatch.management.accountId`

No additional description is declared by the module.

Type: `string matching the pattern [0-9]{12}`.

Default: Required when its service or enclosing record is selected.


## `services.overallsCloudWatch.management.alarmActions`

Existing SNS topic ARNs; empty means no notifications.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.overallsCloudWatch.management.credentialsFile`

Management-only AWS credentials. Null uses explicit EC2 role mode.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.overallsCloudWatch.management.enable`

Whether to enable CloudWatch resource reconciliation on the designated environment host.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsCloudWatch.management.environment`

No additional description is declared by the module.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9_-]{0,63}`.

Default:

```nix
"production"
```


## `services.overallsCloudWatch.management.expectedHosts`

Expected machine IDs for missing-heartbeat alarms.

Type: `list of string matching the pattern [a-f0-9]{32}`.

Default:

```nix
[ ]
```


## `services.overallsCloudWatch.management.groups`

Source to group mapping shared with writers; one manager per environment.

Type: `attribute set of string matching the pattern /[A-Za-z0-9_./-]+`.

Default:

```nix
{ }
```


## `services.overallsCloudWatch.management.kmsKeyArn`

No additional description is declared by the module.

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsCloudWatch.management.partition`

No additional description is declared by the module.

Type: `one of "aws", "aws-us-gov", "aws-cn"`.

Default:

```nix
"aws"
```


## `services.overallsCloudWatch.management.queueAlarmBytes`

Per-host queue alarm threshold; align with each writer budget.

Type: `positive integer, meaning >0`.

Default:

```nix
858993459
```


## `services.overallsCloudWatch.management.region`

No additional description is declared by the module.

Type: `string matching the pattern [a-z0-9-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsCloudWatch.management.retentionDays`

No additional description is declared by the module.

Type: `attribute set of (one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653)`.

Default:

```nix
{ }
```


## `services.overallsCloudWatch.management.roleArn`

No additional description is declared by the module.

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsCloudWatch.management.secretUnits`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.overallsCrashDumpRetention.directories`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.overallsFleetExporter.enable`

Whether to enable independent fleet infrastructure Prometheus exporter.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsFleetExporter.externalInterfaces`

Interfaces counted as external network traffic; excludes bridges and taps unless explicitly selected.

Type: `list of string matching the pattern [a-zA-Z0-9][a-zA-Z0-9_.-]{0,14}`.

Default:

```nix
[ ]
```


## `services.overallsFleetExporter.port`

Loopback Prometheus resource exporter; no application credentials or ingestion.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
9466
```


## `services.overallsFleetExporter.roles`

No additional description is declared by the module.

Type: `list of (one of "marshall", "lilly", "audi", "porsche", "ziggy", "galileo", "enrico", "brady", "underclass")`.

Default:

```nix
[ ]
```


## `services.overallsFleetExporter.units`

Explicit platform service units; VM units are discovered by bounded systemd metadata.

Type: `list of string matching the pattern [a-zA-Z0-9_.@:-]+\.service`.

Default:

```nix
[ ]
```


## `services.overallsFleetExporter.zfs`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
false
```


## `services.overallsLogStore.address`

WireGuard fleet IPv4 the entry binds; never a public or wildcard address.

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsLogStore.backendPort`

Loopback-only VictoriaLogs HTTP port.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
9428
```


## `services.overallsLogStore.certificateFile`

Runtime leaf certificate for the fleet entry (full chain).

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogStore.enable`

Whether to enable fleet diagnostic log store (VictoriaLogs) with a path-scoped fleet entry.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsLogStore.entryMemoryMiB`

Memory budget for the authenticated HAProxy fleet entry under backlog recovery.

Type: `positive integer, meaning >0`.

Default:

```nix
256
```


## `services.overallsLogStore.insertPasswordFile`

Runtime insert credential; admits only /insert/* paths.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogStore.keyFile`

Runtime leaf private key for the fleet entry.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogStore.minFreeBytes`

Store refuses ingestion when free disk falls below this many bytes.

Type: `positive integer, meaning >0`.

Default:

```nix
5368709120
```


## `services.overallsLogStore.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
8443
```


## `services.overallsLogStore.readerPasswordFile`

Runtime reader credential; admits only /select/* and health paths.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogStore.retentionDays`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
30
```


## `services.overallsLogStore.secretUnits`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.overallsLogStore.stateDataset`

Optional ZFS dataset mounted at the store state directory with a hard refquota. Uses a static service user (DynamicUser bind-mounts conflict with pre-mounted datasets).

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsLogStore.stateQuotaGiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
20
```


## `services.overallsLogStore.storeCpuPercent`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
200
```


## `services.overallsLogStore.storeMemoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
1024
```


## `services.overallsLogging.aws.credentialsFile`

No additional description is declared by the module.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.overallsLogging.aws.mode`

No additional description is declared by the module.

Type: `one of "none", "ec2", "file"`.

Default:

```nix
"none"
```


## `services.overallsLogging.cpuPercent`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
100
```


## `services.overallsLogging.enable`

Whether to enable host-local Fluent Bit collection and pluggable direct export.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsLogging.environment`

No additional description is declared by the module.

Type: `string matching the pattern [a-zA-Z0-9][a-zA-Z0-9_-]{0,63}`.

Default:

```nix
"production"
```


## `services.overallsLogging.healthAddress`

Loopback or authenticated fleet address for independent health scraping.

Type: `string`.

Default:

```nix
"127.0.0.1"
```


## `services.overallsLogging.healthPort`

Independent logging health metrics; never carries records.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
9467
```


## `services.overallsLogging.journalKeepFreeBytes`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2147483648
```


## `services.overallsLogging.journalMaxBytes`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
1073741824
```


## `services.overallsLogging.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
512
```


## `services.overallsLogging.metricsPort`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
2020
```


## `services.overallsLogging.outputs`

No additional description is declared by the module.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.overallsLogging.outputs.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsLogging.outputs.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsLogging.outputs.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsLogging.outputs.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogging.outputs.<name>.credentialFiles`

Plugin setting names mapped to root-only runtime secret files.

Type: `attribute set of string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
{ }
```


## `services.overallsLogging.outputs.<name>.enable`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsLogging.outputs.<name>.endpoint`

OTLP hostname, without scheme, path or credentials.

Type: `string`.

Default:

```nix
""
```


## `services.overallsLogging.outputs.<name>.groupPrefix`

No additional description is declared by the module.

Type: `string matching the pattern /[A-Za-z0-9_./-]+`.

Default:

```nix
"/overalls/production"
```


## `services.overallsLogging.outputs.<name>.plugin`

Native preset's compiled-in output plugin.

Type: `string matching the pattern [a-z][a-z0-9_]*`.

Default:

```nix
"http"
```


## `services.overallsLogging.outputs.<name>.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
443
```


## `services.overallsLogging.outputs.<name>.queueBytes`

Queue limit per effective output group. Native/OTLP platform sources share a group; CloudWatch sources have separate groups.

Type: `positive integer, meaning >0`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogging.outputs.<name>.region`

No additional description is declared by the module.

Type: `string matching the pattern [a-z0-9-]*`.

Default:

```nix
""
```


## `services.overallsLogging.outputs.<name>.settings`

Non-secret native output settings; routing and queue keys are reserved.

Type: `attribute set of (JSON value)`.

Default:

```nix
{ }
```


## `services.overallsLogging.outputs.<name>.sources`

Explicit sources; audit is never implicitly selected.

Type: `list of (one of "marshall", "lilly", "porsche", "audi", "ziggy", "enrico", "brady", "galileo", "underclass", "haproxy", "audit", "firecracker", "auth", "kernel", "storage", "mail", "operations", "system", "metrics")`.

Default:

```nix
[ ]
```


## `services.overallsLogging.outputs.<name>.type`

No additional description is declared by the module.

Type: `one of "cloudwatch", "otlp", "native"`.

Default: Required when its service or enclosing record is selected.


## `services.overallsLogging.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation fluent-bit-5.0.7>
```


## `services.overallsLogging.queueBudgetBytes`

Host queue budget; selected per-source output limits must fit. Size from measured rate for 24 hours plus 50% headroom.

Type: `positive integer, meaning >0`.

Default:

```nix
1073741824
```


## `services.overallsLogging.sdkMetricsPort`

Loopback-only Fluent Bit numeric application health exporter when fleet telemetry and logging are enabled.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
9468
```


## `services.overallsLogging.secretUnits`

No additional description is declared by the module.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.overallsNixGc.diskThresholdGiB`

Minimum free space in GiB on the filesystem holding /nix. Falling
below it triggers a collection run.


Type: `positive integer, meaning >0`.

Default:

```nix
100
```


## `services.overallsNixGc.enable`

Whether to enable bounded automatic Nix store garbage collection.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsNixGc.interval`

Delay between garbage collection checks. The first check runs one
interval after boot; missed checks are caught up after downtime.


Type: `string matching the pattern [1-9][0-9]*(s|min|h)`.

Default:

```nix
"1h"
```


## `services.overallsNixGc.maxFreedGiB`

Maximum space in GiB a single collection run may delete.

Type: `positive integer, meaning >0`.

Default:

```nix
200
```


## `services.overallsNixGc.preserveGenerations`

Age passed to nix-collect-garbage --delete-older-than. Generations
younger than this are preserved.


Type: `string matching the pattern [1-9][0-9]*[smhd]`.

Default:

```nix
"14d"
```


## `services.overallsOtelFleet.burnAlerts.bearerTokenFile`

Optional private runtime bearer credential for the approved webhook.

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsOtelFleet.burnAlerts.enable`

Whether to enable private Alertmanager delivery of provisional seven-day burn warnings.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsOtelFleet.burnAlerts.webhookUrlFile`

Private runtime file containing the approved HTTPS webhook URL; no plaintext URL enters Nix configuration.

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsOtelFleet.enable`

Whether to enable bounded fleet OpenTelemetry collection.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsOtelFleet.hosts.central`

Host name of this deployment's central telemetry host (fleet address 10.90.0.1).

Type: `string matching the pattern [a-z][a-z0-9-]*`.

Default:

```nix
"overalls"
```


## `services.overallsOtelFleet.hosts.worker`

Host name of this deployment's worker telemetry host (fleet address 10.90.0.2), or null for a single-host deployment.

Type: `null or string matching the pattern [a-z][a-z0-9-]*`.

Default:

```nix
"dungarees"
```


## `services.overallsOtelFleet.metricsRetentionDays`

Prometheus time retention in days; distinct from the seven-day SLO window.

Type: `integer between 7 and 365 (both inclusive)`.

Default:

```nix
90
```


## `services.overallsOtelFleet.publicGrafana.enable`

Whether to enable authenticated public Grafana HTTPS through the existing proxy.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsOtelFleet.publicGrafana.port`

Public Grafana HTTPS port on the Marshall proxy's explicit IPv4 address and hostname.

Type: `integer between 1 and 65535 (both inclusive)`.

Default:

```nix
3443
```


## `services.overallsOtelFleet.role`

Central metrics/traces/Grafana store or worker collector.

Type: `one of "central", "worker"`.

Default: Required when its service or enclosing record is selected.


## `services.overallsOtelFleet.roster`

Telemetry roster derived from hosts: the central host first, then the worker.

Type: `list of string`.

Default:

```nix
[
  "overalls"
  "dungarees"
]
```


## `services.overallsOtelFleet.tempoDataset`

Optional ZFS dataset mounted at /var/lib/tempo with a hard refquota.

Type: `null or string`.

Default:

```nix
null
```


## `services.overallsOtelFleet.tempoQuotaGiB`

No additional description is declared by the module.

Type: `integer between 1 and 100 (both inclusive)`.

Default:

```nix
20
```


## `services.overallsOtelFleet.traceSpool.enable`

Independent per-producer durable trace custody; failures leave producers running.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsOtelFleet.traceSpool.hostBudgetBytes`

Reviewed aggregate per-host producer archive allocation ceiling; evaluation refuses an overcommitted inventory.

Type: `integer between 4194304 and 1099511627776 (both inclusive)`.

Default:

```nix
34359738368
```


## `services.overallsOtelFleet.traceSpool.package`

Reviewed typed OTLP custody implementation.

Type: `package`.

Default:

```nix
<derivation overalls-trace-spool-0.1.0>
```


## `services.overallsOtelFleet.traceSpool.pendingQuotaBytes`

Pending export admission budget per producer, within retained archive budget.

Type: `integer between 262144 and 68719476736 (both inclusive)`.

Default:

```nix
268435456
```


## `services.overallsOtelFleet.traceSpool.producers`

Evaluated producer identity inventory for topology and independent health.

Type: `list of (submodule)`.

Default:

```nix
[ ]
```


## `services.overallsOtelFleet.traceSpool.producers.*._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsOtelFleet.traceSpool.producers.*._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsOtelFleet.traceSpool.producers.*._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsOtelFleet.traceSpool.producers.*._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsOtelFleet.traceSpool.producers.*.instance`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsOtelFleet.traceSpool.producers.*.service`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsOtelFleet.traceSpool.producers.*.user`

No additional description is declared by the module.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsOtelFleet.traceSpool.quotaBytes`

Logical archive/SQLite budget per producer, distinct from Tempo quota. New data refuses when full.

Type: `integer between 4194304 and 68719476736 (both inclusive)`.

Default:

```nix
2147483648
```


## `services.overallsOtelFleet.traceSpool.retentionDays`

Immutable per-batch retention, including traces already acknowledged upstream.

Type: `integer between 1 and 365 (both inclusive)`.

Default:

```nix
90
```


## `services.overallsOtelFleet.traceSpool.traceSampling`

Official parent/trace-ID ratio for routine spans; committed lifecycle diagnostics always sample and SLO accounting is independent.

Type: `signed integer or floating point number`.

Default:

```nix
1.0
```


## `services.overallsOtelFleet.tracesRetentionDays`

Tempo trace retention in days, subject to its monitored storage quota.

Type: `integer between 7 and 365 (both inclusive)`.

Default:

```nix
90
```


## `services.overallsOtelGuest.enable`

Whether to enable bounded guest OTLP intake behind Audi.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsRequestRecorder.instances`

Independent durable request recorders; enabling requires reviewed producer hooks and source-specific deadlines.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.overallsRequestRecorder.instances.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsRequestRecorder.instances.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsRequestRecorder.instances.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsRequestRecorder.instances.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsRequestRecorder.instances.<name>.deadlineSeconds`

Immutable measurement deadline reconciled with this source's request budget.

Type: `integer between 1 and 86400 (both inclusive)`.

Default: Required when its service or enclosing record is selected.


## `services.overallsRequestRecorder.instances.<name>.enable`

Whether to enable this source recorder.

Type: `boolean`.

Default:

```nix
true
```

Example:

```nix
true
```


## `services.overallsRequestRecorder.instances.<name>.environmentSuffix`

Suffix of the producer's socket and marker variables, so one unit can admit to several sources without reading another source's recorder.

Type: `string matching the pattern (_[A-Z0-9]+)*`.

Default:

```nix
""
```


## `services.overallsRequestRecorder.instances.<name>.package`

Pinned Rust request recorder package.

Type: `package`.

Default:

```nix
<derivation overalls-otel-guest-receiver-0.1.0>
```


## `services.overallsRequestRecorder.instances.<name>.producerUnit`

Exact cgroup v2 systemd service allowed to admit requests.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsRequestRecorder.instances.<name>.producerUser`

Expected Unix peer account, including dynamically allocated application users.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.overallsRequestRecorder.instances.<name>.source`

Closed trusted request-source name; physical measurements stay in PostgreSQL.

Type: `one of "marshall_web", "marshall_live", "galileo", "enrico", "brady", "porsche", "audi_private", "audi_dns", "audi_ssh", "vscode_browser_nixos", "vscode_browser_ubuntu"`.

Default: Required when its service or enclosing record is selected.


## `services.overallsSecrets.bundles`

Separate SOPS documents and atomically published application bundles.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.overallsSecrets.bundles.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsSecrets.bundles.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsSecrets.bundles.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsSecrets.bundles.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsSecrets.bundles.<name>.directory`

Canonical runtime directory containing the complete published bundle.

Type: `string`.

Default:

```nix
"/run/overalls-secrets/‹name›"
```


## `services.overallsSecrets.bundles.<name>.encryptedFile`

Root-controlled SOPS-encrypted JSON or YAML document; no plaintext.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.overallsSecrets.bundles.<name>.group`

Read-only recipient group; root uses 0700/0600, other groups 0750/0640.

Type: `string matching the pattern [a-z_][a-z0-9_-]*`.

Default:

```nix
"root"
```


## `services.overallsSecrets.bundles.<name>.outputs`

Files in this bundle; all selected secrets are required.

Type: `attribute set of (submodule)`.

Default: Required when its service or enclosing record is selected.


## `services.overallsSecrets.bundles.<name>.outputs.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.overallsSecrets.bundles.<name>.outputs.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.overallsSecrets.bundles.<name>.outputs.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.overallsSecrets.bundles.<name>.outputs.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.overallsSecrets.bundles.<name>.outputs.<name>.format`

Raw single secret, or a systemd EnvironmentFile of selected values.

Type: `one of "raw", "environment"`.

Default: Required when its service or enclosing record is selected.


## `services.overallsSecrets.bundles.<name>.outputs.<name>.secrets`

SecretSpec names under project overalls-BUNDLE, profile production.

Type: `list of string matching the pattern [A-Z_][A-Z0-9_]*`.

Default:

```nix
[ ]
```


## `services.overallsSecrets.bundles.<name>.unit`

Preparation dependency to add to a consumer's secretUnits.

Type: `string`.

Default:

```nix
"overalls-secrets-‹name›.service"
```


## `services.overallsSecrets.descriptors`

Public preparation descriptors shared with candidate deployment staging.

Type: `attribute set of absolute path`.

Default:

```nix
{ }
```


## `services.overallsSecrets.enable`

Whether to enable SSH-derived age identities and direct SecretSpec/SOPS delivery.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsSecurityAudit.enable`

Whether to enable restricted host audit evidence including command arguments.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.overallsSecurityAudit.extraWatchPaths`

Existing administrative directories; never guest disk trees.

Type: `list of string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
[ ]
```


## `services.peach.caFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.peach.controlPlane`

Verified HTTPS Marshall origin.

Type: `string`.

Default:

```nix
<derived from required configuration>
```


## `services.peach.credentialFile`

Dedicated Peach control credential runtime file.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/peach/control.token"
```


## `services.peach.enable`

Whether to enable guest reflection service behind Audi's private frontend.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.peach.hostId`

Enrolled local Lilly host identity.

Type: `string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default:

```nix
<derived from required configuration>
```


## `services.peach.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-peach-0.1.0>
```


## `services.peach.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.peach.secretsFile`

SOPS document containing PEACH_CREDENTIAL.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.peach.socket`

Unix socket Audi's private frontend forwards reflection.internal to.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/peach/reflection.sock"
```


## `services.porsche.administrativeAccess`

Administrative access path. Console-only deployments must disable administrative OpenSSH.

Type: `one of "openssh", "console"`.

Default:

```nix
"openssh"
```


## `services.porsche.bindAddress`

Static IPv4 listener address for the Porsche SSH listener; null when bindAddressFile supplies it at runtime.

Type: `null or string`.

Default:

```nix
if bindAddressFile == null then "0.0.0.0" else null
```


## `services.porsche.bindAddressFile`

Runtime file under /run holding the canonical IPv4 listener address for the Porsche SSH listener, kept out of the repository and the Nix store.

Type: `null or string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
null
```


## `services.porsche.bindAddressUnit`

Unit that publishes bindAddressFile; the Porsche SSH listener starts after it and stops with it.

Type: `null or string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
null
```


## `services.porsche.caFile`

CA certificates authenticating the Marshall HTTPS endpoint.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.porsche.controlPlane`

Verified HTTPS Marshall origin.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.porsche.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2
```


## `services.porsche.crashDumps.enable`

Whether to enable bounded encrypted OTP crash dumps.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.porsche.crashDumps.publicKeyFile`

Operator RSA public key (at least 3072 bits). Keep its private key off-host.

Type: `null or string matching the pattern /[^
]+`.

Default:

```nix
null
```


## `services.porsche.credentialFile`

Private runtime file containing a separately provisioned Marshall gateway token.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.porsche.enable`

Whether to enable Porsche SSH machine management.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.porsche.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
1024
```


## `services.porsche.openFirewall`

No additional description is declared by the module.

Type: `boolean`.

Default:

```nix
false
```


## `services.porsche.package`

Independent source-built Porsche release.

Type: `package`.

Default:

```nix
<derivation overalls-porsche-0.1.0>
```


## `services.porsche.port`

No additional description is declared by the module.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
22
```


## `services.porsche.publicOrigin`

Public HTTPS origin for browser key approval.

Type: `string`.

Default: Required when its service or enclosing record is selected.


## `services.porsche.secretUnits`

Credential preparation services required before startup.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.susan.apnsTopics`

Accepted APNs topics (Mila bundle identifiers).

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.susan.bind`

Listener address behind the TLS-terminating proxy.

Type: `string`.

Default:

```nix
"127.0.0.1"
```


## `services.susan.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
2
```


## `services.susan.database.createLocally`

Create a local PostgreSQL database and peer-authenticated role named susan.

Type: `boolean`.

Default:

```nix
true
```


## `services.susan.enable`

Whether to enable the Susan push relay for content-free Mila notifications (ADR-0224).

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.susan.fcmAppIds`

Accepted FCM application identifiers.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.susan.limits`

Optional token-bucket overrides keyed by key, install, source, global or issue.

Type: `attribute set of (submodule)`.

Default:

```nix
{ }
```


## `services.susan.limits.<name>._module.args`

Additional arguments passed to each module in addition to ones
like `lib`, `config`,
and `pkgs`, `modulesPath`.

This option is also available to all submodules. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules. The sole exception to
this is the argument `name` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:
- {var}`lib`: The nixpkgs library.
- {var}`config`: The results of all options after merging the values from all modules together.
- {var}`options`: The options declared in all modules.
- {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
- All attributes of {var}`specialArgs`

  Whereas option values can generally depend on other option values
  thanks to laziness, this does not apply to `imports`, which
  must be computed statically before anything else.

  For this reason, callers of the module system can provide `specialArgs`
  which are available during import resolution.

  For NixOS, `specialArgs` includes
  {var}`modulesPath`, which allows you to import
  extra modules from the nixpkgs package tree without having to
  somehow make the module aware of the location of the
  `nixpkgs` or NixOS directories.
  ```
  { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
    ];
  }
  ```

For NixOS, the default value for this option includes at least this argument:
- {var}`pkgs`: The nixpkgs package set according to
  the {option}`nixpkgs.pkgs` option.


Type: `lazy attribute set of raw value`.

Default:

```nix
{ }
```


## `services.susan.limits.<name>._module.check`

Whether to check whether all option definitions have matching declarations.

Type: `boolean`.

Default:

```nix
true
```


## `services.susan.limits.<name>._module.freeformType`

If set, merge all definitions that don't have an associated option
together using this type. The result then gets combined with the
values of all declared options to produce the final `
config` value.

If this is `null`, definitions without an option
will throw an error unless {option}`_module.check` is
turned off.


Type: `null or optionType`.

Default:

```nix
null
```


## `services.susan.limits.<name>._module.specialArgs`

Externally provided module arguments that can't be modified from
within a configuration, but can be used in module imports.


Type: `unspecified value`.

Default: Required when its service or enclosing record is selected.


## `services.susan.limits.<name>.burst`

No additional description is declared by the module.

Type: `integer between 1 and 100000 (both inclusive)`.

Default: Required when its service or enclosing record is selected.


## `services.susan.limits.<name>.per_hour`

No additional description is declared by the module.

Type: `integer between 1 and 10000000 (both inclusive)`.

Default: Required when its service or enclosing record is selected.


## `services.susan.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
1024
```


## `services.susan.package`

Susan OTP release.

Type: `package`.

Default:

```nix
<derivation overalls-susan-0.1.0>
```


## `services.susan.port`

Plain HTTP listener port; TLS terminates at the fronting proxy.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
4100
```


## `services.susan.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.susan.secretsFile`

SOPS document secrets/overalls-susan.enc.json with the six Susan secrets.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.


## `services.susan.trustedProxies`

Peers whose last X-Forwarded-For hop is believed for per-source rate limits.

Type: `list of string`.

Default:

```nix
[
  "127.0.0.1"
]
```


## `services.susan.wnsAppIds`

Accepted WNS application identifiers (Mila's MSIX identity). Non-empty requires WNS_TENANT_ID, WNS_CLIENT_ID and WNS_CLIENT_SECRET in the secrets bundle.

Type: `list of string`.

Default:

```nix
[ ]
```


## `services.underclass.egress.enable`

Whether to enable a dedicated userspace Tailscale node whose loopback HTTP proxy can carry
Underclass upstream traffic. The node starts logged out; an operator joins it
once with `sudo underclass-egress up`.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.underclass.egress.exitNode`

Tailnet exit node (MagicDNS name or Tailscale IP) that all Underclass upstream
traffic leaves through. Setting it implies `route`. Null with `route` keeps
traffic behind the egress node's proxy but leaves from the host's own address,
and every Underclass start clears any stale exit-node preference.


Type: `null or string matching the pattern [A-Za-z0-9][A-Za-z0-9.:-]*`.

Default:

```nix
null
```

Example:

```nix
"mac-mini"
```


## `services.underclass.egress.proxyPort`

Loopback port of the egress node's outbound HTTP proxy.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
1055
```


## `services.underclass.egress.route`

Send all Underclass upstream traffic through the egress node's loopback proxy.
Underclass then reaches only loopback and refuses to start until the egress node
is logged in with the configured exit-node preference (`exitNode`, or none).


Type: `boolean`.

Default:

```nix
config.services.underclass.egress.exitNode != null
```


## `services.underclass.egress.tags`

Tailscale ACL tags the egress node advertises whenever an operator joins it with
`underclass-egress up` or `login`. The tailnet policy must let the joining
identity own each tag.


Type: `non-empty (list of string matching the pattern tag:[a-z0-9][a-z0-9-]*)`.

Default:

```nix
[
  "tag:underclass"
]
```


## `services.underclass.enable`

Whether to enable independent host-local Underclass subscription pool.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.underclass.environmentFile`

Runtime environment file containing UNDERCLASS_PROXY_KEY and UNDERCLASS_UI_TOKEN.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/underclass/environment"
```


## `services.underclass.package`

Pinned Underclass package.

Type: `package`.

Default:

```nix
<derivation underclass-0.1.0-d7a0ccf>
```


## `services.underclass.port`

Loopback HTTP port. Underclass is never bound directly to a fleet interface.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
8080
```


## `services.underclass.secretUnits`

Secret preparation units required before Underclass starts.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.underclass.tailscaleServe.enable`

Publish the loopback service through tailnet-only Tailscale Serve HTTPS.

Type: `boolean`.

Default:

```nix
true
```


## `services.underclass.tailscaleServe.httpsPort`

Tailnet HTTPS port reserved for Underclass on this host.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`.

Default:

```nix
443
```


## `services.ziggy.agentEnable`

Poll Marshall for host-bound agent model calls.

Type: `boolean`.

Default:

```nix
false
```


## `services.ziggy.anthropicKeyFile`

Private runtime Anthropic API key file.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/ziggy/anthropic.key"
```


## `services.ziggy.caFile`

No additional description is declared by the module.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"<store>/nss-cacert-3.126/etc/ssl/certs/ca-bundle.crt"
```


## `services.ziggy.configurationFile`

Release-independent runtime configuration; null uses the deployed configuration.

Type: `null or absolute path`.

Default:

```nix
null
```


## `services.ziggy.controlPlane`

Verified HTTPS Marshall origin.

Type: `string`.

Default:

```nix
<derived from required configuration>
```


## `services.ziggy.cpuCores`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
4
```


## `services.ziggy.credentialFile`

Dedicated Ziggy control credential runtime file.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/ziggy/control.token"
```


## `services.ziggy.enable`

Whether to enable private node-local inference proxy.

Type: `boolean`.

Default:

```nix
false
```

Example:

```nix
true
```


## `services.ziggy.enabledProviders`

Nonempty set of providers enabled for discovery and inference; readiness requires all selected catalogs.

Type: `list of (one of "openai", "anthropic")`.

Default:

```nix
[
  "openai"
  "anthropic"
]
```


## `services.ziggy.githubBootstrapRelease`

Immutable executor artifacts for fenced retained-machine GitHub tools bootstrap.

Type: `null or package`.

Default:

```nix
<derivation overalls-executor-bootstrap-v1>
```


## `services.ziggy.githubToolsRelease`

Immutable managed GitHub CLI and LFS release for fenced guest maintenance.

Type: `null or package`.

Default:

```nix
<derivation overalls-github-tools-release-v1>
```


## `services.ziggy.hostId`

Enrolled local Lilly host identity.

Type: `string matching the pattern [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`.

Default:

```nix
<derived from required configuration>
```


## `services.ziggy.lyraRelease`

Trusted local Overalls CLI artifacts for private guest updates.

Type: `package`.

Default:

```nix
<derivation lyra-0.1.0>
```


## `services.ziggy.maxPendingRequests`

No additional description is declared by the module.

Type: `integer between 1 and 100000 (both inclusive)`.

Default:

```nix
65536
```


## `services.ziggy.memoryMiB`

No additional description is declared by the module.

Type: `positive integer, meaning >0`.

Default:

```nix
4096
```


## `services.ziggy.openaiKeyFile`

Private runtime OpenAI-compatible proxy key file.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default:

```nix
"/run/overalls-secrets/ziggy/openai.key"
```


## `services.ziggy.openaiOrigin`

Fixed OpenAI-compatible origin; enrolled hosts use host-local Underclass.

Type: `one of "https://api.openai.com", "http://127.0.0.1:8080"`.

Default:

```nix
"https://api.openai.com"
```


## `services.ziggy.package`

No additional description is declared by the module.

Type: `package`.

Default:

```nix
<derivation overalls-ziggy-0.1.0>
```


## `services.ziggy.secretUnits`

No additional description is declared by the module.

Type: `list of string matching the pattern [a-zA-Z0-9_.@-]+\.service`.

Default:

```nix
[ ]
```


## `services.ziggy.secretsFile`

SOPS document containing ZIGGY_CREDENTIAL, OPENAI_API_KEY and ANTHROPIC_API_KEY.

Type: `string matching the pattern /[a-zA-Z0-9_./:+-]+`.

Default: Required when its service or enclosing record is selected.
