/// Flutter Golden Test impact analysis tool.
///
/// Detects which Golden Tests are affected by code changes
/// by building a dependency graph and traversing it.
library;

export 'src/analyzer/dependency_graph.dart';
export 'src/analyzer/golden_test_detector.dart';
export 'src/analyzer/import_parser.dart';
export 'src/git/diff_provider.dart';
