// test/fixtures_widget/lib/widgets/button_constants.dart
import 'button.dart';

/// button.dart を import しているが AppButton Widget は使わないファイル。
/// button.dart の定数やユーティリティのみ参照するケースを模擬。
///
/// Widget モードでは button.dart の変更が Widget 使用エッジのみで伝搬するため、
/// AppButton を使わないこのファイルは影響範囲から除外される。
const defaultLabel = 'OK';

// ignore: unused_import を回避するための参照（実際には Widget を生成しない）
Type get buttonType => AppButton;
