import 'package:uuid/uuid.dart';

class SessionManager {
  static const _uuid = Uuid();

  static String generateSessionId() => _uuid.v4();
}
