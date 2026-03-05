import 'user.dart';

/// freezed を使った状態管理モデル
class AppState {
  const AppState({required this.user, this.isLoading = false});
  final User user;
  final bool isLoading;
}
