import '../models/theme_data.dart' if (dart.library.html) '../models/theme_data_web.dart';

class PlatformHelper {
  static int get color => AppTheme.primaryColor;
}
