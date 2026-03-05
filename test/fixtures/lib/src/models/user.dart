import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// json_serializable を使ったモデル
@JsonSerializable()
class User {
  const User({required this.name, required this.email});
  final String name;
  final String email;
}
