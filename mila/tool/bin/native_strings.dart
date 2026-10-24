// `dart run bin/native_strings.dart [--check]`: writes the Windows runner's
// notification strings header from the app's ARB catalogs, or with `--check`
// fails when the committed header is stale.
import 'dart:io' as io;

import 'package:mila_build/native_strings.dart';

Future<void> main(List<String> arguments) async {
  final check = arguments.contains('--check');
  if (arguments.any((a) => a != '--check')) {
    io.stderr.writeln('usage: native_strings [--check]');
    io.exit(64);
  }
  final root = _repositoryRoot();
  final texts = <NotificationText>[];
  final catalogs = io.Directory('$root/mila/localization/catalogs').listSync().whereType<io.File>();
  try {
    for (final file in catalogs) {
      final locale = localeOf(file.uri.pathSegments.last);
      if (locale != null) texts.add(readCatalog(locale, await file.readAsString()));
    }
    final header = renderHeader(texts);
    final target = io.File('$root/$headerPath');
    if (check) {
      if (!target.existsSync() || await target.readAsString() != header) {
        io.stderr.writeln('$headerPath is stale; run dart run bin/native_strings.dart');
        io.exit(1);
      }
      io.stdout.writeln('$headerPath is current (${texts.length} locales)');
    } else {
      await target.writeAsString(header);
      io.stdout.writeln('wrote $headerPath (${texts.length} locales)');
    }
  } on CatalogError catch (error) {
    io.stderr.writeln('native_strings: $error');
    io.exit(1);
  }
}

/// The checkout holding `flake.nix` and `mila/`, found from this script.
String _repositoryRoot() {
  var directory = io.File.fromUri(io.Platform.script).parent;
  while (true) {
    if (io.File('${directory.path}/flake.nix').existsSync() &&
        io.Directory('${directory.path}/mila').existsSync()) {
      return directory.path;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) throw StateError('no repository root above the script');
    directory = parent;
  }
}
