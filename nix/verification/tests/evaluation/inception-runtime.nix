{ pkgs, toolchain }:
pkgs.runCommand "inception-runtime-check" { nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.cryptography ])) pkgs.openssl pkgs.git toolchain.elixir ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  export ERL_FLAGS="+S 2:2"
  # Release eval scripts are outside Mix's compilation scope. Parse every script
  # with the pinned runtime before accepting this configuration check.
  elixir -e '
    [directory] = System.argv()
    for path <- Path.wildcard(Path.join(directory, "*.exs")) do
      Code.string_to_quoted!(File.read!(path), file: path)
    end
  ' ${../../../domains/artifacts/guest/inception}
  python3 -W error ${./marshall-public-host.py} ${../../../domains/system/marshall-public-host.py}
  python3 -W error ${./marshall-default-image.py} ${../../../domains/system/marshall-default-image.py}
  python3 -W error ${./inception-runtime.py} ${../../../domains/artifacts/guest/inception/runtime.py}
  python3 -W error ${./inception-git-identity.py} ${../../../domains/artifacts/guest/inception/git_identity.py}
  python3 -W error ${./inception-publication.py} ${../../../domains/artifacts/guest/inception}
  python3 -W error ${./inception-observations.py} ${../../../domains/artifacts/guest/inception}
  python3 -W error ${./inception-control-proofs.py} ${../../../domains/artifacts/guest/inception} ${../../../../protocol/test/fixtures/inception_public.json}
  python3 -W error ${./inception-control-tls.py} ${../../../domains/artifacts/guest/inception} ${../../../domains/system/acme/publish.py} ${pkgs.openssl}/bin/openssl ${pkgs.haproxy}/bin/haproxy ${../../../../protocol/test/fixtures/inception_public.json}
  python3 -W error ${./inception-control-worker.py} ${../../../domains/artifacts/guest/inception} ${../../../../protocol/test/fixtures/inception_public.json}
  python3 -W error ${./inception-public-settings.py} ${../../../domains/artifacts/guest/inception} ${../../../../protocol/test/fixtures/inception_public.json}
  python3 -W error ${./inception-ingress.py} ${../../../domains/artifacts/guest/inception} ${../../../domains/artifacts/guest/flush.py}
  python3 -W error ${./inception-credentials.py} ${../../../domains/artifacts/guest/inception}
  python3 -W error ${./inception-private-pki.py} ${../../../domains/artifacts/guest/inception} ${../../../../audi/priv/private_pki}
  python3 -W error ${./inception-ziggy.py} ${../../../domains/artifacts/guest/inception}
  python3 -W error ${./inception-private-runtime.py} ${../../../domains/artifacts/guest/inception}
  python3 -W error ${./inception-prepare.py} ${../../../domains/artifacts/guest/inception} ${pkgs.openssl}/bin/openssl ${pkgs.git}/bin/git
  touch $out
''
