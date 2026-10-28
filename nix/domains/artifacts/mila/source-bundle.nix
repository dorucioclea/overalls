# Native Mila source bundle. Inputs: mila/native/android, mila/native/apple, mila/native/linux, mila/rust/Cargo.lock, SHA256SUMS. It contains only Rust, GTK, Compose, Swift,
# WinUI/.NET and shared localization inputs; no Dart or Flutter sources.
{ pkgs, root, version }:
pkgs.runCommand "mila-source-bundle-${version}" {} ''
  name=mila-source-bundle-${version}
  b="$PWD/$name"
  mkdir -p "$b/mila/native" "$b/mila/rust" "$b/mila/windows-dotnet" "$b/mila/localization/catalogs"
  cp -r ${root}/native/. "$b/mila/native/"
  cp -r ${root}/rust/. "$b/mila/rust/"
  cp -r ${root}/windows-dotnet/. "$b/mila/windows-dotnet/"
  cp ${root}/localization/generate_catalogs.py "$b/mila/localization/generate_catalogs.py"
  cp ${root}/localization/catalogs/*.arb "$b/mila/localization/catalogs/"
  mkdir -p "$b/protocol/test/fixtures"
  for f in app_routes machine_states porsche_client_results push_pokes ssh_command_lines ssh_host_certificates terminal_attach; do
    cp ${../../../../protocol/test/fixtures}/$f.json "$b/protocol/test/fixtures/$f.json"
  done
  cat > "$b/flake.nix" <<'EOT'
  { outputs = _: { }; }
  EOT
  (cd "$b" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
  mkdir -p $out
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu -cf - "$name" | gzip -n -9 > $out/$name.tar.gz
  (cd $out && sha256sum $name.tar.gz > SHA256SUMS)
''
