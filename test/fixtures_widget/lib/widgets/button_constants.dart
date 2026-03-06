// test/fixtures_widget/lib/widgets/button_constants.dart
// ignore: unused_import
import 'button.dart';

/// button.dart を import しているが AppButton Widget は使わないファイル。
/// button.dart の定数やユーティリティのみ参照するケースを模擬。
///
/// Widget モードでは button.dart の変更が Widget 使用エッジのみで伝搬するため、
/// AppButton を使わないこのファイルは影響範囲から除外される。
const defaultLabel = 'OK';
