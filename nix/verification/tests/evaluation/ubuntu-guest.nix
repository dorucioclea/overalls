{ pkgs, packages }:
let
  builder = packages.mkUbuntuGuest;
  codingClis = import ../../../domains/artifacts/guest/coding-clis.nix { inherit pkgs; };
  source = pkgs.writeText "ubuntu-config-test" "fixture";
  accepts = args: (builtins.tryEval (builder args).drvPath).success;
  invalidFiles = [
    "/etc/../passwd" "/etc//app" "etc/app" "/etc/systemd/system/lilly-network.service"
    "/etc/shadow" "/usr/local/lib/lilly-network.py" "/etc/resolv.conf"
    "/etc/bash.bashrc" "/etc/profile.d/overalls-starship.sh"
  ];
  lock = builtins.fromJSON (builtins.readFile ../../../domains/artifacts/guest/ubuntu/packages.lock.json);
  lockFile = changes: builtins.toFile "invalid-ubuntu-lock.json" (builtins.toJSON (lock // changes));
  python = pkgs.python3.withPackages (p: [ p.hypothesis ]);
  inherit (pkgs) lib;
  # @cc [owner:ghuntley,label:verification] ubuntu-workspace-receiver-present
  # The private-service Ubuntu image MUST install and enable overalls-workspaced
  # from the Lyra build, trust /workspace checkouts in the system git config,
  # and MUST NOT make the receiver a readiness dependency (ADR-0128).
  privateImage = builder { privateServiceRoots = [ ../../../../secrets/brady-root.pem ]; };
  baseImage = builder { };
  # Store-path context is irrelevant to these textual builder checks.
  plain = builtins.unsafeDiscardStringContext;
  rootfsScript = plain privateImage.rootfs.buildCommand;
  # @cc [owner:ghuntley,label:verification;build] ubuntu-guest-db-canonicalization-gate
  # The cheap image evaluation gate MUST keep the sandboxed normalization call
  # in the real rootfs builder and exercise its paths/reference-preserving
  # refusal tests. This is not a substitute for rebuilding the complete image
  # twice and comparing the content-addressed artifacts on both hosts.
  normalizeNixDb = plain
    "python3 ${../../../domains/artifacts/guest/ubuntu/normalize_nix_db.py} \"$root/nix/var/nix/db/db.sqlite\"";
  workspaceUnit = builtins.readFile ../../../domains/artifacts/guest/ubuntu/units/overalls-workspace.service;
  unitLines = lib.splitString "\n" workspaceUnit;
  requiredUnits = builtins.filter (line: lib.hasInfix "LILLY_REQUIRED_UNITS" line)
    (lib.splitString "\n" rootfsScript);
in
# @cc [owner:ghuntley,label:verification] ubuntu-starship-global-startup
# The Ubuntu image MUST install locked Bash and Starship, default new users to
# Bash, and wire the same initializer into login and non-login shell startup.
assert builtins.elem "bash" lock.requested && builtins.elem "starship" lock.requested;
assert builtins.any (entry: entry.name == "starship") lock.packages;
assert lib.hasInfix "useradd --defaults --shell /bin/bash" rootfsScript;
assert lib.hasInfix
  (plain "install -D -m 0644 ${../../../domains/artifacts/guest/ubuntu/starship.sh} \"$root/etc/profile.d/overalls-starship.sh\"")
  rootfsScript;
assert lib.hasInfix ". /etc/profile.d/overalls-starship.sh" rootfsScript;
assert lib.hasInfix
  (plain "install -D -m 0755 ${packages.lyraLinux}/bin/overalls-workspaced \"$root/usr/local/bin/overalls-workspaced\"")
  rootfsScript;
assert lib.hasInfix
  "ln -sf ../overalls-workspace.service \"$root/etc/systemd/system/multi-user.target.wants/overalls-workspace.service\""
  rootfsScript;
assert lib.hasInfix "directory = /workspace/*" rootfsScript;
assert lib.hasInfix "ln -sf /dev/null \"$root/etc/systemd/system/serial-getty@.service\"" rootfsScript;
assert lib.hasInfix "ln -sf /dev/null \"$root/etc/systemd/system/console-getty.service\"" rootfsScript;
assert lib.hasInfix "lilly-console-ready" rootfsScript;
assert lib.hasInfix "systemd.getty_auto=0" (plain privateImage.buildCommand);
# v4 declaration follows service activation, rather than binary installation.
assert privateImage.workspaceSourceEnabled;
assert !baseImage.workspaceSourceEnabled;
assert lib.hasInfix "--argjson workspace_source_version '2'" (plain privateImage.buildCommand);
assert lib.hasInfix "--argjson workspace_source_version 'null'" (plain baseImage.buildCommand);
assert lib.hasInfix "version:4" (plain privateImage.buildCommand);
# guest-quiet-serial-console and ubuntu-prebuilt-platform-trust (ADR-0154).
assert lib.hasInfix "printk.time=1 quiet loglevel=3 systemd.show_status=error" (plain privateImage.buildCommand);
assert lib.hasInfix "overalls-platform/overalls-0.crt" rootfsScript;
assert lib.hasInfix "experimental-features = nix-command flakes" (builtins.readFile privateImage.nixConfig);
assert lib.hasInfix
  (plain "install -D -m 0644 ${privateImage.nixConfig} \"$root/etc/nix/nix.conf\"")
  rootfsScript;
assert lib.hasInfix "platform_digest.py" rootfsScript;
assert lib.hasInfix "lilly-boot-report" rootfsScript;
assert lib.hasInfix normalizeNixDb rootfsScript;
assert requiredUnits != [ ] && !(lib.any (line: lib.hasInfix "overalls-workspace" line) requiredUnits);
assert builtins.elem "ExecStart=/usr/local/bin/overalls-workspaced ubuntu" unitLines;
assert builtins.elem "After=overalls-guest-trust.service" unitLines;
assert !(lib.any (line: lib.hasPrefix "Before=" line || lib.hasPrefix "RequiredBy=" line) unitLines);
assert accepts { files."/etc/myapp/config.json" = { inherit source; }; };
assert accepts { privateServiceRoots = [ ../../../../secrets/brady-root.pem ]; };
assert !accepts { packages = [ "hello" ]; };
assert !accepts { packages = [ "--allow-unauthenticated" ]; };
assert !accepts { packageLock = lockFile { packages = [ ]; }; };
assert !accepts { packageLock = lockFile { version = 2; }; };
assert !accepts { packageLock = lockFile { packages = [ ((builtins.head lock.packages) // { sha256 = "invalid"; }) ]; }; };
assert !accepts { minimumMemoryBytes = 1; };
assert !accepts { minimumMemoryBytes = 536870912.5; };
assert !accepts { files."/etc/myapp/config" = { inherit source; mode = "4777"; }; };
assert pkgs.lib.all (path: !accepts { files.${path} = { inherit source; }; }) invalidFiles;
assert pkgs.lib.getName packages.ubuntuGuest.ubuntuDevelopmentTools
  == "ubuntu-guest-development-tools";
# @cc [owner:ghuntley,label:verification;build] ubuntu-native-coding-cli-closure
# The real Ubuntu builder MUST install native Ziggy settings and login/PAM CA
# trust, link both packaged clients from its registered development closure,
# and retain that closure's GC root. Package presence alone does not establish
# inference compatibility or native guest execution.
assert lib.hasInfix "for command in devenv codex claude gh git-lfs; do" rootfsScript;
assert lib.hasInfix
  (plain "ln -s ${privateImage.ubuntuDevelopmentTools}/bin/$command \"$root/usr/local/bin/$command\"")
  rootfsScript;
assert lib.hasInfix
  (plain "ln -s ${privateImage.ubuntuDevelopmentTools} \"$root/nix/var/nix/gcroots/ubuntu-guest-development-tools\"")
  rootfsScript;
assert lib.hasInfix
  (plain "install -D -m 0644 ${codingClis.codexConfiguration} \"$root/etc/codex/config.toml\"")
  rootfsScript;
assert lib.hasInfix
  (plain "install -D -m 0644 ${codingClis.claudeConfiguration} \"$root/etc/claude-code/managed-settings.json\"")
  rootfsScript;
assert lib.hasInfix
  (plain "install -D -m 0644 ${codingClis.loginEnvironment} \"$root/etc/profile.d/overalls-coding-clis.sh\"")
  rootfsScript;
assert lib.hasInfix (plain "cat ${codingClis.pamEnvironment} >> \"$root/etc/environment\"") rootfsScript;
pkgs.runCommand "ubuntu-guest-unit-properties" { nativeBuildInputs = [ python ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  export PYTHONPATH=${../../../domains/artifacts/guest/ubuntu}
  test -x ${packages.lyraLinux}/bin/overalls-workspaced
  test -f ${../../../domains/artifacts/guest/ubuntu/units/overalls-workspace.service}
  test -x ${packages.ubuntuGuest.ubuntuDevelopmentTools}/bin/codex
  test -x ${packages.ubuntuGuest.ubuntuDevelopmentTools}/bin/claude
  python3 ${./ubuntu-guest.py} ${../../../domains/artifacts/guest}
  python3 ${../../../domains/artifacts/guest/ubuntu/test_normalize_nix_db.py}
  touch $out
''
