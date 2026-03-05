import '../models/app_state.dart';

/// ユーザー情報を表示するカード（AppState → User に依存）
class UserCard {
  const UserCard({required this.state});
  final AppState state;
}
