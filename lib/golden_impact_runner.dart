/// Flutter Golden Test の影響解析ツール。
///
/// コード変更の影響を受ける Golden Test を、
/// 依存グラフを構築・走査して検出する。
library;

export 'src/analyzer/dependency_graph.dart';
export 'src/analyzer/golden_test_detector.dart';
export 'src/analyzer/import_parser.dart';
export 'src/git/diff_provider.dart';
