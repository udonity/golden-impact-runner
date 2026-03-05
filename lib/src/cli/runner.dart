import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../analyzer/dependency_graph.dart';
import '../analyzer/golden_test_detector.dart';
import '../git/diff_provider.dart';

enum OutputFormat { text, json }

class RunnerConfig {
  const RunnerConfig({
    required this.projectRoot,
    this.baseBranch = 'origin/main',
    this.head = 'HEAD',
    this.changedFiles = const [],
    this.format = OutputFormat.text,
    this.verbose = false,
  });

  final String projectRoot;
  final String baseBranch;
  final String head;
  final List<String> changedFiles;
  final OutputFormat format;
  final bool verbose;
}

/// Main orchestrator: ties together diff, graph, and detection.
class Runner {
  Future<int> run(RunnerConfig config) async {
    final projectRoot = p.normalize(p.absolute(config.projectRoot));

    // 1. Resolve package name from pubspec.yaml
    final packageName = _readPackageName(projectRoot);
    if (packageName == null) {
      stderr.writeln('Error: Could not read package name from pubspec.yaml');
      return 1;
    }

    if (config.verbose) {
      stderr.writeln('Project: $packageName ($projectRoot)');
    }

    // 2. Get changed files
    Set<String> changedFiles;
    if (config.changedFiles.isNotEmpty) {
      final diffProvider = DiffProvider(projectRoot);
      changedFiles = diffProvider.resolveExplicitFiles(config.changedFiles);
    } else {
      final diffProvider = DiffProvider(projectRoot);
      try {
        changedFiles = await diffProvider.getChangedDartFiles(
          baseBranch: config.baseBranch,
          head: config.head,
        );
      } on DiffException catch (e) {
        stderr.writeln('Error: $e');
        return 1;
      }
    }

    if (changedFiles.isEmpty) {
      if (config.verbose) {
        stderr.writeln('No changed .dart files found.');
      }
      return 0;
    }

    if (config.verbose) {
      stderr.writeln('Changed files (${changedFiles.length}):');
      for (final f in changedFiles) {
        stderr.writeln('  ${p.relative(f, from: projectRoot)}');
      }
    }

    // 3. Build dependency graph
    final graph = DependencyGraph.build(
      projectRoot: projectRoot,
      packageName: packageName,
    );

    if (config.verbose) {
      stderr.writeln(
        'Dependency graph: ${graph.allFiles.length} files, '
        '${graph.dependsOn.values.fold<int>(0, (sum, s) => sum + s.length)} edges',
      );
    }

    // 4. Find all impacted files via BFS
    final impactedFiles = graph.findImpactedFiles(changedFiles);

    if (config.verbose) {
      stderr.writeln('Impacted files (${impactedFiles.length}):');
      for (final f in impactedFiles) {
        stderr.writeln('  ${p.relative(f, from: projectRoot)}');
      }
    }

    // 5. Filter to golden tests
    final detector = GoldenTestDetector(projectRoot);
    final goldenTests = detector.filterGoldenTests(impactedFiles);

    // 6. Output
    if (config.format == OutputFormat.json) {
      final output = {
        'changed_files': changedFiles
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort(),
        'impacted_files': impactedFiles
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort(),
        'golden_tests': goldenTests
            .map((f) => p.relative(f, from: projectRoot))
            .toList()
          ..sort(),
      };
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
    } else {
      final sorted = goldenTests
          .map((f) => p.relative(f, from: projectRoot))
          .toList()
        ..sort();
      for (final test in sorted) {
        stdout.writeln(test);
      }
    }

    return 0;
  }

  String? _readPackageName(String projectRoot) {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;

    final content = pubspecFile.readAsStringSync();
    // Simple regex to extract name from pubspec.yaml without yaml dependency
    final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(
      content,
    );
    return match?.group(1)?.replaceAll(RegExp(r"""^['"]|['"]$"""), '');
  }
}
