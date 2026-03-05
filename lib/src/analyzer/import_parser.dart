import 'dart:io';

import 'package:path/path.dart' as p;

/// Parses Dart import/export/part directives from file contents
/// and resolves them to absolute file paths.
class ImportParser {
  ImportParser(this.projectRoot, this.packageName);

  final String projectRoot;
  final String packageName;

  // Matches: import 'x'; export 'x';
  static final _importExportPattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  // Matches: part 'x'; but NOT part of 'x';
  // Uses negative lookahead to exclude `part of`.
  static final _partPattern = RegExp(
    r'''^\s*part\s+(?!of\b)['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Extract all import/export/part URIs from Dart source content.
  List<String> extractDependencyUris(String content) {
    final uris = <String>[];

    for (final match in _importExportPattern.allMatches(content)) {
      uris.add(match.group(1)!);
    }

    for (final match in _partPattern.allMatches(content)) {
      uris.add(match.group(1)!);
    }

    return uris;
  }

  /// Resolve an import URI to an absolute file path, or null if it should be
  /// ignored (e.g. dart: SDK imports, external packages).
  String? resolveUri(String uri, String currentFilePath) {
    // Ignore SDK imports
    if (uri.startsWith('dart:')) return null;

    // Package import for this project
    if (uri.startsWith('package:$packageName/')) {
      final relativePath = uri.substring('package:$packageName/'.length);
      return p.normalize(p.join(projectRoot, 'lib', relativePath));
    }

    // External package imports — ignore
    if (uri.startsWith('package:')) return null;

    // Relative import
    final dir = p.dirname(currentFilePath);
    return p.normalize(p.join(dir, uri));
  }

  /// Parse a single file and return all resolved dependency paths.
  Set<String> parseDependencies(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return {};

    final content = file.readAsStringSync();
    final uris = extractDependencyUris(content);
    final resolved = <String>{};

    for (final uri in uris) {
      final path = resolveUri(uri, filePath);
      if (path != null) {
        resolved.add(path);
      }
    }

    return resolved;
  }
}
